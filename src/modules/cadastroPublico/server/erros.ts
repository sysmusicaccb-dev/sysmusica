/**
 * SysMúsica — Tradução dos erros do banco para respostas HTTP das rotas do cadastro público/pendentes.
 * As funções do banco escrevem a mensagem para a pessoa (em português). Só repassamos a mensagem dos códigos
 * "esperados"; qualquer outro erro vira a mensagem genérica e o detalhe fica apenas no log do servidor.
 */
import { ErroHttp } from "@/modules/administracao/server/erros";

export interface ErroDoBanco {
  code?: string;
  message?: string;
}

const STATUS_POR_CODIGO: Record<string, number> = {
  P0429: 429, // limite de tentativas
  "42501": 403, // sem permissão
  P0002: 404, // não encontrado
  "23505": 409, // CPF já existe
  "22023": 409, // regra de negócio (já analisado, arquivo ausente...)
  P0001: 400, // raise exception comum (validação do formulário)
};

/** Devolve um ErroHttp com a mensagem do banco (códigos esperados) ou um Error genérico para o log. */
export function erroDoBanco(erro: ErroDoBanco): Error {
  const status = erro.code ? STATUS_POR_CODIGO[erro.code] : undefined;
  if (status && erro.message) return new ErroHttp(status, erro.message);
  return new Error(`Erro do banco (${erro.code ?? "sem código"}): ${erro.message ?? ""}`);
}

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export function exigirUuid(valor: unknown): string {
  if (typeof valor !== "string" || !UUID.test(valor)) throw new ErroHttp(400, "Pedido inválido.");
  return valor;
}
