/**
 * Sysmusica — Tipos do módulo Fichas Musicais (Comissão Musical).
 */

/** Código de cada ficha (igual ao check da tabela fichas_musicais no banco). */
export type TipoFicha =
  | "M01"
  | "M02"
  | "M03"
  | "M05"
  | "M07"
  | "AVALIACAO_RJM"
  | "AVALIACAO_CANDIDATO"
  | "PRE_AVALIACAO_ORGANISTA"
  | "EXAME_ORGANISTA"
  | "ACOMPANHAMENTO_GEM"
  | "NECESSIDADE_INSTRUMENTO";

export type ResultadoFicha = "APTO" | "NAO_APTO";

/** Uma linha da lista (função listar_fichas). */
export interface LinhaFicha {
  id: string;
  tipo: TipoFicha;
  membro_id: string | null;
  membro_nome: string | null;
  casa_oracao_id: string;
  casa_nome: string | null;
  resultado: ResultadoFicha | null;
  aplicado_em: string | null; // quando o cadastro do músico foi alterado pelo resultado
  criado_em: string;
  criado_por_nome: string | null;
}
