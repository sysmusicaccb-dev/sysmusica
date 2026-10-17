/**
 * SysMúsica — Resposta de erro padronizada das rotas de servidor da Administração.
 * Erros esperados (ErroHttp) saem com a própria mensagem; qualquer outro vira um erro genérico
 * e o detalhe técnico fica só no log do servidor.
 */
import { NextResponse } from "next/server";
import { ErroHttp } from "./erros";

export function respostaDeErro(erro: unknown): NextResponse {
  if (erro instanceof ErroHttp) {
    return NextResponse.json({ erro: erro.message }, { status: erro.status });
  }
  console.error("Erro inesperado na rota de administração:", erro);
  return NextResponse.json(
    { erro: "Não foi possível concluir a operação. Tente novamente." },
    { status: 500 }
  );
}
