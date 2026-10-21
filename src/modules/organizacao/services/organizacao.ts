/**
 * SysMúsica — Serviço de dados da organização (Estado › RRM › RA › ADM › Setor › Casa de Oração) e dos vínculos dos usuários.
 * Todas as regras (permissão, nomes repetidos, abrangência) são aplicadas pelo banco (migração 0012);
 * a tela só chama e mostra o resultado, com as mensagens do banco já escritas para o usuário.
 */
import { supabase } from "@/lib/supabase";
import { mensagemDoErro } from "@/lib/erros";
import type { NivelOrganizacao, NoOrganizacao, VinculoRotulado, VinculoUsuario } from "../tipos";

interface LinhaNo extends Omit<NoOrganizacao, "qtd_filhos" | "qtd_membros"> {
  qtd_filhos?: number | string;
  qtd_membros?: number | string;
}

/** Árvore completa (tela de Organização e vínculos). */
export async function listarOrganizacao(): Promise<NoOrganizacao[]> {
  const { data, error } = await supabase.rpc("listar_organizacao");
  if (error) throw new Error(mensagemDoErro(error, "Não foi possível carregar a organização."));
  return ((data ?? []) as LinhaNo[]).map((linha) => ({
    ...linha,
    qtd_filhos: Number(linha.qtd_filhos ?? 0), // o banco devolve bigint
    qtd_membros: Number(linha.qtd_membros ?? 0),
  }));
}

/** Itens ativos que o usuário pode usar (seletor de casa de oração nos formulários). */
export async function listarOrganizacaoParaSelecao(): Promise<NoOrganizacao[]> {
  const { data, error } = await supabase.rpc("listar_organizacao_para_selecao");
  if (error) throw new Error(mensagemDoErro(error, "Não foi possível carregar as casas de oração."));
  return (data ?? []) as NoOrganizacao[];
}

/** Cria (id nulo) ou altera um item da organização. */
export async function salvarNo(dados: {
  nivel: NivelOrganizacao;
  id: string | null;
  paiId: string | null;
  nome: string;
  descricao: string;
  ativo: boolean;
  cidade: string;
  bairro: string;
}): Promise<void> {
  const { error } = await supabase.rpc("salvar_organizacao", {
    p_nivel: dados.nivel,
    p_id: dados.id,
    p_parent: dados.paiId,
    p_nome: dados.nome,
    p_descricao: dados.descricao,
    p_ativo: dados.ativo,
    p_cidade: dados.cidade,
    p_bairro: dados.bairro,
  });
  if (error) throw new Error(mensagemDoErro(error, "Não foi possível salvar."));
}

/** Exclui um item VAZIO da organização (o banco confere permissão, filhos, membros, eventos, portarias e vínculos). */
export async function excluirNo(nivel: NivelOrganizacao, id: string): Promise<void> {
  const { error } = await supabase.rpc("excluir_organizacao", { p_nivel: nivel, p_id: id });
  if (error) throw new Error(mensagemDoErro(error, "Não foi possível excluir."));
}

/** Muda uma casa de oração de local: o destino é uma ADM (fica sem setor) ou um setor (fica no histórico e na auditoria). */
export async function transferirCasaOracao(casaOracaoId: string, destinoId: string, justificativa: string): Promise<void> {
  const { error } = await supabase.rpc("transferir_casa_oracao", {
    p_casa_oracao: casaOracaoId,
    p_destino: destinoId,
    p_justificativa: justificativa,
  });
  if (error) throw new Error(mensagemDoErro(error, "Não foi possível transferir a casa de oração."));
}

/** Vínculos de cada usuário com o rótulo: { idDoUsuario: [{ nivel, alvo_id, rotulo }] }. */
export async function listarVinculosRotulados(): Promise<Record<string, VinculoRotulado[]>> {
  const { data, error } = await supabase.rpc("listar_vinculos_rotulados");
  if (error) throw new Error(mensagemDoErro(error, "Não foi possível carregar os vínculos dos usuários."));

  const mapa: Record<string, VinculoRotulado[]> = {};
  for (const linha of (data ?? []) as (VinculoRotulado & { usuario_id: string })[]) {
    mapa[linha.usuario_id] = [
      ...(mapa[linha.usuario_id] ?? []),
      { nivel: linha.nivel, alvo_id: linha.alvo_id, rotulo: linha.rotulo },
    ];
  }
  return mapa;
}

/** Define os vínculos de um usuário, substituindo a lista anterior (exige usuarios.vinculos). */
export async function definirVinculos(usuarioId: string, vinculos: VinculoUsuario[]): Promise<void> {
  const { error } = await supabase.rpc("definir_vinculos", { p_usuario: usuarioId, p_vinculos: vinculos });
  if (error) throw new Error(mensagemDoErro(error, "Não foi possível salvar os vínculos."));
}
