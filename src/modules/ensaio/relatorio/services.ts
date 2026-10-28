/** Sysmusica — Serviço do Relatório do Ensaio: uma chamada só ao banco (função relatorio_ensaio, migração 0083). */
import { mensagemDoErro } from "@/lib/erros";
import { supabase } from "@/lib/supabase";
import type { RespostaRelatorioEnsaio } from "./tipos";

export async function buscarRelatorioEnsaio(eventoId: string): Promise<RespostaRelatorioEnsaio> {
  const { data, error } = await supabase.rpc("relatorio_ensaio", { p_evento_id: eventoId });
  if (error) throw new Error(mensagemDoErro(error, "Não foi possível montar o relatório do ensaio."));
  return data as RespostaRelatorioEnsaio;
}

/** Eventos para escolher na tela de Relatórios (os mais recentes que o usuário pode ver). */
export interface EventoParaRelatorio {
  id: string;
  tipo: string;
  data_evento: string;
  local: string | null;
  cidade: string | null;
}

export async function listarEventosParaRelatorio(): Promise<EventoParaRelatorio[]> {
  const { data, error } = await supabase
    .from("eventos")
    .select("id, tipo, data_evento, local, cidade")
    .is("excluido_em", null)
    .order("data_evento", { ascending: false })
    .limit(100);
  if (error) throw new Error(mensagemDoErro(error, "Não foi possível carregar os eventos."));
  return (data ?? []) as EventoParaRelatorio[];
}
