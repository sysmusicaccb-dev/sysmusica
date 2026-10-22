/**
 * Sysmusica — Listas de sugestões para campos de texto com autocompletar (cidade, bairro...).
 */
import { normalizarTexto } from "@/lib/texto";

/**
 * Valores distintos de uma lista, ignorando acento, maiúsculas e espaços repetidos.
 * Mantém a primeira grafia encontrada e devolve em ordem alfabética (pt-BR).
 */
export function valoresDistintos(valores: Array<string | null | undefined>): string[] {
  const mapa = new Map<string, string>();
  for (const valor of valores) {
    const limpo = valor?.trim().replace(/\s+/g, " ");
    if (!limpo) continue;
    const chave = normalizarTexto(limpo);
    if (!mapa.has(chave)) mapa.set(chave, limpo);
  }
  return [...mapa.values()].sort((a, b) => a.localeCompare(b, "pt-BR"));
}
