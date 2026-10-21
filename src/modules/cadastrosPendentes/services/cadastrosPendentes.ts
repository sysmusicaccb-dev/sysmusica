/**
 * SysMúsica — Serviço da tela "Cadastros pendentes". Listar, abrir, contar e recusar passam por funções do banco
 * (que conferem permissão e abrangência). Aprovar e ver as imagens passam por rotas do servidor, porque mexem
 * no armazenamento privado com a chave de serviço.
 */
import { supabase } from "@/lib/supabase";
import { mensagemDoErro } from "@/lib/erros";
import type { ArquivosDoCadastro, DetalheCadastro, FiltroStatus, ResumoCadastro } from "../tipos";

/** Avisa o contador do menu que a fila mudou (aprovar, recusar). */
export const EVENTO_FILA_MUDOU = "sysmusica:cadastros-mudaram";
export function avisarQueFilaMudou(): void {
  if (typeof window !== "undefined") window.dispatchEvent(new Event(EVENTO_FILA_MUDOU));
}

export async function listarCadastros(status: FiltroStatus): Promise<ResumoCadastro[]> {
  const { data, error } = await supabase.rpc("listar_cadastros_pendentes", { p_status: status });
  if (error) throw new Error(mensagemDoErro(error, "Não foi possível carregar os cadastros."));
  return ((data ?? []) as ResumoCadastro[]).map((linha) => ({ ...linha, outros_pendentes: Number(linha.outros_pendentes ?? 0) }));
}

export async function obterCadastro(id: string): Promise<DetalheCadastro> {
  const { data, error } = await supabase.rpc("obter_cadastro_pendente", { p_id: id });
  if (error) throw new Error(mensagemDoErro(error, "Não foi possível abrir o cadastro."));
  if (!data) throw new Error("Não foi possível abrir o cadastro."); // sem erro, mas sem dados (ex.: fora da sua abrangência)
  const d = data as DetalheCadastro;
  return { ...d, outros_pendentes: Number(d.outros_pendentes ?? 0) };
}

/** Quantos pedidos esperam análise (0 para quem não tem permissão; nunca lança erro). */
export async function contarPendentes(): Promise<number> {
  const { data, error } = await supabase.rpc("contar_cadastros_pendentes");
  if (error) return 0;
  return Number(data ?? 0);
}

export async function recusarCadastro(id: string, motivo: string): Promise<void> {
  const { error } = await supabase.rpc("rejeitar_cadastro_pendente", { p_id: id, p_motivo: motivo });
  if (error) throw new Error(mensagemDoErro(error, "Não foi possível recusar o cadastro."));
  avisarQueFilaMudou();
}

/** Chama uma rota do servidor levando o token do login. */
async function chamar<T>(caminho: string, metodo: "GET" | "POST", corpo?: unknown): Promise<T> {
  const { data } = await supabase.auth.getSession();
  const token = data.session?.access_token;
  if (!token) throw new Error("Sua sessão expirou. Entre de novo.");
  const resposta = await fetch(caminho, {
    method: metodo,
    headers: { Authorization: `Bearer ${token}`, ...(corpo === undefined ? {} : { "Content-Type": "application/json" }) },
    body: corpo === undefined ? undefined : JSON.stringify(corpo),
    cache: "no-store",
  });
  const json = (await resposta.json().catch(() => null)) as { erro?: string } | null;
  if (!resposta.ok) throw new Error(json?.erro ?? "Não foi possível concluir a operação.");
  return json as T;
}

export function arquivosDoCadastro(id: string): Promise<ArquivosDoCadastro> {
  return chamar<ArquivosDoCadastro>(`/api/cadastros/${id}/arquivos`, "GET");
}

/** `casaId`: obrigatório quando o pedido veio com uma Casa de Oração digitada (que não estava cadastrada). */
export async function aprovarCadastro(id: string, casaId?: string): Promise<{ membro_id: string }> {
  const r = await chamar<{ membro_id: string }>(`/api/cadastros/${id}/aprovar`, "POST", casaId ? { casa_id: casaId } : {});
  avisarQueFilaMudou();
  return r;
}
