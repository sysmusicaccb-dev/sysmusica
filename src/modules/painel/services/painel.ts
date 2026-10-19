/**
 * SysMúsica — Serviço de dados do painel ao vivo.
 * As contagens são feitas no banco (funções painel_ao_vivo e eventos_do_painel): a tela recebe só números,
 * nunca as linhas de presença. O banco confere a permissão "Painel ao vivo" e a abrangência (região e setor)
 * de quem consulta.
 */
import { supabase } from "@/lib/supabase";
import { mensagemDoErro } from "@/lib/erros";
import type { DadosPainel, EventoParaEscolher } from "../tipos";

/** Eventos para escolher: de 30 dias atrás a 30 dias à frente, do mais próximo de agora para o mais distante. */
export async function listarEventosDoPainel(): Promise<EventoParaEscolher[]> {
  const { data, error } = await supabase.rpc("eventos_do_painel");
  if (error) throw new Error(mensagemDoErro(error, "Não foi possível carregar os eventos."));
  return (data ?? []) as EventoParaEscolher[];
}

/** Contagens ao vivo do evento (total, linhas dos blocos e instrumentos por família). */
export async function buscarPainel(eventoId: string): Promise<DadosPainel> {
  const { data, error } = await supabase.rpc("painel_ao_vivo", { p_evento_id: eventoId });
  if (error || !data) {
    throw new Error(error ? mensagemDoErro(error, "Não foi possível atualizar o painel.") : "Não foi possível atualizar o painel.");
  }
  return data as unknown as DadosPainel;
}
