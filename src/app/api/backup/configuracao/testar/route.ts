/** Sysmusica — Rota POST /api/backup/configuracao/testar: envia uma mensagem de teste (Telegram ou e-mail). */
import type { NextRequest } from "next/server";
import { autenticar } from "@/modules/backup/server/autorizacao";
import { testarAviso } from "@/modules/backup/server/configuracao";
import { ErroBackup } from "@/modules/backup/server/erros";
import { responder } from "@/modules/backup/server/rota";

export const maxDuration = 30; // o envio pode demorar alguns segundos

export async function POST(request: NextRequest) {
  return responder(async () => {
    const usuario = await autenticar(request, "backup.configurar");
    const corpo = (await request.json().catch(() => null)) as { canal?: unknown } | null;
    if (corpo?.canal !== "telegram" && corpo?.canal !== "email") throw new ErroBackup(400, "Canal inválido.");
    return await testarAviso(corpo.canal, usuario);
  });
}
