/**
 * Sysmusica — Impressão do Relatório do Ensaio: monta o HTML da janela de impressão a partir da folha já desenhada.
 * A folha tem 1280 x 905 px (A4 paisagem); aqui ela é reduzida para caber na área útil da página. Sem script na página.
 */
import { escaparHtml } from "@/lib/exportacao";

export const LARGURA_PX = 1280;
export const ALTURA_PX = 905;
export const MARGEM_MM = 6;
const A4_LARGURA_MM = 297;
const A4_ALTURA_MM = 210;
const PX_POR_MM = 96 / 25.4;

/** Escala que faz a folha caber na área útil do A4 paisagem (a menor entre a da largura e a da altura). */
export function escalaParaA4(): number {
  const larg = ((A4_LARGURA_MM - 2 * MARGEM_MM) * PX_POR_MM) / LARGURA_PX;
  const alt = ((A4_ALTURA_MM - 2 * MARGEM_MM) * PX_POR_MM) / ALTURA_PX;
  return Math.floor(Math.min(larg, alt) * 1000) / 1000;
}

export function montarHtmlRelatorio(titulo: string, htmlDaFolha: string): string {
  const k = escalaParaA4();
  const largura = Math.round(LARGURA_PX * k);
  const altura = Math.round(ALTURA_PX * k);
  return (
    '<!doctype html><html lang="pt-BR"><head><meta charset="utf-8">' +
    `<title>${escaparHtml(titulo)}</title><style>` +
    `@page{size:A4 landscape;margin:${MARGEM_MM}mm}` +
    "html,body{margin:0;padding:0;background:#fff}" +
    "*{-webkit-print-color-adjust:exact;print-color-adjust:exact}" +
    `#caixa{width:${largura}px;height:${altura}px;overflow:hidden;margin:0 auto}` +
    `#escala{width:${LARGURA_PX}px;height:${ALTURA_PX}px;transform:scale(${k});transform-origin:top left}` +
    `</style></head><body><div id="caixa"><div id="escala">${htmlDaFolha}</div></div></body></html>`
  );
}
