/** SysMúsica — Rota POST /api/backup/[id]/baixar: devolve um link temporário para baixar o arquivo criptografado. */
import type { NextRequest } from "next/server";
import { autenticar } from "@/modules/backup/server/autorizacao";
import { urlDeDownload } from "@/modules/backup/server/operacoes";
import { responder } from "@/modules/backup/server/rota";

export async function POST(request: NextRequest, contexto: { params: Promise<{ id: string }> }) {
  return responder(async () => {
    const usuario = await autenticar(request, "backup.visualizar");
    const { id } = await contexto.params;
    return await urlDeDownload(id, usuario);
  });
}
