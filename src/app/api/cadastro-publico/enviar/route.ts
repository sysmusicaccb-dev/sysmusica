/**
 * Sysmusica — POST /api/cadastro-publico/enviar (PÚBLICA, sem login): passo 2 do envio do Cadastro Musical.
 *
 * Recebe o id do envio (criado no passo 1) e os dados do formulário. O banco refaz TODAS as conferências
 * (CPF, cargo, instrumento, menor de idade, aceite da LGPD, limite por CPF...) e grava um pedido PENDENTE.
 * A resposta é sempre a mesma ({ ok: true }), exista ou não um cadastro anterior com o CPF.
 */
import { NextResponse } from "next/server";
import { clienteAdmin } from "@/modules/administracao/server/clienteAdmin";
import { ErroHttp } from "@/modules/administracao/server/erros";
import { respostaDeErro } from "@/modules/administracao/server/resposta";
import { erroDoBanco, exigirUuid } from "@/modules/cadastroPublico/server/erros";
import { avisarNovoCadastro } from "@/modules/cadastroPublico/server/avisoTelegram";
import { extrairIp, hashDoIp } from "@/modules/cadastroPublico/server/ip";

const TAMANHO_MAXIMO = 30_000; // caracteres; o formulário real fica bem abaixo disso

export async function POST(request: Request) {
  try {
    const texto = await request.text();
    if (texto.length > TAMANHO_MAXIMO) throw new ErroHttp(413, "Pedido grande demais.");
    let corpo: { envio_id?: unknown; dados?: unknown } | null = null;
    try {
      corpo = JSON.parse(texto) as { envio_id?: unknown; dados?: unknown };
    } catch {
      corpo = null;
    }
    if (!corpo || typeof corpo !== "object") throw new ErroHttp(400, "Pedido inválido.");
    const envioId = exigirUuid(corpo.envio_id);
    if (!corpo.dados || typeof corpo.dados !== "object" || Array.isArray(corpo.dados)) {
      throw new ErroHttp(400, "Pedido inválido.");
    }

    const sal = process.env.CADASTRO_PUBLICO_SALT ?? process.env.SUPABASE_SERVICE_ROLE_KEY ?? "";
    const ipHash = hashDoIp(extrairIp(request.headers), sal);
    const { error } = await clienteAdmin().rpc("registrar_cadastro_publico", {
      p_envio: envioId,
      p_dados: corpo.dados,
      p_ip_hash: ipHash,
    });
    if (error) throw erroDoBanco(error);
    await avisarNovoCadastro(); // Telegram (se ligado em Backup > Notificações); nunca derruba o cadastro
    return NextResponse.json({ ok: true }, { headers: { "Cache-Control": "no-store" } });
  } catch (erro) {
    return respostaDeErro(erro);
  }
}
