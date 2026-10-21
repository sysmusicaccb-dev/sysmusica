-- 0041 — Parte 8: Tipos de evento, Hinos e Dados do Ensaio
--
-- O QUE ESTA MIGRAÇÃO FAZ
--   A) Tipo do Evento vira um cadastro (tipos_evento). O evento ganha eventos.tipo_evento_id; a coluna de texto
--      eventos.tipo continua existindo (relatórios, painel e portaria a usam) e é preenchida SOZINHA com o nome do
--      tipo escolhido. Eventos antigos "Ensaio Local" e "Ensaio Regional" são ligados ao tipo automaticamente;
--      os demais (ex.: "Ensaio") continuam como estão até alguém editar o evento e escolher o tipo.
--      Cada tipo diz se usa a tela "Dados do Ensaio" e em qual modelo (LOCAL, REGIONAL ou nenhum).
--   B) Hinos: lista editável (hinário 5 = categoria HINO; corinhos = categoria CORO, exibidos como "Coro 1", "Coro 2"...).
--   C) Dados do Ensaio (só ensaios Local e Regional): quem atendeu, hino de abertura, palavra (só no Regional),
--      de 1 a 3 encarregados (nome + Cidade/UF) e os hinos executados (sem repetir; o de abertura fica fora da lista).
--   D) Permissões novas (só o Administrador recebe; os demais grupos são liberados em Grupos e permissões):
--        tipoevento.visualizar|criar|editar|excluir, hinos.visualizar|criar|editar|excluir,
--        ensaio.visualizar, ensaio.registrar (preencher os Dados do Ensaio).
--   E) Backup (backup_aplicar) passa a conhecer as tabelas novas; a Auditoria registra tipos, hinos e ensaios.
--
-- SEGURANÇA: as tabelas novas têm RLS ligado e NENHUM acesso direto para anon/authenticated; tudo passa por
-- funções (security definer, search_path fixo) que conferem permissão e abrangência.
begin;
set local check_function_bodies = off;

do $$
begin
  if to_regclass('public.eventos') is null or to_regclass('public.permissoes') is null
     or to_regprocedure('public.exigir_permissao(text)') is null
     or to_regprocedure('public.evento_na_abrangencia(uuid)') is null
     or to_regprocedure('public.registrar_auditoria(text, text, uuid, jsonb)') is null
     or to_regprocedure('public.auditar_tabela()') is null
     or to_regprocedure('public.normalizar_texto(text)') is null
     or to_regprocedure('public.portaria_encerrada(timestamptz, timestamptz)') is null
     or to_regprocedure('public.backup_aplicar(uuid, jsonb, jsonb)') is null then
    raise exception 'Aplique primeiro as migrações até a 0040. Nada foi alterado.';
  end if;
  if to_regclass('public.tipos_evento') is not null then
    raise exception 'A migração 0041 já foi aplicada. Nada foi alterado.';
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 1. Funções de apoio
-- ---------------------------------------------------------------------------
-- Tira espaços das pontas e repetidos; vazio vira nulo.
create or replace function public.limpar_espacos(p_texto text)
returns text language sql immutable set search_path to 'public'
as $$ select nullif(btrim(regexp_replace(coalesce(p_texto, ''), '\s+', ' ', 'g')), '') $$;

-- Como o hino aparece para as pessoas: hino do hinário = "002"; corinho = "Coro 3".
create or replace function public.rotulo_hino(p_categoria text, p_numero integer)
returns text language sql immutable set search_path to 'public'
as $$ select case when p_categoria = 'CORO' then 'Coro ' || p_numero::text else lpad(p_numero::text, 3, '0') end $$;

-- ---------------------------------------------------------------------------
-- 2. Tipos de evento
-- ---------------------------------------------------------------------------
create table public.tipos_evento (
  id            uuid primary key default gen_random_uuid(),
  nome          text not null check (char_length(btrim(nome)) between 3 and 60),
  descricao     text check (descricao is null or char_length(descricao) <= 200),
  -- Qual modelo da tela "Dados do Ensaio" o tipo usa (nulo = o tipo não usa essa tela)
  modelo_ensaio text check (modelo_ensaio is null or modelo_ensaio in ('LOCAL', 'REGIONAL')),
  ativo         boolean not null default true,
  ordem         integer not null default 100,   -- só organiza a lista (os 8 iniciais vêm de 1 a 8)
  criado_em     timestamptz not null default now(),
  atualizado_em timestamptz not null default now()
);
create unique index tipos_evento_nome_unico on public.tipos_evento (lower(btrim(nome)));

alter table public.tipos_evento enable row level security;
revoke all on public.tipos_evento from public, anon, authenticated;

insert into public.tipos_evento (nome, descricao, modelo_ensaio, ordem) values
  ('Ensaio Regional',  'Ensaio do ministério regional',        'REGIONAL', 1),
  ('Ensaio Local',     'Ensaio do ministério local',           'LOCAL',    2),
  ('Reunião Musical',  'Reunião de músicos e organistas',      null,       3),
  ('Culto Oficial',    'Culto com participação musical',       null,       4),
  ('Treinamento',      'Treinamento de músicos',               null,       5),
  ('Congresso',        'Congresso ou convenção',               null,       6),
  ('Visita Oficial',   'Visita de irmãos oficiais',            null,       7),
  ('Outro',            'Outros tipos de evento',               null,       8);

-- O evento aponta para o tipo; eventos.tipo (texto) é mantido igual ao nome do tipo por um gatilho
alter table public.eventos add column tipo_evento_id uuid references public.tipos_evento(id);
create index eventos_tipo_evento_idx on public.eventos (tipo_evento_id);
-- Colunas liberadas uma a uma (o cliente lê com select("*") e a edição só toca nas colunas permitidas)
grant select (tipo_evento_id) on public.eventos to authenticated;
grant insert (tipo_evento_id) on public.eventos to authenticated;
grant update (tipo_evento_id) on public.eventos to authenticated;

create or replace function public.eventos_sincroniza_tipo()
returns trigger
language plpgsql security definer set search_path to 'public'
as $$
declare
  v public.tipos_evento;
begin
  if new.tipo_evento_id is null then
    return new;   -- evento antigo, ainda sem tipo cadastrado: o texto de eventos.tipo é mantido
  end if;
  if tg_op = 'UPDATE' and new.tipo_evento_id is not distinct from old.tipo_evento_id then
    return new;   -- o tipo não mudou
  end if;
  select * into v from public.tipos_evento t where t.id = new.tipo_evento_id;
  if not found then
    raise exception 'Tipo de evento não encontrado.';
  end if;
  -- Tipo desativado não pode ser escolhido de novo (a restauração de backup não é barrada)
  if not v.ativo and coalesce(current_setting('sysmusica.restaurando', true), '') = '' then
    raise exception 'O tipo de evento "%" está desativado. Escolha outro tipo.', v.nome;
  end if;
  new.tipo := v.nome;
  return new;
end;
$$;

create trigger trg_eventos_sincroniza_tipo before insert or update on public.eventos
  for each row execute function public.eventos_sincroniza_tipo();

-- Liga os eventos antigos cujo texto é igual ao nome de um tipo (ignorando acento e maiúsculas)
select set_config('sysmusica.restaurando', 'sim', true);
update public.eventos e
   set tipo_evento_id = t.id
  from public.tipos_evento t
 where e.tipo_evento_id is null
   and public.normalizar_texto(btrim(e.tipo)) = public.normalizar_texto(t.nome);
select set_config('sysmusica.restaurando', '', true);

-- ---------------------------------------------------------------------------
-- 3. Hinos
-- ---------------------------------------------------------------------------
create table public.hinos (
  id            uuid primary key default gen_random_uuid(),
  categoria     text not null check (categoria in ('HINO', 'CORO')),
  numero        integer not null check (numero between 1 and 9999),
  nome          text not null check (char_length(btrim(nome)) between 2 and 150),   -- o título do hino
  ativo         boolean not null default true,
  criado_em     timestamptz not null default now(),
  atualizado_em timestamptz not null default now(),
  constraint hinos_categoria_numero_unico unique (categoria, numero)
);
alter table public.hinos enable row level security;
revoke all on public.hinos from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 4. Dados do Ensaio
-- ---------------------------------------------------------------------------
create table public.dados_ensaio (
  id               uuid primary key default gen_random_uuid(),
  evento_id        uuid not null unique references public.eventos(id),
  atende_cargo     text not null check (atende_cargo in ('ANCIAO', 'DIACONO', 'COOPERADOR_OFICIO', 'COOPERADOR_RJM')),
  atende_nome      text not null check (char_length(btrim(atende_nome)) between 3 and 120),
  palavra          text check (palavra is null or char_length(palavra) <= 500),   -- só no ensaio Regional
  hino_abertura_id uuid not null references public.hinos(id),
  criado_por       uuid,
  criado_em        timestamptz not null default now(),
  atualizado_por   uuid,
  atualizado_em    timestamptz not null default now()
);

create table public.dados_ensaio_encarregados (
  id              uuid primary key default gen_random_uuid(),
  dados_ensaio_id uuid not null references public.dados_ensaio(id) on delete cascade,
  ordem           smallint not null check (ordem between 1 and 3),   -- no máximo 3 encarregados
  nome            text not null check (char_length(btrim(nome)) between 3 and 120),
  cidade_uf       text not null check (cidade_uf ~ '^.{2,}-[A-Z]{2}$'),   -- ex.: "São Paulo-SP"
  unique (dados_ensaio_id, ordem)
);

create table public.dados_ensaio_hinos (
  id              uuid primary key default gen_random_uuid(),
  dados_ensaio_id uuid not null references public.dados_ensaio(id) on delete cascade,
  hino_id         uuid not null references public.hinos(id),
  ordem           smallint not null check (ordem between 1 and 100),
  unique (dados_ensaio_id, hino_id),   -- o mesmo hino não repete no ensaio
  unique (dados_ensaio_id, ordem)
);

alter table public.dados_ensaio enable row level security;
alter table public.dados_ensaio_encarregados enable row level security;
alter table public.dados_ensaio_hinos enable row level security;
revoke all on public.dados_ensaio, public.dados_ensaio_encarregados, public.dados_ensaio_hinos
  from public, anon, authenticated;

-- O hino de abertura NÃO conta entre os hinos executados: o banco impede o mesmo hino nos dois lugares
create or replace function public.dados_ensaio_hino_nao_e_abertura()
returns trigger language plpgsql security definer set search_path to 'public'
as $$
begin
  if exists (select 1 from public.dados_ensaio d where d.id = new.dados_ensaio_id and d.hino_abertura_id = new.hino_id) then
    raise exception 'O hino de abertura não pode estar entre os hinos executados.';
  end if;
  return new;
end;
$$;
create trigger trg_dados_ensaio_hinos_abertura before insert or update on public.dados_ensaio_hinos
  for each row execute function public.dados_ensaio_hino_nao_e_abertura();

create or replace function public.dados_ensaio_abertura_nao_e_executado()
returns trigger language plpgsql security definer set search_path to 'public'
as $$
begin
  if exists (select 1 from public.dados_ensaio_hinos h where h.dados_ensaio_id = new.id and h.hino_id = new.hino_abertura_id) then
    raise exception 'O hino de abertura não pode estar entre os hinos executados.';
  end if;
  return new;
end;
$$;
create trigger trg_dados_ensaio_abertura before update of hino_abertura_id on public.dados_ensaio
  for each row execute function public.dados_ensaio_abertura_nao_e_executado();

-- Auditoria: tipos e hinos pela função comum; o ensaio registra uma linha própria (com encarregados e hinos)
create trigger trg_auditar after insert or update or delete on public.tipos_evento
  for each row execute function public.auditar_tabela();
create trigger trg_auditar after insert or update or delete on public.hinos
  for each row execute function public.auditar_tabela();

-- ---------------------------------------------------------------------------
-- 5. Permissões (iguais a CATALOGO_PERMISSOES em src/lib/permissoes.ts). Só o Administrador recebe;
--    os demais grupos são liberados na tela Grupos e permissões.
-- ---------------------------------------------------------------------------
insert into public.permissoes (codigo, modulo, acao, descricao) values
  ('tipoevento.visualizar', 'Tipos de evento', 'Visualizar', 'Ver a lista de tipos de evento'),
  ('tipoevento.criar',      'Tipos de evento', 'Criar',      'Cadastrar tipos de evento'),
  ('tipoevento.editar',     'Tipos de evento', 'Editar',     'Editar, ativar e desativar tipos de evento'),
  ('tipoevento.excluir',    'Tipos de evento', 'Excluir',    'Excluir tipos de evento que nunca foram usados'),
  ('hinos.visualizar',        'Hinos',           'Visualizar', 'Ver a lista de hinos'),
  ('hinos.criar',             'Hinos',           'Criar',      'Cadastrar e importar hinos'),
  ('hinos.editar',            'Hinos',           'Editar',     'Editar, ativar e desativar hinos'),
  ('hinos.excluir',           'Hinos',           'Excluir',    'Excluir hinos que nunca foram usados'),
  ('ensaio.visualizar',       'Dados do Ensaio', 'Visualizar', 'Ver os dados dos ensaios Local e Regional'),
  ('ensaio.registrar',        'Dados do Ensaio', 'Preencher',  'Preencher e alterar os Dados do Ensaio (quem atendeu, palavra, encarregados e hinos)')
on conflict (codigo) do update
  set modulo = excluded.modulo, acao = excluded.acao, descricao = excluded.descricao;

insert into public.grupo_permissoes (grupo_id, permissao_codigo)
select g.id, p.codigo
  from public.grupos g
  cross join public.permissoes p
 where g.sistema and g.nome = 'Administrador'
   and p.codigo in ('tipoevento.visualizar', 'tipoevento.criar', 'tipoevento.editar', 'tipoevento.excluir',
                    'hinos.visualizar', 'hinos.criar', 'hinos.editar', 'hinos.excluir',
                    'ensaio.visualizar', 'ensaio.registrar')
on conflict do nothing;

-- ---------------------------------------------------------------------------
-- 6. Funções — Tipos de evento
-- ---------------------------------------------------------------------------
create or replace function public.listar_tipos_evento()
returns table (id uuid, nome text, descricao text, modelo_ensaio text, ativo boolean, em_uso bigint)
language plpgsql stable security definer set search_path to 'public'
as $$
begin
  -- Quem cadastra ou edita eventos precisa ver a lista para escolher o tipo
  if not public.tem_alguma_permissao(array['tipoevento.visualizar', 'eventos.criar', 'eventos.editar']) then
    raise exception 'Você não tem permissão para esta operação.' using errcode = '42501';
  end if;
  return query
    select t.id, t.nome, t.descricao, t.modelo_ensaio, t.ativo,
           (select count(*) from public.eventos e where e.tipo_evento_id = t.id and e.excluido_em is null)
      from public.tipos_evento t
     order by t.ordem, lower(t.nome);
end;
$$;

create or replace function public.salvar_tipo_evento(p_id uuid, p_dados jsonb)
returns uuid
language plpgsql security definer set search_path to 'public'
as $$
declare
  v_nome   text := public.limpar_espacos(p_dados ->> 'nome');
  v_desc   text := public.limpar_espacos(p_dados ->> 'descricao');
  v_modelo text := nullif(btrim(coalesce(p_dados ->> 'modelo_ensaio', '')), '');
  v_ativo  boolean := coalesce((p_dados ->> 'ativo')::boolean, true);
  v_id     uuid;
  v_ant    public.tipos_evento;
begin
  if p_id is null then
    perform public.exigir_permissao('tipoevento.criar');
  else
    perform public.exigir_permissao('tipoevento.editar');
  end if;

  if v_nome is null or char_length(v_nome) < 3 then
    raise exception 'Informe o nome do tipo de evento (mínimo de 3 caracteres).';
  end if;
  if char_length(v_nome) > 60 then
    raise exception 'O nome pode ter no máximo 60 caracteres.';
  end if;
  if v_desc is not null and char_length(v_desc) > 200 then
    raise exception 'A descrição pode ter no máximo 200 caracteres.';
  end if;
  if v_modelo is not null and v_modelo not in ('LOCAL', 'REGIONAL') then
    raise exception 'Modelo de Dados do Ensaio inválido.';
  end if;
  if exists (select 1 from public.tipos_evento t
              where public.normalizar_texto(t.nome) = public.normalizar_texto(v_nome)
                and (p_id is null or t.id <> p_id)) then
    raise exception 'Já existe um tipo de evento com este nome.';
  end if;

  if p_id is null then
    insert into public.tipos_evento (nome, descricao, modelo_ensaio, ativo)
    values (v_nome, v_desc, v_modelo, v_ativo)
    returning id into v_id;
  else
    select * into v_ant from public.tipos_evento t where t.id = p_id for update;
    if not found then
      raise exception 'Tipo de evento não encontrado.';
    end if;
    -- Mudar o modelo de um tipo que já tem ensaios preenchidos deixaria os dados sem sentido
    if v_ant.modelo_ensaio is distinct from v_modelo
       and exists (select 1 from public.dados_ensaio d join public.eventos e on e.id = d.evento_id
                    where e.tipo_evento_id = p_id) then
      raise exception 'Este tipo já tem Dados do Ensaio preenchidos: não é possível mudar o modelo.';
    end if;
    update public.tipos_evento
       set nome = v_nome, descricao = v_desc, modelo_ensaio = v_modelo, ativo = v_ativo, atualizado_em = now()
     where id = p_id;
    v_id := p_id;
    -- Renomear o tipo atualiza o texto dos eventos dele (ação do sistema: não passa pelas travas de data
    -- e não gera uma linha de auditoria por evento; a alteração do tipo já fica registrada)
    if v_ant.nome is distinct from v_nome then
      perform set_config('sysmusica.restaurando', 'sim', true);
      update public.eventos set tipo = v_nome where tipo_evento_id = p_id and tipo is distinct from v_nome;
      perform set_config('sysmusica.restaurando', '', true);
    end if;
  end if;
  return v_id;
exception when unique_violation then
  raise exception 'Já existe um tipo de evento com este nome.';
end;
$$;

create or replace function public.excluir_tipo_evento(p_id uuid)
returns void
language plpgsql security definer set search_path to 'public'
as $$
begin
  perform public.exigir_permissao('tipoevento.excluir');
  if exists (select 1 from public.eventos e where e.tipo_evento_id = p_id) then
    raise exception 'Este tipo já foi usado em eventos e não pode ser excluído. Desative-o para que não seja mais escolhido.';
  end if;
  delete from public.tipos_evento where id = p_id;
  if not found then
    raise exception 'Tipo de evento não encontrado.';
  end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- 7. Funções — Hinos
-- ---------------------------------------------------------------------------
create or replace function public.listar_hinos()
returns table (id uuid, categoria text, numero integer, nome text, ativo boolean, em_uso bigint)
language plpgsql stable security definer set search_path to 'public'
as $$
begin
  if not public.tem_alguma_permissao(array['hinos.visualizar', 'ensaio.visualizar', 'ensaio.registrar']) then
    raise exception 'Você não tem permissão para esta operação.' using errcode = '42501';
  end if;
  return query
    select h.id, h.categoria, h.numero, h.nome, h.ativo,
           ((select count(*) from public.dados_ensaio_hinos x where x.hino_id = h.id)
          + (select count(*) from public.dados_ensaio d where d.hino_abertura_id = h.id))
      from public.hinos h
     order by (h.categoria = 'CORO'), h.numero;
end;
$$;

create or replace function public.salvar_hino(p_id uuid, p_dados jsonb)
returns uuid
language plpgsql security definer set search_path to 'public'
as $$
declare
  v_cat    text := upper(coalesce(p_dados ->> 'categoria', ''));
  v_num    integer;
  v_nome   text := public.limpar_espacos(p_dados ->> 'nome');
  v_ativo  boolean := coalesce((p_dados ->> 'ativo')::boolean, true);
  v_id     uuid;
begin
  if p_id is null then
    perform public.exigir_permissao('hinos.criar');
  else
    perform public.exigir_permissao('hinos.editar');
  end if;

  if v_cat not in ('HINO', 'CORO') then
    raise exception 'Escolha se é hino ou coro.';
  end if;
  begin
    v_num := (p_dados ->> 'numero')::integer;
  exception when others then
    v_num := null;
  end;
  if v_num is null or v_num < 1 or v_num > 9999 then
    raise exception 'Informe o número do hino (de 1 a 9999).';
  end if;
  if v_nome is null or char_length(v_nome) < 2 then
    raise exception 'Informe o título do hino.';
  end if;
  if char_length(v_nome) > 150 then
    raise exception 'O título pode ter no máximo 150 caracteres.';
  end if;

  if p_id is null then
    insert into public.hinos (categoria, numero, nome, ativo) values (v_cat, v_num, v_nome, v_ativo)
    returning id into v_id;
  else
    update public.hinos
       set categoria = v_cat, numero = v_num, nome = v_nome, ativo = v_ativo, atualizado_em = now()
     where id = p_id
    returning id into v_id;
    if v_id is null then
      raise exception 'Hino não encontrado.';
    end if;
  end if;
  return v_id;
exception when unique_violation then
  raise exception 'Já existe % com este número.', case when v_cat = 'CORO' then 'um coro' else 'um hino' end;
end;
$$;

create or replace function public.excluir_hino(p_id uuid)
returns void
language plpgsql security definer set search_path to 'public'
as $$
begin
  perform public.exigir_permissao('hinos.excluir');
  if exists (select 1 from public.dados_ensaio_hinos x where x.hino_id = p_id)
     or exists (select 1 from public.dados_ensaio d where d.hino_abertura_id = p_id) then
    raise exception 'Este hino já foi usado em um ensaio e não pode ser excluído. Desative-o para que não seja mais escolhido.';
  end if;
  delete from public.hinos where id = p_id;
  if not found then
    raise exception 'Hino não encontrado.';
  end if;
end;
$$;

-- Importa uma lista de hinos de uma vez: [{"categoria":"HINO","numero":1,"nome":"..."}, ...]
-- Só ACRESCENTA: número que já existe é ignorado (para corrigir um título, use Editar).
create or replace function public.importar_hinos(p_itens jsonb)
returns jsonb
language plpgsql security definer set search_path to 'public'
as $$
declare
  v_item   jsonb;
  v_total  integer;
  v_novos  integer;
  v_cat    text;
  v_num    integer;
  v_nome   text;
begin
  perform public.exigir_permissao('hinos.criar');
  if p_itens is null or jsonb_typeof(p_itens) <> 'array' or jsonb_array_length(p_itens) = 0 then
    raise exception 'Nenhum hino para importar.';
  end if;
  v_total := jsonb_array_length(p_itens);
  if v_total > 2000 then
    raise exception 'Importe no máximo 2000 hinos por vez.';
  end if;

  for v_item in select * from jsonb_array_elements(p_itens) loop
    v_cat := upper(coalesce(v_item ->> 'categoria', ''));
    begin
      v_num := (v_item ->> 'numero')::integer;
    exception when others then
      v_num := null;
    end;
    v_nome := public.limpar_espacos(v_item ->> 'nome');
    if v_cat not in ('HINO', 'CORO') or v_num is null or v_num < 1 or v_num > 9999
       or v_nome is null or char_length(v_nome) < 2 or char_length(v_nome) > 150 then
      raise exception 'Item inválido na lista: %', left(v_item::text, 80);
    end if;
  end loop;

  if exists (select 1 from jsonb_to_recordset(p_itens) as x(categoria text, numero integer, nome text)
              group by upper(x.categoria), x.numero having count(*) > 1) then
    raise exception 'A lista tem números repetidos.';
  end if;

  -- Uma única linha de auditoria para a importação (não uma por hino)
  perform set_config('sysmusica.restaurando', 'sim', true);
  insert into public.hinos (categoria, numero, nome)
  select upper(x.categoria), x.numero, public.limpar_espacos(x.nome)
    from jsonb_to_recordset(p_itens) as x(categoria text, numero integer, nome text)
  on conflict (categoria, numero) do nothing;
  get diagnostics v_novos = row_count;
  perform set_config('sysmusica.restaurando', '', true);

  perform public.registrar_auditoria('hinos_importados', 'hino', null,
            jsonb_build_object('rotulo', 'Importação de hinos', 'recebidos', v_total, 'novos', v_novos));
  return jsonb_build_object('recebidos', v_total, 'novos', v_novos, 'ja_existiam', v_total - v_novos);
end;
$$;

-- ---------------------------------------------------------------------------
-- 8. Funções — Dados do Ensaio
-- ---------------------------------------------------------------------------
-- Texto do cargo de quem atendeu (para o histórico de auditoria)
create or replace function public.rotulo_cargo_ensaio(p_cargo text)
returns text language sql immutable set search_path to 'public'
as $$ select case p_cargo
  when 'ANCIAO' then 'Ancião'
  when 'DIACONO' then 'Diácono'
  when 'COOPERADOR_OFICIO' then 'Cooperador do Ofício Ministerial'
  when 'COOPERADOR_RJM' then 'Cooperador da Reunião de Jovens e Menores'
  else p_cargo end $$;

-- Resumo em texto simples do ensaio (usado só no histórico de auditoria)
create or replace function public.ensaio_resumo(p_dados_id uuid)
returns jsonb
language sql stable security definer set search_path to 'public'
as $$
  select jsonb_build_object(
    'atende', d.atende_nome || ' (' || public.rotulo_cargo_ensaio(d.atende_cargo) || ')',
    'palavra', d.palavra,
    'hino_abertura', public.rotulo_hino(h.categoria, h.numero) || ' - ' || h.nome,
    'encarregados', (select string_agg(e.nome || ' (' || e.cidade_uf || ')', '; ' order by e.ordem)
                       from public.dados_ensaio_encarregados e where e.dados_ensaio_id = d.id),
    'hinos', (select string_agg(public.rotulo_hino(x.categoria, x.numero), ', ' order by dh.ordem)
                from public.dados_ensaio_hinos dh join public.hinos x on x.id = dh.hino_id
               where dh.dados_ensaio_id = d.id))
    from public.dados_ensaio d join public.hinos h on h.id = d.hino_abertura_id
   where d.id = p_dados_id
$$;
revoke all on function public.ensaio_resumo(uuid) from public, anon, authenticated;

-- Ensaios (Local e Regional) que a pessoa pode ver: de 30 dias atrás a 2 dias à frente, do mais próximo de agora
create or replace function public.eventos_para_ensaio()
returns table (id uuid, tipo text, modelo_ensaio text, data_evento timestamptz, local_evento text,
               cidade text, casa_oracao_nome text, preenchido boolean, encerrado boolean)
language plpgsql stable security definer set search_path to 'public'
as $$
begin
  if not public.tem_alguma_permissao(array['ensaio.visualizar', 'ensaio.registrar']) then
    raise exception 'Você não tem permissão para esta operação.' using errcode = '42501';
  end if;
  return query
    select e.id, e.tipo, t.modelo_ensaio, e.data_evento, e.local, e.cidade, c.nome,
           exists (select 1 from public.dados_ensaio d where d.evento_id = e.id),
           public.portaria_encerrada(e.data_evento)
      from public.eventos e
      join public.tipos_evento t on t.id = e.tipo_evento_id and t.modelo_ensaio is not null
      left join public.casas_oracao c on c.id = e.casa_oracao_id
     where e.excluido_em is null
       and e.cancelado_em is null
       and public.evento_na_abrangencia(e.id)
       and e.data_evento between now() - interval '30 days' and now() + interval '2 days'
     order by abs(extract(epoch from (e.data_evento - now())))
     limit 40;
end;
$$;

create or replace function public.obter_dados_ensaio(p_evento_id uuid)
returns jsonb
language plpgsql stable security definer set search_path to 'public'
as $$
declare
  v_e        record;
  v_d        public.dados_ensaio;
  v_admin    boolean;
  v_iniciado boolean;
  v_encerr   boolean;
begin
  if not public.tem_alguma_permissao(array['ensaio.visualizar', 'ensaio.registrar']) then
    raise exception 'Você não tem permissão para esta operação.' using errcode = '42501';
  end if;

  select e.id, e.tipo, e.data_evento, e.local, e.cidade, e.cancelado_em, t.modelo_ensaio, c.nome as casa
    into v_e
    from public.eventos e
    left join public.tipos_evento t on t.id = e.tipo_evento_id
    left join public.casas_oracao c on c.id = e.casa_oracao_id
   where e.id = p_evento_id and e.excluido_em is null;
  if not found then
    raise exception 'Evento não encontrado.';
  end if;
  if not public.evento_na_abrangencia(p_evento_id) then
    raise exception 'Este evento está fora da sua abrangência.' using errcode = '42501';
  end if;
  if v_e.modelo_ensaio is null then
    raise exception 'Este evento não é um ensaio Local ou Regional.';
  end if;

  v_admin    := public.tem_permissao('eventos.cancelar');
  v_iniciado := now() >= v_e.data_evento - interval '2 hours';
  v_encerr   := public.portaria_encerrada(v_e.data_evento);
  select * into v_d from public.dados_ensaio d where d.evento_id = p_evento_id;

  return jsonb_build_object(
    'evento', jsonb_build_object(
      'id', v_e.id, 'tipo', v_e.tipo, 'modelo_ensaio', v_e.modelo_ensaio, 'data_evento', v_e.data_evento,
      'local', v_e.local, 'cidade', v_e.cidade, 'casa_oracao', v_e.casa,
      'cancelado', v_e.cancelado_em is not null, 'iniciado', v_iniciado, 'encerrado', v_encerr),
    -- A tela só deixa editar quando o banco deixaria salvar
    'pode_editar', public.tem_permissao('ensaio.registrar') and v_e.cancelado_em is null
                   and (v_admin or (v_iniciado and not v_encerr)),
    'dados', case when v_d.id is null then null else jsonb_build_object(
      'atende_cargo', v_d.atende_cargo, 'atende_nome', v_d.atende_nome, 'palavra', v_d.palavra,
      'hino_abertura_id', v_d.hino_abertura_id, 'atualizado_em', v_d.atualizado_em,
      'encarregados', (select coalesce(jsonb_agg(jsonb_build_object('ordem', x.ordem, 'nome', x.nome, 'cidade_uf', x.cidade_uf)
                                                 order by x.ordem), '[]'::jsonb)
                         from public.dados_ensaio_encarregados x where x.dados_ensaio_id = v_d.id),
      'hinos', (select coalesce(jsonb_agg(h.hino_id order by h.ordem), '[]'::jsonb)
                  from public.dados_ensaio_hinos h where h.dados_ensaio_id = v_d.id)) end);
end;
$$;

create or replace function public.salvar_dados_ensaio(p_evento_id uuid, p_dados jsonb)
returns uuid
language plpgsql security definer set search_path to 'public'
as $$
declare
  v_uid      uuid := (select auth.uid());
  v_e        record;
  v_d        public.dados_ensaio;
  v_admin    boolean;
  v_cargo    text := upper(coalesce(p_dados ->> 'atende_cargo', ''));
  v_nome     text := public.limpar_espacos(p_dados ->> 'atende_nome');
  v_palavra  text := nullif(btrim(coalesce(p_dados ->> 'palavra', '')), '');
  v_abertura uuid;
  v_enc      jsonb := coalesce(p_dados -> 'encarregados', '[]'::jsonb);
  v_hinos    jsonb := coalesce(p_dados -> 'hinos', '[]'::jsonb);
  v_item     jsonb;
  v_ordem    integer;
  v_n        integer;
  v_nomeenc  text;
  v_cidade   text;
  v_id       uuid;
  v_antes    jsonb;
  v_depois   jsonb;
  v_mud      jsonb;
  v_ufs      text[] := array['AC','AL','AP','AM','BA','CE','DF','ES','GO','MA','MT','MS','MG','PA','PB','PR','PE','PI','RJ','RN','RS','RO','RR','SC','SP','SE','TO'];
begin
  perform public.exigir_permissao('ensaio.registrar');
  -- Duas pessoas salvando o mesmo ensaio ao mesmo tempo: a segunda espera a primeira
  perform pg_advisory_xact_lock(hashtextextended('ensaio:' || p_evento_id::text, 0));

  select e.id, e.tipo, e.local, e.data_evento, e.cancelado_em, t.modelo_ensaio
    into v_e
    from public.eventos e
    left join public.tipos_evento t on t.id = e.tipo_evento_id
   where e.id = p_evento_id and e.excluido_em is null;
  if not found then
    raise exception 'Evento não encontrado.';
  end if;
  if not public.evento_na_abrangencia(p_evento_id) then
    raise exception 'Este evento está fora da sua abrangência.' using errcode = '42501';
  end if;
  if v_e.modelo_ensaio is null then
    raise exception 'Este evento não é um ensaio Local ou Regional.';
  end if;
  if v_e.cancelado_em is not null then
    raise exception 'Este evento foi cancelado.';
  end if;

  -- Preenche-se DURANTE o ensaio (a partir de 2h antes até 3h depois do início). Só o Administrador
  -- (permissão eventos.cancelar) corrige fora dessa janela, como nos demais dados de evento encerrado.
  v_admin := public.tem_permissao('eventos.cancelar');
  if not v_admin then
    if now() < v_e.data_evento - interval '2 hours' then
      raise exception 'O ensaio ainda não começou. Os dados podem ser preenchidos a partir de 2 horas antes do horário.';
    end if;
    if public.portaria_encerrada(v_e.data_evento) then
      raise exception 'Este ensaio já foi encerrado. Só o Administrador pode alterar os dados.' using errcode = '42501';
    end if;
  end if;

  -- Quem atende
  if v_e.modelo_ensaio = 'REGIONAL' then
    if v_cargo <> 'ANCIAO' then
      raise exception 'No ensaio Regional quem atende é sempre um Ancião.';
    end if;
  elsif v_cargo not in ('ANCIAO', 'DIACONO', 'COOPERADOR_OFICIO', 'COOPERADOR_RJM') then
    raise exception 'Escolha o cargo de quem atendeu (Ancião, Diácono, Cooperador do Ofício ou Cooperador de RJM).';
  end if;
  if v_nome is null or char_length(v_nome) < 3 then
    raise exception 'Informe o nome de quem atendeu o ensaio.';
  end if;
  if char_length(v_nome) > 120 then
    raise exception 'O nome de quem atendeu pode ter no máximo 120 caracteres.';
  end if;

  -- Palavra: obrigatória no Regional; o Local não tem palavra
  if v_e.modelo_ensaio = 'REGIONAL' then
    if v_palavra is null then
      raise exception 'Informe a palavra que foi exortada.';
    end if;
    if char_length(v_palavra) > 500 then
      raise exception 'A palavra pode ter no máximo 500 caracteres.';
    end if;
  else
    v_palavra := null;
  end if;

  -- Hino de abertura (obrigatório; fica fora da lista de hinos executados)
  begin
    v_abertura := (p_dados ->> 'hino_abertura_id')::uuid;
  exception when others then
    v_abertura := null;
  end;
  if v_abertura is null then
    raise exception 'Escolha o hino de abertura.';
  end if;
  if not exists (select 1 from public.hinos h where h.id = v_abertura) then
    raise exception 'Hino de abertura não encontrado.';
  end if;

  select * into v_d from public.dados_ensaio d where d.evento_id = p_evento_id;

  if v_abertura is distinct from v_d.hino_abertura_id
     and exists (select 1 from public.hinos h where h.id = v_abertura and not h.ativo) then
    raise exception 'O hino de abertura escolhido está desativado.';
  end if;

  -- Encarregados: de 1 a 3, com nome e Cidade/UF
  if jsonb_typeof(v_enc) <> 'array' or jsonb_array_length(v_enc) < 1 then
    raise exception 'Informe pelo menos 1 encarregado.';
  end if;
  if jsonb_array_length(v_enc) > 3 then
    raise exception 'Informe no máximo 3 encarregados.';
  end if;
  for v_item in select * from jsonb_array_elements(v_enc) loop
    v_nomeenc := public.limpar_espacos(v_item ->> 'nome');
    v_cidade  := public.limpar_espacos(v_item ->> 'cidade_uf');
    if v_nomeenc is null or char_length(v_nomeenc) < 3 or char_length(v_nomeenc) > 120 then
      raise exception 'Informe o nome de cada encarregado (de 3 a 120 caracteres).';
    end if;
    if v_cidade is null or v_cidade !~ '^.{2,}-[A-Z]{2}$' or not (right(v_cidade, 2) = any (v_ufs)) then
      raise exception 'Informe a cidade de % no formato Cidade-UF (ex.: São Paulo-SP).', v_nomeenc;
    end if;
  end loop;
  if (select count(distinct public.normalizar_texto(public.limpar_espacos(x ->> 'nome')))
        from jsonb_array_elements(v_enc) x) <> jsonb_array_length(v_enc) then
    raise exception 'Há encarregados com o mesmo nome.';
  end if;

  -- Hinos executados: sem repetir, sem o hino de abertura
  if jsonb_typeof(v_hinos) <> 'array' then
    raise exception 'Lista de hinos inválida.';
  end if;
  if jsonb_array_length(v_hinos) > 100 then
    raise exception 'Informe no máximo 100 hinos executados.';
  end if;
  if exists (select 1 from jsonb_array_elements_text(v_hinos) x
              where x !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$') then
    raise exception 'Lista de hinos inválida.';
  end if;
  if (select count(distinct lower(x)) from jsonb_array_elements_text(v_hinos) x) <> jsonb_array_length(v_hinos) then
    raise exception 'O mesmo hino não pode ser executado duas vezes no ensaio.';
  end if;
  if exists (select 1 from jsonb_array_elements_text(v_hinos) x where x::uuid = v_abertura) then
    raise exception 'O hino de abertura não conta entre os hinos executados. Tire-o da lista.';
  end if;
  select count(*) into v_n from jsonb_array_elements_text(v_hinos) x join public.hinos h on h.id = x::uuid;
  if v_n <> jsonb_array_length(v_hinos) then
    raise exception 'Algum hino escolhido não foi encontrado.';
  end if;
  -- Hino desativado só pode ficar se já fazia parte deste ensaio
  if exists (select 1 from jsonb_array_elements_text(v_hinos) x join public.hinos h on h.id = x::uuid
              where not h.ativo
                and not exists (select 1 from public.dados_ensaio_hinos dh where dh.dados_ensaio_id = v_d.id and dh.hino_id = h.id)) then
    raise exception 'Algum hino escolhido está desativado.';
  end if;

  if v_d.id is not null then
    v_antes := public.ensaio_resumo(v_d.id);
  end if;

  if v_d.id is null then
    insert into public.dados_ensaio (evento_id, atende_cargo, atende_nome, palavra, hino_abertura_id, criado_por, atualizado_por)
    values (p_evento_id, v_cargo, v_nome, v_palavra, v_abertura, v_uid, v_uid)
    returning id into v_id;
  else
    v_id := v_d.id;
    -- Apaga os itens antes de trocar o hino de abertura (o gatilho confere abertura x executados)
    delete from public.dados_ensaio_encarregados where dados_ensaio_id = v_id;
    delete from public.dados_ensaio_hinos where dados_ensaio_id = v_id;
    update public.dados_ensaio
       set atende_cargo = v_cargo, atende_nome = v_nome, palavra = v_palavra, hino_abertura_id = v_abertura,
           atualizado_por = v_uid, atualizado_em = now()
     where id = v_id;
  end if;

  v_ordem := 0;
  for v_item in select * from jsonb_array_elements(v_enc) loop
    v_ordem := v_ordem + 1;
    insert into public.dados_ensaio_encarregados (dados_ensaio_id, ordem, nome, cidade_uf)
    values (v_id, v_ordem, public.limpar_espacos(v_item ->> 'nome'), public.limpar_espacos(v_item ->> 'cidade_uf'));
  end loop;

  v_ordem := 0;
  for v_item in select * from jsonb_array_elements(v_hinos) loop
    v_ordem := v_ordem + 1;
    insert into public.dados_ensaio_hinos (dados_ensaio_id, hino_id, ordem)
    values (v_id, (v_item #>> '{}')::uuid, v_ordem);
  end loop;

  -- Auditoria: uma linha por gravação, com o que mudou (texto simples)
  v_depois := public.ensaio_resumo(v_id);
  if v_antes is null then
    perform public.registrar_auditoria('ensaio_registrado', 'ensaio', p_evento_id,
              jsonb_build_object('rotulo', v_e.tipo || ' · ' || v_e.local, 'depois', v_depois));
  else
    select coalesce(jsonb_object_agg(n.key, jsonb_build_object('de', o.value, 'para', n.value)), '{}'::jsonb)
      into v_mud
      from jsonb_each(v_depois) n
      left join jsonb_each(v_antes) o on o.key = n.key
     where n.value is distinct from o.value;
    if v_mud <> '{}'::jsonb then
      perform public.registrar_auditoria('ensaio_alterado', 'ensaio', p_evento_id,
                jsonb_build_object('rotulo', v_e.tipo || ' · ' || v_e.local, 'mudancas', v_mud));
    end if;
  end if;

  return v_id;
end;
$$;

-- ---------------------------------------------------------------------------
-- 9. Quem pode executar cada função (só usuários logados; cada função confere a permissão)
-- ---------------------------------------------------------------------------
revoke all on function public.listar_tipos_evento() from public, anon;
revoke all on function public.salvar_tipo_evento(uuid, jsonb) from public, anon;
revoke all on function public.excluir_tipo_evento(uuid) from public, anon;
revoke all on function public.listar_hinos() from public, anon;
revoke all on function public.salvar_hino(uuid, jsonb) from public, anon;
revoke all on function public.excluir_hino(uuid) from public, anon;
revoke all on function public.importar_hinos(jsonb) from public, anon;
revoke all on function public.eventos_para_ensaio() from public, anon;
revoke all on function public.obter_dados_ensaio(uuid) from public, anon;
revoke all on function public.salvar_dados_ensaio(uuid, jsonb) from public, anon;
grant execute on function public.listar_tipos_evento() to authenticated;
grant execute on function public.salvar_tipo_evento(uuid, jsonb) to authenticated;
grant execute on function public.excluir_tipo_evento(uuid) to authenticated;
grant execute on function public.listar_hinos() to authenticated;
grant execute on function public.salvar_hino(uuid, jsonb) to authenticated;
grant execute on function public.excluir_hino(uuid) to authenticated;
grant execute on function public.importar_hinos(jsonb) to authenticated;
grant execute on function public.eventos_para_ensaio() to authenticated;
grant execute on function public.obter_dados_ensaio(uuid) to authenticated;
grant execute on function public.salvar_dados_ensaio(uuid, jsonb) to authenticated;
grant execute on function public.rotulo_hino(text, integer) to authenticated;

-- ---------------------------------------------------------------------------
-- 10. Backup: a função de restauração passa a aceitar as tabelas novas
--     (cópia da versão da migração 0039 com as linhas novas na lista permitida)
-- ---------------------------------------------------------------------------
create or replace function public.backup_aplicar(p_usuario uuid, p_operacoes jsonb, p_resumo jsonb)
returns jsonb
language plpgsql security definer set search_path to 'public'
as $$
declare
  v_op        jsonb;
  v_tabela    text;
  v_acao      text;
  v_linhas    jsonb;
  v_colunas   text[];
  v_def       record;
  v_cols      text;
  v_bcols     text;
  v_set       text;
  v_pk_cond   text;
  v_extra     text;
  v_n         bigint;
  v_ignorados bigint;
  v_resultado jsonb := '[]'::jsonb;
begin
  if p_operacoes is null or jsonb_typeof(p_operacoes) <> 'array' then
    raise exception 'Operações inválidas.';
  end if;

  perform set_config('sysmusica.restaurando', 'sim', true);

  for v_op in select * from jsonb_array_elements(p_operacoes) loop
    v_tabela := v_op ->> 'tabela';
    v_acao   := v_op ->> 'acao';
    v_linhas := coalesce(v_op -> 'linhas', '[]'::jsonb);

    select t.* into v_def
    from (values
      ('estados',             array['id'],                              false, false, ''),
      ('rrms',                array['id'],                              false, false, ''),
      ('ras',                 array['id'],                              false, false, ''),
      ('adms',                array['id'],                              false, false, ''),
      ('setores',             array['id'],                              false, false, ''),
      ('casas_oracao',        array['id'],                              false, false, ''),
      ('familias',            array['id'],                              false, false, ''),
      ('cargos',              array['id'],                              false, false, ''),
      ('finalidades_evento',  array['id'],                              false, false, ''),
      ('instrumentos',        array['id'],                              false, false, ''),
      ('tipos_evento',        array['id'],                              false, false, ''),
      ('hinos',               array['id'],                              false, false, ''),
      ('dados_ensaio',        array['id'],                              false, false, ''),
      ('dados_ensaio_encarregados', array['id'],                        false, false, ''),
      ('dados_ensaio_hinos',  array['id'],                              false, false, ''),
      ('grupos',              array['id'],                              false, false, ''),
      ('grupo_permissoes',    array['grupo_id', 'permissao_codigo'],    false, false, ''),
      ('usuarios',            array['id'],                              false, false, 'login'),
      ('usuario_grupos',      array['usuario_id', 'grupo_id'],          false, false, ''),
      ('usuario_vinculos',    array['usuario_id', 'nivel', 'alvo_id'],  false, false, ''),
      ('membros',             array['id'],                              true,  false, ''),
      ('eventos',             array['id'],                              true,  false, ''),
      ('portarias',           array['id'],                              true,  false, ''),
      ('portarias_historico', array['id'],                              false, true,  ''),
      ('presencas',           array['id'],                              true,  false, ''),
      ('presencas_avulsas',   array['id'],                              true,  false, '')
    ) as t(tabela, pk, soft, so_inserir, extra)
    where t.tabela = v_tabela;
    if not found then
      raise exception 'Tabela não permitida na restauração: %', coalesce(v_tabela, '(vazia)');
    end if;

    if v_acao is null or v_acao not in ('inserir', 'atualizar', 'excluir_logico', 'excluir') then
      raise exception 'Ação inválida na restauração: %', coalesce(v_acao, '(vazia)');
    end if;
    if v_def.so_inserir and v_acao <> 'inserir' then
      raise exception 'A tabela % só aceita devolver registros apagados.', v_tabela;
    end if;
    if v_acao = 'excluir_logico' and not v_def.soft then
      raise exception 'A tabela % não usa exclusão lógica.', v_tabela;
    end if;
    if v_acao = 'excluir' and v_def.soft then
      raise exception 'Os itens da tabela % são excluídos logicamente.', v_tabela;
    end if;
    if jsonb_typeof(v_linhas) <> 'array' then
      raise exception 'Linhas inválidas em %.', v_tabela;
    end if;
    if jsonb_array_length(v_linhas) = 0 then
      continue;
    end if;

    select coalesce(array_agg(x), '{}'::text[]) into v_colunas
    from jsonb_array_elements_text(coalesce(v_op -> 'colunas', '[]'::jsonb)) as x;

    if not (v_def.pk <@ v_colunas) then
      raise exception 'Faltam as colunas de identificação em %.', v_tabela;
    end if;

    -- Só colunas que existem e podem ser gravadas (as geradas ficam de fora)
    select string_agg(quote_ident(c.column_name), ', ' order by c.ordinal_position),
           string_agg(format('b.%I', c.column_name), ', ' order by c.ordinal_position),
           string_agg(format('%1$I = b.%1$I', c.column_name), ', ' order by c.ordinal_position)
             filter (where c.column_name <> all (v_def.pk))
      into v_cols, v_bcols, v_set
    from information_schema.columns c
    where c.table_schema = 'public' and c.table_name = v_tabela
      and c.is_generated = 'NEVER' and c.column_name = any (v_colunas);

    select string_agg(format('c.%1$I = b.%1$I', k), ' and ') into v_pk_cond from unnest(v_def.pk) as k;

    v_ignorados := 0;

    if v_acao = 'inserir' then
      -- Usuários só voltam se a conta de login ainda existir (a senha não é guardada no backup)
      v_extra := case when v_def.extra = 'login' then 'where exists (select 1 from auth.users a where a.id = b.id)' else '' end;
      execute format(
        'insert into public.%1$I (%2$s) select %3$s from jsonb_populate_recordset(null::public.%1$I, $1) b %4$s',
        v_tabela, v_cols, v_bcols, v_extra) using v_linhas;
      get diagnostics v_n = row_count;
      v_ignorados := jsonb_array_length(v_linhas) - v_n;

    elsif v_acao = 'atualizar' then
      if v_set is null then
        v_n := 0;
      else
        execute format(
          'update public.%1$I c set %2$s from jsonb_populate_recordset(null::public.%1$I, $1) b where %3$s',
          v_tabela, v_set, v_pk_cond) using v_linhas;
        get diagnostics v_n = row_count;
      end if;

    elsif v_acao = 'excluir_logico' then
      execute format(
        'update public.%1$I c set excluido_em = now() from jsonb_populate_recordset(null::public.%1$I, $1) b where %2$s and c.excluido_em is null',
        v_tabela, v_pk_cond) using v_linhas;
      get diagnostics v_n = row_count;

    else
      execute format(
        'delete from public.%1$I c using jsonb_populate_recordset(null::public.%1$I, $1) b where %2$s',
        v_tabela, v_pk_cond) using v_linhas;
      get diagnostics v_n = row_count;
    end if;

    v_resultado := v_resultado || jsonb_build_object(
      'tabela', v_tabela, 'acao', v_acao, 'afetados', v_n, 'ignorados', v_ignorados);
  end loop;

  perform set_config('sysmusica.restaurando', '', true);

  -- Uma única entrada resumida na auditoria (a auditoria linha a linha ficou pausada)
  insert into public.auditoria (usuario_id, acao, entidade, entidade_id, detalhes)
  values (p_usuario, 'backup_restaurado', 'backup', null,
          coalesce(p_resumo, '{}'::jsonb) || jsonb_build_object('operacoes', v_resultado));

  return v_resultado;
end;
$$;

-- ---------------------------------------------------------------------------
-- 11. Conferência final
-- ---------------------------------------------------------------------------
do $$
begin
  if (select count(*) from public.tipos_evento) < 8
     or (select count(*) from public.permissoes where codigo in (
           'tipoevento.visualizar', 'tipoevento.criar', 'tipoevento.editar', 'tipoevento.excluir',
           'hinos.visualizar', 'hinos.criar', 'hinos.editar', 'hinos.excluir', 'ensaio.visualizar', 'ensaio.registrar')) <> 10
     or to_regprocedure('public.salvar_dados_ensaio(uuid, jsonb)') is null
     or not exists (select 1 from pg_trigger where tgname = 'trg_eventos_sincroniza_tipo') then
    raise exception 'Teste falhou: objetos da Parte 8 ausentes. Nada foi alterado.';
  end if;
  raise notice 'OK: tipos de evento, hinos e dados do ensaio instalados.';
end $$;

select set_config('sysmusica.restaurando', '', true);
commit;
