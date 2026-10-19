/**
 * SysMúsica — GET /api/cron/backup: rotina diária do agendamento (chamada pelo Vercel às 06:00 UTC = 03:00 em
 * Salvador). Protegida pelo segredo CRON_SECRET que o próprio Vercel envia. Não usamos "runtime" nem "dynamic":
 * o projeto usa cacheComponents, que não aceita essas opções.
 */
import type { NextRequest } from "next/server";
import { exigirCron, executarRotina } from "@/modules/backup/server/agendamento";
import { responder } from "@/modules/backup/server/rota";

export const maxDuration = 60; // backup + verificação + cópia para o servidor local

export async function GET(request: NextRequest) {
  return responder(async () => {
    exigirCron(request);
    return await executarRotina({ forcar: false, usuario: null });
  });
}
