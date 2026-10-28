/**
 * Sysmusica — Serviço do Perfil do Evento. Tudo passa por funções do banco (migração 0079), que conferem a
 * permissão e se a pessoa é administradora: a tabela não é acessada diretamente.
 */
import { supabase } from "@/lib/supabase";
import { mensagemDoErro } from "@/lib/erros";
import type { ConfigEnsaio } from "@/modules/ensaio/perfilConfig";
import type { ModeloEnsaio } from "@/modules/tiposEvento/regras";
import type { PerfilEvento } from "../regras";

/** Lista os perfis (ativos e desativados). */
export async function listarPerfis(): Promise<PerfilEvento[]> {
  const { data, error } = await supabase.rpc("listar_perfis_evento");
  if (error) throw new Error(mensagemDoErro(error, "Não foi possível carregar os perfis de evento."));
  return ((data ?? []) as PerfilEvento[]).map((p) => ({ ...p, em_uso: Number(p.em_uso) }));
}

export interface DadosPerfil {
  nome: string;
  descricao: string;
  modelo_base: ModeloEnsaio;
  ativo: boolean;
  config?: ConfigEnsaio; // indefinido = não mexe nos campos do perfil
}

/** Cria (id = null) ou altera um perfil. Devolve o id. */
export async function salvarPerfil(id: string | null, dados: DadosPerfil): Promise<string> {
  const { data, error } = await supabase.rpc("salvar_perfil_evento", {
    p_id: id,
    p_dados: {
      nome: dados.nome,
      descricao: dados.descricao.trim() === "" ? null : dados.descricao,
      modelo_base: dados.modelo_base,
      ativo: dados.ativo,
      config: dados.config,
    },
  });
  if (error) throw new Error(mensagemDoErro(error, "Não foi possível salvar o perfil."));
  return data as string;
}

/** Cria uma cópia do perfil ("Nome (cópia)"). Devolve o id da cópia. */
export async function duplicarPerfil(id: string): Promise<string> {
  const { data, error } = await supabase.rpc("duplicar_perfil_evento", { p_id: id });
  if (error) throw new Error(mensagemDoErro(error, "Não foi possível duplicar o perfil."));
  return data as string;
}

/** Exclui um perfil que nenhum tipo usa (o banco recusa se algum usar). */
export async function excluirPerfil(id: string): Promise<void> {
  const { error } = await supabase.rpc("excluir_perfil_evento", { p_id: id });
  if (error) throw new Error(mensagemDoErro(error, "Não foi possível excluir o perfil."));
}
