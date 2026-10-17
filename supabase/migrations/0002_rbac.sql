-- =====================================================================
-- SysMúsica — Migração 0002: usuários, grupos e permissões (RBAC)
--
-- O que esta migração faz:
--   * cria usuarios, grupos, permissoes e grupo_permissoes;
--   * cria o catálogo de permissões e os grupos iniciais (Administrador, Secretaria, Portaria);
--   * cria uma linha em "usuarios" automaticamente para cada conta nova do Supabase Auth;
--   * troca TODAS as políticas de RLS: o acesso anônimo termina e cada operação passa a exigir
--     login + permissão do grupo do usuário (validado aqui no banco, não só na tela).
--
-- É IDEMPOTENTE (pode ser reexecutada) e roda em uma única transação.
-- Aplique depois do 0001 e NÃO reexecute o 0001 depois deste arquivo.
--
-- COMO CRIAR O PRIMEIRO ADMINISTRADOR (uma vez, depois de aplicar este arquivo):
--   1) Dashboard > Authentication > Users > Add user > Create new user
--      (e-mail + senha, marcando "Auto Confirm User").
--   2) No SQL Editor, trocando o e-mail:
--        update public.usuarios
--           set grupo_id = (select id from public.grupos where nome = 'Administrador'),
--               nome = 'Seu Nome',
--               ativo = true
--         where email = 'seu-email@exemplo.com';
--   3) Recomendado: Authentication > Sign In / Providers > desativar "Allow new users to sign up",
--      para que só você crie contas.
--
-- ENQUANTO NÃO HÁ TELA DE USUÁRIOS, para colocar alguém em um grupo:
--        update public.usuarios
--           set grupo_id = (select id from public.grupos where nome = 'Portaria')
--         where email = 'operador@exemplo.com';
-- =====================================================================
begin;

-- ---------------------------------------------------------------------
-- 1) TABELAS
-- ---------------------------------------------------------------------

-- Catálogo de permissões: código no formato "modulo.acao" (ex: membros.editar).
-- Mantenha igual a CATALOGO_PERMISSOES em src/lib/permissoes.ts (há um teste que confere).
create table if not exists public.permissoes (
  codigo    text primary key,
  modulo    text not null,
  acao      text not null,
  descricao text not null
);

-- Grupos de acesso: cada usuário pertence a UM grupo, e o grupo define o que ele pode fazer.
create table if not exists public.grupos (
  id        uuid        primary key default gen_random_uuid(),
  nome      text        not null unique,
  descricao text,
  ativo     boolean     not null default true,
  sistema   boolean     not null default false,   -- grupos do sistema não podem ser excluídos
  criado_em timestamptz not null default now()
);

create table if not exists public.grupo_permissoes (
  grupo_id         uuid not null references public.grupos (id) on delete cascade,
  permissao_codigo text not null references public.permissoes (codigo) on delete cascade,
  primary key (grupo_id, permissao_codigo)
);

-- Usuários do sistema: o id é o mesmo da conta no Supabase Auth.
-- Sem grupo (grupo_id nulo), o usuário consegue entrar, mas não acessa nada.
create table if not exists public.usuarios (
  id        uuid        primary key references auth.users (id) on delete cascade,
  nome      text        not null,
  email     text        not null,
  grupo_id  uuid        references public.grupos (id) on delete set null,
  ativo     boolean     not null default true,
  criado_em timestamptz not null default now()
);

create index if not exists idx_usuarios_grupo_id on public.usuarios (grupo_id);

-- ---------------------------------------------------------------------
-- 2) CATÁLOGO DE PERMISSÕES
-- ---------------------------------------------------------------------
insert into public.permissoes (codigo, modulo, acao, descricao) values
  ('dashboard.visualizar',   'Dashboard',    'Visualizar', 'Ver o dashboard com indicadores e gráficos'),
  ('membros.visualizar',     'Membros',      'Visualizar', 'Ver a lista de membros'),
  ('membros.criar',          'Membros',      'Criar',      'Cadastrar novos membros'),
  ('membros.editar',         'Membros',      'Editar',     'Alterar dados de membros'),
  ('membros.excluir',        'Membros',      'Excluir',    'Excluir membros'),
  ('eventos.visualizar',     'Eventos',      'Visualizar', 'Ver a lista de eventos'),
  ('eventos.criar',          'Eventos',      'Criar',      'Cadastrar novos eventos'),
  ('eventos.editar',         'Eventos',      'Editar',     'Alterar dados de eventos'),
  ('eventos.excluir',        'Eventos',      'Excluir',    'Excluir eventos'),
  ('instrumentos.visualizar','Instrumentos', 'Visualizar', 'Ver instrumentos e famílias'),
  ('instrumentos.criar',     'Instrumentos', 'Criar',      'Cadastrar novos instrumentos'),
  ('instrumentos.editar',    'Instrumentos', 'Editar',     'Alterar instrumentos e corrigir a família'),
  ('instrumentos.excluir',   'Instrumentos', 'Excluir',    'Excluir instrumentos'),
  ('portaria.visualizar',    'Portaria',     'Visualizar', 'Ver a portaria e o histórico de entradas'),
  ('portaria.registrar',     'Portaria',     'Registrar',  'Registrar a entrada de membros nos eventos'),
  ('portaria.editar',        'Portaria',     'Editar',     'Corrigir registros da portaria'),
  ('portaria.excluir',       'Portaria',     'Excluir',    'Excluir registros da portaria')
on conflict (codigo) do update
  set modulo = excluded.modulo, acao = excluded.acao, descricao = excluded.descricao;

-- ---------------------------------------------------------------------
-- 3) GRUPOS INICIAIS
--    Administrador: sempre recebe TODAS as permissões do catálogo (inclusive as futuras).
--    Secretaria e Portaria: criados só na primeira execução; depois você pode ajustá-los sem
--    que uma nova execução desfaça suas alterações.
-- ---------------------------------------------------------------------
do $$
declare
  v_grupo uuid;
begin
  -- Administrador
  select id into v_grupo from public.grupos where nome = 'Administrador';
  if v_grupo is null then
    insert into public.grupos (nome, descricao, sistema)
    values ('Administrador', 'Acesso total ao sistema.', true)
    returning id into v_grupo;
  end if;
  insert into public.grupo_permissoes (grupo_id, permissao_codigo)
  select v_grupo, p.codigo from public.permissoes p
  on conflict do nothing;

  -- Secretaria: cadastros e consulta, sem exclusão
  if not exists (select 1 from public.grupos where nome = 'Secretaria') then
    insert into public.grupos (nome, descricao)
    values ('Secretaria', 'Gerencia membros, eventos e instrumentos; consulta a portaria.')
    returning id into v_grupo;
    insert into public.grupo_permissoes (grupo_id, permissao_codigo)
    select v_grupo, p.codigo from public.permissoes p
    where p.codigo = any (array[
      'dashboard.visualizar',
      'membros.visualizar', 'membros.criar', 'membros.editar',
      'eventos.visualizar', 'eventos.criar', 'eventos.editar',
      'instrumentos.visualizar', 'instrumentos.criar', 'instrumentos.editar',
      'portaria.visualizar'
    ]);
  end if;

  -- Portaria: só acessa o módulo Portaria, para registrar a entrada dos membros
  if not exists (select 1 from public.grupos where nome = 'Portaria') then
    insert into public.grupos (nome, descricao)
    values ('Portaria', 'Acessa apenas a portaria, para registrar a entrada dos membros nos eventos.')
    returning id into v_grupo;
    insert into public.grupo_permissoes (grupo_id, permissao_codigo)
    select v_grupo, p.codigo from public.permissoes p
    where p.codigo = any (array['portaria.visualizar', 'portaria.registrar']);
  end if;
end
$$;

-- ---------------------------------------------------------------------
-- 4) USUÁRIOS: linha criada automaticamente para cada conta nova do Supabase Auth
--    (sem grupo: a pessoa só acessa o sistema depois que um administrador definir o grupo)
-- ---------------------------------------------------------------------
create or replace function public.criar_usuario_ao_cadastrar()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.usuarios (id, nome, email)
  values (
    new.id,
    coalesce(nullif(new.raw_user_meta_data ->> 'nome', ''), split_part(coalesce(new.email, ''), '@', 1)),
    coalesce(new.email, '')
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists trg_criar_usuario on auth.users;
create trigger trg_criar_usuario
  after insert on auth.users
  for each row execute function public.criar_usuario_ao_cadastrar();

-- Contas que já existiam antes desta migração
insert into public.usuarios (id, nome, email)
select u.id,
       coalesce(nullif(u.raw_user_meta_data ->> 'nome', ''), split_part(coalesce(u.email, ''), '@', 1)),
       coalesce(u.email, '')
from auth.users u
on conflict (id) do nothing;

-- ---------------------------------------------------------------------
-- 5) FUNÇÕES DE PERMISSÃO
--    security definer: leem usuarios/grupos mesmo com o RLS ligado nessas tabelas.
--    São usadas pelas políticas abaixo e pela tela (minha_conta).
-- ---------------------------------------------------------------------

-- O usuário logado tem pelo menos uma das permissões informadas? (usuário e grupo ativos)
create or replace function public.tem_alguma_permissao(p_codigos text[])
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.usuarios u
    join public.grupos g on g.id = u.grupo_id and g.ativo
    join public.grupo_permissoes gp on gp.grupo_id = g.id
    where u.id = (select auth.uid())
      and u.ativo
      and gp.permissao_codigo = any (p_codigos)
  )
$$;

create or replace function public.tem_permissao(p_codigo text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.tem_alguma_permissao(array[p_codigo])
$$;

-- O usuário logado está ativo e pertence a um grupo ativo? (acesso mínimo ao sistema)
create or replace function public.tem_acesso()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.usuarios u
    join public.grupos g on g.id = u.grupo_id and g.ativo
    where u.id = (select auth.uid()) and u.ativo
  )
$$;

-- Dados do usuário logado para a tela: nome, e-mail, grupo e lista de permissões
-- (lista vazia quando o usuário ou o grupo está inativo)
create or replace function public.minha_conta()
returns table (nome text, email text, grupo text, ativo boolean, permissoes text[])
language sql
stable
security definer
set search_path = public
as $$
  select u.nome,
         u.email,
         g.nome,
         (u.ativo and coalesce(g.ativo, false)),
         case
           when u.ativo and coalesce(g.ativo, false) then
             array(select gp.permissao_codigo from public.grupo_permissoes gp
                   where gp.grupo_id = u.grupo_id order by gp.permissao_codigo)
           else '{}'::text[]
         end
  from public.usuarios u
  left join public.grupos g on g.id = u.grupo_id
  where u.id = (select auth.uid())
$$;

-- Só usuários logados executam estas funções (anônimos não)
revoke all on function public.tem_alguma_permissao(text[]) from public;
revoke all on function public.tem_permissao(text)           from public;
revoke all on function public.tem_acesso()                  from public;
revoke all on function public.minha_conta()                 from public;
grant execute on function public.tem_alguma_permissao(text[]) to authenticated;
grant execute on function public.tem_permissao(text)           to authenticated;
grant execute on function public.tem_acesso()                  to authenticated;
grant execute on function public.minha_conta()                 to authenticated;

-- ---------------------------------------------------------------------
-- 6) RLS: TABELAS DE ACESSO (usuarios, grupos, permissoes, grupo_permissoes)
--    Sem políticas = ninguém lê nem altera diretamente. O acesso é só pelas funções acima.
--    (A tela de usuários e grupos, na próxima etapa, adicionará políticas para administradores.)
-- ---------------------------------------------------------------------
alter table public.usuarios         enable row level security;
alter table public.grupos           enable row level security;
alter table public.permissoes       enable row level security;
alter table public.grupo_permissoes enable row level security;

revoke all on public.usuarios, public.grupos, public.permissoes, public.grupo_permissoes
  from anon, authenticated;

-- ---------------------------------------------------------------------
-- 7) RLS: TABELAS DO SISTEMA — troca as políticas antigas (acesso anônimo) por políticas
--    de permissão. Sem login não se lê nem se grava nada.
-- ---------------------------------------------------------------------

-- Remove TODAS as políticas anteriores
drop policy if exists "anon_select_cargos"        on public.cargos;
drop policy if exists "anon_select_familias"      on public.familias;
drop policy if exists "anon_select_instrumentos"  on public.instrumentos;
drop policy if exists "anon_insert_instrumentos"  on public.instrumentos;
drop policy if exists "admin_update_instrumentos" on public.instrumentos;
drop policy if exists "anon_select_membros"       on public.membros;
drop policy if exists "anon_insert_membros"       on public.membros;
drop policy if exists "anon_select_eventos"       on public.eventos;
drop policy if exists "anon_insert_eventos"       on public.eventos;
drop policy if exists "anon_select_presencas"     on public.presencas;
drop policy if exists "anon_insert_presencas"     on public.presencas;

-- Remove também as políticas desta migração (para poder reexecutar)
drop policy if exists "cargos_select"       on public.cargos;
drop policy if exists "familias_select"     on public.familias;
drop policy if exists "instrumentos_select" on public.instrumentos;
drop policy if exists "instrumentos_insert" on public.instrumentos;
drop policy if exists "instrumentos_update" on public.instrumentos;
drop policy if exists "instrumentos_delete" on public.instrumentos;
drop policy if exists "membros_select"      on public.membros;
drop policy if exists "membros_insert"      on public.membros;
drop policy if exists "membros_update"      on public.membros;
drop policy if exists "membros_delete"      on public.membros;
drop policy if exists "eventos_select"      on public.eventos;
drop policy if exists "eventos_insert"      on public.eventos;
drop policy if exists "eventos_update"      on public.eventos;
drop policy if exists "eventos_delete"      on public.eventos;
drop policy if exists "presencas_select"    on public.presencas;
drop policy if exists "presencas_insert"    on public.presencas;
drop policy if exists "presencas_update"    on public.presencas;
drop policy if exists "presencas_delete"    on public.presencas;

-- cargos e famílias: leitura para qualquer usuário ativo com grupo (alimentam formulários e telas)
create policy "cargos_select" on public.cargos
  for select to authenticated using (public.tem_acesso());
create policy "familias_select" on public.familias
  for select to authenticated using (public.tem_acesso());

-- instrumentos: o cadastro de membros também cria instrumentos (por isso membros.criar vale)
create policy "instrumentos_select" on public.instrumentos
  for select to authenticated using (public.tem_acesso());
create policy "instrumentos_insert" on public.instrumentos
  for insert to authenticated
  with check (public.tem_alguma_permissao(array['instrumentos.criar', 'membros.criar']));
create policy "instrumentos_update" on public.instrumentos
  for update to authenticated
  using (public.tem_permissao('instrumentos.editar'))
  with check (public.tem_permissao('instrumentos.editar'));
create policy "instrumentos_delete" on public.instrumentos
  for delete to authenticated
  using (public.tem_permissao('instrumentos.excluir'));

-- membros: a portaria e o dashboard também precisam ler a lista
create policy "membros_select" on public.membros
  for select to authenticated
  using (public.tem_alguma_permissao(array[
    'membros.visualizar', 'portaria.visualizar', 'portaria.registrar', 'dashboard.visualizar'
  ]));
create policy "membros_insert" on public.membros
  for insert to authenticated with check (public.tem_permissao('membros.criar'));
create policy "membros_update" on public.membros
  for update to authenticated
  using (public.tem_permissao('membros.editar'))
  with check (public.tem_permissao('membros.editar'));
create policy "membros_delete" on public.membros
  for delete to authenticated using (public.tem_permissao('membros.excluir'));

-- eventos: a portaria e o dashboard também precisam ler a lista
create policy "eventos_select" on public.eventos
  for select to authenticated
  using (public.tem_alguma_permissao(array[
    'eventos.visualizar', 'portaria.visualizar', 'portaria.registrar', 'dashboard.visualizar'
  ]));
create policy "eventos_insert" on public.eventos
  for insert to authenticated with check (public.tem_permissao('eventos.criar'));
create policy "eventos_update" on public.eventos
  for update to authenticated
  using (public.tem_permissao('eventos.editar'))
  with check (public.tem_permissao('eventos.editar'));
create policy "eventos_delete" on public.eventos
  for delete to authenticated using (public.tem_permissao('eventos.excluir'));

-- presencas (portaria)
create policy "presencas_select" on public.presencas
  for select to authenticated
  using (public.tem_alguma_permissao(array[
    'portaria.visualizar', 'portaria.registrar', 'dashboard.visualizar'
  ]));
create policy "presencas_insert" on public.presencas
  for insert to authenticated with check (public.tem_permissao('portaria.registrar'));
create policy "presencas_update" on public.presencas
  for update to authenticated
  using (public.tem_permissao('portaria.editar'))
  with check (public.tem_permissao('portaria.editar'));
create policy "presencas_delete" on public.presencas
  for delete to authenticated using (public.tem_permissao('portaria.excluir'));

-- ---------------------------------------------------------------------
-- 8) PRIVILÉGIOS DAS TABELAS
--    - anônimo: sem nenhum acesso às tabelas do sistema;
--    - cargos e famílias: somente leitura;
--    - membros: o qr_secret nunca é lido nem alterado pela aplicação (o revoke vem ANTES do grant);
--    - atualizações só nas colunas editáveis.
-- ---------------------------------------------------------------------
revoke all on public.cargos, public.familias, public.instrumentos,
              public.membros, public.eventos, public.presencas
  from anon;

revoke insert, update, delete on public.cargos, public.familias from authenticated;

revoke select on public.membros from authenticated;
grant select (id, nome, congregacao, cargo_id, data_nascimento, instrumento_id, status, data_cadastro)
  on public.membros to authenticated;

revoke update on public.membros from authenticated;
grant update (nome, congregacao, cargo_id, data_nascimento, instrumento_id, status)
  on public.membros to authenticated;

revoke update on public.instrumentos from authenticated;
grant update (nome, familia_id) on public.instrumentos to authenticated;

-- ---------------------------------------------------------------------
-- 9) RPC registrar_presenca_qr: agora só para usuários logados
--    (a permissão portaria.registrar é conferida pela política de INSERT de presencas)
-- ---------------------------------------------------------------------
revoke all on function public.registrar_presenca_qr(uuid, uuid) from anon;
grant execute on function public.registrar_presenca_qr(uuid, uuid) to authenticated;

commit;
