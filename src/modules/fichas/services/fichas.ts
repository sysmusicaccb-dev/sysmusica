/**
 * Sysmusica — Serviço do módulo Fichas Musicais. Tudo passa por funções do banco (listar_fichas, obter_ficha,
 * salvar_ficha, excluir_ficha, definir_resultado_ficha, buscar_membros_para_ficha), que conferem a permissão e a
 * região de quem usa: o navegador nunca lê a tabela diretamente.
 */
import { supabase } from "@/lib/supabase";
import { mensagemDoErro } from "@/lib/erros";
import type { DadosFicha } from "../dados";
import type { LinhaFicha, ResultadoFicha, TipoFicha } from "../tipos";

/** Fichas da região de quem consulta (mais novas primeiro). Filtra por tipo se informado. */
export async function listarFichas(tipo: TipoFicha | null = null): Promise<LinhaFicha[]> {
  const { data, error } = await supabase.rpc("listar_fichas", { p_tipo: tipo });
  if (error) throw new Error(mensagemDoErro(error, "Não foi possível carregar as fichas."));
  return (data ?? []) as LinhaFicha[];
}

/** Ficha inteira (com nomes da pessoa e da Casa), vinda de obter_ficha. */
export interface FichaCompleta {
  id: string;
  tipo: TipoFicha;
  membro_id: string | null;
  casa_oracao_id: string;
  dados: unknown;
  resultado: ResultadoFicha | null;
  resultado_em: string | null;
  aplicado_em: string | null;
  membro_nome: string | null;
  casa_nome: string | null;
}

/** Pessoa encontrada na busca do cadastro (buscar_membros_para_ficha). */
export interface MembroBusca {
  id: string;
  nome: string;
  casa_oracao_id: string | null;
  casa_nome: string | null;
  cargo: string | null;
  instrumento_id: string | null;
  instrumento_nome: string | null;
  categoria: string | null;
}

export async function obterFicha(id: string): Promise<FichaCompleta> {
  const { data, error } = await supabase.rpc("obter_ficha", { p_id: id });
  if (error) throw new Error(mensagemDoErro(error, "Não foi possível abrir a ficha."));
  return data as FichaCompleta;
}

/** Cria (id nulo) ou altera a ficha. A Casa de Oração vem do cadastro da pessoa escolhida. */
export async function salvarFicha(id: string | null, tipo: TipoFicha, membroId: string, dados: DadosFicha): Promise<string> {
  const { data, error } = await supabase.rpc("salvar_ficha", { p_id: id, p_tipo: tipo, p_membro: membroId, p_casa: null, p_dados: dados });
  if (error) throw new Error(mensagemDoErro(error, "Não foi possível salvar a ficha."));
  return data as string;
}

export async function excluirFicha(id: string): Promise<void> {
  const { error } = await supabase.rpc("excluir_ficha", { p_id: id });
  if (error) throw new Error(mensagemDoErro(error, "Não foi possível excluir a ficha."));
}

/** Secretário da Música: marca o resultado. Se for Apto, o banco já altera o cadastro; devolve o aviso a mostrar. */
export async function definirResultadoFicha(id: string, resultado: ResultadoFicha): Promise<string> {
  const { data, error } = await supabase.rpc("definir_resultado_ficha", { p_id: id, p_resultado: resultado });
  if (error) throw new Error(mensagemDoErro(error, "Não foi possível registrar o resultado."));
  return ((data as { mensagem?: string } | null)?.mensagem) ?? "Resultado registrado.";
}

export async function buscarMembrosParaFicha(termo: string): Promise<MembroBusca[]> {
  const { data, error } = await supabase.rpc("buscar_membros_para_ficha", { p_termo: termo });
  if (error) throw new Error(mensagemDoErro(error, "Não foi possível buscar no cadastro."));
  return (data ?? []) as MembroBusca[];
}
