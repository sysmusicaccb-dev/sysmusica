/**
 * SysMúsica — Serviço de dados de membros.
 *
 * Em "membros" só se lêem colunas liberadas (nunca "*": o qr_secret é protegido).
 * Excluir é EXCLUSÃO LÓGICA: o membro some das telas e o histórico de presenças é mantido.
 */
import { supabase } from "@/lib/supabase";
import { mensagemDoErro } from "@/lib/erros";
import {
  COLUNAS_MEMBRO_PUBLICO,
  type Cargo,
  type Familia,
  type Instrumento,
  type MembroInsert,
  type MembroPublico,
} from "@/types/database";

export interface DadosMembros {
  cargos: Cargo[];
  instrumentos: Instrumento[];
  familias: Familia[];
  membros: MembroPublico[];
}

/** Busca cargos, instrumentos, famílias e membros em paralelo. Lança erro se qualquer consulta falhar. */
export async function buscarDadosMembros(): Promise<DadosMembros> {
  const [resCargos, resInstrumentos, resFamilias, resMembros] = await Promise.all([
    supabase.from("cargos").select("*").order("nome", { ascending: true }),
    supabase.from("instrumentos").select("*").order("nome", { ascending: true }),
    supabase.from("familias").select("*").order("nome", { ascending: true }),
    supabase.from("membros").select(COLUNAS_MEMBRO_PUBLICO).order("nome", { ascending: true }),
  ]);

  const erroBanco = resCargos.error ?? resInstrumentos.error ?? resFamilias.error ?? resMembros.error;
  if (erroBanco) throw new Error(erroBanco.message);

  return {
    cargos: (resCargos.data ?? []) as Cargo[],
    instrumentos: (resInstrumentos.data ?? []) as Instrumento[],
    familias: (resFamilias.data ?? []) as Familia[],
    // Cast duplo: com lista de colunas, o cliente (sem tipagem gerada) não infere a linha
    membros: (resMembros.data ?? []) as unknown as MembroPublico[],
  };
}

export async function criarMembro(dados: MembroInsert): Promise<void> {
  const { error } = await supabase.from("membros").insert(dados);
  if (error) throw new Error(mensagemDoErro(error, "Não foi possível cadastrar o membro."));
}

/** Campos que podem ser alterados na edição (o banco libera só estas colunas). */
export interface DadosAtualizacaoMembro {
  nome: string;
  congregacao: string;
  cargo_id: string;
  data_nascimento: string | null;
  instrumento_id: string | null;
  status: string;
}

export async function atualizarMembro(id: string, dados: DadosAtualizacaoMembro): Promise<void> {
  // .select("id") devolve as linhas alteradas: se o RLS negar, o update não dá erro, só não altera nada
  const { data, error } = await supabase.from("membros").update(dados).eq("id", id).select("id");
  if (error) throw new Error(mensagemDoErro(error, "Não foi possível salvar as alterações do membro."));
  if (!data || data.length === 0) {
    throw new Error("Não foi possível salvar: você não tem permissão ou o membro não existe mais.");
  }
}

/** Exclusão lógica (função do banco, que confere a permissão membros.excluir). */
export async function excluirMembro(id: string): Promise<void> {
  const { error } = await supabase.rpc("excluir_membro", { p_id: id });
  if (error) throw new Error(mensagemDoErro(error, "Não foi possível excluir o membro."));
}
