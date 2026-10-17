/**
 * SysMúsica — Preparo da fotografia no navegador antes do envio.
 * Reduz a imagem (lado maior de 800 px) e converte para JPEG: a foto fica leve (poucas centenas de KB)
 * e o envio é rápido, inclusive em rede móvel. A conferência de tipo e tamanho final também é feita
 * pelo armazenamento do banco (limite de 2 MB; JPEG, PNG ou WebP).
 */

const LADO_MAXIMO = 800;
const QUALIDADE_JPEG = 0.82;
const TAMANHO_MAXIMO_ORIGINAL = 15 * 1024 * 1024; // 15 MB de entrada (a saída é bem menor)

export async function prepararFoto(arquivo: File): Promise<Blob> {
  if (!arquivo.type.startsWith("image/")) {
    throw new Error("Escolha um arquivo de imagem (JPG, PNG ou WebP).");
  }
  if (arquivo.size > TAMANHO_MAXIMO_ORIGINAL) {
    throw new Error("A imagem é grande demais (máximo de 15 MB).");
  }

  // "from-image" respeita a rotação gravada pela câmera do celular; se o navegador não aceitar a opção, tenta sem ela
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

  const imagem = await new Promise<Blob | null>((resolver) =>
    canvas.toBlob(resolver, "image/jpeg", QUALIDADE_JPEG)
  );
  if (!imagem) throw new Error("Não foi possível processar a imagem.");
  return imagem;
}
