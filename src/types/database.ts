/**
 * SysMúsica — Tipos TypeScript das tabelas do banco (Supabase/PostgreSQL)
 *
 * Mantenha este arquivo em sincronia com supabase/schema.sql.
 * Convenções:
 *  - uuid        -> string
 *  - text        -> string
 *  - text[]      -> string[]
 *  - boolean     -> boolean
 *  - date        -> string ("AAAA-MM-DD", sem horário nem fuso)
 *  - timestamptz -> string (ISO 8601, ex: "2026-10-13T19:30:00+00:00")
 *  - colunas que aceitam NULL -> "tipo | null"
 */

// ---------------------------------------------------------------------
// Tabela: cargos
// ---------------------------------------------------------------------
export interface Cargo {
  id: string;
  nome: string;
  permite_instrumento: boolean; // true = o cargo informa instrumento
}

/** Payload para INSERT: apenas o id é gerado pelo banco (permite_instrumento tem padrão false). */
export type CargoInsert = Pick<Cargo, "nome"> & Partial<Pick<Cargo, "id" | "permite_instrumento">>;

// ---------------------------------------------------------------------
// Tabela: familias (Cordas, Madeiras, Metais, Teclas...)
// ---------------------------------------------------------------------
export interface Familia {
  id: string;
  nome: string;
  /** Trechos (minúsculas, sem acento) que classificam um instrumento nesta família. */
  palavras_chave: string[];
}

/** Payload para INSERT: id e palavras_chave são opcionais (o padrão de palavras_chave é lista vazia). */
export type FamiliaInsert = Pick<Familia, "nome"> & Partial<Pick<Familia, "id" | "palavras_chave">>;

// ---------------------------------------------------------------------
// Tabela: instrumentos
// ---------------------------------------------------------------------
export interface Instrumento {
  id: string;
  nome: string; // único (sem diferenciar maiúsculas/minúsculas)
  familia_id: string | null; // FK -> familias.id (null = ainda não classificado)
}

/** Payload para INSERT: o id é gerado pelo banco; se familia_id faltar, o gatilho do banco classifica. */
export type InstrumentoInsert = Pick<Instrumento, "nome"> &
  Partial<Pick<Instrumento, "id" | "familia_id">>;

// ---------------------------------------------------------------------
// Tabela: membros (antiga "musicos")
// ---------------------------------------------------------------------
export interface Membro {
  id: string;
  nome: string;
  congregacao: string;
  cargo_id: string; // FK -> cargos.id
  data_nascimento: string | null; // date (AAAA-MM-DD)
  instrumento_id: string | null; // FK -> instrumentos.id (null = sem instrumento)
  status: string; // ex: "Ativo", "Inativo" (padrão no banco: "Ativo")
  qr_secret: string; // segredo do QR Code; NÃO é legível pela chave anon (ver schema.sql, seção 13)
  data_cadastro: string; // timestamptz, preenchido automaticamente (now())
  excluido_em: string | null; // exclusão lógica: preenchido quando o membro é excluído (some das telas)
  cpf: string | null; // 11 dígitos; NÃO é lido diretamente (use cpf_mascarado ou a função obter_cpf_membro)
  cpf_mascarado: string | null; // "***.***.***-25": coluna gerada pelo banco
  cidade: string | null; // município da congregação
  bairro: string | null; // bairro ou igreja de referência
  atualizado_em: string; // timestamptz, atualizado automaticamente a cada alteração
  casa_oracao_id?: string | null; // FK -> casas_oracao.id: a casa de oração do membro (define quem enxerga o cadastro)
  foto_path?: string | null; // caminho da fotografia no armazenamento privado (exibida por URL temporária)
  categoria?: string | null; // OFICIALIZADO, CULTO_OFICIAL ou RJM (só Músico e Organista; define a linha do painel ao vivo)
}

/**
 * Membro como o frontend consegue LER com a chave anon (sem qr_secret).
 * Use este tipo nas telas que buscam membros. A família do membro é a do seu instrumento.
 */
export type MembroPublico = Omit<Membro, "qr_secret" | "excluido_em" | "cpf">;

/**
 * Colunas liberadas para leitura pública em "membros".
 * Deve ser IGUAL à lista do GRANT SELECT (...) em supabase/schema.sql e às chaves de MembroPublico.
 * Usada no lugar de select("*"), que falha porque inclui o qr_secret.
 */
export const COLUNAS_MEMBRO_PUBLICO =
  "id, nome, congregacao, cargo_id, data_nascimento, instrumento_id, status, data_cadastro, cidade, bairro, atualizado_em, cpf_mascarado, casa_oracao_id, foto_path, categoria" as const;

/** Payload para INSERT: o qr_secret é sempre gerado pelo banco e não pode ser enviado. */
export type MembroInsert = Pick<Membro, "nome" | "congregacao" | "cargo_id"> &
  Partial<
    Pick<
      Membro,
      "id" | "data_nascimento" | "instrumento_id" | "status" | "data_cadastro" | "cidade" | "bairro" | "cpf" | "casa_oracao_id" | "foto_path" | "categoria"
    >
  >;

// ---------------------------------------------------------------------
// Tabela: eventos
// ---------------------------------------------------------------------
export interface Evento {
  id: string;
  tipo: string; // ex: "Ensaio", "Culto"
  data_evento: string; // timestamptz (ISO 8601)
  local: string;
  finalidade_id: string | null; // FK -> finalidades_evento.id (nula em eventos antigos)
  cidade?: string | null; // município do evento (informativo; o setor vem da casa de oração)
  casa_oracao_id?: string | null; // casa de oração do evento: define o setor da portaria e quem enxerga o evento
}

/** Payload para INSERT: o id é gerado pelo banco; a finalidade é opcional (eventos antigos não têm). */
export type EventoInsert = Pick<Evento, "tipo" | "data_evento" | "local"> &
  Partial<Pick<Evento, "id" | "finalidade_id" | "cidade" | "casa_oracao_id">>;

// ---------------------------------------------------------------------
// Tabela: finalidades_evento (catálogo reaproveitável de finalidades)
// ---------------------------------------------------------------------
export interface FinalidadeEvento {
  id: string;
  nome: string; // único (sem diferenciar maiúsculas/minúsculas)
  criado_em: string; // timestamptz
}

/** Payload para INSERT: o id e criado_em são gerados pelo banco. */
export type FinalidadeEventoInsert = Pick<FinalidadeEvento, "nome"> & Partial<Pick<FinalidadeEvento, "id">>;

// ---------------------------------------------------------------------
// Tabela: presencas
// ---------------------------------------------------------------------
export interface Presenca {
  id: string;
  membro_id: string; // FK -> membros.id
  evento_id: string; // FK -> eventos.id
  status: string; // ex: "Presente", "Ausente", "Justificado"
  hora_entrada: string; // timestamptz (padrão no banco: now())
  hora_saida: string | null; // timestamptz; null = entrada ainda em aberto
  portaria_id?: string | null; // FK -> portarias.id (nula em presenças antigas)
  registrado_por?: string | null; // quem registrou (definido pelo banco)
  origem?: string; // "MANUAL" ou "QR" (definida pelo banco)
}

/** Payload para INSERT: hora_entrada, hora_saida e id são opcionais (valores padrão do banco). */
export type PresencaInsert = Pick<Presenca, "membro_id" | "evento_id" | "status"> &
  Partial<Pick<Presenca, "id" | "hora_entrada" | "hora_saida" | "portaria_id">>;

// ---------------------------------------------------------------------
// RPC: registrar_entrada(p_portaria_id, p_membro_id, p_origem) — só em portaria APROVADA
// Uso: supabase.rpc("registrar_entrada", args) -> devolve a Presenca criada
// ---------------------------------------------------------------------
export interface RegistrarEntradaArgs {
  p_portaria_id: string;
  p_membro_id: string;
  p_origem?: "MANUAL" | "QR";
}
