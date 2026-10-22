/**
 * Sysmusica — Serviço dos Dados do Ensaio. Tudo passa por funções do banco (migração 0041), que conferem
 * permissão, abrangência (região/casa de oração) e o prazo de edição.
 */
import { supabase } from "@/lib/supabase";
import { mensagemDoErro } from "@/lib/erros";
import type { CargaEnsaio, EventoParaEnsaio, RespostaEnsaio } from "../tipos";

/** Ensaios (Local/Regional) recentes ou próximos, dentro da abrangência de quem consulta. */
export async function listarEventosParaEnsaio(): Promise<EventoParaEnsaio[]> {
  const { data, error } = await supabase.rpc("eventos_para_ensaio");
  if (error) throw new Error(mensagemDoErro(error, "Não foi possível carregar os ensaios."));
  return (data ?? []) as EventoParaEnsaio[];
}

/** Evento + dados já gravados (ou null) + se esta pessoa pode editar agora. */
export async function obterDadosEnsaio(eventoId: string): Promise<RespostaEnsaio> {
  const { data, error } = await supabase.rpc("obter_dados_ensaio", { p_evento_id: eventoId });
  if (error) throw new Error(mensagemDoErro(error, "Não foi possível carregar os dados do ensaio."));
  return data as RespostaEnsaio;
}

/** Grava (cria ou substitui) os dados do ensaio. O banco refaz todas as conferências. */
export async function salvarDadosEnsaio(eventoId: string, carga: CargaEnsaio): Promise<void> {
  const { error } = await supabase.rpc("salvar_dados_ensaio", { p_evento_id: eventoId, p_dados: carga });
  if (error) throw new Error(mensagemDoErro(error, "Não foi possível salvar os dados do ensaio."));
}
