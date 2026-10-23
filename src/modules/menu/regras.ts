/**
 * Sysmusica — Regras dos nomes do menu (funções puras).
 * O nome padrão vem de navegacao.ts; o Master pode trocá-lo e o nome novo vale para todos os usuários.
 */
export const LIMITE_ROTULO = 40;

/** Tira espaços sobrando (início, fim e repetidos no meio). */
export function normalizarRotulo(texto: string): string {
  return texto.replace(/\s+/g, " ").trim();
}

/** Devolve a mensagem de erro, ou null se o nome é válido. */
export function validarRotulo(texto: string): string | null {
  const limpo = normalizarRotulo(texto);
  if (limpo.length === 0) return "Informe o nome do item.";
  if (limpo.length > LIMITE_ROTULO) return `Use no máximo ${LIMITE_ROTULO} caracteres.`;
  if (/[<>]/.test(limpo)) return "Não use os símbolos < e >.";
  return null;
}

/** Nome que aparece no menu: o personalizado (se houver) ou o padrão. */
export function rotuloEfetivo(href: string, padrao: string, personalizados: Record<string, string>): string {
  const salvo = personalizados[href];
  return salvo && salvo.trim() ? salvo : padrao;
}
