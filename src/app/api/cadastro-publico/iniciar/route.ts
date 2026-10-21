/**
 * SysMúsica — POST /api/cadastro-publico/iniciar (PÚBLICA, sem login): passo 1 do envio do Cadastro Musical.
 *
 * 1) confere o campo-armadilha e o Turnstile (anti-robô) no servidor;
 * 2) o banco confere o limite de envios por IP e cria o id do envio;
 * 3) devolve 3 endereços de envio de uso único (foto, frente e verso) para o navegador mandar as imagens
 *    direto ao armazenamento privado (a Vercel limita o corpo de cada pedido a 4,5 MB).
 * Nada é gravado em "membros".
 */
import { NextResponse } from "next/server";
import { clienteAdmin } from "@/modules/administracao/server/clienteAdmin";
import { ErroHttp } from "@/modules/administracao/server/erros";
import { respostaDeErro } from "@/modules/administracao/server/resposta";
import { BUCKET_PUBLICO, caminhosNaFila } from "@/modules/cadastroPublico/server/arquivos";
import { erroDoBanco } from "@/modules/cadastroPublico/server/erros";
import { extrairIp, hashDoIp } from "@/modules/cadastroPublico/server/ip";
import { verificarTurnstile } from "@/modules/cadastroPublico/server/turnstile";

export async function POST(request: Request) {
  try {
    const corpo = (await request.json().catch(() => null)) as { turnstile?: unknown; site?: unknown } | null;
    if (!corpo || typeof corpo !== "object") throw new ErroHttp(400, "Pedido inválido.");
    // Campo-armadilha preenchido = robô. Mensagem genérica, sem explicar.
    if (typeof corpo.site === "string" && corpo.site.trim() !== "") {
      throw new ErroHttp(400, "Não foi possível enviar o cadastro. Atualize a página e tente de novo.");
    }

    const ip = extrairIp(request.headers);
    await verificarTurnstile(corpo.turnstile, ip);

    const admin = clienteAdmin();
    const sal = process.env.CADASTRO_PUBLICO_SALT ?? process.env.SUPABASE_SERVICE_ROLE_KEY ?? "";
    const { data, error } = await admin.rpc("iniciar_envio_publico", { p_ip_hash: hashDoIp(ip, sal) });
    if (error || typeof data !== "string") throw erroDoBanco(error ?? { message: "Envio não criado." });

    const caminhos = caminhosNaFila(data);
    const enderecos: Record<string, { caminho: string; token: string }> = {};
    for (const [nome, caminho] of Object.entries(caminhos)) {
      const { data: url, error: erroUrl } = await admin.storage.from(BUCKET_PUBLICO).createSignedUploadUrl(caminho);
      if (erroUrl || !url) throw new Error(`Endereço de envio não criado: ${erroUrl?.message ?? ""}`);
      enderecos[nome] = { caminho, token: url.token };
    }
    return NextResponse.json({ envio_id: data, ...enderecos }, { headers: { "Cache-Control": "no-store" } });
  } catch (erro) {
    return respostaDeErro(erro);
  }
}
