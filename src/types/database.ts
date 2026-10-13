/**
 * SysMúsica — Tipos TypeScript das tabelas do banco (Supabase/PostgreSQL)
 *
 * Mantenha este arquivo em sincronia com supabase/schema.sql.
 * Convenções:
 *  - uuid        -> string
 *  - text        -> string
 *  - timestamptz -> string (o Supabase devolve data/hora em formato ISO 8601,
 *                   ex: "2026-10-13T19:30:00+00:00")
 */

// ---------------------------------------------------------------------
// Tabela: musicos
// ---------------------------------------------------------------------
export interface Musico {
  id: string;
  nome: string;
  instrumento: string;
  congregacao: string;
  status: string; // ex: "Ativo", "Inativo" (padrão no banco: "Ativo")
  data_cadastro: string; // timestamptz, preenchido automaticamente (now())
}

/** Payload para INSERT: campos com valor padrão no banco são opcionais. */
export type MusicoInsert = Omit<Musico, "id" | "status" | "data_cadastro"> &
  Partial<Pick<Musico, "id" | "status" | "data_cadastro">>;

// ---------------------------------------------------------------------
// Tabela: eventos
// ---------------------------------------------------------------------
export interface Evento {
  id: string;
  tipo: string; // ex: "Ensaio", "Culto"
  data_evento: string; // timestamptz (ISO 8601)
  local: string;
}

/** Payload para INSERT: apenas o id é gerado pelo banco. */
export type EventoInsert = Omit<Evento, "id"> & Partial<Pick<Evento, "id">>;

// ---------------------------------------------------------------------
// Tabela: presencas
// ---------------------------------------------------------------------
export interface Presenca {
  id: string;
  musico_id: string; // FK -> musicos.id
  evento_id: string; // FK -> eventos.id
  status: string; // ex: "Presente", "Ausente", "Justificado"
}

/** Payload para INSERT: apenas o id é gerado pelo banco. */
export type PresencaInsert = Omit<Presenca, "id"> & Partial<Pick<Presenca, "id">>;
