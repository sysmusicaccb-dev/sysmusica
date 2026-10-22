/**
 * Sysmusica — Regras puras da tela Registrar Presença (sem React nem banco). Testadas em regrasPresenca.test.ts.
 * A tela é um passo a passo: 1) tipo de participante (Ministério, Músicos ou Organistas), 2) categoria,
 * 3) instrumento (quando se aplica). Quem decide de verdade é o banco; aqui só se monta o que a tela mostra.
 */
import type { BlocoEntrada, InstrumentoEntrada, LinhaEntrada } from "./tiposEntrada";

export const BLOCOS_ENTRADA: BlocoEntrada[] = ["MINISTERIO", "MUSICOS", "ORGANISTAS"];

/** Nome no singular, para os títulos "Categoria do Músico", "Aba Músicos"... */
export const SINGULAR_BLOCO: Record<BlocoEntrada, string> = {
  MINISTERIO: "Ministério",
  MUSICOS: "Músico",
  ORGANISTAS: "Organista",
};

/** Linhas (categorias) do bloco, na ordem em que o banco as entrega. */
export function linhasDoBloco(linhas: LinhaEntrada[], bloco: BlocoEntrada): LinhaEntrada[] {
  return linhas.filter((linha) => linha.bloco === bloco);
}

/** "Encarregado Local, Instrutor, Músico": as categorias do bloco em uma linha, para o cartão. */
export function resumoCategorias(linhas: LinhaEntrada[], bloco: BlocoEntrada): string {
  return linhasDoBloco(linhas, bloco)
    .map((linha) => linha.rotulo)
    .join(", ");
}

/** Em que passo a pessoa está: 1 sem tipo escolhido, 2 sem categoria, 3 com categoria escolhida. */
export function passoAtual(bloco: BlocoEntrada | null, linhaCodigo: string): 1 | 2 | 3 {
  if (!bloco) return 1;
  return linhaCodigo === "" ? 2 : 3;
}

/** Famílias de instrumentos, sem repetir, na ordem de chegada. */
export function familiasDosInstrumentos(instrumentos: InstrumentoEntrada[]): string[] {
  return [...new Set(instrumentos.map((item) => item.familia))];
}

/** Instrumentos de uma família (família vazia = nenhum). */
export function instrumentosDaFamilia(instrumentos: InstrumentoEntrada[], familia: string): InstrumentoEntrada[] {
  if (familia === "") return [];
  return instrumentos.filter((item) => item.familia === familia);
}
