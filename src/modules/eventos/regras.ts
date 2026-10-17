/**
 * SysMúsica — Regras puras de eventos (sem acesso ao banco). Testadas em regras.test.ts.
 */
export const FINALIDADE_MINIMO = 3;
export const FINALIDADE_MAXIMO = 150;

/** Ajusta a finalidade antes de salvar: tira espaços extras e põe a 1ª letra em maiúscula. */
export function formatarNomeFinalidade(texto: string): string {
  const limpo = texto.trim().replace(/\s+/g, " ");
  return limpo.charAt(0).toUpperCase() + limpo.slice(1);
}

/** Valida o texto da finalidade; devolve a mensagem de erro ou null quando está tudo certo. */
export function validarFinalidade(texto: string): string | null {
  const tamanho = texto.trim().replace(/\s+/g, " ").length;
  if (tamanho < FINALIDADE_MINIMO) {
    return `Informe a finalidade do evento (mínimo de ${FINALIDADE_MINIMO} caracteres).`;
  }
  if (tamanho > FINALIDADE_MAXIMO) {
    return `A finalidade pode ter no máximo ${FINALIDADE_MAXIMO} caracteres.`;
  }
  return null;
}
