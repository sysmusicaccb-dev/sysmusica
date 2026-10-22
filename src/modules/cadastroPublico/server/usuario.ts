/**
 * Sysmusica — Cliente Supabase "como o usuário logado" para as rotas do servidor.
 * Necessário quando a função do banco usa auth.uid() (aprovar cadastro grava quem aprovou na auditoria).
 * O token vem no cabeçalho Authorization (a sessão do navegador não usa cookies).
 */
import { createClient, type SupabaseClient } from "@supabase/supabase-js";
import { ErroHttp } from "@/modules/administracao/server/erros";

export function clienteDoUsuario(request: Request): SupabaseClient {
  const cabecalho = request.headers.get("authorization") ?? "";
  const token = cabecalho.toLowerCase().startsWith("bearer ") ? cabecalho.slice(7).trim() : "";
  if (!token) throw new ErroHttp(401, "Sessão ausente. Entre novamente.");

  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const chavePublica = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;
  if (!url || !chavePublica) {
    console.error("Variáveis públicas do Supabase ausentes no servidor.");
    throw new ErroHttp(500, "Servidor sem a configuração do banco de dados.");
  }
  return createClient(url, chavePublica, {
    auth: { persistSession: false, autoRefreshToken: false },
    global: { headers: { Authorization: `Bearer ${token}` } },
  });
}
