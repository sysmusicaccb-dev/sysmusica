/**
 * SysMúsica — Regras puras dos Hinos (sem banco). Testadas em regras.test.ts.
 *
 * Duas categorias: HINO (hinário 5, exibido como "002") e CORO (corinhos, exibidos como "Coro 1", "Coro 2"...).
 * O mesmo número pode existir nas duas categorias (hino 1 e Coro 1). As mesmas regras são aplicadas no banco
 * (migração 0041); aqui ficam as conferências para a tela, a busca e a leitura da lista colada na importação.
 */
import { normalizarTexto } from "@/lib/texto";

export type CategoriaHino = "HINO" | "CORO";

/** Um hino como a função listar_hinos devolve. */
export interface Hino {
  id: string;
  categoria: CategoriaHino;
  numero: number;
  nome: string; // o título do hino
  ativo: boolean;
  em_uso: number; // em quantos ensaios foi usado (hino usado não pode ser excluído, só desativado)
}

export const NUMERO_MINIMO = 1;
export const NUMERO_MAXIMO = 9999;
export const TITULO_MINIMO = 2;
export const TITULO_MAXIMO = 150;
/** Limite de itens por importação (o banco recusa acima disso). */
export const IMPORTACAO_MAXIMA = 2000;

export const ROTULO_CATEGORIA: Record<CategoriaHino, string> = {
  HINO: "Hino",
  CORO: "Coro",
};

/** Como o número aparece: hino do hinário = "002"; coro = "Coro 3". */
export function rotuloHino(categoria: CategoriaHino, numero: number): string {
  return categoria === "CORO" ? `Coro ${numero}` : String(numero).padStart(3, "0");
}

/** "002 – Oh! quão suave é confiar em Jesus" / "Coro 3 – Título". */
export function rotuloCompleto(hino: Pick<Hino, "categoria" | "numero" | "nome">): string {
  return `${rotuloHino(hino.categoria, hino.numero)} – ${hino.nome}`;
}

/** Tira espaços das pontas e os repetidos do título. */
export function formatarTitulo(texto: string): string {
  return texto.trim().replace(/\s+/g, " ");
}

/** Confere os dados de um hino; devolve a mensagem de erro ou null quando está tudo certo. */
export function validarHino(dados: { categoria: string; numero: number | null; nome: string }): string | null {
  if (dados.categoria !== "HINO" && dados.categoria !== "CORO") return "Escolha se é hino ou coro.";
  if (
    dados.numero === null ||
    !Number.isInteger(dados.numero) ||
    dados.numero < NUMERO_MINIMO ||
    dados.numero > NUMERO_MAXIMO
  ) {
    return `Informe o número (de ${NUMERO_MINIMO} a ${NUMERO_MAXIMO}).`;
  }
  const titulo = formatarTitulo(dados.nome);
  if (titulo.length < TITULO_MINIMO) return "Informe o título.";
  if (titulo.length > TITULO_MAXIMO) return `O título pode ter no máximo ${TITULO_MAXIMO} caracteres.`;
  return null;
}

/** Ordem da lista: hinos do hinário primeiro, depois os coros; dentro de cada um, pelo número. */
export function compararHinos(a: Pick<Hino, "categoria" | "numero">, b: Pick<Hino, "categoria" | "numero">): number {
  if (a.categoria !== b.categoria) return a.categoria === "HINO" ? -1 : 1;
  return a.numero - b.numero;
}

/**
 * Busca por número ou título (sem diferenciar acento nem maiúsculas). Exemplos:
 *   "2" ou "002" -> hinos 2, 20..29, 200..299 (e "Coro 2"...); "coro 3" -> Coro 3, 30..39; "suave" -> pelo título.
 */
export function filtrarHinos<T extends Pick<Hino, "categoria" | "numero" | "nome">>(lista: T[], busca: string): T[] {
  const termo = normalizarTexto(busca).replace(/\s+/g, " ");
  if (termo === "") return lista;
  const soNumero = /^\d+$/.test(termo) ? String(Number(termo)) : null;
  return lista.filter((hino) => {
    if (normalizarTexto(hino.nome).includes(termo)) return true;
    if (hino.categoria === "CORO" && normalizarTexto(rotuloHino("CORO", hino.numero)).includes(termo)) return true;
    return soNumero !== null && hino.categoria === "HINO" && String(hino.numero).startsWith(soNumero);
  });
}

// ---------------------------------------------------------------------------
// Importação de uma lista colada (um hino por linha)
// ---------------------------------------------------------------------------

export interface ItemImportacao {
  categoria: CategoriaHino;
  numero: number;
  nome: string;
  linha: number; // linha do texto colado (começa em 1), para avisar onde está um problema
}

export interface ProblemaImportacao {
  linha: number;
  texto: string;
  motivo: string;
}

export interface ListaImportada {
  itens: ItemImportacao[];
  problemas: ProblemaImportacao[];
}

// "001 - Título", "1. Título", "1) Título", "001 Título" e "Coro 1 - Título"
const LINHA_DE_HINO = /^(?:(coro)\s*[-.:]?\s*)?(\d{1,4})(?!\d)\s*[-–—.:)]*\s*(.+)$/i;

/**
 * Lê o texto colado. Linhas começadas por "Coro N" viram coros; as demais usam a categoria escolhida
 * (categoriaPadrao). Linhas vazias são ignoradas; linhas com problema são devolvidas à parte (não são importadas).
 */
export function interpretarLista(texto: string, categoriaPadrao: CategoriaHino): ListaImportada {
  const itens: ItemImportacao[] = [];
  const problemas: ProblemaImportacao[] = [];
  const vistos = new Set<string>();

  texto.split(/\r?\n/).forEach((bruta, indice) => {
    const linha = indice + 1;
    const limpa = bruta.trim();
    if (limpa === "") return;

    const achou = LINHA_DE_HINO.exec(limpa);
    if (!achou) {
      problemas.push({ linha, texto: limpa, motivo: "Não encontrei o número no começo da linha." });
      return;
    }
    const categoria: CategoriaHino = achou[1] ? "CORO" : categoriaPadrao;
    const numero = Number(achou[2]);
    const nome = formatarTitulo(achou[3]);

    const erro = validarHino({ categoria, numero, nome });
    if (erro) {
      problemas.push({ linha, texto: limpa, motivo: erro });
      return;
    }
    const chave = `${categoria}:${numero}`;
    if (vistos.has(chave)) {
      problemas.push({ linha, texto: limpa, motivo: "Número repetido na lista." });
      return;
    }
    vistos.add(chave);
    itens.push({ categoria, numero, nome, linha });
  });

  return { itens, problemas };
}

export interface ResumoImportacao {
  novos: number;
  jaExistem: number; // mesmo número já cadastrado (a importação não altera o título de quem já existe)
  tituloDiferente: number; // dos que já existem, quantos têm título diferente do colado
}

/** Compara a lista lida com o que já está cadastrado. */
export function resumirImportacao(
  itens: ItemImportacao[],
  existentes: Pick<Hino, "categoria" | "numero" | "nome">[]
): ResumoImportacao {
  const mapa = new Map(existentes.map((hino) => [`${hino.categoria}:${hino.numero}`, hino.nome] as const));
  let jaExistem = 0;
  let tituloDiferente = 0;
  for (const item of itens) {
    const atual = mapa.get(`${item.categoria}:${item.numero}`);
    if (atual === undefined) continue;
    jaExistem += 1;
    if (normalizarTexto(atual) !== normalizarTexto(item.nome)) tituloDiferente += 1;
  }
  return { novos: itens.length - jaExistem, jaExistem, tituloDiferente };
}
