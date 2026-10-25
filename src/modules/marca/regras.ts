/**
 * Sysmusica — Regras da logo do sistema (puras, sem banco e sem tela; testadas em regras.test.ts).
 * O banco (migração 0067) confere as mesmas regras de novo: a tela é só a resposta rápida.
 */

export interface TipoDeLogo {
  mime: string; // tipo do arquivo, como o navegador informa
  extensao: string; // extensão guardada no nome do arquivo
  rotulo: string; // como aparece para a pessoa
}

/** Tipos de arquivo aceitos. */
export const TIPOS_DE_LOGO: TipoDeLogo[] = [
  { mime: "image/png", extensao: "png", rotulo: "PNG" },
  { mime: "image/jpeg", extensao: "jpg", rotulo: "JPG" },
  { mime: "image/webp", extensao: "webp", rotulo: "WEBP" },
  { mime: "image/svg+xml", extensao: "svg", rotulo: "SVG" },
];

/** Menor e maior medida (em pixels) de cada lado da imagem. */
export const LOGO_MINIMO_PX = 64;
export const LOGO_MAXIMO_PX = 2048;
/** Medida recomendada: quadrada, 256 por 256 pixels. */
export const LOGO_RECOMENDADO_PX = 256;
/** Tamanho máximo do arquivo: 1 MB. */
export const LOGO_MAXIMO_BYTES = 1024 * 1024;

/** Valor do atributo accept do campo de arquivo. */
export const ACEITA_LOGO = TIPOS_DE_LOGO.map((tipo) => tipo.mime).join(",");

/** Logo gravada no banco (função marca_do_sistema). */
export interface MarcaSalva {
  caminho: string;
  tipo: string;
  largura: number;
  altura: number;
  tamanho_bytes: number;
  versao: number; // muda a cada troca (evita mostrar a imagem antiga guardada no navegador)
}

export function tipoDeLogo(mime: string): TipoDeLogo | undefined {
  return TIPOS_DE_LOGO.find((tipo) => tipo.mime === mime);
}

/** Extensão do arquivo para o tipo aceito; undefined se o tipo não é aceito. */
export function extensaoDaLogoOuNada(mime: string): string | undefined {
  return tipoDeLogo(mime)?.extensao;
}

export function rotuloDoTipo(mime: string): string {
  return tipoDeLogo(mime)?.rotulo ?? mime;
}

/** "256 KB", "1,2 MB"... */
export function formatarTamanho(bytes: number): string {
  if (bytes < 1024) return `${bytes} B`;
  if (bytes < 1024 * 1024) return `${Math.round(bytes / 1024)} KB`;
  return `${(bytes / (1024 * 1024)).toFixed(1).replace(".", ",")} MB`;
}

/** Nome do arquivo no armazenamento: logo-<32 letras/números>.<extensão> (mesmo formato que o banco exige). */
export function nomeDoArquivoDaLogo(extensao: string, identificador: string): string {
  return `logo-${identificador.replace(/-/g, "").toLowerCase()}.${extensao}`;
}

export interface DadosDaImagem {
  tipo: string;
  bytes: number;
  largura: number;
  altura: number;
}

/** Confere a imagem escolhida. Devolve a mensagem do primeiro problema ou null se estiver tudo certo. */
export function validarLogo(imagem: DadosDaImagem): string | null {
  if (!tipoDeLogo(imagem.tipo)) return "Tipo de arquivo não aceito. Use PNG, JPG, WEBP ou SVG.";
  if (imagem.bytes <= 0) return "O arquivo está vazio.";
  if (imagem.bytes > LOGO_MAXIMO_BYTES) {
    return `O arquivo tem ${formatarTamanho(imagem.bytes)}. O máximo é ${formatarTamanho(LOGO_MAXIMO_BYTES)}.`;
  }
  if (imagem.largura < LOGO_MINIMO_PX || imagem.altura < LOGO_MINIMO_PX) {
    return `A imagem tem ${imagem.largura} x ${imagem.altura} pixels. O mínimo é ${LOGO_MINIMO_PX} x ${LOGO_MINIMO_PX}.`;
  }
  if (imagem.largura > LOGO_MAXIMO_PX || imagem.altura > LOGO_MAXIMO_PX) {
    return `A imagem tem ${imagem.largura} x ${imagem.altura} pixels. O máximo é ${LOGO_MAXIMO_PX} x ${LOGO_MAXIMO_PX}.`;
  }
  return null;
}

/** Aviso (não impede de salvar) quando a imagem não é quadrada: ela será ajustada dentro do quadrado, sem cortar. */
export function avisoDeProporcao(largura: number, altura: number): string | null {
  if (largura <= 0 || altura <= 0) return null;
  const razao = largura / altura;
  if (razao > 1.15 || razao < 0.87) {
    return "A imagem não é quadrada: ela será ajustada dentro de um quadrado (sem cortar), ficando com espaço nas laterais.";
  }
  return null;
}
