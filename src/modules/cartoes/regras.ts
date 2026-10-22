/**
 * Sysmusica — Regras PURAS do módulo Cartões (sem acesso ao banco), testadas em regras.test.ts.
 * Quem decide o que está vencido ou a vencer é o banco (fuso America/Sao_Paulo); aqui só se
 * formatam textos e se filtra a lista que o banco já devolveu.
 */
import type { FiltroCartao, LinhaCartao, SituacaoCartao } from "./tipos";

/** Prazo padrão do alerta (card do Dashboard e primeira abertura da tela). */
export const PRAZO_PADRAO_DIAS = 30;

/** Prazos que a tela oferece (o banco aceita de 1 a 365). */
export const PRAZOS_DIAS = [30, 60, 90] as const;

export const ROTULO_SITUACAO: Record<SituacaoCartao, string> = {
  VENCIDO: "Vencido",
  A_VENCER: "A vencer",
  SEM_VALIDADE: "Sem validade",
};

// Cores dos selos (as mesmas variantes de Badge usadas no resto do sistema)
export const VARIANTE_SITUACAO: Record<SituacaoCartao, "perigo" | "alerta" | "neutro"> = {
  VENCIDO: "perigo",
  A_VENCER: "alerta",
  SEM_VALIDADE: "neutro",
};

/** "2026-11-05" -> "05/11/2026" (sem usar Date, para o fuso não mudar o dia). */
export function formatarValidade(iso: string | null): string {
  const partes = /^(\d{4})-(\d{2})-(\d{2})/.exec(iso ?? "");
  return partes ? `${partes[3]}/${partes[2]}/${partes[1]}` : "—";
}

/** Texto do prazo: "venceu há 5 dias", "vence hoje", "vence em 12 dias"... */
export function textoPrazo(situacao: SituacaoCartao, dias: number | null): string {
  if (situacao === "SEM_VALIDADE" || dias === null) return "validade não informada";
  if (dias < 0) {
    const atras = Math.abs(dias);
    return atras === 1 ? "venceu ontem" : `venceu há ${atras} dias`;
  }
  if (dias === 0) return "vence hoje";
  return dias === 1 ? "vence amanhã" : `vence em ${dias} dias`;
}

/** Aplica o filtro de situação da tela. */
export function filtrarCartoes(itens: LinhaCartao[], filtro: FiltroCartao): LinhaCartao[] {
  return filtro === "TODOS" ? itens : itens.filter((item) => item.situacao === filtro);
}

/** Quantidade de cada situação (os números dos botões de filtro). */
export function contarSituacoes(itens: LinhaCartao[]): Record<FiltroCartao, number> {
  const total: Record<FiltroCartao, number> = { TODOS: itens.length, VENCIDO: 0, A_VENCER: 0, SEM_VALIDADE: 0 };
  for (const item of itens) total[item.situacao] += 1;
  return total;
}
