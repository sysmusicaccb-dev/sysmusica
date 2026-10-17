/**
 * SysMúsica — Tradução de erros do banco para mensagens do usuário.
 *
 * Regras de negócio (P0001), falta de permissão (42501) e validações (23514) já vêm do banco com
 * texto escrito para o usuário. Registro repetido (23505) usa a mensagem informada por quem chama.
 * Qualquer outro erro vira a mensagem padrão, e o detalhe técnico vai só para o console.
 */
export interface ErroDoBanco {
  code?: string;
  message: string;
}

export function mensagemDoErro(
  erro: ErroDoBanco,
  padrao: string,
  duplicado = "Já existe um registro com estes dados."
): string {
  if (erro.code === "23505") return duplicado;
  if (erro.code === "P0001" || erro.code === "42501" || erro.code === "23514") return erro.message;
  console.error("Erro do banco:", erro);
  return padrao;
}
