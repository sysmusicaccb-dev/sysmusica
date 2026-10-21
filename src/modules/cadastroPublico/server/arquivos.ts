/**
 * SysMúsica — Nomes e movimentação dos arquivos do cadastro público (SOMENTE SERVIDOR).
 *
 * Enquanto o pedido está na fila, as 3 imagens ficam no bucket privado "cadastro-publico", em <id>/foto.jpg,
 * frente.jpg e verso.jpg. Na aprovação elas são MOVIDAS para as pastas finais do membro (fotos-membros e
 * documentos-membros); se a aprovação falhar no banco, são devolvidas.
 */
import "server-only";
import type { SupabaseClient } from "@supabase/supabase-js";

export const BUCKET_PUBLICO = "cadastro-publico";

export interface Movimento {
  de: { bucket: string; caminho: string };
  para: { bucket: string; caminho: string };
}

/** Caminhos dos arquivos na fila. */
export function caminhosNaFila(pedidoId: string) {
  return { foto: `${pedidoId}/foto.jpg`, frente: `${pedidoId}/frente.jpg`, verso: `${pedidoId}/verso.jpg` };
}

/** Movimentos da aprovação: fila -> pastas finais do membro (nomes únicos, como no cadastro interno). */
export function movimentosDaAprovacao(pedidoId: string, membroId: string, sufixo: () => string) {
  const fila = caminhosNaFila(pedidoId);
  const foto: Movimento = {
    de: { bucket: BUCKET_PUBLICO, caminho: fila.foto },
    para: { bucket: "fotos-membros", caminho: `${membroId}/${sufixo()}.jpg` },
  };
  const frente: Movimento = {
    de: { bucket: BUCKET_PUBLICO, caminho: fila.frente },
    para: { bucket: "documentos-membros", caminho: `${membroId}/frente-${sufixo()}.jpg` },
  };
  const verso: Movimento = {
    de: { bucket: BUCKET_PUBLICO, caminho: fila.verso },
    para: { bucket: "documentos-membros", caminho: `${membroId}/verso-${sufixo()}.jpg` },
  };
  return { foto, frente, verso };
}

/** Move um arquivo entre buckets. */
async function mover(admin: SupabaseClient, m: Movimento): Promise<void> {
  const { error } = await admin.storage.from(m.de.bucket).move(m.de.caminho, m.para.caminho, {
    destinationBucket: m.para.bucket,
  });
  if (error) throw new Error(`Falha ao mover ${m.de.caminho}: ${error.message}`);
}

/**
 * Move todos; se algum falhar, devolve os que já foram e lança o erro.
 * Devolve a lista dos movimentos feitos (para desfazer depois, se o banco recusar).
 */
export async function moverTodos(admin: SupabaseClient, movimentos: Movimento[]): Promise<Movimento[]> {
  const feitos: Movimento[] = [];
  try {
    for (const m of movimentos) {
      await mover(admin, m);
      feitos.push(m);
    }
  } catch (e) {
    await desfazer(admin, feitos);
    throw e;
  }
  return feitos;
}

/** Devolve os arquivos para a fila (melhor esforço: erros só vão para o log). */
export async function desfazer(admin: SupabaseClient, feitos: Movimento[]): Promise<void> {
  for (const m of [...feitos].reverse()) {
    try {
      await mover(admin, { de: m.para, para: m.de });
    } catch (e) {
      console.error("Não consegui devolver o arquivo à fila:", e);
    }
  }
}

/** Apaga arquivos de um bucket (melhor esforço). */
export async function apagar(admin: SupabaseClient, bucket: string, caminhos: Array<string | null | undefined>): Promise<void> {
  const lista = caminhos.filter((c): c is string => typeof c === "string" && c !== "");
  if (lista.length === 0) return;
  const { error } = await admin.storage.from(bucket).remove(lista);
  if (error) console.error(`Não consegui apagar arquivos de ${bucket}:`, error.message);
}
