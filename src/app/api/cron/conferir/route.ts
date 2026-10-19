/**
 * SysMúsica — GET /api/cron/conferir: conferência da tarde (18:00 UTC = 15:00 em Salvador): avisa se o backup de
 * hoje não foi feito e, às segundas-feiras, reverifica os backups mais recentes. Protegida pelo CRON_SECRET.
 */
import type { NextRequest } from "next/server";
import { conferirDia, exigirCron } from "@/modules/backup/server/agendamento";
import { responder } from "@/modules/backup/server/rota";

export const maxDuration = 60;

export async function GET(request: NextRequest) {
  return responder(async () => {
    exigirCron(request);
    return await conferirDia();
  });
}
