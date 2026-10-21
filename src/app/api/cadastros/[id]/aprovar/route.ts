/**
 * SysMúsica — POST /api/cadastros/[id]/aprovar: aprova um cadastro pendente.
 *
 * Fluxo (precisa da permissão cadastros.aprovar e da abrangência, conferidas no banco):
 *  1) lê o pedido como o usuário (confirma que ele existe, está PENDENTE e é visível para quem aprova);
 *  2) MOVE as 3 imagens da fila para as pastas finais do membro (fotos-membros / documentos-membros);
 *  3) chama aprovar_cadastro_pendente COMO O USUÁRIO (cria/atualiza o membro e registra quem aprovou);
 *  4) se o banco recusar, DEVOLVE as imagens à fila; se aprovar, apaga as imagens antigas (atualização).
 */
import { NextResponse } from "next/server";
import { exigirPermissao } from "@/modules/administracao/server/autorizacao";
import { clienteAdmin } from "@/modules/administracao/server/clienteAdmin";
import { ErroHttp } from "@/modules/administracao/server/erros";
import { respostaDeErro } from "@/modules/administracao/server/resposta";
import { apagar, desfazer, moverTodos, movimentosDaAprovacao } from "@/modules/cadastroPublico/server/arquivos";
import { erroDoBanco, exigirUuid } from "@/modules/cadastroPublico/server/erros";
import { clienteDoUsuario } from "@/modules/cadastroPublico/server/usuario";

interface Detalhe {
  casa_oracao_id: string | null;
  tipo: "NOVO" | "ATUALIZACAO";
  status: string;
  membro_id: string | null;
  arquivos_disponiveis: boolean;
  atual: unknown;
}

interface ResultadoAprovacao {
  membro_id: string;
  antigos: { foto?: string | null; doc_frente?: string | null; doc_verso?: string | null };
}

export async function POST(request: Request, contexto: { params: Promise<{ id: string }> }) {
  try {
    const id = exigirUuid((await contexto.params).id);
    await exigirPermissao(request, "cadastros.aprovar");
    const usuario = clienteDoUsuario(request);

    // Corpo opcional: { casa_id } — a Casa de Oração escolhida por quem aprova (pedido com casa digitada)
    let casaId: string | null = null;
    try {
      const corpo = (await request.json()) as { casa_id?: unknown } | null;
      if (corpo && corpo.casa_id !== undefined && corpo.casa_id !== null && corpo.casa_id !== "") casaId = exigirUuid(corpo.casa_id);
    } catch (e) {
      if (e instanceof ErroHttp) throw e; // id inválido: devolve o erro
      casaId = null; // sem corpo / corpo vazio: segue sem casa escolhida
    }

    const { data, error } = await usuario.rpc("obter_cadastro_pendente", { p_id: id });
    if (error) throw erroDoBanco(error);
    const pedido = data as Detalhe;
    if (pedido.status !== "PENDENTE") throw new ErroHttp(409, "Este cadastro já foi analisado.");
    if (!pedido.arquivos_disponiveis) throw new ErroHttp(409, "As imagens deste cadastro não estão mais disponíveis. Recuse o pedido.");
    if (!pedido.casa_oracao_id && !casaId) {
      throw new ErroHttp(400, "Este pedido trouxe uma Casa de Oração que não está cadastrada. Escolha a casa correta antes de aprovar.");
    }
    if (pedido.tipo === "ATUALIZACAO" && !pedido.atual) {
      throw new ErroHttp(409, "O membro deste pedido foi excluído. Recuse o pedido.");
    }

    // Atualização usa a pasta do membro existente; cadastro novo ganha um id novo (que o banco usa no INSERT)
    const membroId = pedido.tipo === "ATUALIZACAO" && pedido.membro_id ? pedido.membro_id : crypto.randomUUID();
    const mov = movimentosDaAprovacao(id, membroId, () => crypto.randomUUID());

    const admin = clienteAdmin();
    let feitos;
    try {
      feitos = await moverTodos(admin, [mov.foto, mov.frente, mov.verso]);
    } catch (e) {
      console.error("Falha ao mover as imagens do cadastro", id, e);
      throw new ErroHttp(409, "Não foi possível preparar as imagens. Atualize a lista e tente de novo.");
    }

    const { data: resultado, error: erroAprovar } = await usuario.rpc("aprovar_cadastro_pendente", {
      p_id: id,
      p_membro: pedido.tipo === "NOVO" ? membroId : null,
      p_foto: mov.foto.para.caminho,
      p_doc_frente: mov.frente.para.caminho,
      p_doc_verso: mov.verso.para.caminho,
      p_casa: pedido.casa_oracao_id ? null : casaId, // só vale quando o pedido não tem casa
    });
    if (erroAprovar) {
      await desfazer(admin, feitos); // o banco recusou: as imagens voltam para a fila
      throw erroDoBanco(erroAprovar);
    }

    // Atualização: apaga a foto e o documento que foram substituídos
    const antigos = (resultado as ResultadoAprovacao).antigos ?? {};
    await apagar(admin, "fotos-membros", [antigos.foto]);
    await apagar(admin, "documentos-membros", [antigos.doc_frente, antigos.doc_verso]);

    return NextResponse.json({ membro_id: (resultado as ResultadoAprovacao).membro_id }, { headers: { "Cache-Control": "no-store" } });
  } catch (erro) {
    return respostaDeErro(erro);
  }
}
