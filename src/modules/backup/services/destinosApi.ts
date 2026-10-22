/**
 * Sysmusica — Chamadas do navegador às rotas /api/backup/destinos. Cada chamada leva o token do login (o servidor
 * confere a sessão e a permissão). Client Secret e chave de assinatura só trafegam daqui para o servidor, ao salvar;
 * nada secreto volta na resposta.
 */
import { supabase } from "@/lib/supabase";
import type { DestinoPublico, EntradaDestino } from "../destinos";

async function chamar<T>(caminho: string, metodo: "GET" | "POST" | "PUT", corpo?: unknown): Promise<T> {
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

export async function obterDestino(): Promise<DestinoPublico> {
  return (await chamar<{ destino: DestinoPublico }>("/api/backup/destinos", "GET")).destino;
}

export async function salvarDestino(entrada: EntradaDestino): Promise<DestinoPublico> {
  return (await chamar<{ destino: DestinoPublico }>("/api/backup/destinos", "PUT", entrada)).destino;
}

export function testarDestino(): Promise<{ detalhe: string }> {
  return chamar<{ detalhe: string }>("/api/backup/destinos/testar", "POST");
}

export function enviarMaisRecente(): Promise<{ detalhe: string }> {
  return chamar<{ detalhe: string }>("/api/backup/destinos/enviar", "POST");
}
