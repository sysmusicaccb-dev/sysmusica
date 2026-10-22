/**
 * Sysmusica — Serviço dos Hinos. Tudo passa por funções do banco (migração 0041), que conferem a permissão
 * de cada operação: a tabela não é acessada diretamente.
 */
import { supabase } from "@/lib/supabase";
import { mensagemDoErro } from "@/lib/erros";
import type { CategoriaHino, Hino, ItemImportacao } from "../regras";

/** Lista os hinos e coros (ativos e desativados): hinos do hinário primeiro, depois os coros. */
export async function listarHinos(): Promise<Hino[]> {
  const { data, error } = await supabase.rpc("listar_hinos");
  if (error) throw new Error(mensagemDoErro(error, "Não foi possível carregar os hinos."));
  return ((data ?? []) as Hino[]).map((hino) => ({ ...hino, numero: Number(hino.numero), em_uso: Number(hino.em_uso) }));
}

export interface DadosHino {
  categoria: CategoriaHino;
  numero: number;
  nome: string;
  ativo: boolean;
}

/** Cria (id = null) ou altera um hino. Devolve o id. */
export async function salvarHino(id: string | null, dados: DadosHino): Promise<string> {
  const { data, error } = await supabase.rpc("salvar_hino", { p_id: id, p_dados: dados });
  if (error) throw new Error(mensagemDoErro(error, "Não foi possível salvar o hino."));
  return data as string;
}

/** Exclui um hino que nunca foi usado em ensaio (o banco recusa se já foi usado). */
export async function excluirHino(id: string): Promise<void> {
  const { error } = await supabase.rpc("excluir_hino", { p_id: id });
  if (error) throw new Error(mensagemDoErro(error, "Não foi possível excluir o hino."));
}

export interface ResultadoImportacao {
  recebidos: number;
  novos: number;
  ja_existiam: number;
}

/** Importa a lista de uma vez. Só acrescenta: número que já existe é ignorado. */
export async function importarHinos(itens: ItemImportacao[]): Promise<ResultadoImportacao> {
  const carga = itens.map(({ categoria, numero, nome }) => ({ categoria, numero, nome }));
  const { data, error } = await supabase.rpc("importar_hinos", { p_itens: carga });
  if (error) throw new Error(mensagemDoErro(error, "Não foi possível importar os hinos."));
  return data as ResultadoImportacao;
}
