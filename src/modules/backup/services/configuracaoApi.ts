/**
 * SysMúsica — Chamadas do navegador às rotas /api/backup/configuracao. Cada chamada leva o token do login
 * (o servidor confere a sessão e a permissão). Tokens e senhas só trafegam daqui para o servidor, ao salvar;
 * nada secreto volta na resposta.
 */
import { supabase } from "@/lib/supabase";
import type { ChatTelegram, ConfiguracaoPublica, Destinatario, EntradaConfiguracao } from "../configuracao";

async function chamar<T>(caminho: string, metodo: "GET" | "POST" | "PUT" | "PATCH" | "DELETE", corpo?: unknown): Promise<T> {
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

export async function obterConfiguracao(): Promise<ConfiguracaoPublica> {
  return (await chamar<{ configuracao: ConfiguracaoPublica }>("/api/backup/configuracao", "GET")).configuracao;
}

export async function salvarConfiguracao(entrada: EntradaConfiguracao): Promise<ConfiguracaoPublica> {
  return (await chamar<{ configuracao: ConfiguracaoPublica }>("/api/backup/configuracao", "PUT", entrada)).configuracao;
}

export async function adicionarDestinatario(email: string): Promise<Destinatario[]> {
  return (await chamar<{ destinatarios: Destinatario[] }>("/api/backup/configuracao/destinatarios", "POST", { email })).destinatarios;
}

export async function alterarDestinatario(id: string, ativo: boolean): Promise<Destinatario[]> {
  return (await chamar<{ destinatarios: Destinatario[] }>(`/api/backup/configuracao/destinatarios/${id}`, "PATCH", { ativo })).destinatarios;
}

export async function removerDestinatario(id: string): Promise<Destinatario[]> {
  return (await chamar<{ destinatarios: Destinatario[] }>(`/api/backup/configuracao/destinatarios/${id}`, "DELETE")).destinatarios;
}

export function testarAviso(canal: "telegram" | "email"): Promise<{ detalhe: string }> {
  return chamar<{ detalhe: string }>("/api/backup/configuracao/testar", "POST", { canal });
}

export async function buscarChats(): Promise<ChatTelegram[]> {
  return (await chamar<{ chats: ChatTelegram[] }>("/api/backup/configuracao/telegram-chats", "POST")).chats;
}
