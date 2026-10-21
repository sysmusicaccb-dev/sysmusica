/**
 * SysMúsica — GET /api/cron/conferir: conferência da tarde (18:00 UTC = 15:00 em Salvador): avisa se o backup de
 * hoje não foi feito e, às segundas-feiras, reverifica os backups mais recentes. Protegida pelo CRON_SECRET.
 */
import type { NextRequest } from "next/server";
import { conferirDia, exigirCron } from "@/modules/backup/server/agendamento";
import { responder } from "@/modules/backup/server/rota";
import { limparCadastroPublico } from "@/modules/cadastroPublico/server/limpeza";

export const maxDuration = 60;

export async function GET(request: NextRequest) {
  return responder(async () => {
    exigirCron(request);
    const conferencia = await conferirDia();
    // Aproveita a conferência diária para apagar fotos/documentos de cadastros públicos vencidos ou recusados
    // (um erro aqui não pode derrubar a conferência do backup; a limpeza tenta de novo no dia seguinte).
    let cadastroPublico: unknown = null;
    try {
      cadastroPublico = await limparCadastroPublico();
    } catch (erro) {
      console.error("Limpeza do cadastro público falhou:", erro instanceof Error ? erro.message : erro);
      cadastroPublico = { falhou: true };
    }
    return { conferencia, cadastro_publico: cadastroPublico };
  });
}
