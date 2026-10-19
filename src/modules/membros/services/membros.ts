/**
 * SysMúsica — Serviço de dados de membros.
 *
 * Em "membros" só se lêem colunas liberadas (nunca "*": o qr_secret e o CPF completo são
 * protegidos). O CPF completo e o código do QR Code vêm de funções do banco que conferem a
 * permissão e registram a consulta na auditoria.
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

const MSG_CPF_DUPLICADO = "Já existe um membro cadastrado com este CPF.";

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
  if (error) {
    throw new Error(mensagemDoErro(error, "Não foi possível cadastrar o membro.", MSG_CPF_DUPLICADO));
  }
}

/** Campos que podem ser alterados na edição (o banco libera só estas colunas). */
export interface DadosAtualizacaoMembro {
  nome: string;
  congregacao: string;
  cargo_id: string;
  data_nascimento: string | null;
  instrumento_id: string | null;
  status: string;
  cidade: string | null;
  bairro: string | null;
  comum_id?: string | null; // a comum escolhida (o banco ajusta o nome da congregação)
  categoria?: string | null; // Oficializado, Culto Oficial ou RJM (Músico e Organista)
  /** Só enviar quando o usuário tem a permissão membros.cpf (null = apagar o CPF). */
  cpf?: string | null;
}

export async function atualizarMembro(id: string, dados: DadosAtualizacaoMembro): Promise<void> {
  // .select("id") devolve as linhas alteradas: se o RLS negar, o update não dá erro, só não altera nada
  const { data, error } = await supabase.from("membros").update(dados).eq("id", id).select("id");
  if (error) {
    throw new Error(
      mensagemDoErro(error, "Não foi possível salvar as alterações do membro.", MSG_CPF_DUPLICADO)
    );
  }
  if (!data || data.length === 0) {
    throw new Error("Não foi possível salvar: você não tem permissão ou o membro não existe mais.");
  }
}

/** Exclusão lógica (função do banco, que confere a permissão membros.excluir). */
export async function excluirMembro(id: string): Promise<void> {
  const { error } = await supabase.rpc("excluir_membro", { p_id: id });
  if (error) throw new Error(mensagemDoErro(error, "Não foi possível excluir o membro."));
}

/** CPF completo (permissão membros.cpf; a consulta fica registrada na auditoria). */
export async function obterCpfMembro(id: string): Promise<string | null> {
  const { data, error } = await supabase.rpc("obter_cpf_membro", { p_id: id });
  if (error) throw new Error(mensagemDoErro(error, "Não foi possível consultar o CPF."));
  return (data as string | null) ?? null;
}

/** Código do QR Code do membro (permissão membros.qr; a consulta fica registrada na auditoria). */
export async function obterQrMembro(id: string): Promise<string> {
  const { data, error } = await supabase.rpc("obter_qr_membro", { p_id: id });
  if (error || typeof data !== "string") {
    throw new Error(
      error ? mensagemDoErro(error, "Não foi possível obter o QR Code.") : "Não foi possível obter o QR Code."
    );
  }
  return data;
}

/** Substitui o QR Code (permissão membros.qr_revogar; justificativa obrigatória). Devolve o novo código. */
export async function regenerarQrMembro(id: string, justificativa: string): Promise<string> {
  const { data, error } = await supabase.rpc("regenerar_qr", { p_id: id, p_justificativa: justificativa });
  if (error || typeof data !== "string") {
    throw new Error(
      error
        ? mensagemDoErro(error, "Não foi possível substituir o QR Code.")
        : "Não foi possível substituir o QR Code."
    );
  }
  return data;
}
