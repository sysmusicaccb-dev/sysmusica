/**
 * SysMúsica — Limpeza diária do cadastro público (chamada pelo cron /api/cron/conferir, 1x por dia).
 *
 * O banco diz QUAIS pastas devem ser apagadas (envios abandonados há 24 h, pedidos vencidos em 60 dias, recusados há
 * 30 dias). Aqui o servidor apaga os arquivos do armazenamento e, SÓ se conseguiu apagar tudo, avisa o banco para
 * zerar os dados pessoais desses pedidos. Se algo falhar, nada é marcado e a limpeza tenta de novo no dia seguinte.
 */
import "server-only";
import type { SupabaseClient } from "@supabase/supabase-js";
import { clienteAdmin } from "@/modules/administracao/server/clienteAdmin";
import { BUCKET_PUBLICO, caminhosNaFila } from "./arquivos";

interface RespostaLimpeza {
  pastas: string[];
  para_marcar: string[];
  abandonados: string[];
}

export interface ResultadoLimpeza {
  pastas: number;
  arquivos_apagados: number;
  pedidos_zerados: number;
  falhou: boolean;
}

const LOTE = 100;

export async function limparCadastroPublico(admin: SupabaseClient = clienteAdmin()): Promise<ResultadoLimpeza> {
  const { data, error } = await admin.rpc("limpeza_cadastro_publico");
  if (error || !data) throw new Error(`Limpeza do cadastro público falhou: ${error?.message ?? "sem resposta"}`);
  const r = data as RespostaLimpeza;

  const caminhos = r.pastas.flatMap((id) => Object.values(caminhosNaFila(id)));
  let apagados = 0;
  let falhou = false;
  for (let i = 0; i < caminhos.length; i += LOTE) {
    const lote = caminhos.slice(i, i + LOTE);
    const { data: removidos, error: erroRemover } = await admin.storage.from(BUCKET_PUBLICO).remove(lote);
    if (erroRemover) {
      console.error("Falha ao apagar arquivos do cadastro público:", erroRemover.message);
      falhou = true;
      break;
    }
    apagados += removidos?.length ?? 0;
  }

  let zerados = 0;
  if (!falhou && (r.para_marcar.length > 0 || r.abandonados.length > 0)) {
    const { data: n, error: erroMarcar } = await admin.rpc("marcar_cadastros_limpos", {
      p_ids: r.para_marcar,
      p_abandonados: r.abandonados,
    });
    if (erroMarcar) {
      console.error("Falha ao marcar cadastros limpos:", erroMarcar.message);
      falhou = true;
    } else {
      zerados = Number(n ?? 0);
    }
  }
  return { pastas: r.pastas.length, arquivos_apagados: apagados, pedidos_zerados: zerados, falhou };
}
