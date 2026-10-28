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
  const tipos = ((data ?? []) as TipoEvento[]).map((tipo) => ({ ...tipo, em_uso: Number(tipo.em_uso) }));
  // Perfil de cada tipo (migração 0079): se a consulta falhar, a lista segue sem o nome do perfil
  const { data: ligacoes, error: erroPerfis } = await supabase.rpc("perfis_dos_tipos_evento");
  if (erroPerfis) return tipos;
  const porTipo = new Map(
    ((ligacoes ?? []) as { tipo_id: string; perfil_id: string; perfil_nome: string }[]).map((l) => [l.tipo_id, l])
  );
  return tipos.map((tipo) => ({
    ...tipo,
    perfil_id: porTipo.get(tipo.id)?.perfil_id ?? null,
    perfil_nome: porTipo.get(tipo.id)?.perfil_nome ?? null,
  }));
}

export interface DadosTipoEvento {
  nome: string;
  descricao: string;
  modelo_ensaio: ModeloEnsaio | null;
  ativo: boolean;
  perfil_id?: string | null; // indefinido = não mexe no perfil do tipo; nulo = tira o perfil
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
  const idTipo = data as string;
  // Liga (ou desliga) o perfil escolhido; o modelo do tipo já foi salvo acima, com as regras de sempre
  if (dados.perfil_id !== undefined) {
    const { error: erroVinculo } = await supabase.rpc("vincular_perfil_tipo_evento", { p_tipo: idTipo, p_perfil: dados.perfil_id });
    if (erroVinculo) throw new Error(mensagemDoErro(erroVinculo, "O tipo foi salvo, mas não foi possível ligar o perfil."));
  }
  return idTipo;
}

/** Exclui um tipo que nunca foi usado (o banco recusa se algum evento usar). */
export async function excluirTipoEvento(id: string): Promise<void> {
  const { error } = await supabase.rpc("excluir_tipo_evento", { p_id: id });
  if (error) throw new Error(mensagemDoErro(error, "Não foi possível excluir o tipo de evento."));
}
