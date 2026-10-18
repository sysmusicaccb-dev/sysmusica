/** SysMúsica — Rota DELETE /api/backup/[id]: exclui um backup (exige a permissão de configurar). */
import type { NextRequest } from "next/server";
import { autenticar } from "@/modules/backup/server/autorizacao";
import { excluirBackup } from "@/modules/backup/server/operacoes";
import { responder } from "@/modules/backup/server/rota";

export async function DELETE(request: NextRequest, contexto: { params: Promise<{ id: string }> }) {
  return responder(async () => {
    const usuario = await autenticar(request, "backup.configurar");
    const { id } = await contexto.params;
    return await excluirBackup(id, usuario);
  });
}
