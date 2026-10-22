/**
 * Sysmusica — Regras puras do Painel de Totais visual (sem banco, sem tela). Testadas em detalhe.test.ts.
 * Monta o detalhe por instrumento, a escala dos gráficos de barras e as fatias do gráfico de rosca.
 * O detalhe por instrumento vem da migração 0049; sem ela, o painel continua mostrando só as famílias.
 */
import { formatarPercentual, montarFamilias } from "./regras";
import type { DadosPainel, FamiliaResumo } from "./tipos";

/** Quantidade de quem toca um instrumento (ex.: Violino), com a família dele. */
export interface DetalheInstrumento {
  familia: string;
  instrumento: string;
  qtd: number;
}

/** Resposta do painel com o detalhe por instrumento (campo novo da migração 0049; pode não existir ainda). */
export type DadosPainelTotais = DadosPainel & { instrumentos_detalhe?: DetalheInstrumento[] };

export interface InstrumentoResumo {
  nome: string;
  familia: string;
  qtd: number;
  percentual: string; // "12,8%"
}

/**
 * Famílias (Cordas, Madeiras, Metais...) e, quando o banco já devolve, cada instrumento com quantidade e percentual.
 * O percentual é sobre o total de quem toca (o mesmo do bloco Instrumentos). `instrumentos` é nulo sem a migração 0049.
 */
export function montarInstrumentos(dados: DadosPainelTotais): {
  total: number;
  familias: FamiliaResumo[];
  instrumentos: InstrumentoResumo[] | null;
} {
  const { total, familias } = montarFamilias(dados.instrumentos ?? []);
  if (!Array.isArray(dados.instrumentos_detalhe)) return { total, familias, instrumentos: null };

  const ordemDaFamilia = (nome: string) => {
    const posicao = familias.findIndex((familia) => familia.nome === nome);
    return posicao === -1 ? 999 : posicao;
  };
  const instrumentos = dados.instrumentos_detalhe
    .filter((item) => item.qtd > 0)
    .map((item) => ({
      nome: item.instrumento,
      familia: item.familia,
      qtd: item.qtd,
      percentual: formatarPercentual(item.qtd, total),
    }))
    .sort(
      (a, b) =>
        ordemDaFamilia(a.familia) - ordemDaFamilia(b.familia) ||
        b.qtd - a.qtd ||
        a.nome.localeCompare(b.nome, "pt-BR")
    );
  return { total, familias, instrumentos };
}

/** Divide a lista em duas colunas (a primeira fica com a metade maior quando o número é ímpar). */
export function dividirEmDuas<T>(itens: T[]): [T[], T[]] {
  const meio = Math.ceil(itens.length / 2);
  return [itens.slice(0, meio), itens.slice(meio)];
}

/**
 * Escala do eixo vertical: topo e marcas "redondas" (no máximo 4 intervalos), sempre cobrindo o maior valor.
 * Ex.: maior 14 -> topo 15, marcas 0, 5, 10, 15. Tudo zero -> topo 4, marcas 0 a 4.
 */
export function escalaDoGrafico(valores: number[]): { topo: number; marcas: number[] } {
  const maior = Math.max(4, ...valores.map((valor) => Math.ceil(valor)));
  const passo = [1, 2, 5, 10, 20, 25, 50, 100, 200, 500, 1000].find((p) => Math.ceil(maior / p) <= 4) ?? 1000;
  const intervalos = Math.ceil(maior / passo);
  const marcas = Array.from({ length: intervalos + 1 }, (_, i) => i * passo);
  return { topo: intervalos * passo, marcas };
}

export interface FatiaDaRosca {
  rotulo: string;
  qtd: number;
  percentual: string; // "8,9%"
  comprimento: number; // tamanho do arco (em unidades da circunferência)
  deslocamento: number; // onde o arco começa
}

/** Fatias do gráfico de rosca para uma circunferência dada. Total zero: todas com arco zero. */
export function fatiasDaRosca(partes: { rotulo: string; qtd: number }[], circunferencia: number): FatiaDaRosca[] {
  const total = partes.reduce((soma, parte) => soma + parte.qtd, 0);
  let acumulado = 0;
  return partes.map((parte) => {
    const comprimento = total > 0 ? (parte.qtd / total) * circunferencia : 0;
    const fatia = {
      rotulo: parte.rotulo,
      qtd: parte.qtd,
      percentual: formatarPercentual(parte.qtd, total),
      comprimento,
      deslocamento: acumulado,
    };
    acumulado += comprimento;
    return fatia;
  });
}
