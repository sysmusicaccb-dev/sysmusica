/**
 * Sysmusica — Serviço da configuração de encerramento dos eventos (migração 0077).
 * "Encerra sozinho" liga/desliga o encerramento automático; "horas" conta a partir do HORÁRIO DE INÍCIO do evento.
 * O banco confere a permissão eventos.configurar ao salvar.
 */
import { supabase } from "@/lib/supabase";
import { mensagemDoErro } from "@/lib/erros";

export interface ConfigEventos {
  encerra_sozinho: boolean;
  horas_apos_inicio: number;
}

/** Regra atual (qualquer usuário logado pode ler: as telas precisam dela para calcular a janela da portaria). */
export async function obterConfigEventos(): Promise<ConfigEventos> {
  const { data, error } = await supabase.rpc("obter_config_eventos");
  if (error) throw new Error(mensagemDoErro(error, "Não foi possível carregar a configuração dos eventos."));
  const linha = (Array.isArray(data) ? data[0] : data) as ConfigEventos | undefined;
  return { encerra_sozinho: linha?.encerra_sozinho ?? true, horas_apos_inicio: Number(linha?.horas_apos_inicio ?? 24) };
}

export async function salvarConfigEventos(config: ConfigEventos): Promise<void> {
  const { error } = await supabase.rpc("salvar_config_eventos", {
    p_encerra_sozinho: config.encerra_sozinho,
    p_horas: config.horas_apos_inicio,
  });
  if (error) throw new Error(mensagemDoErro(error, "Não foi possível salvar a configuração."));
}

/** Tipo do evento -> modelo do ensaio ("LOCAL", "REGIONAL" ou nulo). Decide quem vê o botão Encerrar. */
export async function listarModelosDosTipos(): Promise<Map<string, string | null>> {
  const { data, error } = await supabase.rpc("modelos_dos_tipos_evento");
  if (error) throw new Error(mensagemDoErro(error, "Não foi possível carregar os tipos de evento."));
  const mapa = new Map<string, string | null>();
  for (const linha of (data ?? []) as { nome: string; modelo: string | null }[]) mapa.set(chaveDoTipo(linha.nome), linha.modelo);
  return mapa;
}

/** Nome do tipo sem acento e em minúsculas (o evento guarda só o nome do tipo). */
export function chaveDoTipo(nome: string | null | undefined): string {
  return (nome ?? "").normalize("NFD").replace(/[̀-ͯ]/g, "").trim().toLowerCase();
}
