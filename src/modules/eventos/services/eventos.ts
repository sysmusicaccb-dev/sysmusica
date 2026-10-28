/**
 * Sysmusica — Serviço de dados de eventos.
 * Excluir é EXCLUSÃO LÓGICA: o evento some das telas e as presenças registradas são mantidas.
 */
import { supabase } from "@/lib/supabase";
import { mensagemDoErro } from "@/lib/erros";
import type { Evento, EventoInsert, FinalidadeEvento } from "@/types/database";
import { janelaDoMinuto, type EventoNoHorario } from "../duplicado";

/** Busca eventos (do mais recente para o mais antigo) e finalidades. Lança erro se a consulta falhar. */
export async function buscarEventosEFinalidades(): Promise<{
  eventos: Evento[];
  finalidades: FinalidadeEvento[];
}> {
  const [resEventos, resFinalidades] = await Promise.all([
    supabase.from("eventos").select("*").order("data_evento", { ascending: false }),
    supabase.from("finalidades_evento").select("*").order("nome", { ascending: true }),
  ]);

  const erroBanco = resEventos.error ?? resFinalidades.error;
  if (erroBanco) throw new Error(erroBanco.message);

  return {
    eventos: (resEventos.data ?? []) as Evento[],
    finalidades: (resFinalidades.data ?? []) as FinalidadeEvento[],
  };
}

export async function criarEvento(dados: EventoInsert): Promise<void> {
  const { error } = await supabase.from("eventos").insert(dados);
  if (error) throw new Error(mensagemDoErro(error, "Não foi possível cadastrar o evento."));
}

/**
 * Eventos já cadastrados na MESMA Casa de Oração, na mesma data e no mesmo minuto (menos o próprio, ao editar).
 * Só enxerga o que o usuário pode ver. É um aviso: quem chama decide se continua.
 */
export async function buscarEventosNoMesmoHorario(
  casaOracaoId: string,
  dataIso: string,
  ignorarId: string | null
): Promise<EventoNoHorario[]> {
  const janela = janelaDoMinuto(dataIso);
  if (!janela) return [];
  let consulta = supabase
    .from("eventos")
    .select("id, tipo, data_evento, local")
    .eq("casa_oracao_id", casaOracaoId)
    .is("excluido_em", null)
    .is("cancelado_em", null)
    .gte("data_evento", janela.inicio)
    .lt("data_evento", janela.fim);
  if (ignorarId) consulta = consulta.neq("id", ignorarId);
  const { data, error } = await consulta;
  if (error) throw new Error(mensagemDoErro(error, "Não foi possível verificar eventos no mesmo horário."));
  return (data ?? []) as EventoNoHorario[];
}

/** Campos que podem ser alterados na edição (o banco libera só estas colunas). */
export interface DadosAtualizacaoEvento {
  tipo: string;
  data_evento: string;
  local: string;
  finalidade_id?: string | null; // opcional: a tela não envia mais (mantém o valor atual)
  cidade: string | null;
  casa_oracao_id?: string | null;
}

export async function atualizarEvento(id: string, dados: DadosAtualizacaoEvento): Promise<void> {
  // .select("id") devolve as linhas alteradas: se o RLS negar, o update não dá erro, só não altera nada
  const { data, error } = await supabase.from("eventos").update(dados).eq("id", id).select("id");
  if (error) throw new Error(mensagemDoErro(error, "Não foi possível salvar as alterações do evento."));
  if (!data || data.length === 0) {
    throw new Error("Não foi possível salvar: você não tem permissão ou o evento não existe mais.");
  }
}

/** Cancela o evento com motivo (função do banco, que confere a permissão eventos.cancelar: só o Administrador). */
export async function cancelarEvento(id: string, motivo: string): Promise<void> {
  const { error } = await supabase.rpc("cancelar_evento", { p_id: id, p_motivo: motivo });
  if (error) throw new Error(mensagemDoErro(error, "Não foi possível cancelar o evento."));
}

/** Encerra o evento ANTES do horário (função do banco, que confere a permissão de aprovar portarias e a abrangência). */
export async function encerrarEvento(id: string): Promise<void> {
  const { error } = await supabase.rpc("encerrar_evento", { p_id: id });
  if (error) throw new Error(mensagemDoErro(error, "Não foi possível encerrar o evento."));
}

/** Reabre um evento encerrado à mão (só o Administrador; o banco confere). */
export async function reabrirEvento(id: string): Promise<void> {
  const { error } = await supabase.rpc("reabrir_evento", { p_id: id });
  if (error) throw new Error(mensagemDoErro(error, "Não foi possível reabrir o evento."));
}

/** Exclusão lógica (função do banco, que confere a permissão eventos.excluir). */
export async function excluirEvento(id: string): Promise<void> {
  const { error } = await supabase.rpc("excluir_evento", { p_id: id });
  if (error) throw new Error(mensagemDoErro(error, "Não foi possível excluir o evento."));
}
