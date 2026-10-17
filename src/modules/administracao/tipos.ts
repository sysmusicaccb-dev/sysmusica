/**
 * SysMúsica — Tipos do módulo Administração (usuários, grupos e permissões).
 * Os nomes dos campos seguem as colunas devolvidas pelas funções do banco (migração 0003).
 */

/** Permissão do catálogo do banco (ex: membros.editar). */
export interface PermissaoCatalogo {
  codigo: string;
  modulo: string; // nome de exibição do módulo (ex: "Membros")
  acao: string; // ex: "Visualizar", "Criar", "Editar", "Excluir", "Registrar"
  descricao: string;
}

/** Grupo de acesso, com quantidade de usuários e permissões. */
export interface GrupoAcesso {
  id: string;
  nome: string;
  descricao: string | null;
  ativo: boolean;
  sistema: boolean; // true = grupo protegido (Administrador)
  qtd_usuarios: number;
  permissoes: string[]; // códigos das permissões do grupo
}

/** Usuário do sistema (conta de login + grupo). */
export interface UsuarioSistema {
  id: string;
  nome: string;
  email: string;
  grupo_id: string | null;
  grupo_nome: string | null;
  ativo: boolean;
  ultimo_acesso: string | null; // timestamptz (ISO 8601)
  criado_em: string;
}

/** Dados para criar um usuário (validados em src/modules/administracao/regras.ts). */
export interface DadosNovoUsuario {
  nome: string;
  email: string;
  senha: string;
  grupoId: string;
}
