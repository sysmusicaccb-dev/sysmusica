/**
 * Sysmusica — Rotas /api/backup/agendamento: GET lê o agendamento; PUT salva. Só o Administrador entra
 * (backup.configurar, conferida no banco a cada chamada).
 */
import type { NextRequest } from "next/server";
import { lerEntradaAgendamento } from "@/modules/backup/agendamento";
import { autenticar } from "@/modules/backup/server/autorizacao";
import { lerAgendamentoPublico, salvarAgendamento } from "@/modules/backup/server/agendamento";
import { ErroBackup } from "@/modules/backup/server/erros";
import { responder } from "@/modules/backup/server/rota";

export async function GET(request: NextRequest) {
  return responder(async () => {
    await autenticar(request, "backup.configurar");
    return { agendamento: await lerAgendamentoPublico() };
  });
}

export async function PUT(request: NextRequest) {
  return responder(async () => {
    const usuario = await autenticar(request, "backup.configurar");
    const entrada = lerEntradaAgendamento(await request.json().catch(() => null));
    if (!entrada) throw new ErroBackup(400, "Os dados enviados estão em um formato inválido.");
    return { agendamento: await salvarAgendamento(entrada, usuario) };
  });
}
