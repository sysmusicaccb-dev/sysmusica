/**
 * SysMúsica — Chamadas do navegador às rotas /api/backup/agendamento. Cada chamada leva o token do login
 * (o servidor confere a sessão e a permissão).
 */
import { supabase } from "@/lib/supabase";
import type { AgendamentoPublico, ConfigAgendamento } from "../agendamento";

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

export async function obterAgendamento(): Promise<AgendamentoPublico> {
  return (await chamar<{ agendamento: AgendamentoPublico }>("/api/backup/agendamento", "GET")).agendamento;
}

export async function salvarAgendamento(config: ConfigAgendamento): Promise<AgendamentoPublico> {
  return (await chamar<{ agendamento: AgendamentoPublico }>("/api/backup/agendamento", "PUT", config)).agendamento;
}

export function executarRotinaAgora(): Promise<{ mensagem: string }> {
  return chamar<{ mensagem: string }>("/api/backup/agendamento/executar", "POST");
}
