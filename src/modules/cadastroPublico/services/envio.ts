/**
 * SysMúsica — Serviço do cadastro público (navegador, SEM login).
 *
 * Fluxo do envio (em 2 etapas, porque a Vercel limita o corpo de cada pedido a 4,5 MB):
 *  1) /api/cadastro-publico/iniciar: confere o Turnstile (anti-robô) e devolve endereços de envio de uso único;
 *  2) o navegador envia foto e documento direto para o armazenamento privado "cadastro-publico";
 *  3) /api/cadastro-publico/enviar: grava os dados. Nada entra em "membros" aqui: vira um pedido a ser aprovado.
 */
import { supabase } from "@/lib/supabase";
import type { CargaCadastroPublico, OpcoesCadastroPublico } from "../regras";

const BUCKET = "cadastro-publico";
const MENSAGEM_PADRAO = "Não foi possível enviar o cadastro agora. Tente novamente em alguns minutos.";

interface EnderecoDeEnvio {
  caminho: string;
  token: string;
}

interface RespostaIniciar {
  envio_id: string;
  foto: EnderecoDeEnvio;
  frente: EnderecoDeEnvio;
  verso: EnderecoDeEnvio;
}

/** Lê o JSON da resposta; se o servidor mandou uma mensagem de erro, repassa. */
async function lerResposta<T>(resposta: Response): Promise<T> {
  let corpo: unknown = null;
  try {
    corpo = await resposta.json();
  } catch {
    /* resposta sem JSON: cai na mensagem padrão */
  }
  if (!resposta.ok) {
    const msg = (corpo as { erro?: unknown } | null)?.erro;
    throw new Error(typeof msg === "string" && msg !== "" ? msg : MENSAGEM_PADRAO);
  }
  return corpo as T;
}

/** Cargos, instrumentos, famílias e Casas de Oração para o formulário (função pública do banco). */
export async function carregarOpcoes(): Promise<OpcoesCadastroPublico> {
  const { data, error } = await supabase.rpc("opcoes_cadastro_publico");
  if (error || !data) throw new Error("Não foi possível carregar o formulário. Atualize a página e tente de novo.");
  const o = data as Partial<OpcoesCadastroPublico>;
  return {
    cargos: o.cargos ?? [],
    instrumentos: o.instrumentos ?? [],
    familias: o.familias ?? [],
    casas: o.casas ?? [],
  };
}

async function enviarArquivo(endereco: EnderecoDeEnvio, arquivo: Blob): Promise<void> {
  const { error } = await supabase.storage.from(BUCKET).uploadToSignedUrl(endereco.caminho, endereco.token, arquivo, {
    contentType: "image/jpeg",
  });
  if (error) throw new Error("Não foi possível enviar as imagens. Confira a conexão e tente de novo.");
}

/** Faz o envio completo. `tokenTurnstile` vem do componente anti-robô. */
export async function enviarCadastroPublico(
  carga: CargaCadastroPublico,
  arquivos: { foto: Blob; frente: Blob; verso: Blob },
  tokenTurnstile: string
): Promise<void> {
  const inicio = await lerResposta<RespostaIniciar>(
    await fetch("/api/cadastro-publico/iniciar", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ turnstile: tokenTurnstile, site: carga.site }),
    })
  );

  await enviarArquivo(inicio.foto, arquivos.foto);
  await enviarArquivo(inicio.frente, arquivos.frente);
  await enviarArquivo(inicio.verso, arquivos.verso);

  await lerResposta<{ ok: true }>(
    await fetch("/api/cadastro-publico/enviar", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ envio_id: inicio.envio_id, dados: carga }),
    })
  );
}
