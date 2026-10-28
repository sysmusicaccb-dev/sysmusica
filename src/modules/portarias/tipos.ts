/** Sysmusica — Tipos da Gestão de portarias (campos = colunas devolvidas pelas funções do banco, migração 0007). */

export type StatusPortaria = "PENDENTE_APROVACAO" | "APROVADA" | "REJEITADA";

/** Portaria com dados do evento, de quem criou e de quem decidiu (já filtrada pelo que o usuário pode ver). */
export interface PortariaDetalhada {
  id: string;
  evento_id: string;
  status: StatusPortaria;
  cidade: string;
  criada_em: string;
  criada_por: string;
  criador_nome: string | null;
  decidida_em: string | null;
  decisor_nome: string | null;
  motivo_rejeicao: string | null;
  evento_tipo: string | null;
  evento_data: string | null;
  evento_local: string | null;
  evento_finalidade: string | null;
  /** Calculado pelo banco: tem a permissão, está na abrangência, não é o criador e está pendente. */
  pode_decidir: boolean;
  /** Calculado pelo banco: tem permissão (ou é o criador de uma pendente) e não há presenças. */
  pode_excluir: boolean;
  /** Preenchido pela tela (serviço): quando o evento foi encerrado à mão. A portaria encerra junto. */
  evento_encerrado_em?: string | null;
}

/** Evento que pode receber uma portaria. */
export interface EventoParaPortaria {
  id: string;
  tipo: string;
  data_evento: string;
  local: string;
  cidade: string | null;
}

/** Cota diária de criação de portarias de quem está logado. */
export interface CotaPortarias {
  usadas: number;
  limite: number;
  restantes: number;
  /** Controle total: sem limite diário (o "restantes" não limita). */
  ilimitada?: boolean;
}

/** Uma linha do histórico de uma portaria. */
export interface HistoricoPortaria {
  acao: string; // CRIADA, APROVADA, REJEITADA ou EXCLUIDA
  status_anterior: string | null;
  status_novo: string | null;
  usuario_nome: string | null;
  ocorrido_em: string;
  motivo: string | null;
}
