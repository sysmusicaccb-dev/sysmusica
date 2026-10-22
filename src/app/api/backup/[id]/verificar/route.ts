/** Sysmusica — Rota POST /api/backup/[id]/verificar: confere o arquivo (sem restaurar nada). */
import type { NextRequest } from "next/server";
import { autenticar } from "@/modules/backup/server/autorizacao";
import { verificarBackup } from "@/modules/backup/server/operacoes";
import { responder } from "@/modules/backup/server/rota";

export const maxDuration = 60; // abrir e conferir o arquivo pode levar alguns segundos

export async function POST(request: NextRequest, contexto: { params: Promise<{ id: string }> }) {
  return responder(async () => {
    const usuario = await autenticar(request, "backup.visualizar");
    const { id } = await contexto.params;
    return await verificarBackup(id, usuario);
  });
}
