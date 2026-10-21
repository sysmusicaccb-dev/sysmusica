/**
 * SysMúsica — Preparo da foto do documento no navegador antes do envio.
 * Reduz a imagem (lado maior de 1600 px, para o texto continuar legível) e converte para JPEG.
 * O armazenamento confere de novo o tipo (JPEG, PNG ou WebP) e o tamanho (máximo de 3 MB).
 * (Mesma ideia de fotoImagem.ts, com a imagem maior e mais nítida porque é um documento.)
 */

const LADO_MAXIMO = 1600;
const QUALIDADE_JPEG = 0.85;
const TAMANHO_MAXIMO_ORIGINAL = 15 * 1024 * 1024; // 15 MB de entrada (a saída é bem menor)

export async function prepararDocumento(arquivo: File): Promise<Blob> {
  if (!arquivo.type.startsWith("image/")) {
    throw new Error("Escolha uma foto do documento (JPG, PNG ou WebP).");
  }
  if (arquivo.size > TAMANHO_MAXIMO_ORIGINAL) {
    throw new Error("A imagem é grande demais (máximo de 15 MB).");
  }

  // "from-image" respeita a rotação gravada pela câmera do celular; se o navegador não aceitar, tenta sem ela
  let bitmap: ImageBitmap;
  try {
    bitmap = await createImageBitmap(arquivo, { imageOrientation: "from-image" });
  } catch {
    try {
      bitmap = await createImageBitmap(arquivo);
    } catch {
      throw new Error("Não foi possível ler esta imagem. Tente outra foto.");
    }
  }

  const escala = Math.min(1, LADO_MAXIMO / Math.max(bitmap.width, bitmap.height));
  const largura = Math.max(1, Math.round(bitmap.width * escala));
  const altura = Math.max(1, Math.round(bitmap.height * escala));

  const canvas = document.createElement("canvas");
  canvas.width = largura;
  canvas.height = altura;
  const contexto = canvas.getContext("2d");
  if (!contexto) {
    bitmap.close();
    throw new Error("Não foi possível processar a imagem neste navegador.");
  }
  contexto.drawImage(bitmap, 0, 0, largura, altura);
  bitmap.close();

  const imagem = await new Promise<Blob | null>((resolver) => canvas.toBlob(resolver, "image/jpeg", QUALIDADE_JPEG));
  if (!imagem) throw new Error("Não foi possível processar a imagem.");
  return imagem;
}
