/**
 * SysMúsica — Serviço de dados dos gráficos do dashboard.
 *
 * Busca os dados no Supabase e delega os cálculos a ./agregacoes.ts.
 * Observações:
 *  - Em "membros" só se lêem colunas liberadas (nunca "*", pois o qr_secret é protegido).
 *  - O Supabase devolve no máximo 1000 linhas por consulta: acima disso, as distribuições de
 *    membros ficariam truncadas. As contagens de presença por status usam count (exato) e a
 *    frequência por evento é paginada.
 */
import { supabase } from "@/lib/supabase";
import type { ItemGrafico } from "@/components/charts/tipos";
import type { Cargo, Familia, Instrumento } from "@/types/database";
import {
  agruparFrequencia,
  calcularFrequenciaMedia,
  montarDistribuicoes,
  type FrequenciaEvento,
  type MembroResumo,
} from "./agregacoes";

const EVENTOS_NO_GRAFICO = 8;
const TAMANHO_PAGINA = 1000;
const MAXIMO_PAGINAS = 20;

// Cores semânticas dos status de presença
const COR_PRESENTE = { texto: "text-emerald-500", fundo: "bg-emerald-500" };
const COR_AUSENTE = { texto: "text-red-500", fundo: "bg-red-500" };
const COR_JUSTIFICADO = { texto: "text-amber-500", fundo: "bg-amber-500" };

export interface DadosGraficos {
  porCargo: ItemGrafico[];
  porFamilia: ItemGrafico[];
  porInstrumento: ItemGrafico[];
  porCongregacao: ItemGrafico[];
  presencasPorStatus: ItemGrafico[];
  frequencia: FrequenciaEvento[];
  frequenciaMedia: number | null;
}

/** Presenças dos eventos informados, lidas em páginas de 1000 para não truncar. */
async function buscarPresencasDosEventos(
  ids: string[]
): Promise<{ evento_id: string; status: string }[]> {
  if (ids.length === 0) return [];

  const linhas: { evento_id: string; status: string }[] = [];
  for (let pagina = 0; pagina < MAXIMO_PAGINAS; pagina += 1) {
    const inicio = pagina * TAMANHO_PAGINA;
    const { data, error } = await supabase
      .from("presencas")
      .select("evento_id, status")
      .in("evento_id", ids)
      .order("id") // ordem estável entre as páginas
      .range(inicio, inicio + TAMANHO_PAGINA - 1);
    if (error) throw new Error(error.message);

    const trecho = (data ?? []) as { evento_id: string; status: string }[];
    linhas.push(...trecho);
    if (trecho.length < TAMANHO_PAGINA) break;
  }
  return linhas;
}

/** Busca e calcula todos os dados dos gráficos. Lança erro se qualquer consulta falhar. */
export async function buscarDadosGraficos(): Promise<DadosGraficos> {
  const agora = new Date().toISOString();
  const contarStatus = (status: string) =>
    supabase.from("presencas").select("id", { count: "exact", head: true }).eq("status", status);

  const [
    resMembros,
    resCargos,
    resInstrumentos,
    resFamilias,
    resEventos,
    resPresente,
    resAusente,
    resJustificado,
  ] = await Promise.all([
    supabase.from("membros").select("id, cargo_id, instrumento_id, congregacao, status"),
    supabase.from("cargos").select("*"),
    supabase.from("instrumentos").select("*"),
    supabase.from("familias").select("*"),
    supabase
      .from("eventos")
      .select("id, data_evento")
      .lte("data_evento", agora) // só eventos que já aconteceram
      .order("data_evento", { ascending: false })
      .limit(EVENTOS_NO_GRAFICO),
    contarStatus("Presente"),
    contarStatus("Ausente"),
    contarStatus("Justificado"),
  ]);

  const respostas = [
    resMembros,
    resCargos,
    resInstrumentos,
    resFamilias,
    resEventos,
    resPresente,
    resAusente,
    resJustificado,
  ];
  const erroBanco = respostas.find((resposta) => resposta.error)?.error;
  if (erroBanco) throw new Error(erroBanco.message);

  const distribuicoes = montarDistribuicoes({
    membros: (resMembros.data ?? []) as MembroResumo[],
    cargos: (resCargos.data ?? []) as Cargo[],
    instrumentos: (resInstrumentos.data ?? []) as Instrumento[],
    familias: (resFamilias.data ?? []) as Familia[],
  });

  const eventos = (resEventos.data ?? []) as { id: string; data_evento: string }[];
  const presencas = await buscarPresencasDosEventos(eventos.map((evento) => evento.id));
  const frequencia = agruparFrequencia(eventos, presencas);

  return {
    ...distribuicoes,
    presencasPorStatus: [
      { rotulo: "Presente", valor: resPresente.count ?? 0, cor: COR_PRESENTE },
      { rotulo: "Ausente", valor: resAusente.count ?? 0, cor: COR_AUSENTE },
      { rotulo: "Justificado", valor: resJustificado.count ?? 0, cor: COR_JUSTIFICADO },
    ],
    frequencia,
    frequenciaMedia: calcularFrequenciaMedia(frequencia),
  };
}
