/**
 * Sysmusica — GET /api/cadastros/[id]/arquivos: endereços TEMPORÁRIOS (5 min) das imagens de um cadastro pendente.
 *
 * Quem chama precisa de cadastros.visualizar e enxergar a Casa de Oração do pedido (o banco confere em
 * obter_cadastro_pendente). A fotografia vai para quem passou nisso; a FRENTE e o VERSO do documento só vão
 * para quem também tem a permissão membros.cpf (mesma regra do documento do membro).
 */
import { NextResponse } from "next/server";
import { clienteAdmin } from "@/modules/administracao/server/clienteAdmin";
import { respostaDeErro } from "@/modules/administracao/server/resposta";
import { BUCKET_PUBLICO, caminhosNaFila } from "@/modules/cadastroPublico/server/arquivos";
import { erroDoBanco, exigirUuid } from "@/modules/cadastroPublico/server/erros";
import { clienteDoUsuario } from "@/modules/cadastroPublico/server/usuario";

const VALIDADE_SEGUNDOS = 300;

export async function GET(request: Request, contexto: { params: Promise<{ id: string }> }) {
  try {
    const id = exigirUuid((await contexto.params).id);
    const usuario = clienteDoUsuario(request);

    const { data: detalhe, error } = await usuario.rpc("obter_cadastro_pendente", { p_id: id });
    if (error) throw erroDoBanco(error);
    const cabecalhos = { "Cache-Control": "no-store" };
    if (!(detalhe as { arquivos_disponiveis?: boolean }).arquivos_disponiveis) {
      return NextResponse.json({ disponivel: false }, { headers: cabecalhos });
    }

    const { data: podeDocumento } = await usuario.rpc("tem_permissao", { p_codigo: "membros.cpf" });
    const caminhos = caminhosNaFila(id);
    const pedidos = [caminhos.foto, ...(podeDocumento === true ? [caminhos.frente, caminhos.verso] : [])];

    const { data: urls, error: erroUrls } = await clienteAdmin().storage.from(BUCKET_PUBLICO).createSignedUrls(pedidos, VALIDADE_SEGUNDOS);
    if (erroUrls || !urls) throw new Error(`Endereços não criados: ${erroUrls?.message ?? ""}`);
    const urlDe = (caminho: string) => urls.find((u) => u.path === caminho)?.signedUrl ?? null;

    return NextResponse.json(
      {
        disponivel: true,
        foto: urlDe(caminhos.foto),
        frente: podeDocumento === true ? urlDe(caminhos.frente) : null,
        verso: podeDocumento === true ? urlDe(caminhos.verso) : null,
        documentos_liberados: podeDocumento === true,
      },
      { headers: cabecalhos }
    );
  } catch (erro) {
    return respostaDeErro(erro);
  }
}
