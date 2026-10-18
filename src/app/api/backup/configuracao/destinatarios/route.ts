/** SysMúsica — Rota POST /api/backup/configuracao/destinatarios: adiciona um e-mail que recebe os avisos. */
import type { NextRequest } from "next/server";
import { autenticar } from "@/modules/backup/server/autorizacao";
import { adicionarDestinatario } from "@/modules/backup/server/configuracao";
import { ErroBackup } from "@/modules/backup/server/erros";
import { responder } from "@/modules/backup/server/rota";

export async function POST(request: NextRequest) {
  return responder(async () => {
    const usuario = await autenticar(request, "backup.configurar");
    const corpo = (await request.json().catch(() => null)) as { email?: unknown } | null;
    if (typeof corpo?.email !== "string") throw new ErroBackup(400, "Digite um e-mail válido.");
    return { destinatarios: await adicionarDestinatario(corpo.email, usuario) };
  });
}
