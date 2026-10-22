/**
 * Sysmusica — Tradução de erros do banco para mensagens do usuário.
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
  // O próprio Postgres também usa 42501 com texto técnico em inglês ("permission denied...", "...row-level security...").
  // Esse texto vira uma mensagem clara; as mensagens escritas pelo sistema (em português) passam direto.
  if (erro.code === "42501" && /^(permission denied|new row violates row-level security)/i.test(erro.message)) {
    console.error("Permissão negada pelo banco:", erro);
    return "Você não tem permissão para fazer esta ação. Se acha que deveria ter, fale com o Administrador.";
  }
  if (erro.code === "23503") {
    console.error("Referência inválida:", erro);
    return "Este registro está ligado a outros dados (ou aponta para algo que não existe mais), por isso a operação não foi feita.";
  }
  if (erro.code === "23502") {
    console.error("Campo obrigatório vazio:", erro);
    return "Preencha todos os campos obrigatórios e tente de novo.";
  }
  if (erro.code === "P0001" || erro.code === "42501" || erro.code === "23514") return erro.message;
  console.error("Erro do banco:", erro);
  return padrao;
}
