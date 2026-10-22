/**
 * Sysmusica — Rota /api/backup/restauracao/aplicar: POST restaura um backup (grava no banco).
 * Somente o Administrador (backup.restaurar), com a SENHA conferida de novo a cada restauração.
 */
import type { NextRequest } from "next/server";
import { lerEntradaAplicacao } from "@/modules/backup/aplicacao";
import { autenticar } from "@/modules/backup/server/autorizacao";
import { ErroBackup } from "@/modules/backup/server/erros";
import { restaurarBackup } from "@/modules/backup/server/aplicacao";
import { responder } from "@/modules/backup/server/rota";
import { GRUPOS_DADOS } from "@/modules/backup/tabelas";

export const maxDuration = 60;

export async function POST(request: NextRequest) {
  return responder(async () => {
    const usuario = await autenticar(request, "backup.restaurar");
    const corpo: unknown = await request.json().catch(() => null);
    const entrada = lerEntradaAplicacao(
      corpo,
      GRUPOS_DADOS.map((g) => g.id)
    );
    if (!entrada) throw new ErroBackup(400, "Confira o backup, os grupos, a senha e (no modo Espelhar) a palavra ESPELHAR.");
    return await restaurarBackup(entrada, usuario);
  });
}
