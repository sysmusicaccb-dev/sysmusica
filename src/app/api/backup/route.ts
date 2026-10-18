/**
 * SysMúsica — Rotas /api/backup: GET lista os backups; POST faz um backup manual agora.
 * Só o Administrador entra (a permissão é conferida no banco a cada chamada).
 * Não usamos "runtime" nem "dynamic" aqui: o projeto usa cacheComponents, que não aceita essas opções.
 */
import type { NextRequest } from "next/server";
import { autenticar } from "@/modules/backup/server/autorizacao";
import { fazerBackup, listarBackups } from "@/modules/backup/server/operacoes";
import { responder } from "@/modules/backup/server/rota";

export const maxDuration = 60; // o backup pode levar alguns segundos

export async function GET(request: NextRequest) {
  return responder(async () => {
    await autenticar(request, "backup.visualizar");
    return { backups: await listarBackups() };
  });
}

export async function POST(request: NextRequest) {
  return responder(async () => {
    const usuario = await autenticar(request, "backup.criar");
    const corpo = (await request.json().catch(() => ({}))) as { observacao?: unknown };
    const observacao = typeof corpo.observacao === "string" ? corpo.observacao.trim().slice(0, 200) || null : null;
    return await fazerBackup({ tipo: "manual", usuario, observacao });
  });
}
