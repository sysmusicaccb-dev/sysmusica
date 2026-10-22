/**
 * Sysmusica — Regras PURAS do prazo dos Cadastros Pendentes (sem acesso ao banco), testadas em prazo.test.ts.
 * O banco é quem manda: ele recusa prazos fora de 7 a 365 dias (migração 0045). Aqui só se valida o que a
 * pessoa digitou, para avisar na hora, e se calcula a data de exemplo mostrada na tela.
 */
export const PRAZO_MINIMO_DIAS = 7;
export const PRAZO_MAXIMO_DIAS = 365;
export const PRAZO_PADRAO_DIAS = 60;

/** Atalhos de prazo mostrados como botões na tela. */
export const ATALHOS_PRAZO = [30, 60, 90, 180] as const;

export type ResultadoPrazo = { ok: true; dias: number } | { ok: false; erro: string };

/** Confere o texto digitado: só números inteiros, de 7 a 365. */
export function validarPrazo(texto: string): ResultadoPrazo {
  const limpo = texto.trim();
  if (limpo === "") return { ok: false, erro: "Informe o prazo em dias." };
  if (!/^\d+$/.test(limpo)) return { ok: false, erro: "Use apenas números inteiros (exemplo: 60)." };
  const dias = Number(limpo);
  if (dias < PRAZO_MINIMO_DIAS || dias > PRAZO_MAXIMO_DIAS) {
    return { ok: false, erro: `O prazo deve ficar entre ${PRAZO_MINIMO_DIAS} e ${PRAZO_MAXIMO_DIAS} dias.` };
  }
  return { ok: true, dias };
}

/** Data em que venceria um pedido enviado em "base" (padrão: agora), no prazo informado. */
export function dataDeVencimento(dias: number, base: Date = new Date()): Date {
  return new Date(base.getTime() + dias * 86_400_000);
}

/** "20/12/2026" no fuso de São Paulo (o mesmo do banco). */
export function formatarDataCurta(data: Date): string {
  return data.toLocaleDateString("pt-BR", { timeZone: "America/Sao_Paulo" });
}
