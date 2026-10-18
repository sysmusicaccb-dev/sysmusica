-- =====================================================================
-- SysMúsica — Migração 0011: um usuário pode pertencer a VÁRIOS grupos
--   * Tabela usuario_grupos (usuário x grupo). As permissões do usuário passam a ser a SOMA das
--     permissões de todos os grupos ATIVOS dele.
--   * usuarios.grupo_id continua existindo como "grupo principal" (o sistema e a criação de
--     usuário já o usam); o grupo principal sempre faz parte dos grupos do usuário.
--   * minha_conta(), tem_alguma_permissao() e tem_acesso() mantêm o mesmo formato: por isso o
--     login, o menu e todas as regras (RLS) continuam funcionando sem mudança.
--   * Mantém a proteção do último administrador ativo e a auditoria.
-- Ao final, a migração TESTA o seu Administrador: se ele perdesse o acesso, tudo é desfeito.
-- Requer as migrações 0002, 0003 e 0006. Idempotente, uma única transação.
-- =====================================================================
begin;

do $$
begin
  if to_regprocedure('public.minha_conta()') is null
     or to_regprocedure('public.atualizar_usuario(uuid,text,uuid,boolean)') is null
     or to_regprocedure('public.registrar_auditoria(text,text,uuid,jsonb)') is null then
    raise exception 'Aplique primeiro as migrações 0002, 0003 e 0006.';
  end if;
end $$;

-- 1) TABELA DOS GRUPOS DE CADA USUÁRIO (sem acesso direto: só pelas funções abaixo)
create table if not exists public.usuario_grupos (
  usuario_id uuid not null references public.usuarios (id) on delete cascade,
  grupo_id   uuid not null references public.grupos (id),
  primary key (usuario_id, grupo_id)
);
create index if not exists idx_usuario_grupos_grupo on public.usuario_grupos (grupo_id);

alter table public.usuario_grupos enable row level security;
revoke all on public.usuario_grupos from anon, authenticated;

-- Quem já tinha um grupo continua com ele
insert into public.usuario_grupos (usuario_id, grupo_id)
select u.id, u.grupo_id from public.usuarios u where u.grupo_id is not null
on conflict do nothing;

-- O grupo principal entra automaticamente nos grupos do usuário (criação de usuário pela tela, etc.)
create or replace function public.usuarios_sincroniza_grupo_principal()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.grupo_id is not null then
    insert into public.usuario_grupos (usuario_id, grupo_id) values (new.id, new.grupo_id)
    on conflict do nothing;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_usuarios_grupo_principal on public.usuarios;
create trigger trg_usuarios_grupo_principal
  after insert or update of grupo_id on public.usuarios
  for each row execute function public.usuarios_sincroniza_grupo_principal();

-- O usuário pertence ao grupo? (grupo principal OU lista de grupos)
create or replace function public.usuario_no_grupo(p_usuario uuid, p_grupo uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select p_grupo is not null and (
    exists (select 1 from public.usuarios u where u.id = p_usuario and u.grupo_id = p_grupo)
    or exists (select 1 from public.usuario_grupos ug where ug.usuario_id = p_usuario and ug.grupo_id = p_grupo)
  )
$$;

-- 2) PERMISSÕES: soma dos grupos ATIVOS do usuário ATIVO (mesmo formato de antes)
create or replace function public.tem_alguma_permissao(p_codigos text[])
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1
    from public.usuarios u
    join public.grupos g
      on g.ativo
     and (g.id = u.grupo_id
          or exists (select 1 from public.usuario_grupos ug where ug.usuario_id = u.id and ug.grupo_id = g.id))
    join public.grupo_permissoes gp on gp.grupo_id = g.id
    where u.id = (select auth.uid())
      and u.ativo
      and gp.permissao_codigo = any (p_codigos)
  )
$$;

create or replace function public.tem_acesso()
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1
    from public.usuarios u
    join public.grupos g
      on g.ativo
     and (g.id = u.grupo_id
          or exists (select 1 from public.usuario_grupos ug where ug.usuario_id = u.id and ug.grupo_id = g.id))
    where u.id = (select auth.uid()) and u.ativo
  )
$$;

-- Dados do usuário logado para a tela (a coluna "grupo" mostra os nomes dos grupos, separados por vírgula)
create or replace function public.minha_conta()
returns table (nome text, email text, grupo text, ativo boolean, permissoes text[])
language sql stable security definer set search_path = public as $$
  with meus as (
    select g.id, g.nome, g.ativo
    from public.usuarios u
    join public.grupos g
      on g.id = u.grupo_id
      or exists (select 1 from public.usuario_grupos ug where ug.usuario_id = u.id and ug.grupo_id = g.id)
    where u.id = (select auth.uid())
  )
  select u.nome,
         u.email,
         (select string_agg(m.nome, ', ' order by m.nome) from meus m),
         (u.ativo and exists (select 1 from meus m where m.ativo)),
         case
           when u.ativo and exists (select 1 from meus m where m.ativo) then
             array(select distinct gp.permissao_codigo
                   from public.grupo_permissoes gp
                   join meus m on m.id = gp.grupo_id and m.ativo
                   order by gp.permissao_codigo)
           else '{}'::text[]
         end
  from public.usuarios u
  where u.id = (select auth.uid())
$$;

-- 3) TELAS DE ADMINISTRAÇÃO
-- Grupos: a quantidade de usuários considera todos os que pertencem ao grupo
create or replace function public.listar_grupos()
returns table (
  id uuid, nome text, descricao text, ativo boolean, sistema boolean,
  qtd_usuarios bigint, permissoes text[]
)
language plpgsql stable security definer set search_path = public as $$
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
$$;

-- Usuários: "grupo_nome" mostra todos os grupos (o principal primeiro)
create or replace function public.listar_usuarios()
returns table (
  id uuid, nome text, email text, grupo_id uuid, grupo_nome text,
  ativo boolean, ultimo_acesso timestamptz, criado_em timestamptz
)
language plpgsql stable security definer set search_path = public as $$
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
$$;

-- Grupos de cada usuário (ids), para o formulário de edição marcar as caixas
create or replace function public.listar_grupos_dos_usuarios()
returns table (usuario_id uuid, grupos uuid[])
language plpgsql stable security definer set search_path = public as $$
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
$$;

-- Excluir grupo: só se NENHUM usuário pertencer a ele
create or replace function public.excluir_grupo(p_id uuid)
returns void language plpgsql security definer set search_path = public as $$
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
$$;

-- Salva nome, situação e TODOS os grupos do usuário de uma vez (tudo ou nada).
-- Regras: não desativar a própria conta; não deixar o sistema sem administrador ativo.
create or replace function public.atualizar_usuario_grupos(
  p_id uuid, p_nome text, p_grupos uuid[], p_ativo boolean
)
returns void language plpgsql security definer set search_path = public as $$
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
$$;

-- Função antiga (nome, grupo e situação): continua valendo para ativar/desativar. O grupo informado
-- é INCLUÍDO nos grupos do usuário (os demais são mantidos); quem decide a lista é a função acima.
create or replace function public.atualizar_usuario(
  p_id uuid, p_nome text, p_grupo_id uuid, p_ativo boolean
)
returns void language plpgsql security definer set search_path = public as $$
declare
  v_grupos uuid[];
begin
  perform public.exigir_permissao('usuarios.editar');

  select coalesce(array_agg(distinct t.x), '{}'::uuid[]) into v_grupos
  from (
    select ug.grupo_id as x from public.usuario_grupos ug where ug.usuario_id = p_id
    union
    select u.grupo_id from public.usuarios u where u.id = p_id and u.grupo_id is not null
    union
    select p_grupo_id where p_grupo_id is not null
  ) t;

  perform public.atualizar_usuario_grupos(p_id, p_nome, v_grupos, p_ativo);
end;
$$;

-- 4) PERMISSÕES DE EXECUÇÃO
revoke all on function
  public.usuario_no_grupo(uuid, uuid), public.usuarios_sincroniza_grupo_principal()
  from public, anon, authenticated;

revoke all on function
  public.listar_grupos_dos_usuarios(), public.atualizar_usuario_grupos(uuid, text, uuid[], boolean)
  from public, anon;
grant execute on function
  public.listar_grupos_dos_usuarios(), public.atualizar_usuario_grupos(uuid, text, uuid[], boolean)
  to authenticated;

-- 5) VERIFICAÇÃO DE SEGURANÇA: o Administrador precisa continuar com acesso e permissões.
--    Se falhar, a migração INTEIRA é desfeita (nada fica alterado).
do $$
declare
  v_admin uuid;
  v_qtd   int;
begin
  select u.id into v_admin
  from public.usuarios u join public.grupos g on g.id = u.grupo_id
  where g.sistema and g.nome = 'Administrador' and u.ativo
  limit 1;

  if v_admin is null then
    return;  -- ainda não há administrador: nada a verificar
  end if;

  perform set_config('request.jwt.claims', json_build_object('sub', v_admin, 'role', 'authenticated')::text, true);

  select coalesce(array_length(m.permissoes, 1), 0) into v_qtd from public.minha_conta() m;

  if not public.tem_acesso()
     or not public.tem_permissao('usuarios.editar')
     or not public.tem_permissao('grupos.editar')
     or v_qtd = 0 then
    raise exception 'Verificação falhou: o Administrador perderia o acesso. Nada foi alterado.';
  end if;

  perform set_config('request.jwt.claims', '', true);
end $$;

commit;
