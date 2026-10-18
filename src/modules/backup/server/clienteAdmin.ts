/**
 * SysMúsica — Cliente do Supabase com a chave SECRETA (service role). Só existe no servidor: nunca importe
 * este arquivo em um componente de tela. Ele ignora as políticas de acesso, por isso toda rota confere a
 * permissão do usuário (autorizacao.ts) antes de usá-lo.
 */
import { createClient, type SupabaseClient } from "@supabase/supabase-js";
import { ErroBackup } from "./erros";

export function clienteAdmin(): SupabaseClient {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const chave = process.env.SUPABASE_SERVICE_ROLE_KEY;
  if (!url || !chave) {
    throw new ErroBackup(500, "O servidor não está configurado: faltam as variáveis de acesso ao Supabase.");
  }
  return createClient(url, chave, { auth: { persistSession: false, autoRefreshToken: false } });
}
