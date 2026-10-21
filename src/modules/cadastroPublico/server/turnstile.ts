/**
 * SysMúsica — Confere o token do Cloudflare Turnstile (anti-robô) NO SERVIDOR.
 * Falha fechada: sem a chave secreta, sem resposta da Cloudflare ou com token inválido, o envio é recusado.
 * Variável: TURNSTILE_SECRET_KEY (secreta, só no servidor). Teste local: 1x0000000000000000000000000000000AA.
 */
import "server-only";
import { ErroHttp } from "@/modules/administracao/server/erros";

const URL_VERIFICACAO = "https://challenges.cloudflare.com/turnstile/v0/siteverify";

export async function verificarTurnstile(token: unknown, ip: string | null): Promise<void> {
  const segredo = process.env.TURNSTILE_SECRET_KEY;
  if (!segredo) {
    console.error("TURNSTILE_SECRET_KEY ausente: o cadastro público está desligado.");
    throw new ErroHttp(503, "O cadastro está indisponível no momento. Tente novamente mais tarde.");
  }
  if (typeof token !== "string" || token === "" || token.length > 2048) {
    throw new ErroHttp(400, "Confirme a verificação de segurança e tente de novo.");
  }
  const corpo = new URLSearchParams({ secret: segredo, response: token });
  if (ip) corpo.set("remoteip", ip);

  let sucesso = false;
  try {
    const resposta = await fetch(URL_VERIFICACAO, {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: corpo,
      signal: AbortSignal.timeout(8000),
    });
    const json = (await resposta.json()) as { success?: boolean };
    sucesso = resposta.ok && json.success === true;
  } catch (e) {
    console.error("Falha ao consultar o Turnstile:", e);
    throw new ErroHttp(503, "Não foi possível validar a verificação de segurança. Tente novamente.");
  }
  if (!sucesso) throw new ErroHttp(400, "A verificação de segurança falhou. Recarregue a página e tente de novo.");
}
