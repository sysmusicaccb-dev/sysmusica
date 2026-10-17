/**
 * SysMúsica — Autorização das rotas de servidor da Administração.
 *
 * A sessão do navegador fica no armazenamento local (não em cookies), então a tela envia o token
 * de login no cabeçalho "Authorization: Bearer ...". Aqui o servidor:
 *  1) cria um cliente "como aquele usuário" (chave pública + o token dele);
 *  2) pergunta ao banco se ele tem a permissão (função tem_permissao).
 * Token inválido/expirado, ou sem a permissão, interrompe a operação ANTES de qualquer ação.
 */
import { createClient } from "@supabase/supabase-js";
import type { CodigoPermissao } from "@/lib/permissoes";
import { ErroHttp } from "./erros";

export async function exigirPermissao(request: Request, permissao: CodigoPermissao): Promise<void> {
  const cabecalho = request.headers.get("authorization") ?? "";
  const token = cabecalho.toLowerCase().startsWith("bearer ") ? cabecalho.slice(7).trim() : "";
  if (!token) throw new ErroHttp(401, "Sessão ausente. Entre novamente.");

  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const chavePublica = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;
  if (!url || !chavePublica) {
    console.error("Variáveis públicas do Supabase ausentes no servidor.");
    throw new ErroHttp(500, "Servidor sem a configuração do banco de dados.");
  }

  const clienteDoUsuario = createClient(url, chavePublica, {
    auth: { persistSession: false, autoRefreshToken: false },
    global: { headers: { Authorization: `Bearer ${token}` } },
  });

  const { data, error } = await clienteDoUsuario.rpc("tem_permissao", { p_codigo: permissao });
  if (error) throw new ErroHttp(401, "Sessão inválida ou expirada. Entre novamente.");
  if (data !== true) throw new ErroHttp(403, "Você não tem permissão para esta operação.");
}
