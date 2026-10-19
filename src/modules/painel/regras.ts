/**
 * SysMúsica — Regras puras do painel ao vivo (sem banco). Testadas em regras.test.ts.
 * A contagem de verdade é feita no banco (função painel_ao_vivo); aqui ficam a montagem dos blocos para a tela,
 * os percentuais, os formatos de data e hora e a regra do campo Categoria do membro.
 */
import type {
  BlocoPainel,
  BlocoResumo,
  ContagemFamilia,
  FamiliaResumo,
  LinhaPainel,
  TipoCategoria,
} from "./tipos";

// ---------- Atualização automática ----------

/** Intervalos que o usuário pode escolher, em segundos. */
export const INTERVALOS_SEGUNDOS = [5, 10, 15, 30, 60] as const;
export const INTERVALO_PADRAO = 10;

/** Devolve o intervalo se for um dos permitidos; senão, o padrão (10 s). */
export function intervaloValido(valor: unknown): number {
  const numero = typeof valor === "number" ? valor : Number(valor);
  return (INTERVALOS_SEGUNDOS as readonly number[]).includes(numero) ? numero : INTERVALO_PADRAO;
}

// ---------- Percentuais e formatos ----------

/** "27,7%": a parte sobre o total, com uma casa decimal e vírgula. Total zero dá "0,0%". */
export function formatarPercentual(parte: number, total: number): string {
  const valor = total > 0 ? (parte / total) * 100 : 0;
  return `${valor.toLocaleString("pt-BR", { minimumFractionDigits: 1, maximumFractionDigits: 1 })}%`;
}

const FUSO = "America/Sao_Paulo";

/** Dia do evento no formato dd/mm/aaaa (fuso de Salvador). */
export function formatarDiaDoEvento(iso: string): string {
  return new Intl.DateTimeFormat("pt-BR", {
    timeZone: FUSO,
    day: "2-digit",
    month: "2-digit",
    year: "numeric",
  }).format(new Date(iso));
}

/** Hora do evento: "09h" quando é em ponto, "09h30" nos demais casos (fuso de Salvador). */
export function formatarHoraDoEvento(iso: string): string {
  const [hora, minuto] = new Intl.DateTimeFormat("pt-BR", {
    timeZone: FUSO,
    hour: "2-digit",
    minute: "2-digit",
    hour12: false,
  })
    .format(new Date(iso))
    .split(":");
  return minuto === "00" ? `${hora}h` : `${hora}h${minuto}`;
}

/** "Atualizado às 10:46:12" (fuso de Salvador). */
export function formatarHoraDaAtualizacao(data: Date): string {
  return new Intl.DateTimeFormat("pt-BR", {
    timeZone: FUSO,
    hour: "2-digit",
    minute: "2-digit",
    second: "2-digit",
    hour12: false,
  }).format(data);
}

// ---------- Montagem dos blocos ----------

export const ROTULO_BLOCO: Record<BlocoPainel, string> = {
  MINISTERIO: "Ministério",
  MUSICOS: "Músicos",
  ORGANISTAS: "Organistas",
};

const ORDEM_BLOCOS: BlocoPainel[] = ["MINISTERIO", "MUSICOS", "ORGANISTAS"];

/**
 * Agrupa as linhas em Ministério, Músicos e Organistas, com o total de cada bloco.
 * Linhas que não podem ser escolhidas na entrada (ex.: "Sem categoria") só aparecem se tiverem gente.
 */
export function agruparBlocos(linhas: LinhaPainel[]): BlocoResumo[] {
  return ORDEM_BLOCOS.map((bloco) => {
    const doBloco = linhas
      .filter((linha) => linha.bloco === bloco && (linha.selecionavel || linha.qtd > 0))
      .sort((a, b) => a.ordem - b.ordem);
    return {
      bloco,
      rotulo: ROTULO_BLOCO[bloco],
      total: doBloco.reduce((soma, linha) => soma + linha.qtd, 0),
      linhas: doBloco,
    };
  });
}

const FAMILIAS_FIXAS = ["Cordas", "Madeiras", "Metais"];

/**
 * Famílias do bloco Instrumentos: Cordas, Madeiras e Metais sempre aparecem (mesmo com zero);
 * outras (como Teclas, para o acordeom) só quando houver alguém. O percentual é sobre o total do bloco.
 */
export function montarFamilias(itens: ContagemFamilia[]): { total: number; familias: FamiliaResumo[] } {
  const total = itens.reduce((soma, item) => soma + item.qtd, 0);
  const quantidade = (nome: string) => itens.find((item) => item.familia === nome)?.qtd ?? 0;

  const extras = itens
    .filter((item) => !FAMILIAS_FIXAS.includes(item.familia) && item.qtd > 0)
    .map((item) => item.familia)
    .sort((a, b) => a.localeCompare(b, "pt-BR"));

  const familias = [...FAMILIAS_FIXAS, ...extras].map((nome) => ({
    nome,
    qtd: quantidade(nome),
    percentual: formatarPercentual(quantidade(nome), total),
  }));
  return { total, familias };
}

// ---------- Categoria do membro (Músico e Organista) ----------

export const CATEGORIAS = [
  { valor: "OFICIALIZADO", musico: "Oficializado", organista: "Oficializada" },
  { valor: "CULTO_OFICIAL", musico: "Culto Oficial", organista: "Culto Oficial" },
  { valor: "RJM", musico: "RJM", organista: "RJM" },
] as const;

function semAcento(texto: string): string {
  return texto
    .normalize("NFD")
    .replace(/[̀-ͯ]/g, "")
    .toLowerCase()
    .trim();
}

/** O cargo usa Categoria? Só Músico e Organista (as demais pessoas contam pelo cargo). */
export function cargoUsaCategoria(nomeCargo: string | undefined | null): TipoCategoria | null {
  if (!nomeCargo) return null;
  const nome = semAcento(nomeCargo);
  if (nome.startsWith("musico")) return "musico";
  if (nome.startsWith("organista")) return "organista";
  return null;
}

/** Texto da categoria para o tipo de cargo (a organista é "Oficializada", no feminino). */
export function rotuloDaCategoria(valor: string | null | undefined, tipo: TipoCategoria): string {
  const encontrada = CATEGORIAS.find((categoria) => categoria.valor === valor);
  return encontrada ? encontrada[tipo] : "Sem categoria";
}

/** Músico e Organista precisam de categoria; devolve a mensagem de erro ou null. O banco só aceita os valores da lista. */
export function validarCategoria(nomeCargo: string | undefined | null, categoria: string): string | null {
  const tipo = cargoUsaCategoria(nomeCargo);
  if (!tipo) return null;
  if (!CATEGORIAS.some((item) => item.valor === categoria)) {
    return `Escolha a categoria (${CATEGORIAS.map((item) => item[tipo]).join(", ")}).`;
  }
  return null;
}
