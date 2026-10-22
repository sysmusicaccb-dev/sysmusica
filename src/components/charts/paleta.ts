/**
 * Sysmusica — Paleta dos gráficos.
 * As classes são escritas por extenso para o Tailwind conseguir detectá-las.
 * Itens "Outros" e "Sem ..." (sem dado) usam um cinza neutro, para não competirem com os dados reais.
 */
import type { CorGrafico, ItemGrafico } from "./tipos";

const PALETA: readonly CorGrafico[] = [
  { texto: "text-brand-600", fundo: "bg-brand-600" },
  { texto: "text-emerald-500", fundo: "bg-emerald-500" },
  { texto: "text-amber-500", fundo: "bg-amber-500" },
  { texto: "text-sky-500", fundo: "bg-sky-500" },
  { texto: "text-rose-500", fundo: "bg-rose-500" },
  { texto: "text-violet-400", fundo: "bg-violet-400" },
  { texto: "text-teal-500", fundo: "bg-teal-500" },
];

const COR_NEUTRA: CorGrafico = { texto: "text-slate-300", fundo: "bg-slate-300" };

/** Cor de um item: a fixa do próprio item, o neutro para "Outros"/"Sem ...", ou a paleta pelo índice. */
export function corDoItem(item: ItemGrafico, indice: number): CorGrafico {
  if (item.cor) return item.cor;
  if (item.rotulo === "Outros" || item.rotulo.startsWith("Sem ")) return COR_NEUTRA;
  return PALETA[indice % PALETA.length];
}
