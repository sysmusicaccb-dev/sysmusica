-- =====================================================================
-- SysMúsica — Schema PostgreSQL (Supabase) — v4
--
-- Novidades desta versão:
--   * tabela FAMILIAS (Cordas, Madeiras, Metais, Teclas) com palavras-chave de classificação
--   * INSTRUMENTOS passa a ter familia_id; a família é definida AUTOMATICAMENTE pelo nome
--     do instrumento (gatilho no INSERT) e só um ADMINISTRADOR pode corrigi-la depois
--   * nomes de família ("Madeiras") deixam de ser aceitos como instrumento; os que já
--     existiam como instrumento são removidos (os membros ligados ficam sem instrumento)
--   * políticas passam a valer para 'anon' E 'authenticated' (usuário logado usa o papel authenticated)
--
-- Como aplicar: Supabase Dashboard > SQL Editor > colar tudo e executar (Run).
-- O script é IDEMPOTENTE e roda em uma única transação (begin/commit):
-- se qualquer passo falhar, nada é alterado. Pode ser executado várias vezes e
-- parte de qualquer versão anterior (v1, v2, v3 ou banco novo).
--
-- COMO CRIAR UM ADMINISTRADOR (uma vez):
--   1) Dashboard > Authentication > Users > Add user (e-mail + senha).
--   2) Rode no SQL Editor, trocando o e-mail:
--        update auth.users
--           set raw_app_meta_data = coalesce(raw_app_meta_data, '{}'::jsonb) || '{"papel": "admin"}'::jsonb
--         where email = 'seu-email@exemplo.com';
--   3) O usuário deve sair e entrar de novo para o login refletir o papel.
--   4) Recomendado: Authentication > Providers/Sign In > desativar novos cadastros (signups).
-- =====================================================================
begin;

-- ---------------------------------------------------------------------
-- 1) CARGOS — lista dinâmica de cargos/funções
--    permite_instrumento: indica se o cargo informa instrumento.
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
-- 2) FAMILIAS — famílias de instrumentos
--    palavras_chave: trechos que, se aparecerem no nome do instrumento, o classificam nesta
--    família. IMPORTANTE: escrever em minúsculas e SEM acentos (ex: 'orgao', 'oboe').
--    Em caso de várias famílias casarem, vence a palavra-chave mais longa
--    (ex: 'saxhorn' em Metais vence 'sax' em Madeiras).
--    Para criar/ajustar uma família: insert/update direto nesta tabela (SQL Editor).
-- ---------------------------------------------------------------------
create table if not exists public.familias (
  id             uuid   primary key default gen_random_uuid(),
  nome           text   not null unique,
  palavras_chave text[] not null default '{}'
);

insert into public.familias (nome, palavras_chave) values
  ('Cordas',   array['violino','viola','violoncelo','cello','contrabaixo','harpa']),
  ('Madeiras', array['flauta','flautim','piccolo','oboe','corne ingles','clarinete','clarone','fagote','contrafagote','saxofone','sax']),
  ('Metais',   array['trompete','corneta','flugelhorn','flugel','trompa','trombone','bombardino','eufonio','euphonium','tuba','bombardao','sousafone','saxhorn']),
  ('Teclas',   array['orgao','piano','teclado','acordeon','acordeao'])
on conflict (nome) do nothing;

-- ---------------------------------------------------------------------
-- 3) INSTRUMENTOS — lista dinâmica de instrumentos (alimentada pelo formulário de membros)
--    familia_id: família do instrumento (definida automaticamente; corrigível por administrador).
-- ---------------------------------------------------------------------
create table if not exists public.instrumentos (
  id         uuid primary key default gen_random_uuid(),
  nome       text not null unique,
  familia_id uuid references public.familias (id) on delete set null
);

-- Banco já existente (v3): garante a coluna nova familia_id
alter table public.instrumentos
  add column if not exists familia_id uuid references public.familias (id) on delete set null;

-- Reforço: não deixa cadastrar "Violino" e "violino" como instrumentos diferentes
create unique index if not exists instrumentos_nome_lower_unico
  on public.instrumentos (lower(nome));

-- ---------------------------------------------------------------------
-- 4) FUNÇÕES DE CLASSIFICAÇÃO
--    normalizar_texto: minúsculas, sem acentos e sem espaços repetidos.
--    inferir_familia_instrumento: devolve o id da família do nome informado (ou null).
--    ATENÇÃO: o frontend repete esta lógica em src/lib/familias.ts (para mostrar a família
--    antes de salvar). Se mudar o algoritmo aqui, mude lá também.
-- ---------------------------------------------------------------------
create or replace function public.normalizar_texto(p_texto text)
returns text
language sql
immutable
as $$
  select btrim(
    regexp_replace(
      translate(
        lower(coalesce(p_texto, '')),
        'áàâãäéèêëíìîïóòôõöúùûüç',
        'aaaaaeeeeiiiiooooouuuuc'
      ),
      '\s+', ' ', 'g'
    )
  )
$$;

create or replace function public.inferir_familia_instrumento(p_nome text)
returns uuid
language sql
stable
set search_path = public
as $$
  select f.id
  from public.familias f
  cross join lateral unnest(f.palavras_chave) as k(palavra)
  where k.palavra <> ''
    and public.normalizar_texto(p_nome) like '%' || k.palavra || '%'
  order by length(k.palavra) desc, f.nome
  limit 1
$$;

-- ---------------------------------------------------------------------
-- 5) MEMBROS — substitui a antiga tabela MUSICOS
--    qr_secret: segredo individual usado para validar o QR Code dinâmico.
--    data_nascimento e instrumento_id são opcionais.
-- ---------------------------------------------------------------------
create table if not exists public.membros (
  id              uuid        primary key default gen_random_uuid(),
  nome            text        not null,
  congregacao     text        not null,
  cargo_id        uuid        not null references public.cargos (id),
  data_nascimento date,
  instrumento_id  uuid        references public.instrumentos (id) on delete set null,
  status          text        not null default 'Ativo',   -- ex: Ativo, Inativo
  qr_secret       uuid        not null unique default gen_random_uuid(),
  data_cadastro   timestamptz not null default now()
);

-- 5.1) Banco já existente (v2): garante a coluna nova instrumento_id
alter table public.membros
  add column if not exists instrumento_id uuid references public.instrumentos (id) on delete set null;

-- 5.2) Migração v1 -> v4: dados antigos de MUSICOS (só roda se musicos ainda existir).
--      Os textos de "instrumento" viram registros em INSTRUMENTOS (sem duplicar por maiúsculas/espaços)
--      e cada membro migrado já é ligado ao seu instrumento. Mantém o mesmo id da pessoa.
do $$
begin
  if to_regclass('public.musicos') is not null then
    insert into public.instrumentos (nome)
    select distinct on (lower(btrim(m.instrumento))) btrim(m.instrumento)
    from public.musicos m
    where m.instrumento is not null and btrim(m.instrumento) <> ''
    order by lower(btrim(m.instrumento)), btrim(m.instrumento)
    on conflict do nothing;

    insert into public.membros (id, nome, congregacao, cargo_id, instrumento_id, status, data_cadastro)
    select m.id,
           m.nome,
           m.congregacao,
           (select c.id from public.cargos c where c.nome = 'Músico'),
           (select i.id from public.instrumentos i where lower(i.nome) = lower(btrim(m.instrumento))),
           m.status,
           m.data_cadastro
    from public.musicos m
    on conflict (id) do nothing;
  end if;
end
$$;

-- 5.3) Migração v2 -> v4: o texto livre "categoria_instrumento" vira "instrumento_id".
--      Só roda se a coluna antiga ainda existir; depois de copiar, ela é removida.
do $$
begin
  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name   = 'membros'
      and column_name  = 'categoria_instrumento'
  ) then
    insert into public.instrumentos (nome)
    select distinct on (lower(btrim(m.categoria_instrumento))) btrim(m.categoria_instrumento)
    from public.membros m
    where m.categoria_instrumento is not null and btrim(m.categoria_instrumento) <> ''
    order by lower(btrim(m.categoria_instrumento)), btrim(m.categoria_instrumento)
    on conflict do nothing;

    update public.membros m
       set instrumento_id = i.id
      from public.instrumentos i
     where m.instrumento_id is null
       and m.categoria_instrumento is not null
       and lower(i.nome) = lower(btrim(m.categoria_instrumento));

    alter table public.membros drop column categoria_instrumento;
  end if;
end
$$;

-- ---------------------------------------------------------------------
-- 6) EVENTOS — sem alteração estrutural
-- ---------------------------------------------------------------------
create table if not exists public.eventos (
  id           uuid        primary key default gen_random_uuid(),
  tipo         text        not null,                    -- ex: Ensaio, Culto
  data_evento  timestamptz not null,
  local        text        not null
);

-- ---------------------------------------------------------------------
-- 7) PRESENCAS — membro_id + hora_entrada / hora_saida
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

-- 7.1) Migração do formato v1 (coluna musico_id): troca por membro_id.
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

-- 7.2) Colunas de entrada/saída (em banco antigo, as linhas existentes recebem now())
alter table public.presencas add column if not exists hora_entrada timestamptz not null default now();
alter table public.presencas add column if not exists hora_saida   timestamptz;

-- ---------------------------------------------------------------------
-- 8) Remove a tabela antiga MUSICOS, mas só depois de conferir que tudo foi copiado.
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
-- 9) LIMPEZA E CLASSIFICAÇÃO DOS INSTRUMENTOS EXISTENTES
--    9.1) Remove "instrumentos" cujo nome é o nome de uma família (ex: "Madeiras", vindo do texto
--         livre antigo). Os membros ligados a eles ficam sem instrumento (on delete set null)
--         e precisam ter o instrumento real informado.
--    9.2) Classifica automaticamente os instrumentos que ainda estão sem família.
-- ---------------------------------------------------------------------
delete from public.instrumentos i
where exists (
  select 1 from public.familias f
  where public.normalizar_texto(f.nome) = public.normalizar_texto(i.nome)
);

update public.instrumentos
   set familia_id = public.inferir_familia_instrumento(nome)
 where familia_id is null;

-- ---------------------------------------------------------------------
-- 10) GATILHO: classificação automática no cadastro de instrumentos
--     - recusa nomes de família digitados como se fossem instrumento;
--     - se o cadastro não trouxer familia_id, define pela inferência do nome.
-- ---------------------------------------------------------------------
create or replace function public.instrumentos_definir_familia()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if exists (
    select 1 from public.familias f
    where public.normalizar_texto(f.nome) = public.normalizar_texto(new.nome)
  ) then
    raise exception '"%" é uma família de instrumentos. Informe o instrumento (ex.: Clarinete).', new.nome
      using errcode = 'check_violation';
  end if;

  if new.familia_id is null then
    new.familia_id := public.inferir_familia_instrumento(new.nome);
  end if;

  return new;
end;
$$;

drop trigger if exists trg_instrumentos_definir_familia on public.instrumentos;
create trigger trg_instrumentos_definir_familia
  before insert on public.instrumentos
  for each row execute function public.instrumentos_definir_familia();

-- ---------------------------------------------------------------------
-- 11) ÍNDICES
--     presencas_entrada_aberta_unica: no máximo UMA entrada sem saída por membro/evento.
--     Permite nova entrada depois de uma saída e protege a função registrar_presenca_qr
--     contra duas leituras simultâneas.
-- ---------------------------------------------------------------------
create unique index if not exists presencas_entrada_aberta_unica
  on public.presencas (membro_id, evento_id)
  where hora_saida is null;

create index if not exists idx_presencas_evento_id    on public.presencas (evento_id);
create index if not exists idx_presencas_membro_id    on public.presencas (membro_id);
create index if not exists idx_membros_cargo_id       on public.membros (cargo_id);
create index if not exists idx_membros_instrumento_id on public.membros (instrumento_id);
create index if not exists idx_instrumentos_familia_id on public.instrumentos (familia_id);

-- ---------------------------------------------------------------------
-- 12) RLS (Row Level Security) — FASE INICIAL
--     As políticas valem para 'anon' E 'authenticated': quem faz login passa a usar o papel
--     authenticated e, sem isso, deixaria de enxergar os dados.
--     cargos      : somente leitura
--     familias    : somente leitura (ajustes são feitos por SQL)
--     instrumentos: leitura e inserção (o formulário cria instrumentos novos);
--                   UPDATE (corrigir a família) somente para ADMINISTRADOR
--     membros / eventos / presencas: leitura e inserção
--     Sem políticas de DELETE: essa operação fica BLOQUEADA.
-- ---------------------------------------------------------------------
alter table public.cargos        enable row level security;
alter table public.familias      enable row level security;
alter table public.instrumentos  enable row level security;
alter table public.membros       enable row level security;
alter table public.eventos       enable row level security;
alter table public.presencas     enable row level security;

-- Remove políticas anteriores (mantém o script reexecutável)
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

-- cargos
create policy "anon_select_cargos"       on public.cargos
  for select to anon, authenticated using (true);

-- familias
create policy "anon_select_familias"     on public.familias
  for select to anon, authenticated using (true);

-- instrumentos
create policy "anon_select_instrumentos" on public.instrumentos
  for select to anon, authenticated using (true);
create policy "anon_insert_instrumentos" on public.instrumentos
  for insert to anon, authenticated with check (true);

-- Corrigir a família de um instrumento: só quem tem papel 'admin' no token (app_metadata),
-- que só pode ser definido pelo painel/SQL — o usuário não consegue se promover sozinho.
create policy "admin_update_instrumentos" on public.instrumentos
  for update to authenticated
  using      ((select auth.jwt() -> 'app_metadata' ->> 'papel') = 'admin')
  with check ((select auth.jwt() -> 'app_metadata' ->> 'papel') = 'admin');

-- membros
create policy "anon_select_membros"      on public.membros
  for select to anon, authenticated using (true);
create policy "anon_insert_membros"      on public.membros
  for insert to anon, authenticated with check (true);

-- eventos
create policy "anon_select_eventos"      on public.eventos
  for select to anon, authenticated using (true);
create policy "anon_insert_eventos"      on public.eventos
  for insert to anon, authenticated with check (true);

-- presencas
create policy "anon_select_presencas"    on public.presencas
  for select to anon, authenticated using (true);
create policy "anon_insert_presencas"    on public.presencas
  for insert to anon, authenticated with check (true);

-- ---------------------------------------------------------------------
-- 13) PRIVILÉGIOS POR COLUNA
--     a) qr_secret: a leitura de membros NÃO inclui essa coluna (nem para anon, nem para
--        authenticated), senão qualquer visitante copiaria os segredos de todos. Consequência:
--        "select *" em membros falha; o frontend lista as colunas (COLUNAS_MEMBRO_PUBLICO em
--        src/types/database.ts deve ficar igual a esta lista). O revoke vem ANTES do grant.
--     b) instrumentos: o único campo que pode ser alterado é familia_id (e só passa pela política
--        de administrador acima).
-- ---------------------------------------------------------------------
revoke select on public.membros from anon, authenticated;
grant select (id, nome, congregacao, cargo_id, data_nascimento, instrumento_id, status, data_cadastro)
  on public.membros to anon, authenticated;

revoke update on public.instrumentos from anon, authenticated;
grant update (familia_id) on public.instrumentos to authenticated;

-- ---------------------------------------------------------------------
-- 14) RPC registrar_presenca_qr — entrada via QR Code
--     Se já existe entrada SEM hora_saida para o membro neste evento, levanta exceção
--     (evita duplicidade). Caso contrário, insere a presença e devolve o registro criado.
--     security invoker (padrão): executa com as permissões de quem chama, respeitando o RLS.
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
