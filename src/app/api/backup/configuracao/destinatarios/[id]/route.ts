/** SysMúsica — Rotas /api/backup/configuracao/destinatarios/[id]: PATCH liga ou desliga; DELETE remove. */
import type { NextRequest } from "next/server";
import { autenticar } from "@/modules/backup/server/autorizacao";
import { alterarDestinatario, removerDestinatario } from "@/modules/backup/server/configuracao";
import { ErroBackup } from "@/modules/backup/server/erros";
import { responder } from "@/modules/backup/server/rota";

export async function PATCH(request: NextRequest, contexto: { params: Promise<{ id: string }> }) {
  return responder(async () => {
    const usuario = await autenticar(request, "backup.configurar");
    const { id } = await contexto.params;
    const corpo = (await request.json().catch(() => null)) as { ativo?: unknown } | null;
    if (typeof corpo?.ativo !== "boolean") throw new ErroBackup(400, "Os dados enviados são inválidos.");
    return { destinatarios: await alterarDestinatario(id, corpo.ativo, usuario) };
  });
}

export async function DELETE(request: NextRequest, contexto: { params: Promise<{ id: string }> }) {
  return responder(async () => {
    const usuario = await autenticar(request, "backup.configurar");
    const { id } = await contexto.params;
    return { destinatarios: await removerDestinatario(id, usuario) };
  });
}
