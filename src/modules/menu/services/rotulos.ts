/** Sysmusica — Serviço dos nomes do menu (leitura para todos; gravação só do Master, validada no banco). */
import { supabase } from "@/lib/supabase";
import { mensagemDoErro } from "@/lib/erros";

export async function listarRotulosMenu(): Promise<Record<string, string>> {
  const { data, error } = await supabase.rpc("listar_rotulos_menu");
  if (error) throw new Error(error.message);
  const mapa: Record<string, string> = {};
  for (const linha of (data ?? []) as { href: string; rotulo: string }[]) mapa[linha.href] = linha.rotulo;
  return mapa;
}

export async function souMaster(): Promise<boolean> {
  const { data, error } = await supabase.rpc("usuario_master");
  if (error) throw new Error(error.message);
  return data === true;
}

export async function salvarRotuloMenu(href: string, rotulo: string): Promise<void> {
  const { error } = await supabase.rpc("salvar_rotulo_menu", { p_href: href, p_rotulo: rotulo });
  if (error) throw new Error(mensagemDoErro(error, "Não foi possível salvar o nome do menu."));
}

export async function restaurarRotuloMenu(href: string): Promise<void> {
  const { error } = await supabase.rpc("restaurar_rotulo_menu", { p_href: href });
  if (error) throw new Error(mensagemDoErro(error, "Não foi possível restaurar o nome do menu."));
}
