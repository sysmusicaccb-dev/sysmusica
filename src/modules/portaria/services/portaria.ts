/**
 * SysMúsica — Serviço de dados da Portaria (registro de entrada e histórico).
 * Em "membros" só se lêem colunas liberadas (nunca "*": qr_secret e CPF completo são protegidos).
 * As portarias APROVADAS que o usuário pode usar vêm de listarPortarias (o banco já filtra pela
 * permissão e pela abrangência). Excluir é EXCLUSÃO LÓGICA. Editar altera só status e horários.
 */
import { supabase } from "@/lib/supabase";
import { mensagemDoErro } from "@/lib/erros";
import { listarPortarias } from "@/modules/portarias/services/portarias";
import type { PortariaDetalhada } from "@/modules/portarias/tipos";
import {
  COLUNAS_MEMBRO_PUBLICO,
  type Evento,
  type Instrumento,
  type MembroPublico,
  type Presenca,
} from "@/types/database";

export interface DadosPortaria {
  eventos: Evento[];
  membros: MembroPublico[];
  instrumentos: Instrumento[];
  presencas: Presenca[];
  portarias: PortariaDetalhada[]; // as que o usuário pode ver (a tela usa só as APROVADAS)
}

/** Busca eventos, membros, instrumentos, presenças e portarias em paralelo. Lança erro se algo falhar. */
export async function buscarDadosPortaria(): Promise<DadosPortaria> {
  const [resEventos, resMembros, resPresencas, resInstrumentos, portarias] = await Promise.all([
    supabase.from("eventos").select("*").order("data_evento", { ascending: false }),
    supabase.from("membros").select(COLUNAS_MEMBRO_PUBLICO).order("nome", { ascending: true }),
    supabase.from("presencas").select("*"),
    supabase.from("instrumentos").select("*"),
    listarPortarias(),
  ]);

  const erroBanco = resEventos.error ?? resMembros.error ?? resPresencas.error ?? resInstrumentos.error;
  if (erroBanco) throw new Error(erroBanco.message);

  return {
    eventos: (resEventos.data ?? []) as Evento[],
    // Cast duplo: com lista de colunas, o cliente (sem tipagem gerada) não infere a linha
    membros: (resMembros.data ?? []) as unknown as MembroPublico[],
    instrumentos: (resInstrumentos.data ?? []) as Instrumento[],
    presencas: (resPresencas.data ?? []) as Presenca[],
    portarias,
  };
}

/** Campos que podem ser alterados na edição de uma presença. */
export interface DadosAtualizacaoPresenca {
  status: string;
  hora_entrada: string; // ISO (UTC)
  hora_saida: string | null; // ISO (UTC) ou null = ainda não saiu
}

export async function atualizarPresenca(id: string, dados: DadosAtualizacaoPresenca): Promise<void> {
  // .select("id") devolve as linhas alteradas: se o RLS negar, o update não dá erro, só não altera nada
  const { data, error } = await supabase.from("presencas").update(dados).eq("id", id).select("id");
  if (error) {
    // 23514 = regra do banco "saída depois da entrada" (a mensagem nativa é técnica)
    if (error.code === "23514") {
      throw new Error("A hora de saída não pode ser anterior à hora de entrada.");
    }
    throw new Error(
      mensagemDoErro(
        error,
        "Não foi possível salvar as alterações da presença.",
        "Este membro já tem uma entrada em aberto neste evento."
      )
    );
  }
  if (!data || data.length === 0) {
    throw new Error("Não foi possível salvar: você não tem permissão ou o registro não existe mais.");
  }
}

/** Exclusão lógica (função do banco, que confere a permissão portaria.excluir). */
export async function excluirPresenca(id: string): Promise<void> {
  const { error } = await supabase.rpc("excluir_presenca", { p_id: id });
  if (error) throw new Error(mensagemDoErro(error, "Não foi possível excluir o registro."));
}
