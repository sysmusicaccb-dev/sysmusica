/**
 * Sysmusica — Configuração do Perfil do Evento para a tela Dados do Ensaio (regra pura, sem banco).
 *
 * Cada perfil diz quais campos a tela mostra e como se comportam:
 *   - Quem atendeu: liga/desliga, título, cargos permitidos e o rótulo do campo de nome;
 *   - Hino de abertura: não usa, pergunta "Houve hino de abertura?" (Sim/Não) ou obrigatório;
 *   - Palavra exortada: liga/desliga, obrigatória ou não, limite de caracteres;
 *   - Encarregados: liga/desliga, cargos (Regional, Local, Instrutor), mínimo e máximo, Cidade-UF;
 *   - Hinos executados: liga/desliga.
 * O banco guarda a mesma configuração (migração 0080) e refaz as conferências; este arquivo espelha o padrão e a
 * normalização do banco. Testado em perfilConfig.test.ts.
 */
import type { ModeloEnsaio } from "@/modules/tiposEvento/regras";
import { CARGOS_ATENDE, MAXIMO_ENCARREGADOS, PALAVRA_MAXIMA } from "./regras";
import type { CargoAtende } from "./tipos";

export type ModoAbertura = "obrigatorio" | "pergunta" | "nao_usa";
export type CargoEncarregado = "REGIONAL" | "LOCAL" | "INSTRUTOR";

export interface ConfigEnsaio {
  quem_atendeu: { ativo: boolean; titulo: string; rotulo_nome: string; cargos: CargoAtende[] };
  hino_abertura: { modo: ModoAbertura };
  palavra: { ativo: boolean; obrigatoria: boolean; limite: number };
  encarregados: { ativo: boolean; cargos: CargoEncarregado[]; minimo: number; maximo: number; cidade_uf: boolean };
  hinos_executados: { ativo: boolean };
}

export const CARGOS_ENCARREGADO: { codigo: CargoEncarregado; rotulo: string }[] = [
  { codigo: "REGIONAL", rotulo: "Encarregado Regional" },
  { codigo: "LOCAL", rotulo: "Encarregado Local" },
  { codigo: "INSTRUTOR", rotulo: "Instrutor" },
];

export const ROTULO_MODO_ABERTURA: Record<ModoAbertura, string> = {
  nao_usa: "Não usa hino de abertura",
  pergunta: 'Pergunta "Houve hino de abertura?" (Sim/Não)',
  obrigatorio: "Hino de abertura obrigatório",
};

const CODIGOS_ATENDE = CARGOS_ATENDE.map((c) => c.codigo);
const CODIGOS_ENCARREGADO = CARGOS_ENCARREGADO.map((c) => c.codigo);
const MODOS: ModoAbertura[] = ["obrigatorio", "pergunta", "nao_usa"];
const TEXTO_MAXIMO = 60;

/** Padrão por modelo (igual ao do banco). Regional: só Ancião atende e há palavra. Local: os 4 cargos, sem palavra. */
export function configPadrao(modelo: ModeloEnsaio): ConfigEnsaio {
  return {
    quem_atendeu: {
      ativo: true,
      titulo: "Quem atendeu",
      rotulo_nome: "Nome de quem atendeu",
      cargos: modelo === "REGIONAL" ? ["ANCIAO"] : [...CODIGOS_ATENDE],
    },
    hino_abertura: { modo: "pergunta" },
    palavra: { ativo: modelo === "REGIONAL", obrigatoria: true, limite: PALAVRA_MAXIMA },
    encarregados: { ativo: true, cargos: [...CODIGOS_ENCARREGADO], minimo: 1, maximo: MAXIMO_ENCARREGADOS, cidade_uf: true },
    hinos_executados: { ativo: true },
  };
}

function objeto(v: unknown): Record<string, unknown> {
  return typeof v === "object" && v !== null && !Array.isArray(v) ? (v as Record<string, unknown>) : {};
}
function bool(v: unknown, padrao: boolean): boolean {
  return typeof v === "boolean" ? v : padrao;
}
function inteiro(v: unknown, minimo: number, maximo: number, padrao: number): number {
  if (typeof v !== "number" || !Number.isFinite(v)) return padrao;
  return Math.min(maximo, Math.max(minimo, Math.trunc(v)));
}
function texto(v: unknown, padrao: string): string {
  const limpo = typeof v === "string" ? v.trim().replace(/\s+/g, " ").slice(0, TEXTO_MAXIMO) : "";
  return limpo === "" ? padrao : limpo;
}
/** Só os valores permitidos, na ordem canônica; se não sobrar nenhum, usa o padrão. */
function lista<T extends string>(v: unknown, permitidos: readonly T[], padrao: T[]): T[] {
  if (!Array.isArray(v)) return padrao;
  const achados = permitidos.filter((p) => v.includes(p));
  return achados.length > 0 ? achados : padrao;
}

/** Limpa uma configuração qualquer (do banco ou da tela): tipos errados e valores fora dos limites voltam ao padrão. */
export function normalizarConfig(bruto: unknown, modelo: ModeloEnsaio): ConfigEnsaio {
  const padrao = configPadrao(modelo);
  const i = objeto(bruto);
  const qa = objeto(i.quem_atendeu);
  const ab = objeto(i.hino_abertura);
  const pa = objeto(i.palavra);
  const en = objeto(i.encarregados);
  const hx = objeto(i.hinos_executados);
  const maximo = inteiro(en.maximo, 1, MAXIMO_ENCARREGADOS, MAXIMO_ENCARREGADOS);
  return {
    quem_atendeu: {
      ativo: bool(qa.ativo, true),
      titulo: texto(qa.titulo, padrao.quem_atendeu.titulo),
      rotulo_nome: texto(qa.rotulo_nome, padrao.quem_atendeu.rotulo_nome),
      cargos: lista(qa.cargos, CODIGOS_ATENDE, padrao.quem_atendeu.cargos),
    },
    hino_abertura: { modo: MODOS.find((m) => m === ab.modo) ?? padrao.hino_abertura.modo },
    palavra: {
      ativo: bool(pa.ativo, padrao.palavra.ativo),
      obrigatoria: bool(pa.obrigatoria, true),
      limite: inteiro(pa.limite, 1, PALAVRA_MAXIMA, PALAVRA_MAXIMA),
    },
    encarregados: {
      ativo: bool(en.ativo, true),
      cargos: lista(en.cargos, CODIGOS_ENCARREGADO, padrao.encarregados.cargos),
      minimo: Math.min(inteiro(en.minimo, 0, MAXIMO_ENCARREGADOS, 1), maximo),
      maximo,
      cidade_uf: bool(en.cidade_uf, true),
    },
    hinos_executados: { ativo: bool(hx.ativo, true) },
  };
}

export function rotuloDoCargoEncarregado(cargo: CargoEncarregado | string | null | undefined): string {
  return CARGOS_ENCARREGADO.find((c) => c.codigo === cargo)?.rotulo ?? "";
}

/** "Encarregado Local" (um cargo só) ou "Encarregado Regional, Encarregado Local ou Instrutor". */
export function rotuloEncarregados(cargos: CargoEncarregado[]): string {
  const rotulos = cargos.map((c) => rotuloDoCargoEncarregado(c));
  if (rotulos.length <= 1) return rotulos[0] ?? "Encarregado";
  return `${rotulos.slice(0, -1).join(", ")} ou ${rotulos[rotulos.length - 1]}`;
}

/** Título do bloco: o cargo (quando só há um) ou "Encarregados". */
export function tituloBlocoEncarregados(cargos: CargoEncarregado[]): string {
  return cargos.length === 1 ? rotuloEncarregados(cargos) : "Encarregados";
}

/** A partir de 2 encarregados o verbo vai para o plural. */
export function verboAtendeu(quantidade: number): string {
  return quantidade >= 2 ? "atenderam" : "atendeu";
}

/** Resumo em frases curtas do que a configuração liga (usado na prévia do editor de perfil). */
export function descreverConfig(c: ConfigEnsaio): string[] {
  const linhas: string[] = [];
  if (c.quem_atendeu.ativo) {
    const cargos = c.quem_atendeu.cargos.map((x) => CARGOS_ATENDE.find((a) => a.codigo === x)?.rotulo ?? x).join(", ");
    linhas.push(`${c.quem_atendeu.titulo}: ${cargos}`);
  }
  if (c.hino_abertura.modo !== "nao_usa") {
    linhas.push(c.hino_abertura.modo === "pergunta" ? "Pergunta se houve hino de abertura" : "Hino de abertura obrigatório");
  }
  if (c.palavra.ativo) linhas.push(`Palavra exortada (${c.palavra.obrigatoria ? "obrigatória" : "opcional"}, até ${c.palavra.limite} caracteres)`);
  if (c.encarregados.ativo) {
    const faixa = c.encarregados.minimo === c.encarregados.maximo ? `${c.encarregados.maximo}` : `${c.encarregados.minimo} a ${c.encarregados.maximo}`;
    linhas.push(`${rotuloEncarregados(c.encarregados.cargos)}: ${faixa}${c.encarregados.cidade_uf ? ", com Cidade-UF" : ""}`);
  }
  if (c.hinos_executados.ativo) linhas.push("Hinos executados");
  return linhas;
}
