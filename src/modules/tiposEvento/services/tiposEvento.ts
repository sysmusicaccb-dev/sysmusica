/**
 * Sysmusica — Serviço dos Tipos de evento. Tudo passa por funções do banco (migração 0041), que conferem a
 * permissão de cada operação: a tabela não é acessada diretamente.
 */
import { supabase } from "@/lib/supabase";
import { mensagemDoErro } from "@/lib/erros";
import type { ModeloEnsaio, TipoEvento } from "../regras";

/** Lista os tipos (ativos e desativados), na ordem de cadastro. */
export async function listarTiposEvento(): Promise<TipoEvento[]> {
  const { data, error } = await supabase.rpc("listar_tipos_evento");
  if (error) throw new Error(mensagemDoErro(error, "Não foi possível carregar os tipos de evento."));
  return ((data ?? []) as TipoEvento[]).map((tipo) => ({ ...tipo, em_uso: Number(tipo.em_uso) }));
}

export interface DadosTipoEvento {
  nome: string;
  descricao: string;
  modelo_ensaio: ModeloEnsaio | null;
  ativo: boolean;
}

/** Cria (id = null) ou altera um tipo. Devolve o id. */
export async function salvarTipoEvento(id: string | null, dados: DadosTipoEvento): Promise<string> {
  const { data, error } = await supabase.rpc("salvar_tipo_evento", {
    p_id: id,
    p_dados: {
      nome: dados.nome,
      descricao: dados.descricao.trim() === "" ? null : dados.descricao,
      modelo_ensaio: dados.modelo_ensaio,
      ativo: dados.ativo,
    },
  });
  if (error) throw new Error(mensagemDoErro(error, "Não foi possível salvar o tipo de evento."));
  return data as string;
}

/** Exclui um tipo que nunca foi usado (o banco recusa se algum evento usar). */
export async function excluirTipoEvento(id: string): Promise<void> {
  const { error } = await supabase.rpc("excluir_tipo_evento", { p_id: id });
  if (error) throw new Error(mensagemDoErro(error, "Não foi possível excluir o tipo de evento."));
}
