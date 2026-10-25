/**
 * Sysmusica — Estrutura (campos, linhas e escalas) das fichas M10, M11, organistas e necessidade de instrumentos.
 * Formulário na tela e folha impressa usam ESTAS listas, então o que aparece num aparece no outro.
 * Os valores ficam em DadosFicha.notas (chave -> texto). Sem banco e sem tela: testado em layouts.test.ts.
 */

/** Tipos de ficha cujo formulário é o "extra" (a pessoa pode ainda não estar no cadastro). */
export type TipoExtra =
  | "AVALIACAO_CANDIDATO"
  | "PRE_AVALIACAO_ORGANISTA"
  | "EXAME_ORGANISTA"
  | "ACOMPANHAMENTO_GEM"
  | "NECESSIDADE_INSTRUMENTO";

export const TIPOS_EXTRA: TipoExtra[] = [
  "AVALIACAO_CANDIDATO",
  "PRE_AVALIACAO_ORGANISTA",
  "EXAME_ORGANISTA",
  "ACOMPANHAMENTO_GEM",
  "NECESSIDADE_INSTRUMENTO",
];

export function ehTipoExtra(tipo: string): tipo is TipoExtra {
  return (TIPOS_EXTRA as string[]).includes(tipo);
}

export interface Opcao {
  valor: string;
  rotulo: string;
}
export interface Linha {
  chave: string;
  rotulo: string;
}

/** Escala de avaliação usada nas fichas (Ótimo, Bom, Regular, Fraco). */
export const ESCALA: Opcao[] = [
  { valor: "OTIMO", rotulo: "Ótimo" },
  { valor: "BOM", rotulo: "Bom" },
  { valor: "REGULAR", rotulo: "Regular" },
  { valor: "FRACO", rotulo: "Fraco" },
];

// ------------------------------------------------------------------ M10 — avaliação de candidato a músico
export const M10_LEITURA: Linha[] = [
  { chave: "lr", rotulo: "Leitura Rítmica" },
  { chave: "sol", rotulo: "Clave de Sol" },
  { chave: "fa", rotulo: "Clave de Fá" },
  { chave: "do", rotulo: "Clave de Dó" },
];
export const M10_PRATICA: Linha[] = [
  { chave: "esc", rotulo: "Escalas" },
  { chave: "pos", rotulo: "Postura" },
  { chave: "afi", rotulo: "Afinação" },
  { chave: "qs", rotulo: "Qualidade Sonora" },
  { chave: "art", rotulo: "Articulações" },
  { chave: "rit", rotulo: "Rítmo e Pulsação" },
  { chave: "fra", rotulo: "Fraseado e Expressões" },
];

// ------------------------------------------------------------------ Organistas (pré-avaliação e exames)
export interface ColunaOrganista {
  chave: string;
  titulo: string;
  metodo: string; // "Método CCB v. 1 e 2"
  exame: boolean; // a última coluna fala "novo exame"; as demais, "novo teste"
}
export const COLUNAS_ORGANISTA: ColunaOrganista[] = [
  { chave: "rjm", titulo: "Reunião de jovens e menores", metodo: "Método CCB v. 1 e 2", exame: false },
  { chave: "co", titulo: "Culto oficial", metodo: "Método CCB v. 3", exame: false },
  { chave: "of", titulo: "Oficialização", metodo: "Método CCB v. 4", exame: true },
];
export const ORG_TEORIA: Linha[] = [
  { chave: "teoria", rotulo: "Teoria" },
  { chave: "mts", rotulo: "MTS" },
  { chave: "solfejo", rotulo: "Solfejo dos Hinos" },
];
export const ORG_METODO: Linha[] = [
  { chave: "escalas", rotulo: "Escalas e Arpejos" },
  { chave: "tecnicos", rotulo: "Exercícios técnicos" },
  { chave: "pedaleira", rotulo: "Exercícios de pedaleira" },
  { chave: "estudos", rotulo: "Estudos" },
];
export const ORG_HINARIO: Linha[] = [
  { chave: "hinos", rotulo: "Hinos" },
  { chave: "ceia", rotulo: "Stª Ceia / Batismo" },
  { chave: "meia", rotulo: "Meia hora" },
  { chave: "intro", rotulo: "Introduções" },
  { chave: "coros", rotulo: "Coros" },
];
export const ORG_PRATICA: Linha[] = [
  { chave: "leitura", rotulo: "Leitura de notas" },
  { chave: "dedilhado", rotulo: "Dedilhado" },
  { chave: "articulacao", rotulo: "Articulação" },
  { chave: "ritmo", rotulo: "Ritmo" },
  { chave: "andamento", rotulo: "Andamento" },
  { chave: "dinamica", rotulo: "Dinâmica" },
];
export function resultadosOrganista(col: ColunaOrganista): Opcao[] {
  return [
    { valor: "APROVADA", rotulo: "Aprovada" },
    { valor: "RETORNAR", rotulo: col.exame ? "Retornar novo exame" : "Retornar novo teste" },
  ];
}
/** Chave de um campo da coluna: "co_hinos", "of_aval_teorica"... */
export const chaveOrg = (col: string, campo: string): string => `${col}_${campo}`;

// ------------------------------------------------------------------ M11 — acompanhamento do GEM
export const TOTAL_AULAS_GEM = 20;
export const TOTAL_AVALIACOES_GEM = 3;
export const AREAS_GEM: Opcao[] = [
  { valor: "LEITURA", rotulo: "Leitura métrica" },
  { valor: "TEORIA", rotulo: "Teoria musical" },
  { valor: "PRATICA", rotulo: "Prática de instrumento" },
];
export const PRESENCAS: Opcao[] = [
  { valor: "P", rotulo: "Presente" },
  { valor: "A", rotulo: "Ausente" },
  { valor: "J", rotulo: "Justificada" },
];
export const JUSTIFICATIVAS: Opcao[] = [
  { valor: "E", rotulo: "E - Enfermidade" },
  { valor: "T", rotulo: "T - Trabalho" },
  { valor: "V", rotulo: "V - Viagem" },
  { valor: "O", rotulo: "O - Outros" },
];
/** Chaves de uma aula (n de 1 a 20) ou avaliação (prefixo "v"): "a01_data", "v2_nota"... */
export const chaveAula = (n: number, campo: string): string => `a${String(n).padStart(2, "0")}_${campo}`;
export const chaveAval = (n: number, campo: string): string => `v${n}_${campo}`;

/** Média das notas das avaliações (aceita vírgula). Vazio se nenhuma nota válida. */
export function mediaGem(notas: Record<string, string>): string {
  const valores: number[] = [];
  for (let i = 1; i <= TOTAL_AVALIACOES_GEM; i++) {
    const v = Number((notas[chaveAval(i, "nota")] ?? "").trim().replace(",", "."));
    if ((notas[chaveAval(i, "nota")] ?? "").trim() !== "" && Number.isFinite(v)) valores.push(v);
  }
  if (valores.length === 0) return "";
  const media = valores.reduce((a, b) => a + b, 0) / valores.length;
  return (Math.round(media * 10) / 10).toString().replace(".", ",");
}

// ------------------------------------------------------------------ Necessidade e entrega de instrumentos
export const FASES_NECESSIDADE: Opcao[] = [
  { valor: "RJM", rotulo: "Reunião de jovens e menores" },
  { valor: "CULTO_OFICIAL", rotulo: "Culto oficial" },
  { valor: "OFICIALIZADO", rotulo: "Oficializado" },
];
export const ITENS_NECESSIDADE: Linha[] = [
  { chave: "item_instrumento", rotulo: "Instrumento musical" },
  { chave: "item_acessorios", rotulo: "Acessórios" },
  { chave: "item_reforma", rotulo: "Reforma de instrumento" },
  { chave: "item_metodo", rotulo: "Método, MTS, hinário" },
];
export const DESTINOS_ATENDIMENTO: Opcao[] = [
  { valor: "ESTOQUE", rotulo: "Item em estoque" },
  { valor: "COMPRA", rotulo: "Será comprado para atendimento individual" },
];

/** Texto dos botões de resultado conforme o tipo (a necessidade é "aprovada", a organista é "apta"). */
export function rotulosResultado(tipo: string): { sim: string; nao: string; titulo: string } {
  if (tipo === "NECESSIDADE_INSTRUMENTO") return { sim: "Aprovado", nao: "Não aprovado", titulo: "Aprovado" };
  if (tipo === "M05" || tipo === "PRE_AVALIACAO_ORGANISTA" || tipo === "EXAME_ORGANISTA") return { sim: "Apta", nao: "Não apta", titulo: "Apta" };
  return { sim: "Apto", nao: "Não apto", titulo: "Apto" };
}
