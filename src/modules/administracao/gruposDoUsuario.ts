/**
 * Sysmusica — Regras puras para escolher os grupos de um usuário (sem banco). Testadas em
 * gruposDoUsuario.test.ts. A regra de verdade (ao menos um grupo, último administrador, etc.)
 * é aplicada pelo banco; aqui há só conferências para dar resposta imediata na tela.
 */

/** Marca ou desmarca um grupo; devolve uma lista nova (não altera a original). */
export function alternarGrupo(escolhidos: string[], id: string): string[] {
  return escolhidos.includes(id) ? escolhidos.filter((item) => item !== id) : [...escolhidos, id];
}

/** O usuário precisa ter pelo menos um grupo. */
export function validarGruposEscolhidos(ids: string[]): string | null {
  return ids.length === 0 ? "Escolha pelo menos um grupo." : null;
}

/** Texto com os nomes dos grupos (ex.: "Secretaria, Aprovadores de portarias"). */
export function resumoGrupos(nomes: string[]): string {
  return nomes.length === 0 ? "Sem grupo" : nomes.join(", ");
}
