/** Sysmusica — Envelope das rotas de backup: devolve JSON, converte erros em respostas e nunca guarda cache. */
import { NextResponse } from "next/server";
import { ErroBackup } from "./erros";

export async function responder(tarefa: () => Promise<unknown>): Promise<NextResponse> {
  const cabecalhos = { "Cache-Control": "no-store" };
  try {
    return NextResponse.json(await tarefa(), { headers: cabecalhos });
  } catch (e) {
    if (e instanceof ErroBackup) {
      return NextResponse.json({ erro: e.message }, { status: e.status, headers: cabecalhos });
    }
    console.error("Falha em uma rota de backup:", e);
    return NextResponse.json({ erro: "Erro interno no servidor." }, { status: 500, headers: cabecalhos });
  }
}
