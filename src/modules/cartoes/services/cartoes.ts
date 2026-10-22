/**
 * Sysmusica — Serviço do módulo Cartões. As duas consultas passam por funções do banco
 * (resumo_cartoes e listar_cartoes) que conferem a permissão cartoes.visualizar e a abrangência
 * de quem consulta: o navegador nunca lê a tabela diretamente.
 */
import { supabase } from "@/lib/supabase";
import { mensagemDoErro } from "@/lib/erros";
import type { LinhaCartao, ResumoCartoes } from "../tipos";

/** Totais do card do Dashboard (vencidos, a vencer no prazo e sem validade). */
export async function buscarResumoCartoes(dias: number): Promise<ResumoCartoes> {
  const { data, error } = await supabase.rpc("resumo_cartoes", { p_dias: dias });
  if (error) throw new Error(mensagemDoErro(error, "Não foi possível carregar os cartões."));
  const r = (data ?? {}) as Partial<ResumoCartoes>;
  return {
    dias: Number(r.dias ?? dias),
    vencidos: Number(r.vencidos ?? 0),
    a_vencer: Number(r.a_vencer ?? 0),
    sem_validade: Number(r.sem_validade ?? 0),
  };
}

/** Lista da tela "Cartões a Vencer" (já vem ordenada pelo banco: mais urgentes primeiro). */
export async function listarCartoes(dias: number): Promise<LinhaCartao[]> {
  const { data, error } = await supabase.rpc("listar_cartoes", { p_dias: dias });
  if (error) throw new Error(mensagemDoErro(error, "Não foi possível carregar os cartões."));
  return ((data ?? []) as LinhaCartao[]).map((linha) => ({ ...linha, dias: linha.dias === null ? null : Number(linha.dias) }));
}
