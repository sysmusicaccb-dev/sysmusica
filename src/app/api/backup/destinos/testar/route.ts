/** Sysmusica — POST /api/backup/destinos/testar: testa o destino JÁ SALVO (alcança o receptor e envia um arquivo de teste). */
import type { NextRequest } from "next/server";
import { autenticar } from "@/modules/backup/server/autorizacao";
import { testarDestino } from "@/modules/backup/server/destinos";
import { responder } from "@/modules/backup/server/rota";

export const maxDuration = 60;

export async function POST(request: NextRequest) {
  return responder(async () => {
    const usuario = await autenticar(request, "backup.configurar");
    return await testarDestino(usuario);
  });
}
