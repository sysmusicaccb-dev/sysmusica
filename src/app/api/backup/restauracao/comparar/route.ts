/**
 * SysMúsica — Rota /api/backup/restauracao/comparar: POST compara um backup com os dados de hoje (só leitura).
 * Somente o Administrador (permissão backup.restaurar, conferida no banco a cada chamada).
 */
import type { NextRequest } from "next/server";
import { autenticar } from "@/modules/backup/server/autorizacao";
import { ErroBackup } from "@/modules/backup/server/erros";
import { responder } from "@/modules/backup/server/rota";
import { compararBackup } from "@/modules/backup/server/restauracao";
import { lerEntradaComparacao } from "@/modules/backup/restauracao";
import { GRUPOS_DADOS } from "@/modules/backup/tabelas";

export const maxDuration = 60;

export async function POST(request: NextRequest) {
  return responder(async () => {
    await autenticar(request, "backup.restaurar");
    const corpo: unknown = await request.json().catch(() => null);
    const entrada = lerEntradaComparacao(
      corpo,
      GRUPOS_DADOS.map((g) => g.id)
    );
    if (!entrada) throw new ErroBackup(400, "Escolha um backup e pelo menos um grupo de dados.");
    return await compararBackup(entrada.id, entrada.grupos);
  });
}
