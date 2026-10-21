/**
 * SysMúsica — Busca os dados de UMA Casa de Oração para o formulário de evento (nome e cidade).
 * Usa a função do banco dados_casa_oracao (migração 0037), que respeita a abrangência do usuário:
 * fora dela devolve nulo e a tela pede a cidade manualmente.
 */
import { supabase } from "@/lib/supabase";
import { mensagemDoErro } from "@/lib/erros";
import type { DadosDaCasa } from "../casaDoEvento";

export async function buscarDadosDaCasa(casaOracaoId: string): Promise<DadosDaCasa | null> {
  const { data, error } = await supabase.rpc("dados_casa_oracao", { p_casa_oracao: casaOracaoId });
  if (error) throw new Error(mensagemDoErro(error, "Não foi possível buscar os dados da Casa de Oração."));
  return (data ?? null) as DadosDaCasa | null;
}
