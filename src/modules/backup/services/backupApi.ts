/**
 * SysMúsica — Chamadas do navegador às rotas /api/backup. Cada chamada leva o token do login (o servidor
 * confere a sessão e a permissão). Nada de chave secreta passa por aqui.
 */
import { supabase } from "@/lib/supabase";
import type { ResultadoVerificacao } from "../regras";
import type { RegistroBackup, RespostaFazerBackup } from "../tipos";

async function chamar<T>(caminho: string, metodo: "GET" | "POST" | "DELETE" = "GET", corpo?: unknown): Promise<T> {
  const { data } = await supabase.auth.getSession();
  const token = data.session?.access_token;
  if (!token) throw new Error("Sua sessão expirou. Entre de novo.");

  const resposta = await fetch(caminho, {
    method: metodo,
    headers: { Authorization: `Bearer ${token}`, ...(corpo !== undefined ? { "Content-Type": "application/json" } : {}) },
    body: corpo !== undefined ? JSON.stringify(corpo) : undefined,
    cache: "no-store",
  });
  const json = (await resposta.json().catch(() => null)) as { erro?: string } | null;
  if (!resposta.ok) throw new Error(json?.erro ?? "Não foi possível concluir a operação.");
  return json as T;
}

export async function listarBackups(): Promise<RegistroBackup[]> {
  return (await chamar<{ backups: RegistroBackup[] }>("/api/backup")).backups;
}

export function fazerBackup(observacao: string | null): Promise<RespostaFazerBackup> {
  return chamar<RespostaFazerBackup>("/api/backup", "POST", { observacao });
}

/** Link temporário (60 segundos) para baixar o arquivo criptografado. */
export async function obterUrlDeDownload(id: string): Promise<string> {
  return (await chamar<{ url: string }>(`/api/backup/${id}/baixar`, "POST")).url;
}

export function verificarBackup(id: string): Promise<ResultadoVerificacao> {
  return chamar<ResultadoVerificacao>(`/api/backup/${id}/verificar`, "POST");
}

export async function excluirBackup(id: string): Promise<void> {
  await chamar<{ ok: true }>(`/api/backup/${id}`, "DELETE");
}
