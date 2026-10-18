/** SysMúsica — Tipos da Auditoria (campos = colunas devolvidas pelas funções do banco, migração 0015). */

/** Um registro da auditoria. */
export interface LinhaAuditoria {
  id: string;
  ocorrido_em: string;
  usuario_id: string | null;
  usuario_nome: string | null; // nulo = ação do sistema
  acao: string; // código (ex.: registro_alterado, login, portaria_aprovada)
  entidade: string; // tipo de item (ex.: membro, evento, portaria)
  entidade_id: string | null;
  detalhes: Record<string, unknown> | null;
  total: number; // total de registros do filtro (igual em todas as linhas)
}

/** Filtros da tela. As datas vêm dos campos de data (AAAA-MM-DD, vazio = sem limite). */
export interface FiltrosAuditoria {
  inicio: string;
  fim: string;
  usuarioId: string;
  entidade: string;
  acao: string;
  busca: string;
}

/** Opções dos filtros (o que já existe na auditoria). */
export interface OpcoesAuditoria {
  usuarios: { id: string; nome: string }[];
  entidades: string[];
  acoes: string[];
}

/** Uma linha do "antes e depois". Nulo em "de" ou "para" = não se aplica (cadastro ou exclusão). */
export interface MudancaCampo {
  campo: string;
  de: string | null;
  para: string | null;
}
