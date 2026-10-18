/** SysMúsica — Rota POST /api/backup/configuracao/telegram-chats: descobre o ID do chat pelas mensagens recebidas pelo bot. */
import type { NextRequest } from "next/server";
import { autenticar } from "@/modules/backup/server/autorizacao";
import { buscarChatsTelegram } from "@/modules/backup/server/configuracao";
import { responder } from "@/modules/backup/server/rota";

export const maxDuration = 30; // a consulta ao Telegram pode demorar alguns segundos

export async function POST(request: NextRequest) {
  return responder(async () => {
    await autenticar(request, "backup.configurar");
    return { chats: await buscarChatsTelegram() };
  });
}
