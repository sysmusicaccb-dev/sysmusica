/** SysMúsica — Tipos da organização (Estado > Região > Setor > Casa de Oração). Campos = colunas das funções do banco (0012). */

export type NivelOrganizacao = "ESTADO" | "REGIAO" | "SETOR" | "CASA_ORACAO";

/** Um item da árvore. Os campos opcionais só vêm na consulta completa (tela de Organização). */
export interface NoOrganizacao {
  nivel: NivelOrganizacao;
  id: string;
  parent_id: string | null; // estado -> nulo; região -> estado; setor -> região; casa de oração -> setor (nulo = sem setor)
  nome: string;
  descricao?: string | null;
  ativo?: boolean;
  cidade?: string | null; // só casas de oração
  bairro?: string | null; // só casas de oração
  qtd_filhos?: number; // regiões do estado, setores da região, casas de oração do setor
  qtd_membros?: number; // só casas de oração
}

/** Vínculo de um usuário com um nível da organização (sem o rótulo). */
export interface VinculoUsuario {
  nivel: NivelOrganizacao;
  alvo_id: string;
}

/** Vínculo com o texto para exibir (ex.: "Salvador › Setor 1"). */
export interface VinculoRotulado extends VinculoUsuario {
  rotulo: string;
}
