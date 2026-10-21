/**
 * SysMúsica — Serviço dos documentos de identificação dos membros (frente e verso).
 * Ficam em um bucket PRIVADO (documentos-membros), dentro da pasta do próprio membro:
 *   <id do membro>/frente-<código>.jpg  e  <id do membro>/verso-<código>.jpg
 * Quem cadastra ou edita membros pode anexar; VER o documento exige a permissão membros.cpf (o armazenamento
 * confere). O banco (salvar_cadastro_musical) confere se os dois arquivos existem antes de gravar o cadastro.
 */
import { supabase } from "@/lib/supabase";

export const BUCKET_DOCUMENTOS = "documentos-membros";

export type LadoDocumento = "frente" | "verso";

/** Envia o arquivo (já reduzido) para a pasta do membro e devolve o caminho. */
export async function subirDocumento(membroId: string, lado: LadoDocumento, imagem: Blob): Promise<string> {
  const caminho = `${membroId}/${lado}-${crypto.randomUUID()}.jpg`;
  const { error } = await supabase.storage
    .from(BUCKET_DOCUMENTOS)
    .upload(caminho, imagem, { contentType: "image/jpeg", upsert: false });
  if (error) {
    throw new Error("Não foi possível enviar o documento. Verifique a conexão e tente novamente.");
  }
  return caminho;
}

/**
 * Apaga arquivos enviados que não chegaram a ser usados (o cadastro falhou) ou que foram substituídos.
 * Nunca lança erro: se não for possível apagar, o arquivo só fica sem uso no armazenamento privado.
 */
export async function descartarDocumentos(caminhos: string[]): Promise<void> {
  const lista = caminhos.filter((caminho) => caminho !== "");
  if (lista.length === 0) return;
  try {
    await supabase.storage.from(BUCKET_DOCUMENTOS).remove(lista);
  } catch {
    /* sem permissão ou sem conexão: o arquivo fica sem uso */
  }
}

/** Endereço temporário (5 minutos) para ver o documento; null se não houver permissão ou o arquivo sumiu. */
export async function urlDoDocumento(caminho: string): Promise<string | null> {
  const { data, error } = await supabase.storage.from(BUCKET_DOCUMENTOS).createSignedUrl(caminho, 300);
  if (error || !data) return null;
  return data.signedUrl;
}
