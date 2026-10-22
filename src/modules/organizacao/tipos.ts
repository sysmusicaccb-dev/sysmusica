/**
 * Sysmusica — Tipos da organização: Estado › RRM › RA › ADM › Setor (opcional) › Casa de Oração.
 * Campos = colunas das funções do banco (migração 0039).
 *   RRM = Reunião Regional Ministerial · RA = Regional Administrativa · ADM = Administração
 */

export type NivelOrganizacao = "ESTADO" | "RRM" | "RA" | "ADM" | "SETOR" | "CASA_ORACAO";

/** Um item da árvore. Os campos opcionais só vêm na consulta completa (tela de Organização). */
export interface NoOrganizacao {
  nivel: NivelOrganizacao;
  id: string;
  /**
   * estado -> nulo; RRM -> estado; RA -> RRM; ADM -> RA; setor -> ADM;
   * casa de oração -> o setor dela OU, quando não tem setor, a própria ADM.
   */
  parent_id: string | null;
  nome: string;
  descricao?: string | null;
  ativo?: boolean;
  cidade?: string | null; // só casas de oração
  bairro?: string | null; // só casas de oração
  qtd_filhos?: number; // itens diretos abaixo (na ADM: setores + casas de oração sem setor)
  qtd_membros?: number; // só casas de oração
}

/** Vínculo de um usuário com um nível da organização (sem o rótulo). */
export interface VinculoUsuario {
  nivel: NivelOrganizacao;
  alvo_id: string;
}

/** Vínculo com o texto para exibir (ex.: "Jequié › Ipiaú › Setor 1"). */
export interface VinculoRotulado extends VinculoUsuario {
  rotulo: string;
}
