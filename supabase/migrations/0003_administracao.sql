-- =====================================================================
-- SysMúsica — Migração 0003: administração de usuários, grupos e permissões
--
-- O que esta migração faz:
--   * cria as permissões do módulo Administração (usuarios.* e grupos.*) e libera todas
--     para o grupo Administrador;
--   * cria funções protegidas que a tela usa para listar, criar, editar e excluir
--     grupos, definir as permissões de cada grupo e editar usuários;
--   * garante regras de segurança no banco: não é possível excluir/desativar o grupo
--     Administrador, remover o último administrador ativo ou desativar a própria conta.
--
-- É IDEMPOTENTE e roda em uma única transação. Aplique depois do 0002.
-- Criar contas de login e redefinir senhas NÃO passa por aqui: isso é feito pelo servidor
-- da aplicação (precisa da variável SUPABASE_SERVICE_ROLE_KEY no .env.local).
-- =====================================================================
begin;

-- ---------------------------------------------------------------------
-- 1) NOVAS PERMISSÕES (mantenha igual a CATALOGO_PERMISSOES em src/lib/permissoes.ts)
-- ---------------------------------------------------------------------
insert into public.permissoes (codigo, modulo, acao, descricao) values
  ('usuarios.visualizar', 'Usuários',            'Visualizar', 'Ver a lista de usuários'),
  ('usuarios.criar',      'Usuários',            'Criar',      'Criar novos usuários'),
  ('usuarios.editar',     'Usuários',            'Editar',     'Editar usuários, trocar o grupo, ativar/desativar e redefinir a senha'),
  ('grupos.visualizar',   'Grupos e permissões', 'Visualizar', 'Ver os grupos e as permissões de cada um'),
  ('grupos.criar',        'Grupos e permissões', 'Criar',      'Criar novos grupos'),
  ('grupos.editar',       'Grupos e permissões', 'Editar',     'Editar grupos e definir as permissões de cada grupo'),
  ('grupos.excluir',      'Grupos e permissões', 'Excluir',    'Excluir grupos que não tenham usuários')
on conflict (codigo) do update
  set modulo = excluded.modulo, acao = excluded.acao, descricao = excluded.descricao;

-- O grupo Administrador (protegido) sempre recebe TODAS as permissões do catálogo
insert into public.grupo_permissoes (grupo_id, permissao_codigo)
select g.id, p.codigo
from public.grupos g
cross join public.permissoes p
where g.sistema and g.nome = 'Administrador'
on conflict do nothing;

-- Dois grupos não podem ter o mesmo nome, mesmo com maiúsculas/minúsculas diferentes
create unique index if not exists grupos_nome_lower_unico on public.grupos (lower(nome));

-- ---------------------------------------------------------------------
-- 2) FUNÇÕES AUXILIARES (uso interno: não são expostas ao navegador)
-- ---------------------------------------------------------------------

-- Interrompe a operação (erro 42501) se o usuário logado não tiver a permissão
create or replace function public.exigir_permissao(p_codigo text)
returns void
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if not public.tem_permissao(p_codigo) then
    raise exception 'Você não tem permissão para esta operação.' using errcode = '42501';
  end if;
end;
$$;

-- Interrompe a operação se o usuário logado não tiver NENHUMA das permissões
create or replace function public.exigir_alguma_permissao(p_codigos text[])
returns void
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if not public.tem_alguma_permissao(p_codigos) then
    raise exception 'Você não tem permissão para esta operação.' using errcode = '42501';
  end if;
end;
$$;

-- Confere se todos os códigos informados existem no catálogo de permissões
create or replace function public.validar_codigos_permissao(p_codigos text[])
returns void
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if exists (
    select 1
    from unnest(coalesce(p_codigos, '{}'::text[])) as c(codigo)
    where not exists (select 1 from public.permissoes p where p.codigo = c.codigo)
  ) then
    raise exception 'A lista contém uma permissão desconhecida.';
  end if;
end;
$$;

-- ---------------------------------------------------------------------
-- 3) FUNÇÕES DE CONSULTA (a tela chama estas funções; o acesso direto às tabelas segue bloqueado)
-- ---------------------------------------------------------------------

-- Catálogo de permissões (para montar a grade de permissões do grupo)
create or replace function public.listar_permissoes()
returns table (codigo text, modulo text, acao text, descricao text)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  perform public.exigir_alguma_permissao(array[
    'grupos.visualizar', 'grupos.criar', 'grupos.editar', 'usuarios.visualizar'
  ]);
  return query
    select p.codigo, p.modulo, p.acao, p.descricao
    from public.permissoes p
    order by p.modulo, p.codigo;
end;
$$;

-- Grupos, com quantidade de usuários e lista de permissões de cada um
create or replace function public.listar_grupos()
returns table (
  id uuid, nome text, descricao text, ativo boolean, sistema boolean,
  qtd_usuarios bigint, permissoes text[]
)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  perform public.exigir_alguma_permissao(array[
    'grupos.visualizar', 'grupos.criar', 'grupos.editar',
    'usuarios.visualizar', 'usuarios.criar', 'usuarios.editar'
  ]);
  return query
    select g.id, g.nome, g.descricao, g.ativo, g.sistema,
           (select count(*) from public.usuarios u where u.grupo_id = g.id),
           coalesce(
             array(select gp.permissao_codigo from public.grupo_permissoes gp
                   where gp.grupo_id = g.id order by gp.permissao_codigo),
             '{}'::text[]
           )
    from public.grupos g
    order by g.sistema desc, g.nome;
end;
$$;

-- Usuários, com o grupo e a data do último acesso
create or replace function public.listar_usuarios()
returns table (
  id uuid, nome text, email text, grupo_id uuid, grupo_nome text,
  ativo boolean, ultimo_acesso timestamptz, criado_em timestamptz
)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  perform public.exigir_permissao('usuarios.visualizar');
  return query
    select u.id, u.nome, u.email, u.grupo_id, g.nome, u.ativo, a.last_sign_in_at, u.criado_em
    from public.usuarios u
    left join public.grupos g on g.id = u.grupo_id
    left join auth.users a on a.id = u.id
    order by u.nome;
end;
$$;

-- ---------------------------------------------------------------------
-- 4) FUNÇÕES DE ALTERAÇÃO DE GRUPOS
-- ---------------------------------------------------------------------

-- Cria um grupo já com as suas permissões (tudo ou nada). Devolve o id do grupo.
create or replace function public.criar_grupo(p_nome text, p_descricao text, p_permissoes text[])
returns uuid
language plpgsql
security definer
set search_path = public
as $$
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
$$;

-- Atualiza nome, descrição, status e permissões de um grupo.
-- Grupo protegido (Administrador): só a descrição muda; ele sempre mantém todas as permissões.
create or replace function public.atualizar_grupo(
  p_id uuid, p_nome text, p_descricao text, p_ativo boolean, p_permissoes text[]
)
returns void
language plpgsql
security definer
set search_path = public
as $$
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
$$;

-- Exclui um grupo: bloqueia o grupo protegido e grupos que ainda tenham usuários
create or replace function public.excluir_grupo(p_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
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
  if exists (select 1 from public.usuarios u where u.grupo_id = p_id) then
    raise exception 'Este grupo ainda tem usuários. Mova-os para outro grupo antes de excluir.';
  end if;

  delete from public.grupos where id = p_id;
end;
$$;

-- ---------------------------------------------------------------------
-- 5) ALTERAÇÃO DE USUÁRIOS (nome, grupo e status)
--    Regras: não desativar a própria conta; não deixar o sistema sem administrador ativo.
-- ---------------------------------------------------------------------
create or replace function public.atualizar_usuario(
  p_id uuid, p_nome text, p_grupo_id uuid, p_ativo boolean
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_usuario     public.usuarios;
  v_grupo_admin uuid;
  v_nome        text := btrim(coalesce(p_nome, ''));
  v_ativo       boolean;
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
  if p_grupo_id is not null
     and not exists (select 1 from public.grupos g where g.id = p_grupo_id) then
    raise exception 'Grupo não encontrado.';
  end if;
  if p_id = (select auth.uid()) and not v_ativo then
    raise exception 'Você não pode desativar a sua própria conta.';
  end if;

  -- Proteção do último administrador ativo
  select g.id into v_grupo_admin from public.grupos g where g.sistema and g.nome = 'Administrador';
  if v_usuario.grupo_id is not distinct from v_grupo_admin
     and v_usuario.ativo
     and (p_grupo_id is distinct from v_grupo_admin or not v_ativo) then
    if not exists (
      select 1 from public.usuarios u
      where u.grupo_id = v_grupo_admin and u.ativo and u.id <> p_id
    ) then
      raise exception 'Não é possível: este é o último administrador ativo do sistema.';
    end if;
  end if;

  update public.usuarios
     set nome = v_nome, grupo_id = p_grupo_id, ativo = v_ativo
   where id = p_id;
end;
$$;

-- ---------------------------------------------------------------------
-- 6) PERMISSÕES DE EXECUÇÃO
--    Funções auxiliares: só o próprio banco as usa. Funções da tela: só usuários logados.
--    (Também fecha para anônimos as funções criadas no 0002.)
-- ---------------------------------------------------------------------
revoke all on function
  public.exigir_permissao(text),
  public.exigir_alguma_permissao(text[]),
  public.validar_codigos_permissao(text[])
  from public, anon, authenticated;

revoke all on function
  public.listar_permissoes(),
  public.listar_grupos(),
  public.listar_usuarios(),
  public.criar_grupo(text, text, text[]),
  public.atualizar_grupo(uuid, text, text, boolean, text[]),
  public.excluir_grupo(uuid),
  public.atualizar_usuario(uuid, text, uuid, boolean)
  from public, anon;

grant execute on function
  public.listar_permissoes(),
  public.listar_grupos(),
  public.listar_usuarios(),
  public.criar_grupo(text, text, text[]),
  public.atualizar_grupo(uuid, text, text, boolean, text[]),
  public.excluir_grupo(uuid),
  public.atualizar_usuario(uuid, text, uuid, boolean)
  to authenticated;

revoke all on function
  public.tem_alguma_permissao(text[]),
  public.tem_permissao(text),
  public.tem_acesso(),
  public.minha_conta()
  from anon;

commit;
