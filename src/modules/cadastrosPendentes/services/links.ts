/**
 * Sysmusica — Links de cadastro por região (migrações 0063 e 0064).
 * Cada RRM, RA ou ADM gera o próprio link do formulário público. Quem abre o link vê só as Casas de Oração da região,
 * e o pedido com casa digitada (não cadastrada) chega para os responsáveis daquela região.
 * As funções do banco conferem permissão (cadastros.aprovar) e abrangência: a tela só mostra o resultado.
 */
import { supabase } from "@/lib/supabase";
import { mensagemDoErro } from "@/lib/erros";
import type { NivelLink } from "../linksRegras";

export type { NivelLink };


export interface LinkCadastro {
  id: string;
  codigo: string;
  nivel: NivelLink;
  alvo_id: string;
  rotulo: string;
  ativo: boolean;
  criado_em: string;
  criado_por_nome: string | null;
  pendentes: number;
}

export interface RegiaoParaLink {
  nivel: NivelLink;
  alvo_id: string;
  nome: string;
  caminho: string;
}

export async function listarLinks(): Promise<LinkCadastro[]> {
  const { data, error } = await supabase.rpc("listar_links_cadastro");
  if (error) throw new Error(mensagemDoErro(error, "Não foi possível carregar os links."));
  return ((data ?? []) as LinkCadastro[]).map((l) => ({ ...l, pendentes: Number(l.pendentes ?? 0) }));
}

export async function listarRegioesParaLink(): Promise<RegiaoParaLink[]> {
  const { data, error } = await supabase.rpc("regioes_para_link_cadastro");
  if (error) throw new Error(mensagemDoErro(error, "Não foi possível carregar as regiões."));
  return (data ?? []) as RegiaoParaLink[];
}

/** Gera o link da região (se já existir um ativo, o banco devolve o mesmo). */
export async function criarLink(nivel: NivelLink, alvoId: string): Promise<void> {
  const { error } = await supabase.rpc("criar_link_cadastro", { p_nivel: nivel, p_alvo: alvoId });
  if (error) throw new Error(mensagemDoErro(error, "Não foi possível gerar o link."));
}

export async function desativarLink(id: string): Promise<void> {
  const { error } = await supabase.rpc("desativar_link_cadastro", { p_id: id });
  if (error) throw new Error(mensagemDoErro(error, "Não foi possível desativar o link."));
}
