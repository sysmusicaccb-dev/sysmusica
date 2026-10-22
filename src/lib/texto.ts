/**
 * Sysmusica — Utilitários de texto.
 *
 * Usado na busca por nome (ListaMembros) e na comparação de nomes de instrumentos
 * (FormularioMembro), para que "Órgão", "orgao" e "  ORGÃO " sejam tratados como iguais.
 */

/**
 * Normaliza um texto para COMPARAÇÃO e BUSCA: remove acentos, ignora maiúsculas/minúsculas
 * e colapsa espaços repetidos. Ex: "  Órgão  " -> "orgao".
 */
export function normalizarTexto(texto: string): string {
  return texto
    .normalize("NFD") // separa cada letra do seu acento
    .replace(/[\u0300-\u036f]/g, "") // remove os acentos
    .replace(/\s+/g, " ") // colapsa espaços repetidos
    .trim()
    .toLowerCase();
}
