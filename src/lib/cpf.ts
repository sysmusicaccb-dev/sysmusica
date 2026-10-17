/**
 * SysMúsica — Utilitários de CPF.
 * ATENÇÃO: validarCpf segue o MESMO algoritmo da função SQL cpf_valido (supabase/migrations/0006).
 * Se mudar a regra de um lado, mude do outro.
 */

/** Remove tudo que não é dígito ("529.982.247-25" -> "52998224725"). */
export function limparCpf(texto: string): string {
  return texto.replace(/\D/g, "");
}

/** Valida o CPF: 11 dígitos, não repetidos e com os dois dígitos verificadores corretos. */
export function validarCpf(texto: string): boolean {
  const cpf = limparCpf(texto);
  if (cpf.length !== 11 || /^(\d)\1{10}$/.test(cpf)) return false;

  // Calcula um dígito verificador: soma ponderada (pesos decrescentes), regra do resto 10 -> 0
  const digito = (base: string, pesoInicial: number): number => {
    let soma = 0;
    for (let i = 0; i < base.length; i += 1) soma += Number(base[i]) * (pesoInicial - i);
    const resto = (soma * 10) % 11;
    return resto === 10 ? 0 : resto;
  };

  return (
    digito(cpf.slice(0, 9), 10) === Number(cpf[9]) && digito(cpf.slice(0, 10), 11) === Number(cpf[10])
  );
}

/** Formata enquanto a pessoa digita: "52998224725" -> "529.982.247-25" (aceita CPF incompleto). */
export function formatarCpf(texto: string): string {
  const digitos = limparCpf(texto).slice(0, 11);
  const [a, b, c, d] = [digitos.slice(0, 3), digitos.slice(3, 6), digitos.slice(6, 9), digitos.slice(9, 11)];

  let saida = a;
  if (b) saida += `.${b}`;
  if (c) saida += `.${c}`;
  if (d) saida += `-${d}`;
  return saida;
}
