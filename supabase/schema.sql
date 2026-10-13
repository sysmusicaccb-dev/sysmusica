-- =====================================================================
-- SysMúsica — Schema PostgreSQL (Supabase)
--
-- Como aplicar: Supabase Dashboard > SQL Editor > colar e executar (Run).
-- O script é idempotente: pode ser executado mais de uma vez sem erro.
-- =====================================================================

-- gen_random_uuid() é nativo do PostgreSQL 13+ (padrão no Supabase),
-- não requer extensão adicional.

-- ---------------------------------------------------------------------
-- 1) MUSICOS — cadastro dos músicos
-- ---------------------------------------------------------------------
create table if not exists public.musicos (
  id            uuid        primary key default gen_random_uuid(),
  nome          text        not null,
  instrumento   text        not null,
  congregacao   text        not null,
  status        text        not null default 'Ativo',   -- ex: Ativo, Inativo
  data_cadastro timestamptz not null default now()
);

-- ---------------------------------------------------------------------
-- 2) EVENTOS — ensaios, cultos etc.
-- ---------------------------------------------------------------------
create table if not exists public.eventos (
  id           uuid        primary key default gen_random_uuid(),
  tipo         text        not null,                    -- ex: Ensaio, Culto
  data_evento  timestamptz not null,
  local        text        not null
);

-- ---------------------------------------------------------------------
-- 3) PRESENCAS — registro de presença de cada músico em cada evento
-- ---------------------------------------------------------------------
create table if not exists public.presencas (
  id         uuid primary key default gen_random_uuid(),
  musico_id  uuid not null references public.musicos (id) on delete cascade,
  evento_id  uuid not null references public.eventos (id) on delete cascade,
  status     text not null,                             -- ex: Presente, Ausente, Justificado
  -- Impede registrar o mesmo músico duas vezes no mesmo evento
  constraint presencas_musico_evento_unico unique (musico_id, evento_id)
);

-- Índices nas chaves estrangeiras (acelera consultas e joins).
-- Obs.: o índice (musico_id, evento_id) já é coberto pela constraint unique acima;
-- aqui só falta o de evento_id.
create index if not exists idx_presencas_evento_id on public.presencas (evento_id);

-- ---------------------------------------------------------------------
-- 4) RLS (Row Level Security) — FASE INICIAL
--    Leitura (SELECT) e inserção (INSERT) públicas para o papel 'anon'.
--    Sem políticas de UPDATE/DELETE: essas operações ficam BLOQUEADAS.
-- ---------------------------------------------------------------------
alter table public.musicos   enable row level security;
alter table public.eventos   enable row level security;
alter table public.presencas enable row level security;

-- Remove políticas anteriores (mantém o script reexecutável)
drop policy if exists "anon_select_musicos"   on public.musicos;
drop policy if exists "anon_insert_musicos"   on public.musicos;
drop policy if exists "anon_select_eventos"   on public.eventos;
drop policy if exists "anon_insert_eventos"   on public.eventos;
drop policy if exists "anon_select_presencas" on public.presencas;
drop policy if exists "anon_insert_presencas" on public.presencas;

-- musicos
create policy "anon_select_musicos"   on public.musicos
  for select to anon using (true);
create policy "anon_insert_musicos"   on public.musicos
  for insert to anon with check (true);

-- eventos
create policy "anon_select_eventos"   on public.eventos
  for select to anon using (true);
create policy "anon_insert_eventos"   on public.eventos
  for insert to anon with check (true);

-- presencas
create policy "anon_select_presencas" on public.presencas
  for select to anon using (true);
create policy "anon_insert_presencas" on public.presencas
  for insert to anon with check (true);

-- ATENÇÃO: com estas políticas, QUALQUER pessoa com a chave anon (que é pública
-- no frontend) pode ler e inserir dados. Aceitável só nesta fase inicial.
-- Antes de produção: adicionar autenticação e restringir as políticas
-- (ex: 'to authenticated' e checagem de auth.uid()).
