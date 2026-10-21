/** SysMúsica — Tipos da tela "Cadastros pendentes" (formato das funções do banco da migração 0042). */

export type StatusCadastro = "PENDENTE" | "APROVADO" | "REJEITADO" | "EXPIRADO" | "SUBSTITUIDO";
export type TipoCadastro = "NOVO" | "ATUALIZACAO";
/** Filtro da lista: um status ou todos. */
export type FiltroStatus = "PENDENTE" | "APROVADO" | "REJEITADO" | "EXPIRADO" | "TODOS";

export interface ResumoCadastro {
  id: string;
  tipo: TipoCadastro;
  status: StatusCadastro;
  nome: string | null;
  cpf_mascarado: string | null;
  cargo_nome: string | null;
  casa_nome: string | null;
  /** A pessoa digitou uma Casa de Oração que não estava na lista (migração 0043). */
  casa_nao_cadastrada?: boolean;
  menor: boolean;
  cpf_conflito: boolean;
  outros_pendentes: number;
  criado_em: string;
  expira_em: string;
  decidido_em: string | null;
  motivo_rejeicao: string | null;
}

/** Campos do cadastro musical como o banco guarda no pedido (valores já limpos). */
export interface DadosCadastro {
  estado_civil?: string | null;
  sexo?: string | null;
  batizado?: boolean | null;
  data_batismo?: string | null;
  selado?: boolean | null;
  ddd?: string | null;
  telefone?: string | null;
  tem_whatsapp?: boolean | null;
  whatsapp?: string | null;
  email?: string | null;
  cep?: string | null;
  endereco?: string | null;
  numero?: string | null;
  complemento?: string | null;
  uf?: string | null;
  cartao_numero?: string | null;
  cartao_emissao?: string | null;
  cartao_validade?: string | null;
}

/** Como o membro está HOJE (só nas atualizações), para comparar com o pedido. */
export interface MembroAtual {
  nome: string | null;
  casa_oracao_id: string | null;
  casa_nome: string | null;
  cargo_id: string | null;
  cargo_nome: string | null;
  instrumento_id: string | null;
  instrumento_nome: string | null;
  categoria: string | null;
  cidade: string | null;
  bairro: string | null;
  data_nascimento: string | null;
  cadastro: DadosCadastro | null;
}

export interface DetalheCadastro {
  id: string;
  tipo: TipoCadastro;
  status: StatusCadastro;
  membro_id: string | null;
  nome: string | null;
  data_nascimento: string | null;
  cidade: string | null;
  bairro: string | null;
  cpf: string | null;
  cpf_completo_visivel: boolean;
  casa_oracao_id: string | null; // nulo quando a casa foi digitada (veja casa_nome_informada)
  casa_nome: string | null;
  casa_nome_informada?: string | null;
  cargo_id: string | null;
  cargo_nome: string | null;
  instrumento_id: string | null;
  instrumento_nome: string | null;
  categoria: string | null;
  dados: DadosCadastro;
  menor: boolean;
  responsavel_nome: string | null;
  responsavel_telefone: string | null;
  aviso_versao: string;
  aceite_em: string;
  cpf_conflito: boolean;
  criado_em: string;
  expira_em: string;
  decidido_em: string | null;
  motivo_rejeicao: string | null;
  arquivos_disponiveis: boolean;
  outros_pendentes: number;
  atual: MembroAtual | null;
}

/** Endereços temporários das imagens (documento só para quem tem a permissão CPF). */
export interface ArquivosDoCadastro {
  disponivel: boolean;
  foto?: string | null;
  frente?: string | null;
  verso?: string | null;
  documentos_liberados?: boolean;
}
