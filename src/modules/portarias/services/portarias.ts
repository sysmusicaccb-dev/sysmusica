/**
 * Sysmusica — Serviço de dados da Gestão de portarias.
 * Todas as regras (permissão, cota de 4 por dia, abrangência, nunca decidir a própria portaria,
 * motivo da rejeição) são aplicadas pelas funções do banco; a tela só chama e mostra o resultado.
 */
import { supabase } from "@/lib/supabase";
import { mensagemDoErro } from "@/lib/erros";
import type { CotaPortarias, EventoParaPortaria, HistoricoPortaria, PortariaDetalhada } from "../tipos";

/** Portarias que o usuário pode ver, da mais recente para a mais antiga. */
export async function listarPortarias(): Promise<PortariaDetalhada[]> {
  const { data, error } = await supabase.rpc("listar_portarias");
  if (error) throw new Error(mensagemDoErro(error, "Não foi possível carregar as portarias."));
  return marcarEventosEncerrados((data ?? []) as PortariaDetalhada[]);
}

/** Marca nas portarias os eventos encerrados à mão (quem encerra o evento encerra a portaria). Se a consulta falhar, segue sem marcar. */
async function marcarEventosEncerrados(lista: PortariaDetalhada[]): Promise<PortariaDetalhada[]> {
  const ids = Array.from(new Set(lista.map((p) => p.evento_id)));
  if (ids.length === 0) return lista;
  const { data, error } = await supabase.from("eventos").select("id, encerrado_em").in("id", ids).not("encerrado_em", "is", null);
  if (error || !data) return lista;
  const encerrados = new Map((data as { id: string; encerrado_em: string }[]).map((e) => [e.id, e.encerrado_em]));
  return lista.map((p) => (encerrados.has(p.evento_id) ? { ...p, evento_encerrado_em: encerrados.get(p.evento_id) } : p));
}

/** Eventos para escolher ao criar uma portaria (os mais recentes primeiro). */
export async function buscarEventosParaPortaria(): Promise<EventoParaPortaria[]> {
  // O banco já devolve só os eventos das casas de oração da abrangência do usuário ("cidade" = Região › Setor)
  const { data, error } = await supabase.rpc("listar_eventos_para_portaria");
  if (error) throw new Error(mensagemDoErro(error, "Não foi possível carregar os eventos."));
  return (data ?? []) as EventoParaPortaria[];
}

/** (antiga) Eventos direto da tabela, sem filtro por setor. A tela não usa mais. */
export async function buscarEventosParaPortariaSemSetor(): Promise<EventoParaPortaria[]> {
  const { data, error } = await supabase
    .from("eventos")
    .select("id, tipo, data_evento, local, cidade")
    .order("data_evento", { ascending: false })
    .limit(300);
  if (error) throw new Error(mensagemDoErro(error, "Não foi possível carregar os eventos."));
  return (data ?? []) as EventoParaPortaria[];
}

/** Cota do dia de quem está logado (exige a permissão de criar). */
export async function minhaCota(): Promise<CotaPortarias> {
  const { data, error } = await supabase.rpc("minha_cota_portarias");
  const linha = ((data ?? []) as CotaPortarias[])[0];
  if (error || !linha) {
    throw new Error(error ? mensagemDoErro(error, "Não foi possível consultar a cota do dia.") : "Cota indisponível.");
  }
  return linha;
}

/** Cidades da abrangência de quem está logado. */
export async function minhasCidades(): Promise<string[]> {
  const { data, error } = await supabase.rpc("minhas_cidades");
  if (error) throw new Error(mensagemDoErro(error, "Não foi possível consultar a sua abrangência."));
  return (data ?? []) as string[];
}

/** Cria uma portaria PENDENTE para o evento (o banco confere permissão, cota e duplicidade). */
export async function criarPortaria(eventoId: string): Promise<void> {
  const { error } = await supabase.rpc("criar_portaria", { p_evento_id: eventoId });
  if (error) throw new Error(mensagemDoErro(error, "Não foi possível criar a portaria."));
}

/** Aprova ou rejeita (a rejeição exige motivo). O banco confere permissão, abrangência e autoria. */
export async function decidirPortaria(id: string, aprovar: boolean, motivo: string | null): Promise<void> {
  const { error } = await supabase.rpc("decidir_portaria", { p_id: id, p_aprovar: aprovar, p_motivo: motivo });
  if (error) throw new Error(mensagemDoErro(error, "Não foi possível registrar a decisão."));
}

/** Exclusão lógica (a cota do dia NÃO é devolvida). */
export async function excluirPortaria(id: string): Promise<void> {
  const { error } = await supabase.rpc("excluir_portaria", { p_id: id });
  if (error) throw new Error(mensagemDoErro(error, "Não foi possível excluir a portaria."));
}

/** Histórico de uma portaria (criação, decisões e exclusão). */
export async function historicoDaPortaria(id: string): Promise<HistoricoPortaria[]> {
  const { data, error } = await supabase.rpc("historico_portaria", { p_id: id });
  if (error) throw new Error(mensagemDoErro(error, "Não foi possível carregar o histórico."));
  return (data ?? []) as HistoricoPortaria[];
}
