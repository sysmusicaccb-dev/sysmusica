/**
 * SysMúsica — Serviço de dados da Auditoria.
 * A consulta exige a permissão auditoria.visualizar (o banco confere). Imprimir e exportar também ficam
 * registrados na própria auditoria (registrarUso), antes de o arquivo ser gerado.
 */
import { supabase } from "@/lib/supabase";
import { mensagemDoErro } from "@/lib/erros";
import { intervaloDoFiltro } from "../regras";
import type { FiltrosAuditoria, LinhaAuditoria, OpcoesAuditoria } from "../tipos";

type LinhaBruta = Omit<LinhaAuditoria, "total"> & { total: number | string };

/** Registros do filtro, do mais recente para o mais antigo (até 2000 por consulta). */
export async function listarAuditoria(
  filtros: FiltrosAuditoria,
  limite: number,
  deslocamento: number
): Promise<{ linhas: LinhaAuditoria[]; total: number }> {
  const periodo = intervaloDoFiltro(filtros.inicio, filtros.fim);
  const { data, error } = await supabase.rpc("listar_auditoria", {
    p_inicio: periodo.inicio,
    p_fim: periodo.fim,
    p_usuario: filtros.usuarioId || null,
    p_entidade: filtros.entidade || null,
    p_acao: filtros.acao || null,
    p_busca: filtros.busca.trim() || null,
    p_limite: limite,
    p_deslocamento: deslocamento,
  });
  if (error) throw new Error(mensagemDoErro(error, "Não foi possível carregar a auditoria."));

  const linhas: LinhaAuditoria[] = ((data ?? []) as LinhaBruta[]).map((linha) => ({
    ...linha,
    total: Number(linha.total), // o banco devolve bigint
  }));
  return { linhas, total: linhas[0]?.total ?? 0 };
}

/** Usuários, tipos de item e ações disponíveis para os filtros. */
export async function listarOpcoesAuditoria(): Promise<OpcoesAuditoria> {
  const { data, error } = await supabase.rpc("opcoes_auditoria");
  if (error) throw new Error(mensagemDoErro(error, "Não foi possível carregar as opções dos filtros."));

  const linhas = (data ?? []) as { tipo: string; valor: string; rotulo: string }[];
  return {
    usuarios: linhas.filter((l) => l.tipo === "USUARIO").map((l) => ({ id: l.valor, nome: l.rotulo })),
    entidades: linhas.filter((l) => l.tipo === "ENTIDADE").map((l) => l.valor),
    acoes: linhas.filter((l) => l.tipo === "ACAO").map((l) => l.valor),
  };
}

/** Registra na auditoria que alguém imprimiu ou exportou (a tela só gera o arquivo se isto der certo). */
export async function registrarUso(
  acao: "auditoria_impressa" | "auditoria_exportada" | "relatorio_impresso" | "relatorio_exportado",
  detalhes: Record<string, unknown>
): Promise<void> {
  const { error } = await supabase.rpc("registrar_uso", { p_acao: acao, p_detalhes: detalhes });
  if (error) throw new Error(mensagemDoErro(error, "Não foi possível registrar a ação na auditoria."));
}
