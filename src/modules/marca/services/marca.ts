/**
 * Sysmusica — Serviço da logo do sistema (navegador).
 * Ler: qualquer pessoa (até sem login, a tela de entrada usa). Trocar e restaurar: só o Master (o banco confere).
 * O arquivo vai para o armazenamento público "marca" e os dados (tipo, medidas) ficam na tabela marca_sistema.
 */
import { supabase } from "@/lib/supabase";
import { mensagemDoErro } from "@/lib/erros";
import { extensaoDaLogoOuNada, nomeDoArquivoDaLogo, type MarcaSalva } from "../regras";

const BUCKET = "marca";

/** Logo gravada no banco; null = vale a clave de sol padrão. */
export async function buscarMarca(): Promise<MarcaSalva | null> {
  const { data, error } = await supabase.rpc("marca_do_sistema");
  if (error) throw new Error(error.message);
  return (data as MarcaSalva | null) ?? null;
}

/** Endereço público da imagem (com a versão, para o navegador não mostrar a antiga). */
export function urlPublicaDaLogo(marca: MarcaSalva): string {
  const { data } = supabase.storage.from(BUCKET).getPublicUrl(marca.caminho);
  return `${data.publicUrl}?v=${marca.versao}`;
}

/** Envia a imagem e passa a usá-la como logo. A imagem antiga é apagada do armazenamento. */
export async function enviarLogo(arquivo: File, largura: number, altura: number): Promise<void> {
  const extensao = extensaoDaLogoOuNada(arquivo.type);
  if (!extensao) throw new Error("Tipo de arquivo não aceito. Use PNG, JPG, WEBP ou SVG.");
  const caminho = nomeDoArquivoDaLogo(extensao, crypto.randomUUID());

  const envio = await supabase.storage.from(BUCKET).upload(caminho, arquivo, {
    contentType: arquivo.type,
    upsert: false,
    cacheControl: "31536000", // o nome muda a cada troca, então pode ficar guardada por muito tempo
  });
  if (envio.error) throw new Error(mensagemDoErro(envio.error, "Não foi possível enviar a imagem."));

  const { data, error } = await supabase.rpc("salvar_marca_do_sistema", {
    p_caminho: caminho,
    p_tipo: arquivo.type,
    p_largura: largura,
    p_altura: altura,
    p_tamanho: arquivo.size,
  });
  if (error) {
    await supabase.storage.from(BUCKET).remove([caminho]); // não deixa arquivo solto
    throw new Error(mensagemDoErro(error, "Não foi possível trocar a logo."));
  }
  if (typeof data === "string" && data) await supabase.storage.from(BUCKET).remove([data]);
}

/** Volta para a clave de sol padrão (e apaga a imagem enviada). */
export async function restaurarLogoPadrao(): Promise<void> {
  const { data, error } = await supabase.rpc("restaurar_marca_padrao");
  if (error) throw new Error(mensagemDoErro(error, "Não foi possível restaurar a logo padrão."));
  if (typeof data === "string" && data) await supabase.storage.from(BUCKET).remove([data]);
}
