/**
 * SysMúsica — Cliente Supabase com a CHAVE SECRETA (service_role). SOMENTE SERVIDOR.
 *
 * Essa chave ignora todas as regras de acesso do banco: ela jamais pode ir para o navegador.
 * O import "server-only" faz o build falhar se algum componente de tela importar este arquivo.
 * A variável SUPABASE_SERVICE_ROLE_KEY (sem NEXT_PUBLIC_) fica só no .env.local do servidor.
 */
import "server-only";
import { createClient } from "@supabase/supabase-js";
import { ErroHttp } from "./erros";

export function clienteAdmin() {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const chave = process.env.SUPABASE_SERVICE_ROLE_KEY;

  if (!url || !chave) {
    // O detalhe vai para o log do servidor; a tela recebe uma orientação simples
    console.error("SUPABASE_SERVICE_ROLE_KEY ou NEXT_PUBLIC_SUPABASE_URL ausente no servidor.");
    throw new ErroHttp(
      503,
      "O servidor ainda não está configurado para criar contas. Peça ao responsável técnico para configurar a chave de servidor."
    );
  }

  return createClient(url, chave, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
}
