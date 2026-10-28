-- 0079: Perfil do Evento (Entrega 1) — cadastro dos perfis que definem o comportamento da tela "Dados do Ensaio".
-- Nesta entrega o perfil tem nome, descrição, comportamento base (Local ou Regional) e status; os tipos de evento
-- passam a apontar para um perfil. A tela "Dados do Ensaio" segue funcionando pelo modelo (LOCAL/REGIONAL) do tipo.
-- Só o administrador global altera perfis (cadastro compartilhado entre as regiões).
-- perfil_id NÃO tem chave estrangeira de propósito: assim o backup/restauração dos tipos continua funcionando.
-- Seguro rodar mais de uma vez. Para desfazer: 0079_reverter.sql

create table if not exists public.perfis_evento (
  id            uuid primary key default gen_random_uuid(),
  nome          text not null,
  descricao     text,
  modelo_base   text not null check (modelo_base in ('LOCAL', 'REGIONAL')),
  ativo         boolean not null default true,
  ordem         integer not null default 0,
  criado_em     timestamptz not null default now(),
  atualizado_em timestamptz not null default now()
);
create unique index if not exists perfis_evento_nome_uq on public.perfis_evento (lower(btrim(nome)));
alter table public.perfis_evento enable row level security;
revoke all on public.perfis_evento from public, anon, authenticated;   -- só as funções abaixo mexem na tabela

alter table public.tipos_evento add column if not exists perfil_id uuid;

-- Perfis iniciais: Ensaio Técnico nasce como cópia do Ensaio Local
insert into public.perfis_evento (nome, descricao, modelo_base, ordem)
select v.nome, v.descricao, v.modelo, v.ordem
  from (values
    ('Ensaio Local',    'Quem atende pode ser Ancião, Diácono ou Cooperador, sem palavra.', 'LOCAL',    1),
    ('Ensaio Regional', 'Quem atende é sempre Ancião e há a palavra.',                      'REGIONAL', 2),
    ('Ensaio Técnico',  'Cópia do Ensaio Local.',                                           'LOCAL',    3)
  ) as v(nome, descricao, modelo, ordem)
 where not exists (select 1 from public.perfis_evento p where lower(btrim(p.nome)) = lower(btrim(v.nome)));

-- Liga os tipos que já existem: Técnicos -> Ensaio Técnico; os demais pelo modelo atual
update public.tipos_evento t set perfil_id = (select p.id from public.perfis_evento p where lower(p.nome) = 'ensaio técnico')
 where t.perfil_id is null and public.normalizar_texto(t.nome) like 'ensaio tecnico%';
update public.tipos_evento t set perfil_id = (select p.id from public.perfis_evento p where p.modelo_base = t.modelo_ensaio::text order by p.ordem limit 1)
 where t.perfil_id is null and t.modelo_ensaio is not null;

-- Lista (com quantos tipos usam cada perfil)
create or replace function public.listar_perfis_evento()
returns table(id uuid, nome text, descricao text, modelo_base text, ativo boolean, em_uso integer)
language plpgsql stable security definer set search_path = public
as $f$
begin
  perform public.exigir_permissao('tipoevento.visualizar');
  return query
    select p.id, p.nome, p.descricao, p.modelo_base, p.ativo,
           (select count(*)::integer from public.tipos_evento t where t.perfil_id = p.id)
      from public.perfis_evento p
     order by p.ordem, lower(p.nome);
end
$f$;

-- Perfil de cada tipo (a lista de tipos mostra o nome do perfil)
create or replace function public.perfis_dos_tipos_evento()
returns table(tipo_id uuid, perfil_id uuid, perfil_nome text)
language plpgsql stable security definer set search_path = public
as $f$
begin
  perform public.exigir_permissao('tipoevento.visualizar');
  return query
    select t.id, p.id, p.nome from public.tipos_evento t join public.perfis_evento p on p.id = t.perfil_id;
end
$f$;

-- Criar / alterar
create or replace function public.salvar_perfil_evento(p_id uuid, p_dados jsonb)
returns uuid
language plpgsql security definer set search_path = public
as $f$
declare
  v_nome   text := regexp_replace(btrim(coalesce(p_dados ->> 'nome', '')), '\s+', ' ', 'g');
  v_desc   text := nullif(btrim(coalesce(p_dados ->> 'descricao', '')), '');
  v_modelo text := p_dados ->> 'modelo_base';
  v_ativo  boolean := coalesce((p_dados ->> 'ativo')::boolean, true);
  v_id     uuid := p_id;
begin
  if p_id is null then perform public.exigir_permissao('tipoevento.criar');
  else perform public.exigir_permissao('tipoevento.editar'); end if;
  if not public.tem_acesso_total_organizacao() then
    raise exception 'Só o administrador pode alterar os perfis de evento.' using errcode = '42501';
  end if;
  if char_length(v_nome) < 3 or char_length(v_nome) > 60 then
    raise exception 'O nome do perfil deve ter de 3 a 60 caracteres.';
  end if;
  if v_desc is not null and char_length(v_desc) > 200 then
    raise exception 'A descrição pode ter no máximo 200 caracteres.';
  end if;
  if v_modelo is null or v_modelo not in ('LOCAL', 'REGIONAL') then
    raise exception 'Escolha o comportamento base do perfil (Local ou Regional).';
  end if;
  if exists (select 1 from public.perfis_evento p where lower(btrim(p.nome)) = lower(v_nome) and p.id is distinct from p_id) then
    raise exception 'Já existe um perfil com este nome.';
  end if;

  if p_id is null then
    insert into public.perfis_evento (nome, descricao, modelo_base, ativo, ordem)
    values (v_nome, v_desc, v_modelo, v_ativo, coalesce((select max(ordem) from public.perfis_evento), 0) + 1)
    returning id into v_id;
    perform public.registrar_auditoria('perfil_evento_criado', 'perfil_evento', v_id, jsonb_build_object('nome', v_nome));
  else
    update public.perfis_evento set nome = v_nome, descricao = v_desc, modelo_base = v_modelo, ativo = v_ativo, atualizado_em = now()
     where id = p_id;
    if not found then raise exception 'Perfil não encontrado.'; end if;
    perform public.registrar_auditoria('perfil_evento_alterado', 'perfil_evento', p_id, jsonb_build_object('nome', v_nome));
  end if;
  return v_id;
end
$f$;

-- Duplicar ("Nome (cópia)", "Nome (cópia 2)"...)
create or replace function public.duplicar_perfil_evento(p_id uuid)
returns uuid
language plpgsql security definer set search_path = public
as $f$
declare
  v_o    public.perfis_evento;
  v_nome text;
  v_n    integer := 1;
  v_id   uuid;
begin
  perform public.exigir_permissao('tipoevento.criar');
  if not public.tem_acesso_total_organizacao() then
    raise exception 'Só o administrador pode alterar os perfis de evento.' using errcode = '42501';
  end if;
  select * into v_o from public.perfis_evento where id = p_id;
  if not found then raise exception 'Perfil não encontrado.'; end if;
  v_nome := left(v_o.nome, 50) || ' (cópia)';
  while exists (select 1 from public.perfis_evento p where lower(btrim(p.nome)) = lower(v_nome)) loop
    v_n := v_n + 1;
    v_nome := left(v_o.nome, 48) || ' (cópia ' || v_n || ')';
  end loop;
  insert into public.perfis_evento (nome, descricao, modelo_base, ativo, ordem)
  values (v_nome, v_o.descricao, v_o.modelo_base, v_o.ativo, coalesce((select max(ordem) from public.perfis_evento), 0) + 1)
  returning id into v_id;
  perform public.registrar_auditoria('perfil_evento_duplicado', 'perfil_evento', v_id, jsonb_build_object('origem', p_id, 'nome', v_nome));
  return v_id;
end
$f$;

-- Excluir (recusa se algum tipo de evento usar o perfil)
create or replace function public.excluir_perfil_evento(p_id uuid)
returns void
language plpgsql security definer set search_path = public
as $f$
declare
  v_nome text;
  v_uso  integer;
begin
  perform public.exigir_permissao('tipoevento.excluir');
  if not public.tem_acesso_total_organizacao() then
    raise exception 'Só o administrador pode alterar os perfis de evento.' using errcode = '42501';
  end if;
  select nome into v_nome from public.perfis_evento where id = p_id;
  if not found then raise exception 'Perfil não encontrado.'; end if;
  select count(*) into v_uso from public.tipos_evento t where t.perfil_id = p_id;
  if v_uso > 0 then
    raise exception 'Este perfil é usado por % tipo(s) de evento. Troque o perfil desses tipos antes de excluir.', v_uso;
  end if;
  delete from public.perfis_evento where id = p_id;
  perform public.registrar_auditoria('perfil_evento_excluido', 'perfil_evento', p_id, jsonb_build_object('nome', v_nome));
end
$f$;

-- Liga um tipo de evento a um perfil (nulo = sem perfil). O modelo do tipo é salvo à parte, por salvar_tipo_evento.
create or replace function public.vincular_perfil_tipo_evento(p_tipo uuid, p_perfil uuid)
returns void
language plpgsql security definer set search_path = public
as $f$
begin
  perform public.exigir_permissao('tipoevento.editar');
  if not public.tem_acesso_total_organizacao() then
    raise exception 'Só o administrador pode alterar os tipos de evento.' using errcode = '42501';
  end if;
  if p_perfil is not null and not exists (select 1 from public.perfis_evento where id = p_perfil) then
    raise exception 'Perfil não encontrado.';
  end if;
  update public.tipos_evento set perfil_id = p_perfil where id = p_tipo;
  if not found then raise exception 'Tipo de evento não encontrado.'; end if;
end
$f$;

revoke all on function public.listar_perfis_evento(), public.perfis_dos_tipos_evento(), public.salvar_perfil_evento(uuid, jsonb),
  public.duplicar_perfil_evento(uuid), public.excluir_perfil_evento(uuid), public.vincular_perfil_tipo_evento(uuid, uuid)
  from public, anon;
grant execute on function public.listar_perfis_evento(), public.perfis_dos_tipos_evento(), public.salvar_perfil_evento(uuid, jsonb),
  public.duplicar_perfil_evento(uuid), public.excluir_perfil_evento(uuid), public.vincular_perfil_tipo_evento(uuid, uuid)
  to authenticated;

-- Conferência (se falhar, nada é aplicado)
do $$
begin
  if (select count(*) from public.perfis_evento where lower(nome) in ('ensaio local', 'ensaio regional', 'ensaio técnico')) < 3 then
    raise exception '0079: os perfis iniciais não foram criados.';
  end if;
end $$;
