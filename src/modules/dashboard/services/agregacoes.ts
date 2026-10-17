/**
 * SysMúsica — Cálculos dos gráficos do dashboard (funções PURAS, sem acesso ao banco).
 * Ficam separados do serviço de dados para poderem ser testados (agregacoes.test.ts).
 */
import type { ItemGrafico } from "@/components/charts/tipos";
import type { Cargo, Familia, Instrumento } from "@/types/database";

/** Quantidade máxima de barras antes de agrupar o restante em "Outros". */
const LIMITE_BARRAS = 7;

/** Campos de "membros" usados nas distribuições (sem dados sensíveis). */
export interface MembroResumo {
  id: string;
  cargo_id: string;
  instrumento_id: string | null;
  congregacao: string;
  status: string;
}

/** Conta itens agrupando pela chave devolvida; ordena do maior para o menor (empate: ordem alfabética). */
export function contarPor<T>(itens: T[], chave: (item: T) => string): ItemGrafico[] {
  const contagem = new Map<string, number>();
  for (const item of itens) {
    const rotulo = chave(item);
    contagem.set(rotulo, (contagem.get(rotulo) ?? 0) + 1);
  }
  return [...contagem.entries()]
    .map(([rotulo, valor]) => ({ rotulo, valor }))
    .sort((a, b) => b.valor - a.valor || a.rotulo.localeCompare(b.rotulo, "pt-BR"));
}

/** Mantém os N maiores e soma o restante em "Outros". */
export function topComOutros(itens: ItemGrafico[], limite: number): ItemGrafico[] {
  if (itens.length <= limite) return itens;
  const principais = itens.slice(0, limite);
  const resto = itens.slice(limite).reduce((soma, item) => soma + item.valor, 0);
  return [...principais, { rotulo: "Outros", valor: resto }];
}

export interface Distribuicoes {
  porCargo: ItemGrafico[];
  porFamilia: ItemGrafico[];
  porInstrumento: ItemGrafico[];
  porCongregacao: ItemGrafico[];
}

/** Monta as distribuições de membros por cargo, família, instrumento e congregação. */
export function montarDistribuicoes(entrada: {
  membros: MembroResumo[];
  cargos: Cargo[];
  instrumentos: Instrumento[];
  familias: Familia[];
}): Distribuicoes {
  const { membros, cargos, instrumentos, familias } = entrada;
  const cargoPorId = new Map(cargos.map((cargo): [string, Cargo] => [cargo.id, cargo]));
  const familiaPorId = new Map(familias.map((familia): [string, Familia] => [familia.id, familia]));
  const instrumentoPorId = new Map(
    instrumentos.map((instrumento): [string, Instrumento] => [instrumento.id, instrumento])
  );

  const porCargo = topComOutros(
    contarPor(membros, (membro) => cargoPorId.get(membro.cargo_id)?.nome ?? "Cargo não encontrado"),
    LIMITE_BARRAS + 1
  );

  // Família do membro = família do instrumento dele
  const porFamilia = contarPor(membros, (membro) => {
    if (!membro.instrumento_id) return "Sem instrumento";
    const instrumento = instrumentoPorId.get(membro.instrumento_id);
    if (!instrumento) return "Sem instrumento";
    if (!instrumento.familia_id) return "Sem família";
    return familiaPorId.get(instrumento.familia_id)?.nome ?? "Sem família";
  });

  // Instrumentos mais usados (só membros que têm instrumento)
  const nomesDeInstrumento = membros.flatMap((membro) => {
    const nome = membro.instrumento_id ? instrumentoPorId.get(membro.instrumento_id)?.nome : undefined;
    return nome ? [nome] : [];
  });
  const porInstrumento = topComOutros(contarPor(nomesDeInstrumento, (nome) => nome), LIMITE_BARRAS);

  const porCongregacao = topComOutros(
    contarPor(membros, (membro) => membro.congregacao.trim() || "Sem congregação"),
    LIMITE_BARRAS
  );

  return { porCargo, porFamilia, porInstrumento, porCongregacao };
}

export interface FrequenciaEvento {
  eventoId: string;
  rotulo: string; // "dd/mm"
  presentes: number;
  ausentes: number;
  justificados: number;
  total: number;
}

/**
 * Agrupa as presenças por evento. Os eventos chegam do mais recente para o mais antigo;
 * o resultado sai em ordem cronológica (mais antigo primeiro), como o gráfico exibe.
 */
export function agruparFrequencia(
  eventos: { id: string; data_evento: string }[],
  presencas: { evento_id: string; status: string }[]
): FrequenciaEvento[] {
  const ordenados = [...eventos].reverse();
  const porEvento = new Map<string, FrequenciaEvento>();

  for (const evento of ordenados) {
    porEvento.set(evento.id, {
      eventoId: evento.id,
      rotulo: new Date(evento.data_evento).toLocaleDateString("pt-BR", {
        day: "2-digit",
        month: "2-digit",
      }),
      presentes: 0,
      ausentes: 0,
      justificados: 0,
      total: 0,
    });
  }

  for (const presenca of presencas) {
    const frequencia = porEvento.get(presenca.evento_id);
    if (!frequencia) continue;
    frequencia.total += 1;
    if (presenca.status === "Presente") frequencia.presentes += 1;
    else if (presenca.status === "Ausente") frequencia.ausentes += 1;
    else if (presenca.status === "Justificado") frequencia.justificados += 1;
  }

  return ordenados.flatMap((evento) => {
    const frequencia = porEvento.get(evento.id);
    return frequencia ? [frequencia] : [];
  });
}

/** Percentual de presenças "Presente" sobre todos os registros (null quando não há registros). */
export function calcularFrequenciaMedia(frequencias: FrequenciaEvento[]): number | null {
  const total = frequencias.reduce((soma, item) => soma + item.total, 0);
  if (total === 0) return null;
  const presentes = frequencias.reduce((soma, item) => soma + item.presentes, 0);
  return Math.round((presentes / total) * 100);
}
