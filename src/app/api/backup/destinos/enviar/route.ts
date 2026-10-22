/** Sysmusica — POST /api/backup/destinos/enviar: copia o backup mais recente para o servidor local agora. */
import type { NextRequest } from "next/server";
import { autenticar } from "@/modules/backup/server/autorizacao";
import { enviarMaisRecente } from "@/modules/backup/server/destinos";
import { responder } from "@/modules/backup/server/rota";

export const maxDuration = 60;

export async function POST(request: NextRequest) {
  return responder(async () => {
    const usuario = await autenticar(request, "backup.criar");
    return await enviarMaisRecente(usuario);
  });
}
