/**
 * SysMúsica — Serviço das fotografias dos membros.
 * As fotos ficam em um bucket PRIVADO: para exibir, gera-se uma URL temporária (assinada).
 * Quem pode enviar, trocar ou remover é controlado pela permissão membros.foto (banco + armazenamento).
 */
import { supabase } from "@/lib/supabase";
import { mensagemDoErro } from "@/lib/erros";

export const BUCKET_FOTOS = "fotos-membros";

export interface MembroFoto {
  id: string;
  nome: string;
  congregacao: string | null;
  foto_path: string | null;
}

/** Membros (não excluídos) com o caminho da foto, para a tela de fotografias. */
export async function listarMembrosParaFoto(): Promise<MembroFoto[]> {
  const { data, error } = await supabase.rpc("listar_membros_para_foto");
  if (error) throw new Error(mensagemDoErro(error, "Não foi possível carregar os membros."));
  return (data ?? []) as MembroFoto[];
}

// Guarda as URLs temporárias por alguns minutos para não pedir a mesma foto várias vezes
const cacheUrls = new Map<string, { url: string; expira: number }>();
const VALIDADE_URL_SEGUNDOS = 600;

/** URL temporária de uma foto (ou null se não for possível gerar). */
export async function urlDaFoto(caminho: string): Promise<string | null> {
  const agora = Date.now();
  const guardada = cacheUrls.get(caminho);
  if (guardada && guardada.expira > agora) return guardada.url;

  const { data, error } = await supabase.storage
    .from(BUCKET_FOTOS)
    .createSignedUrl(caminho, VALIDADE_URL_SEGUNDOS);
  if (error || !data) return null;

  cacheUrls.set(caminho, { url: data.signedUrl, expira: agora + (VALIDADE_URL_SEGUNDOS - 60) * 1000 });
  return data.signedUrl;
}

/** URLs temporárias de várias fotos de uma vez: { caminho: url }. */
export async function urlsDasFotos(caminhos: string[]): Promise<Record<string, string>> {
  if (caminhos.length === 0) return {};
  const { data, error } = await supabase.storage
    .from(BUCKET_FOTOS)
    .createSignedUrls(caminhos, VALIDADE_URL_SEGUNDOS);
  if (error || !data) return {};

  const mapa: Record<string, string> = {};
  for (const item of data) {
    if (item.path && item.signedUrl) mapa[item.path] = item.signedUrl;
  }
  return mapa;
}

/** Envia a foto (já reduzida) e a vincula ao membro; apaga o arquivo anterior. */
export async function enviarFoto(membroId: string, imagem: Blob): Promise<void> {
  const caminho = `${membroId}/${crypto.randomUUID()}.jpg`;

  const { error: erroEnvio } = await supabase.storage
    .from(BUCKET_FOTOS)
    .upload(caminho, imagem, { contentType: "image/jpeg", upsert: false });
  if (erroEnvio) {
    throw new Error("Não foi possível enviar a fotografia. Verifique a conexão e tente novamente.");
  }

  const { data, error } = await supabase.rpc("definir_foto_membro", { p_membro_id: membroId, p_path: caminho });
  if (error) {
    // Desfaz o envio: não deixa arquivo solto no armazenamento
    await supabase.storage.from(BUCKET_FOTOS).remove([caminho]);
    throw new Error(mensagemDoErro(error, "Não foi possível salvar a fotografia."));
  }

  // Arquivo antigo: apagar é um cuidado extra; se falhar, a foto nova já está valendo
  const anterior = data as string | null;
  if (anterior) await supabase.storage.from(BUCKET_FOTOS).remove([anterior]);
}

/** Remove a fotografia do membro (referência no banco e arquivo). */
export async function removerFoto(membroId: string): Promise<void> {
  const { data, error } = await supabase.rpc("remover_foto_membro", { p_membro_id: membroId });
  if (error) throw new Error(mensagemDoErro(error, "Não foi possível remover a fotografia."));

  const anterior = data as string | null;
  if (anterior) await supabase.storage.from(BUCKET_FOTOS).remove([anterior]);
}
