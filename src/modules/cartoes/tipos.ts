/**
 * SysMúsica — Tipos do módulo Cartões (alerta de vencimento do cartão de identificação).
 * Os dados vêm das funções do banco resumo_cartoes e listar_cartoes (migração 0044).
 */
export type SituacaoCartao = "VENCIDO" | "A_VENCER" | "SEM_VALIDADE";

/** Filtro da tela: uma situação ou todas. */
export type FiltroCartao = "TODOS" | SituacaoCartao;

export interface LinhaCartao {
  membro_id: string;
  nome: string;
  cargo_nome: string | null;
  casa_nome: string | null;
  cartao_numero: string | null;
  cartao_validade: string | null; // "AAAA-MM-DD"; nulo = validade não informada
  dias: number | null; // negativo = já venceu há N dias; 0 = vence hoje; nulo = sem validade
  situacao: SituacaoCartao;
}

export interface ResumoCartoes {
  dias: number;
  vencidos: number;
  a_vencer: number;
  sem_validade: number;
}
