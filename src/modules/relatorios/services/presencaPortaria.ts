/**
 * Sysmusica — Serviço do relatório de presença da portaria.
 * Uma função do banco (migração 0036) confere a permissão e a abrangência e devolve tudo pronto.
 */
import { mensagemDoErro } from "@/lib/erros";
import { supabase } from "@/lib/supabase";
import type { DadosPresencaPortaria } from "../presencaPortaria";

export async function buscarRelatorioPresencaPortaria(portariaId: string): Promise<DadosPresencaPortaria> {
  const { data, error } = await supabase.rpc("relatorio_presenca_portaria", { p_portaria: portariaId });
  if (error) throw new Error(mensagemDoErro(error, "Não foi possível gerar o relatório de presença."));
  return data as DadosPresencaPortaria;
}
