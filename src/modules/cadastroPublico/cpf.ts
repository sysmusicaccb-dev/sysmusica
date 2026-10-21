/**
 * SysMúsica — Conferência do CPF (dígitos verificadores) para o cadastro público.
 * Mesma regra de src/lib/cpf.ts; fica aqui para o cadastro público (e as rotas do servidor) não dependerem da tela interna.
 */

/** Só os números do texto digitado. */
export function soDigitos(texto: string): string {
  return texto.replace(/\D/g, "");
}

/** CPF válido? Aceita com ou sem pontuação. Recusa sequências repetidas (111.111.111-11 etc.). */
export function cpfValido(texto: string): boolean {
  const cpf = soDigitos(texto);
  if (cpf.length !== 11 || /^(\d)\1{10}$/.test(cpf)) return false;
  const digito = (tamanho: number): number => {
    let soma = 0;
    for (let i = 0; i < tamanho; i++) soma += Number(cpf[i]) * (tamanho + 1 - i);
    const resto = (soma * 10) % 11;
    return resto === 10 ? 0 : resto;
  };
  return digito(9) === Number(cpf[9]) && digito(10) === Number(cpf[10]);
}

/** "123.456.789-09" (aceita digitação parcial). */
export function formatarCpfParcial(texto: string): string {
  const d = soDigitos(texto).slice(0, 11);
  if (d.length > 9) return `${d.slice(0, 3)}.${d.slice(3, 6)}.${d.slice(6, 9)}-${d.slice(9)}`;
  if (d.length > 6) return `${d.slice(0, 3)}.${d.slice(3, 6)}.${d.slice(6)}`;
  if (d.length > 3) return `${d.slice(0, 3)}.${d.slice(3)}`;
  return d;
}
