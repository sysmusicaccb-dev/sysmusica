/**
 * Sysmusica — Rotas /api/backup/destinos: GET lê o destino (segredos só mascarados); PUT salva.
 * Só o Administrador entra (backup.configurar, conferida no banco a cada chamada).
 * Não usamos "runtime" nem "dynamic": o projeto usa cacheComponents, que não aceita essas opções.
 */
import type { NextRequest } from "next/server";
import { lerEntradaDestino } from "@/modules/backup/destinos";
import { autenticar } from "@/modules/backup/server/autorizacao";
import { lerDestinoPublico, salvarDestino } from "@/modules/backup/server/destinos";
import { ErroBackup } from "@/modules/backup/server/erros";
import { responder } from "@/modules/backup/server/rota";

export async function GET(request: NextRequest) {
  return responder(async () => {
    await autenticar(request, "backup.configurar");
    return { destino: await lerDestinoPublico() };
  });
}

export async function PUT(request: NextRequest) {
  return responder(async () => {
    const usuario = await autenticar(request, "backup.configurar");
    const entrada = lerEntradaDestino(await request.json().catch(() => null));
    if (!entrada) throw new ErroBackup(400, "Os dados enviados estão em um formato inválido.");
    return { destino: await salvarDestino(entrada, usuario) };
  });
}
