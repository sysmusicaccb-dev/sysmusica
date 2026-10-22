/**
 * Sysmusica — Cliente Supabase (conexão com o banco de dados)
 *
 * Único ponto de criação do cliente: todos os módulos devem importar
 * `supabase` daqui, nunca chamar createClient() por conta própria.
 *
 * Variáveis necessárias em .env.local (raiz do projeto):
 *   NEXT_PUBLIC_SUPABASE_URL
 *   NEXT_PUBLIC_SUPABASE_ANON_KEY
 *
 * Obs.: o prefixo NEXT_PUBLIC_ expõe as variáveis ao navegador. A chave
 * "anon" é pública por design; a proteção dos dados deve vir das
 * políticas RLS (Row Level Security) configuradas no Supabase.
 */
import { createClient, type SupabaseClient } from "@supabase/supabase-js";

const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL;
const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;

// Falha cedo e com mensagem clara se o .env.local não foi preenchido
// (string vazia também é considerada ausente).
if (!supabaseUrl || !supabaseAnonKey) {
  throw new Error(
    "Variáveis do Supabase ausentes: preencha NEXT_PUBLIC_SUPABASE_URL e " +
      "NEXT_PUBLIC_SUPABASE_ANON_KEY no arquivo .env.local e reinicie o servidor."
  );
}

export const supabase: SupabaseClient = createClient(supabaseUrl, supabaseAnonKey);
