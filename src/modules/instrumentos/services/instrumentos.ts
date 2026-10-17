/**
 * SysMúsica — Serviço de dados de instrumentos e famílias.
 */
import { supabase } from "@/lib/supabase";
import type { Familia, Instrumento } from "@/types/database";

/** Busca instrumentos e famílias, ambos em ordem alfabética. Lança erro se a consulta falhar. */
export async function buscarInstrumentosEFamilias(): Promise<{
  instrumentos: Instrumento[];
  familias: Familia[];
}> {
  const [resInstrumentos, resFamilias] = await Promise.all([
    supabase.from("instrumentos").select("*").order("nome", { ascending: true }),
    supabase.from("familias").select("*").order("nome", { ascending: true }),
  ]);

  const erroBanco = resInstrumentos.error ?? resFamilias.error;
  if (erroBanco) throw new Error(erroBanco.message);

  return {
    instrumentos: (resInstrumentos.data ?? []) as Instrumento[],
    familias: (resFamilias.data ?? []) as Familia[],
  };
}

/**
 * Corrige a família de um instrumento (só administrador consegue: o banco confere).
 * Quando o RLS nega, o update NÃO dá erro: apenas não altera nenhuma linha. Por isso
 * pedimos as linhas alteradas de volta (.select) e tratamos "zero linhas" como falta de permissão.
 */
export async function atualizarFamiliaDoInstrumento(
  instrumentoId: string,
  familiaId: string | null
): Promise<void> {
  const { data, error } = await supabase
    .from("instrumentos")
    .update({ familia_id: familiaId })
    .eq("id", instrumentoId)
    .select("id");

  if (error) throw new Error(error.message);
  if (!data || data.length === 0) {
    throw new Error("Sem permissão para alterar este instrumento.");
  }
}
