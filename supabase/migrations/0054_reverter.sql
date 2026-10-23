-- 0054 — REVERTER a Etapa 1 do isolamento regional.
-- Devolve as funções às definições originais (capturadas antes da mudança) e remove o que a 0054 criou.
-- Atenção: depois de reverter, quem tem portarias.controle_total volta a enxergar TODAS as regiões.
-- Tudo roda numa transação: se algo falhar, nada é aplicado.

begin;

-- Gatilhos de escopo da organização
drop trigger if exists trg_org_escopo on public.estados;
drop trigger if exists trg_org_escopo on public.rrms;
drop trigger if exists trg_org_escopo on public.ras;
drop trigger if exists trg_org_escopo on public.adms;
drop trigger if exists trg_org_escopo on public.setores;
drop trigger if exists trg_org_escopo on public.casas_oracao;
drop function if exists public.org_exigir_escopo();

-- Funções originais

CREATE OR REPLACE FUNCTION public.listar_usuarios()
 RETURNS TABLE(id uuid, nome text, email text, grupo_id uuid, grupo_nome text, ativo boolean, ultimo_acesso timestamp with time zone, criado_em timestamp with time zone)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  perform public.exigir_permissao('usuarios.visualizar');
  return query
    select u.id, u.nome, u.email, u.grupo_id,
           (select string_agg(g.nome, ', ' order by (g.id = u.grupo_id) desc, g.nome)
              from public.grupos g
             where g.id = u.grupo_id
                or exists (select 1 from public.usuario_grupos ug
                            where ug.usuario_id = u.id and ug.grupo_id = g.id)),
           u.ativo, a.last_sign_in_at, u.criado_em
    from public.usuarios u
    left join auth.users a on a.id = u.id
    order by u.nome;
end;
$function$;

CREATE OR REPLACE FUNCTION public.listar_grupos_dos_usuarios()
 RETURNS TABLE(usuario_id uuid, grupos uuid[])
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  perform public.exigir_alguma_permissao(array['usuarios.visualizar', 'usuarios.criar', 'usuarios.editar']);
  return query
    select u.id,
           array(select distinct t.x
                   from (select ug.grupo_id as x from public.usuario_grupos ug where ug.usuario_id = u.id
                         union
                         select u.grupo_id where u.grupo_id is not null) t
                  order by t.x)
    from public.usuarios u;
end;
$function$;

CREATE OR REPLACE FUNCTION public.listar_vinculos_rotulados()
 RETURNS TABLE(usuario_id uuid, nivel text, alvo_id uuid, rotulo text)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  perform public.exigir_permissao('usuarios.visualizar');
  return query
    select v.usuario_id, v.nivel, v.alvo_id, public.rotulo_vinculo(v.nivel, v.alvo_id)
    from public.usuario_vinculos v
    where public.rotulo_vinculo(v.nivel, v.alvo_id) is not null
    order by v.usuario_id, 4;
end;
$function$;

CREATE OR REPLACE FUNCTION public.listar_grupos()
 RETURNS TABLE(id uuid, nome text, descricao text, ativo boolean, sistema boolean, qtd_usuarios bigint, permissoes text[])
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  perform public.exigir_alguma_permissao(array[
    'grupos.visualizar', 'grupos.criar', 'grupos.editar',
    'usuarios.visualizar', 'usuarios.criar', 'usuarios.editar'
  ]);
  return query
    select g.id, g.nome, g.descricao, g.ativo, g.sistema,
           (select count(*) from public.usuarios u
             where u.grupo_id = g.id
                or exists (select 1 from public.usuario_grupos ug
                            where ug.usuario_id = u.id and ug.grupo_id = g.id)),
           coalesce(
             array(select gp.permissao_codigo from public.grupo_permissoes gp
                   where gp.grupo_id = g.id order by gp.permissao_codigo),
             '{}'::text[]
           )
    from public.grupos g
    order by g.sistema desc, g.nome;
end;
$function$;

CREATE OR REPLACE FUNCTION public.atualizar_usuario_grupos(p_id uuid, p_nome text, p_grupos uuid[], p_ativo boolean)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_usuario     public.usuarios;
  v_grupo_admin uuid;
  v_nome        text := btrim(coalesce(p_nome, ''));
  v_ativo       boolean;
  v_grupos      uuid[];
  v_principal   uuid;
  v_era_admin   boolean;
  v_sera_admin  boolean;
begin
  perform public.exigir_permissao('usuarios.editar');

  select * into v_usuario from public.usuarios where id = p_id for update;
  if not found then
    raise exception 'Usuário não encontrado.';
  end if;

  v_ativo := coalesce(p_ativo, v_usuario.ativo);

  if char_length(v_nome) < 2 or char_length(v_nome) > 80 then
    raise exception 'O nome deve ter entre 2 e 80 caracteres.';
  end if;

  select coalesce(array_agg(distinct t.x), '{}'::uuid[]) into v_grupos
  from unnest(coalesce(p_grupos, '{}'::uuid[])) as t(x);
  if cardinality(v_grupos) = 0 then
    raise exception 'Escolha pelo menos um grupo.';
  end if;
  if exists (select 1 from unnest(v_grupos) as t(x)
              where not exists (select 1 from public.grupos g where g.id = t.x)) then
    raise exception 'Grupo não encontrado.';
  end if;
  if p_id = (select auth.uid()) and not v_ativo then
    raise exception 'Você não pode desativar a sua própria conta.';
  end if;

  -- Grupo principal: mantém o atual se continuar marcado; senão, o primeiro da lista
  v_principal := case when v_usuario.grupo_id = any (v_grupos) then v_usuario.grupo_id else v_grupos[1] end;

  -- Proteção do último administrador ativo
  select g.id into v_grupo_admin from public.grupos g where g.sistema and g.nome = 'Administrador';
  v_era_admin  := v_usuario.ativo and public.usuario_no_grupo(p_id, v_grupo_admin);
  v_sera_admin := v_ativo and coalesce(v_grupo_admin = any (v_grupos), false);
  if v_era_admin and not v_sera_admin then
    if not exists (
      select 1 from public.usuarios u
      where u.ativo and u.id <> p_id and public.usuario_no_grupo(u.id, v_grupo_admin)
    ) then
      raise exception 'Não é possível: este é o último administrador ativo do sistema.';
    end if;
  end if;

  update public.usuarios set nome = v_nome, grupo_id = v_principal, ativo = v_ativo where id = p_id;

  delete from public.usuario_grupos ug where ug.usuario_id = p_id and not (ug.grupo_id = any (v_grupos));
  insert into public.usuario_grupos (usuario_id, grupo_id)
  select p_id, t.x from unnest(v_grupos) as t(x)
  on conflict do nothing;

  perform public.registrar_auditoria('usuario_grupos_definidos', 'usuario', p_id,
            jsonb_build_object('grupos', to_jsonb(v_grupos), 'ativo', v_ativo));
end;
$function$;

CREATE OR REPLACE FUNCTION public.definir_vinculos(p_usuario uuid, p_vinculos jsonb)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_item  jsonb;
  v_nivel text;
  v_alvo  uuid;
  v_lista jsonb := coalesce(p_vinculos, '[]'::jsonb);
  v_ok    boolean;
begin
  perform public.exigir_permissao('usuarios.vinculos');

  if not exists (select 1 from public.usuarios u where u.id = p_usuario) then
    raise exception 'Usuário não encontrado.';
  end if;
  if jsonb_typeof(v_lista) <> 'array' then
    raise exception 'Vínculos inválidos.';
  end if;

  delete from public.usuario_vinculos where usuario_id = p_usuario;

  for v_item in select * from jsonb_array_elements(v_lista) loop
    v_nivel := v_item ->> 'nivel';
    v_alvo  := (v_item ->> 'alvo_id')::uuid;
    v_ok := case v_nivel
      when 'ESTADO' then exists (select 1 from public.estados x where x.id = v_alvo)
      when 'RRM'    then exists (select 1 from public.rrms x where x.id = v_alvo)
      when 'RA'     then exists (select 1 from public.ras x where x.id = v_alvo)
      when 'ADM'    then exists (select 1 from public.adms x where x.id = v_alvo)
      when 'SETOR'  then exists (select 1 from public.setores x where x.id = v_alvo)
      when 'CASA_ORACAO' then exists (select 1 from public.casas_oracao x where x.id = v_alvo)
      else false
    end;
    if not v_ok then
      raise exception 'Vínculo inválido: o cadastro escolhido não existe mais.';
    end if;
    insert into public.usuario_vinculos (usuario_id, nivel, alvo_id) values (p_usuario, v_nivel, v_alvo)
    on conflict do nothing;
  end loop;

  perform public.registrar_auditoria('vinculos_definidos', 'usuario', p_usuario,
            jsonb_build_object('vinculos', v_lista));
end;
$function$;

CREATE OR REPLACE FUNCTION public.criar_grupo(p_nome text, p_descricao text, p_permissoes text[])
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_id   uuid;
  v_nome text := btrim(coalesce(p_nome, ''));
  v_desc text := nullif(btrim(coalesce(p_descricao, '')), '');
begin
  perform public.exigir_permissao('grupos.criar');

  if char_length(v_nome) < 2 or char_length(v_nome) > 60 then
    raise exception 'O nome do grupo deve ter entre 2 e 60 caracteres.';
  end if;
  if v_desc is not null and char_length(v_desc) > 200 then
    raise exception 'A descrição pode ter no máximo 200 caracteres.';
  end if;
  perform public.validar_codigos_permissao(p_permissoes);

  -- Nome repetido gera o erro 23505 (a tela mostra "já existe")
  insert into public.grupos (nome, descricao) values (v_nome, v_desc) returning id into v_id;

  insert into public.grupo_permissoes (grupo_id, permissao_codigo)
  select v_id, t.codigo from unnest(coalesce(p_permissoes, '{}'::text[])) as t(codigo)
  on conflict do nothing;

  return v_id;
end;
$function$;

CREATE OR REPLACE FUNCTION public.atualizar_grupo(p_id uuid, p_nome text, p_descricao text, p_ativo boolean, p_permissoes text[])
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_grupo public.grupos;
  v_nome  text    := btrim(coalesce(p_nome, ''));
  v_desc  text    := nullif(btrim(coalesce(p_descricao, '')), '');
  v_ativo boolean := coalesce(p_ativo, true);
begin
  perform public.exigir_permissao('grupos.editar');

  select * into v_grupo from public.grupos where id = p_id for update;
  if not found then
    raise exception 'Grupo não encontrado.';
  end if;

  if char_length(v_nome) < 2 or char_length(v_nome) > 60 then
    raise exception 'O nome do grupo deve ter entre 2 e 60 caracteres.';
  end if;
  if v_desc is not null and char_length(v_desc) > 200 then
    raise exception 'A descrição pode ter no máximo 200 caracteres.';
  end if;

  if v_grupo.sistema then
    if v_nome <> v_grupo.nome or v_ativo <> v_grupo.ativo then
      raise exception 'O grupo % é protegido: só a descrição pode ser alterada.', v_grupo.nome;
    end if;
    update public.grupos set descricao = v_desc where id = p_id;
    insert into public.grupo_permissoes (grupo_id, permissao_codigo)
    select p_id, p.codigo from public.permissoes p
    on conflict do nothing;
    return;
  end if;

  perform public.validar_codigos_permissao(p_permissoes);

  update public.grupos set nome = v_nome, descricao = v_desc, ativo = v_ativo where id = p_id;

  -- Substitui as permissões do grupo pela nova lista
  delete from public.grupo_permissoes where grupo_id = p_id;
  insert into public.grupo_permissoes (grupo_id, permissao_codigo)
  select p_id, t.codigo from unnest(coalesce(p_permissoes, '{}'::text[])) as t(codigo)
  on conflict do nothing;
end;
$function$;

CREATE OR REPLACE FUNCTION public.excluir_grupo(p_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_grupo public.grupos;
begin
  perform public.exigir_permissao('grupos.excluir');

  select * into v_grupo from public.grupos where id = p_id for update;
  if not found then
    raise exception 'Grupo não encontrado.';
  end if;
  if v_grupo.sistema then
    raise exception 'O grupo % é protegido e não pode ser excluído.', v_grupo.nome;
  end if;
  if exists (select 1 from public.usuarios u where u.grupo_id = p_id)
     or exists (select 1 from public.usuario_grupos ug where ug.grupo_id = p_id) then
    raise exception 'Este grupo ainda tem usuários. Retire-o dos usuários antes de excluir.';
  end if;

  delete from public.grupos where id = p_id;
end;
$function$;

CREATE OR REPLACE FUNCTION public.listar_organizacao()
 RETURNS TABLE(nivel text, id uuid, parent_id uuid, nome text, descricao text, ativo boolean, cidade text, bairro text, qtd_filhos bigint, qtd_membros bigint)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  perform public.exigir_alguma_permissao(array['organizacao.visualizar', 'usuarios.vinculos', 'usuarios.editar']);
  return query
    select 'ESTADO'::text, e.id, null::uuid, e.nome, null::text, e.ativo, null::text, null::text,
           (select count(*) from public.rrms x where x.estado_id = e.id), 0::bigint
    from public.estados e
    union all
    select 'RRM'::text, rr.id, rr.estado_id, rr.nome, rr.descricao, rr.ativo, null::text, null::text,
           (select count(*) from public.ras x where x.rrm_id = rr.id), 0::bigint
    from public.rrms rr
    union all
    select 'RA'::text, ra.id, ra.rrm_id, ra.nome, ra.descricao, ra.ativo, null::text, null::text,
           (select count(*) from public.adms x where x.ra_id = ra.id), 0::bigint
    from public.ras ra
    union all
    select 'ADM'::text, a.id, a.ra_id, a.nome, a.descricao, a.ativo, null::text, null::text,
           (select count(*) from public.setores x where x.adm_id = a.id)
           + (select count(*) from public.casas_oracao x where x.adm_id = a.id and x.setor_id is null), 0::bigint
    from public.adms a
    union all
    select 'SETOR'::text, s.id, s.adm_id, s.nome, s.descricao, s.ativo, null::text, null::text,
           (select count(*) from public.casas_oracao x where x.setor_id = s.id), 0::bigint
    from public.setores s
    union all
    select 'CASA_ORACAO'::text, c.id, coalesce(c.setor_id, c.adm_id), c.nome, null::text, c.ativo, c.cidade, c.bairro, 0::bigint,
           (select count(*) from public.membros m where m.casa_oracao_id = c.id and m.excluido_em is null)
    from public.casas_oracao c;
end;
$function$;

create or replace function public.tem_acesso_total_organizacao()
returns boolean
language sql
stable
security definer
set search_path to 'public'
as $function$
  select public.tem_permissao('organizacao.acesso_total') or public.tem_permissao('portarias.controle_total')
$function$;

-- Funções novas da 0054
drop function if exists public.grupo_concedivel(uuid);
drop function if exists public.usuario_na_minha_abrangencia(uuid);
drop function if exists public.usuario_e_global(uuid);
drop function if exists public.alvo_na_minha_abrangencia(text, uuid);
drop function if exists public.cadeia_organizacao(text, uuid);

-- Grupo "Administrador Regional" (só é removido se ninguém o usa; senão, fica e avisa)
do $$
declare v_id uuid;
begin
  select id into v_id from public.grupos where nome = 'Administrador Regional';
  if v_id is not null then
    if exists (select 1 from public.usuarios where grupo_id = v_id)
       or exists (select 1 from public.usuario_grupos where grupo_id = v_id) then
      raise notice 'O grupo Administrador Regional tem usuários: foi mantido. Retire-o dos usuários e exclua pela tela de Grupos.';
    else
      delete from public.grupo_permissoes where grupo_id = v_id;
      delete from public.grupos where id = v_id;
    end if;
  end if;
end $$;

-- Permissão acesso.global
delete from public.grupo_permissoes where permissao_codigo = 'acesso.global';
delete from public.permissoes where codigo = 'acesso.global';

-- Coluna criado_por
alter table public.usuarios drop column if exists criado_por;

commit;
