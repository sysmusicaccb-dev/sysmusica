/** SysMúsica — Tipos da organização (Estado > Região > Setor > Comum). Campos = colunas das funções do banco (0012). */

export type NivelOrganizacao = "ESTADO" | "REGIAO" | "SETOR" | "COMUM";

/** Um item da árvore. Os campos opcionais só vêm na consulta completa (tela de Organização). */
export interface NoOrganizacao {
  nivel: NivelOrganizacao;
  id: string;
  parent_id: string | null; // estado -> nulo; região -> estado; setor -> região; comum -> setor (nulo = sem setor)
  nome: string;
  descricao?: string | null;
  ativo?: boolean;
  cidade?: string | null; // só comuns
  bairro?: string | null; // só comuns
  qtd_filhos?: number; // regiões do estado, setores da região, comuns do setor
  qtd_membros?: number; // só comuns
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
