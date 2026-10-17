/**
 * SysMúsica — Serviço do dashboard (acesso a dados).
 *
 * Fica fora do componente para a tela não misturar interface com consultas ao banco.
 * As contagens usam { count: "exact", head: true }: o banco só devolve o número, sem baixar linhas.
 * Atenção: em "membros" sempre se seleciona "id" (nunca "*"), pois o qr_secret é protegido.
 */
import { supabase } from "@/lib/supabase";
import type { Evento } from "@/types/database";

export interface Indicadores {
  membros: number;
  membrosAtivos: number;
  eventos: number;
  eventosFuturos: number;
  presencas: number;
  instrumentos: number;
  instrumentosSemFamilia: number;
}

/** Busca todos os totais do dashboard. Lança erro se qualquer consulta falhar. */
export async function buscarIndicadores(): Promise<Indicadores> {
  const agora = new Date().toISOString();

  const resultados = await Promise.all([
    supabase.from("membros").select("id", { count: "exact", head: true }),
    supabase.from("membros").select("id", { count: "exact", head: true }).eq("status", "Ativo"),
    supabase.from("eventos").select("id", { count: "exact", head: true }),
    supabase.from("eventos").select("id", { count: "exact", head: true }).gte("data_evento", agora),
    supabase.from("presencas").select("id", { count: "exact", head: true }),
    supabase.from("instrumentos").select("id", { count: "exact", head: true }),
    supabase.from("instrumentos").select("id", { count: "exact", head: true }).is("familia_id", null),
  ]);

  // Se qualquer consulta falhar, interrompe com o primeiro erro encontrado
  const erroBanco = resultados.find((resultado) => resultado.error)?.error;
  if (erroBanco) throw new Error(erroBanco.message);

  const [membros, membrosAtivos, eventos, eventosFuturos, presencas, instrumentos, semFamilia] =
    resultados.map((resultado) => resultado.count ?? 0);

  return {
    membros,
    membrosAtivos,
    eventos,
    eventosFuturos,
    presencas,
    instrumentos,
    instrumentosSemFamilia: semFamilia,
  };
}

/** Próximos eventos (a partir de agora), do mais próximo para o mais distante. */
export async function buscarProximosEventos(limite = 5): Promise<Evento[]> {
  const { data, error } = await supabase
    .from("eventos")
    .select("*")
    .gte("data_evento", new Date().toISOString())
    .order("data_evento", { ascending: true })
    .limit(limite);

  if (error) throw new Error(error.message);
  return (data ?? []) as Evento[];
}
