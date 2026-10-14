-- =====================================================================
-- SysMúsica — Schema PostgreSQL (Supabase) — v2
--
-- Novidades desta versão:
--   * tabela CARGOS (cargos dinâmicos, com seed padrão)
--   * MUSICOS foi refatorada para MEMBROS (dados antigos são migrados)
--   * PRESENCAS: membro_id no lugar de musico_id + hora_entrada / hora_saida
--   * função (RPC) registrar_presenca_qr para o controle de acesso via QR Code
--   * RLS atualizado para as novas tabelas
--
-- Como aplicar: Supabase Dashboard > SQL Editor > colar tudo e executar (Run).
-- O script é IDEMPOTENTE e roda em uma única transação (begin/commit):
-- se qualquer passo falhar, nada é alterado. Pode ser executado várias vezes.
-- =====================================================================
begin;

-- ---------------------------------------------------------------------
-- 1) CARGOS — lista dinâmica de cargos/funções
--    permite_instrumento: indica se o cargo informa categoria de instrumento.
--    nome é UNIQUE para o seed ser idempotente (on conflict).
-- ---------------------------------------------------------------------
create table if not exists public.cargos (
  id                  uuid    primary key default gen_random_uuid(),
  nome                text    not null unique,
  permite_instrumento boolean not null default false
);

-- Seed padrão. Se você alterar um valor manualmente depois, reexecutar o script
-- NÃO sobrescreve (on conflict do nothing).
insert into public.cargos (nome, permite_instrumento) values
  ('Músico',                           true),
  ('Organista',                        true),
  ('Instrutor',                        true),
  ('Encarregado Local',                true),
  ('Encarregado Regional',             true),
  ('Examinadora',                      true),
  ('Ancião',                           false),
  ('Diácono',                          false),
  ('Cooperador de Jovens e Menores',   false),
  ('Cooperador do Ofício Ministerial', false),
  ('Secretário da Música',             false)
on conflict (nome) do nothing;

-- ---------------------------------------------------------------------
-- 2) MEMBROS — substitui a antiga tabela MUSICOS
--    qr_secret: segredo individual usado para validar o QR Code dinâmico.
--    data_nascimento é opcional porque os registros migrados de MUSICOS não a possuem.
-- ---------------------------------------------------------------------
create table if not exists public.membros (
  id                    uuid        primary key default gen_random_uuid(),
  nome                  text        not null,
  congregacao           text        not null,
  cargo_id              uuid        not null references public.cargos (id),
  data_nascimento       date,
  categoria_instrumento text,
  status                text        not null default 'Ativo',   -- ex: Ativo, Inativo
  qr_secret             uuid        not null unique default gen_random_uuid(),
  data_cadastro         timestamptz not null default now()
);

-- 2.1) Migração dos dados antigos: musicos -> membros (só roda se musicos ainda existir).
--      Mantém o mesmo id (as presenças antigas continuam apontando para a pessoa certa),
--      usa o cargo 'Músico' e copia o antigo "instrumento" para categoria_instrumento.
do $$
begin
  if to_regclass('public.musicos') is not null then
    insert into public.membros (id, nome, congregacao, cargo_id, categoria_instrumento, status, data_cadastro)
    select m.id,
           m.nome,
           m.congregacao,
           (select c.id from public.cargos c where c.nome = 'Músico'),
           m.instrumento,
           m.status,
           m.data_cadastro
    from public.musicos m
    on conflict (id) do nothing;
  end if;
end
$$;

-- ---------------------------------------------------------------------
-- 3) EVENTOS — sem alteração estrutural
-- ---------------------------------------------------------------------
create table if not exists public.eventos (
  id           uuid        primary key default gen_random_uuid(),
  tipo         text        not null,                    -- ex: Ensaio, Culto
  data_evento  timestamptz not null,
  local        text        not null
);

-- ---------------------------------------------------------------------
-- 4) PRESENCAS — membro_id + hora_entrada / hora_saida
--    (instalação nova já nasce neste formato; banco antigo é ajustado abaixo)
-- ---------------------------------------------------------------------
create table if not exists public.presencas (
  id           uuid        primary key default gen_random_uuid(),
  membro_id    uuid        not null references public.membros (id) on delete cascade,
  evento_id    uuid        not null references public.eventos (id) on delete cascade,
  status       text        not null,                    -- ex: Presente, Ausente, Justificado
  hora_entrada timestamptz not null default now(),
  hora_saida   timestamptz
);

-- 4.1) Migração do formato antigo (coluna musico_id): troca por membro_id.
--      Só roda se a coluna musico_id ainda existir.
do $$
begin
  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name   = 'presencas'
      and column_name  = 'musico_id'
  ) then
    alter table public.presencas add column if not exists membro_id uuid;

    -- Os ids de membros são os mesmos de musicos, então a cópia é direta
    update public.presencas set membro_id = musico_id where membro_id is null;

    -- Remove a regra antiga (1 presença por músico/evento) e a coluna antiga
    -- (a FK para musicos cai junto com a coluna)
    alter table public.presencas drop constraint if exists presencas_musico_evento_unico;
    alter table public.presencas drop column musico_id;

    alter table public.presencas alter column membro_id set not null;
    alter table public.presencas
      add constraint presencas_membro_id_fkey
      foreign key (membro_id) references public.membros (id) on delete cascade;
  end if;
end
$$;

-- 4.2) Colunas de entrada/saída (em banco antigo, as linhas existentes recebem now())
alter table public.presencas add column if not exists hora_entrada timestamptz not null default now();
alter table public.presencas add column if not exists hora_saida   timestamptz;

-- ---------------------------------------------------------------------
-- 5) Remove a tabela antiga MUSICOS, mas só depois de conferir que tudo foi copiado.
--    (Se ainda houver dependência, o DROP falha de propósito e a transação desfaz tudo.)
-- ---------------------------------------------------------------------
do $$
begin
  if to_regclass('public.musicos') is not null then
    if exists (
      select 1 from public.musicos m
      where not exists (select 1 from public.membros b where b.id = m.id)
    ) then
      raise exception 'Migração interrompida: há registros em musicos que não foram copiados para membros.';
    end if;
    drop table public.musicos;
  end if;
end
$$;

-- ---------------------------------------------------------------------
-- 6) ÍNDICES
--    presencas_entrada_aberta_unica: no máximo UMA entrada sem saída por membro/evento.
--    Substitui o antigo UNIQUE (musico_id, evento_id) e permite nova entrada depois de uma saída.
--    Também protege a função registrar_presenca_qr contra duas leituras simultâneas.
-- ---------------------------------------------------------------------
create unique index if not exists presencas_entrada_aberta_unica
  on public.presencas (membro_id, evento_id)
  where hora_saida is null;

create index if not exists idx_presencas_evento_id on public.presencas (evento_id);
create index if not exists idx_presencas_membro_id on public.presencas (membro_id);
create index if not exists idx_membros_cargo_id    on public.membros (cargo_id);

-- ---------------------------------------------------------------------
-- 7) RLS (Row Level Security) — FASE INICIAL
--    cargos   : somente leitura pública (os cargos vêm do seed acima)
--    membros  : leitura e inserção públicas para 'anon'
--    eventos  : leitura e inserção públicas para 'anon'
--    presencas: leitura e inserção públicas para 'anon'
--    Sem políticas de UPDATE/DELETE: essas operações ficam BLOQUEADAS.
-- ---------------------------------------------------------------------
alter table public.cargos    enable row level security;
alter table public.membros   enable row level security;
alter table public.eventos   enable row level security;
alter table public.presencas enable row level security;

-- Remove políticas anteriores (mantém o script reexecutável)
drop policy if exists "anon_select_cargos"    on public.cargos;
drop policy if exists "anon_select_membros"   on public.membros;
drop policy if exists "anon_insert_membros"   on public.membros;
drop policy if exists "anon_select_eventos"   on public.eventos;
drop policy if exists "anon_insert_eventos"   on public.eventos;
drop policy if exists "anon_select_presencas" on public.presencas;
drop policy if exists "anon_insert_presencas" on public.presencas;

-- cargos
create policy "anon_select_cargos"    on public.cargos
  for select to anon using (true);

-- membros
create policy "anon_select_membros"   on public.membros
  for select to anon using (true);
create policy "anon_insert_membros"   on public.membros
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

-- ---------------------------------------------------------------------
-- 8) PROTEÇÃO DO qr_secret
--    A leitura pública de membros NÃO inclui a coluna qr_secret: sem isso, qualquer
--    visitante com a chave anon (pública no frontend) copiaria os segredos de todos.
--    Consequência: "select *" em membros falha para anon; o frontend deve listar as colunas
--    (ver COLUNAS_MEMBRO_PUBLICO em src/types/database.ts, que precisa ficar igual a esta lista).
--    O revoke vem ANTES do grant, pois revogar o privilégio da tabela remove os das colunas.
-- ---------------------------------------------------------------------
revoke select on public.membros from anon;
grant select (id, nome, congregacao, cargo_id, data_nascimento, categoria_instrumento, status, data_cadastro)
  on public.membros to anon;

-- ---------------------------------------------------------------------
-- 9) RPC registrar_presenca_qr — entrada via QR Code
--    Se já existe entrada SEM hora_saida para o membro neste evento, levanta exceção
--    (evita duplicidade). Caso contrário, insere a presença e devolve o registro criado.
--    security invoker (padrão): executa com as permissões de quem chama, respeitando o RLS.
-- ---------------------------------------------------------------------
create or replace function public.registrar_presenca_qr(p_membro_id uuid, p_evento_id uuid)
returns public.presencas
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_presenca public.presencas;
begin
  -- Já existe uma entrada em aberto (sem saída) para este membro neste evento?
  if exists (
    select 1
    from public.presencas p
    where p.membro_id  = p_membro_id
      and p.evento_id  = p_evento_id
      and p.hora_saida is null
  ) then
    raise exception 'Entrada já registrada para este membro neste evento (sem hora de saída).'
      using errcode = 'unique_violation';
  end if;

  -- Registra a entrada (hora_entrada usa o default now())
  insert into public.presencas (membro_id, evento_id, status)
  values (p_membro_id, p_evento_id, 'Presente')
  returning * into v_presenca;

  return v_presenca;
end;
$$;

-- Remove a execução pública padrão e libera só para os papéis da aplicação
revoke all on function public.registrar_presenca_qr(uuid, uuid) from public;
grant execute on function public.registrar_presenca_qr(uuid, uuid) to anon, authenticated;

-- ATENÇÃO: com as políticas atuais, qualquer pessoa com a chave anon pode ler e inserir dados,
-- e a função acima ainda NÃO valida o qr_secret. Aceitável só nesta fase inicial.
-- Antes de produção: autenticação, políticas restritas e validação do QR dinâmico no servidor.

commit;
