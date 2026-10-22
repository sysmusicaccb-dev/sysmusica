/**
 * Sysmusica — Serviço de dados da entrada com "Vai tocar?" e da entrada SEM cadastro (migração 0028).
 * Toda regra é aplicada pelo banco; a tela só chama e mostra o resultado.
 */
import { supabase } from "@/lib/supabase";
import { mensagemDoErro } from "@/lib/erros";
import type { EntradaAvulsa, InfoEntrada, LocalidadeBusca, OpcoesEntrada } from "../tiposEntrada";

/** Como o membro é contado e se a Portaria precisa perguntar "Vai tocar?". */
export async function infoEntrada(portariaId: string, membroId: string): Promise<InfoEntrada> {
  const { data, error } = await supabase.rpc("info_entrada", { p_portaria_id: portariaId, p_membro_id: membroId });
  if (error || !data) {
    throw new Error(error ? mensagemDoErro(error, "Não foi possível consultar os dados da entrada.") : "Membro não encontrado.");
  }
  return data as unknown as InfoEntrada;
}

/** Linhas do painel e instrumentos para a entrada sem cadastro e para a pergunta "Vai tocar?". */
export async function opcoesEntrada(): Promise<OpcoesEntrada> {
  const { data, error } = await supabase.rpc("opcoes_entrada");
  if (error || !data) {
    throw new Error(error ? mensagemDoErro(error, "Não foi possível carregar as opções da entrada.") : "Opções da entrada indisponíveis.");
  }
  return data as unknown as OpcoesEntrada;
}

/** Busca de localidade (casa de oração) pelas primeiras letras; mínimo de 2 letras. */
export async function buscarLocalidades(termo: string): Promise<LocalidadeBusca[]> {
  const { data, error } = await supabase.rpc("buscar_localidades", { p_termo: termo });
  if (error) throw new Error(mensagemDoErro(error, "Não foi possível buscar a localidade."));
  return (data ?? []) as LocalidadeBusca[];
}

/** Registra a entrada de alguém SEM cadastro (candidato, visitante...). Não cria membro. */
export async function registrarEntradaAvulsa(
  portariaId: string,
  dados: {
    linhaCodigo: string;
    toca: boolean | null;
    instrumentoId: string | null;
    origemCasaOracaoId: string | null;
    origemTexto: string | null;
  }
): Promise<void> {
  const { error } = await supabase.rpc("registrar_entrada_avulsa", {
    p_portaria_id: portariaId,
    p_linha_codigo: dados.linhaCodigo,
    p_toca: dados.toca,
    p_instrumento_id: dados.instrumentoId,
    p_origem_casa_oracao_id: dados.origemCasaOracaoId,
    p_origem_texto: dados.origemTexto,
  });
  if (error) throw new Error(mensagemDoErro(error, "Não foi possível registrar a entrada."));
}

/** Desfaz uma entrada sem cadastro (quem registrou, ou quem pode excluir registros). */
export async function desfazerEntradaAvulsa(id: string): Promise<void> {
  const { error } = await supabase.rpc("desfazer_entrada_avulsa", { p_id: id });
  if (error) throw new Error(mensagemDoErro(error, "Não foi possível desfazer a entrada."));
}

/** Últimas entradas sem cadastro da portaria (e o total). */
export async function entradasAvulsasDaPortaria(portariaId: string): Promise<EntradaAvulsa[]> {
  const { data, error } = await supabase.rpc("entradas_avulsas_da_portaria", { p_portaria_id: portariaId });
  if (error) throw new Error(mensagemDoErro(error, "Não foi possível carregar as entradas sem cadastro."));
  return (data ?? []) as EntradaAvulsa[];
}
