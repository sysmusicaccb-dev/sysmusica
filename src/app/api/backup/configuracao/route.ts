/**
 * SysMúsica — Rotas /api/backup/configuracao: GET lê a configuração dos avisos (sem segredos); PUT salva.
 * Só o Administrador entra (permissão backup.configurar, conferida no banco a cada chamada).
 */
import type { NextRequest } from "next/server";
import { lerEntradaConfiguracao } from "@/modules/backup/configuracao";
import { autenticar } from "@/modules/backup/server/autorizacao";
import { lerConfiguracaoPublica, salvarConfiguracao } from "@/modules/backup/server/configuracao";
import { ErroBackup } from "@/modules/backup/server/erros";
import { responder } from "@/modules/backup/server/rota";

export async function GET(request: NextRequest) {
  return responder(async () => {
    await autenticar(request, "backup.configurar");
    return { configuracao: await lerConfiguracaoPublica() };
  });
}

export async function PUT(request: NextRequest) {
  return responder(async () => {
    const usuario = await autenticar(request, "backup.configurar");
    const entrada = lerEntradaConfiguracao(await request.json().catch(() => null));
    if (!entrada) throw new ErroBackup(400, "Os dados enviados são inválidos.");
    return { configuracao: await salvarConfiguracao(entrada, usuario) };
  });
}
