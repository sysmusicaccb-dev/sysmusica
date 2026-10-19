/** SysMúsica — POST /api/backup/agendamento/executar: roda a rotina de hoje agora (botão do Administrador). */
import type { NextRequest } from "next/server";
import { autenticar } from "@/modules/backup/server/autorizacao";
import { executarRotina } from "@/modules/backup/server/agendamento";
import { responder } from "@/modules/backup/server/rota";

export const maxDuration = 60;

export async function POST(request: NextRequest) {
  return responder(async () => {
    const usuario = await autenticar(request, "backup.criar");
    const r = await executarRotina({ forcar: true, usuario });
    return { ...r, mensagem: r.resultado === "falhou" ? `A rotina terminou com problema: ${r.detalhe}.` : `Rotina concluída: ${r.detalhe}.` };
  });
}
