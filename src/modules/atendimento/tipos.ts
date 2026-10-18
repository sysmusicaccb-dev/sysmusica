/** SysMúsica — Tipos do atendimento da portaria (campos = colunas devolvidas pelas funções do banco, migração 0008). */

/** Como a pessoa foi identificada: QR Code lido ou localizada pelo nome. */
export type OrigemEntrada = "QR" | "MANUAL";

/** Dados do membro para conferência na portaria. */
export interface CartaoMembro {
  membro_id: string;
  nome: string;
  congregacao: string | null;
  cargo: string | null;
  instrumento: string | null;
  cidade: string | null;
  bairro: string | null;
  status: string;
  foto_path: string | null;
  /** Hora da entrada, se o membro já foi registrado nesta portaria; senão, nulo. */
  ja_registrado_em: string | null;
}

/** Opções do formulário de visitante (cargos e instrumentos, já filtrados pelo banco). */
export interface OpcoesVisitante {
  cargos: { id: string; nome: string; permite_instrumento: boolean }[];
  instrumentos: { id: string; nome: string }[];
}

/** Uma entrada recente da portaria. */
export interface EntradaRecente {
  presenca_id: string;
  membro_nome: string;
  status: string;
  hora_entrada: string;
  origem: string;
  total: number; // total de entradas da portaria (a lista traz só as últimas)
}
