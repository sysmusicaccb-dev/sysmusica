-- 0054 — Isolamento regional, ETAPA 1: delegação hierárquica de usuários + permissão "Acesso global".
--
-- O que muda:
--  * Nova permissão  acesso.global  = chave-mestra (enxerga e administra TODAS as regiões). Só o grupo Administrador a recebe.
--    A função tem_acesso_total_organizacao() passa a depender SÓ dela (antes: organizacao.acesso_total OU portarias.controle_total).
--    portarias.controle_total continua existindo, mas só dispensa limite diário/janela/autoaprovação: NÃO dá mais acesso a outras regiões.
--  * Usuários e vínculos passam a respeitar a hierarquia: quem não é global só vê/edita usuários da própria abrangência,
--    só concede vínculos dentro dela e só concede grupos cujas permissões ele mesmo possui. Ninguém altera os próprios grupos/vínculos.
--  * Criar/editar/excluir GRUPOS fica só com o administrador global.
--  * Estrutura da Organização (estados, RRMs, RAs, ADMs, setores, casas): gatilho impede mexer fora da própria abrangência.
--  * Novo grupo "Administrador Regional" (sem Acesso global, sem Backup, sem Auditoria nesta etapa).
--  * Coluna usuarios.criado_por: quem cria um usuário continua enxergando-o até definir os vínculos dele.
--
-- Seguro rodar mais de uma vez. Tudo roda numa transação: se algo falhar, nada é aplicado.
-- Reverter: ver 0054_reverter.sql.

begin;

-- ============================================================ A) Permissão Acesso global
insert into public.permissoes (codigo, modulo, acao, descricao)
values ('acesso.global', 'Acesso', 'Global',
        'Chave-mestra: enxerga e administra todas as regiões. Só o grupo Administrador deve ter.')
on conflict (codigo) do nothing;

-- Quem já tinha acesso total à organização (hoje só o Administrador) continua com acesso global
insert into public.grupo_permissoes (grupo_id, permissao_codigo)
select distinct gp.grupo_id, 'acesso.global'
  from public.grupo_permissoes gp
 where gp.permissao_codigo = 'organizacao.acesso_total'
on conflict do nothing;

insert into public.grupo_permissoes (grupo_id, permissao_codigo)
select g.id, 'acesso.global' from public.grupos g where g.sistema and g.nome = 'Administrador'
on conflict do nothing;

-- ============================================================ B) Coluna criado_por
alter table public.usuarios
  add column if not exists criado_por uuid references public.usuarios(id) on delete set null;

-- ============================================================ C) Acesso global passa a depender só de acesso.global
create or replace function public.tem_acesso_total_organizacao()
returns boolean
language sql
stable
security definer
set search_path to 'public'
as $function$
  select public.tem_permissao('acesso.global')
$function$;

-- ============================================================ D) Funções auxiliares da hierarquia
-- Cadeia de um item da organização: ele mesmo e todos os níveis acima (setor, ADM, RA, RRM, estado).
create or replace function public.cadeia_organizacao(p_nivel text, p_alvo uuid)
returns table(r_nivel text, r_id uuid)
language plpgsql
stable
security definer
set search_path to 'public'
as $function$
declare
  v_setor  uuid;
  v_adm    uuid;
  v_ra     uuid;
  v_rrm    uuid;
  v_estado uuid;
begin
  if p_alvo is null or p_nivel is null
     or p_nivel not in ('ESTADO', 'RRM', 'RA', 'ADM', 'SETOR', 'CASA_ORACAO') then
    return;
  end if;

  r_nivel := p_nivel; r_id := p_alvo; return next;   -- o próprio item

  if p_nivel = 'CASA_ORACAO' then
    select c.setor_id, c.adm_id into v_setor, v_adm from public.casas_oracao c where c.id = p_alvo;
    if not found then return; end if;
    if v_setor is not null then
      r_nivel := 'SETOR'; r_id := v_setor; return next;
      if v_adm is null then
        select s.adm_id into v_adm from public.setores s where s.id = v_setor;
      end if;
    end if;
  elsif p_nivel = 'SETOR' then
    select s.adm_id into v_adm from public.setores s where s.id = p_alvo;
    if not found then return; end if;
  elsif p_nivel = 'ADM' then
    v_adm := p_alvo;
  elsif p_nivel = 'RA' then
    v_ra := p_alvo;
  elsif p_nivel = 'RRM' then
    v_rrm := p_alvo;
  end if;

  if v_adm is not null then
    if p_nivel <> 'ADM' then r_nivel := 'ADM'; r_id := v_adm; return next; end if;
    select a.ra_id into v_ra from public.adms a where a.id = v_adm;
  end if;
  if v_ra is not null then
    if p_nivel <> 'RA' then r_nivel := 'RA'; r_id := v_ra; return next; end if;
    select r.rrm_id into v_rrm from public.ras r where r.id = v_ra;
  end if;
  if v_rrm is not null then
    if p_nivel <> 'RRM' then r_nivel := 'RRM'; r_id := v_rrm; return next; end if;
    select rr.estado_id into v_estado from public.rrms rr where rr.id = v_rrm;
  end if;
  if v_estado is not null and p_nivel <> 'ESTADO' then
    r_nivel := 'ESTADO'; r_id := v_estado; return next;
  end if;
end;
$function$;

-- O item está dentro da abrangência de quem chama? (global: sempre; senão, algum vínculo dele cobre o item ou um nível acima)
create or replace function public.alvo_na_minha_abrangencia(p_nivel text, p_alvo uuid)
returns boolean
language sql
stable
security definer
set search_path to 'public'
as $function$
  select public.tem_acesso_total_organizacao()
      or (p_alvo is not null and exists (
            select 1
              from public.usuario_vinculos v
              join lateral public.cadeia_organizacao(p_nivel, p_alvo) c
                on c.r_nivel = v.nivel and c.r_id = v.alvo_id
             where v.usuario_id = (select auth.uid())))
$function$;

-- O usuário tem acesso global (chave-mestra) por algum grupo ativo?
create or replace function public.usuario_e_global(p_usuario uuid)
returns boolean
language sql
stable
security definer
set search_path to 'public'
as $function$
  select exists (
    select 1
      from public.usuarios u
      join public.grupos g
        on g.ativo
       and (g.id = u.grupo_id
            or exists (select 1 from public.usuario_grupos ug where ug.usuario_id = u.id and ug.grupo_id = g.id))
      join public.grupo_permissoes gp on gp.grupo_id = g.id and gp.permissao_codigo = 'acesso.global'
     where u.id = p_usuario)
$function$;

-- O usuário alvo está na abrangência de quem chama? (a própria conta NÃO conta: ninguém muda os próprios acessos)
--  * global: sempre
--  * alvo global: nunca (para quem não é global)
--  * alvo com vínculos: todos dentro da abrangência de quem chama
--  * alvo ainda sem vínculos: só quem o criou
create or replace function public.usuario_na_minha_abrangencia(p_usuario uuid)
returns boolean
language sql
stable
security definer
set search_path to 'public'
as $function$
  select public.tem_acesso_total_organizacao()
      or (
        p_usuario is distinct from (select auth.uid())
        and not public.usuario_e_global(p_usuario)
        and (
          (exists (select 1 from public.usuario_vinculos v where v.usuario_id = p_usuario)
           and not exists (select 1 from public.usuario_vinculos v
                            where v.usuario_id = p_usuario
                              and not public.alvo_na_minha_abrangencia(v.nivel, v.alvo_id)))
          or
          (not exists (select 1 from public.usuario_vinculos v where v.usuario_id = p_usuario)
           and exists (select 1 from public.usuarios u
                        where u.id = p_usuario and u.criado_por = (select auth.uid())))
        )
      )
$function$;

-- Quem chama pode conceder este grupo? (global: sim; senão: grupo ativo cujas permissões ele mesmo possui todas)
create or replace function public.grupo_concedivel(p_grupo uuid)
returns boolean
language sql
stable
security definer
set search_path to 'public'
as $function$
  select public.tem_acesso_total_organizacao()
      or (
        exists (select 1 from public.grupos g where g.id = p_grupo and g.ativo)
        and not exists (select 1 from public.grupo_permissoes gp
                         where gp.grupo_id = p_grupo
                           and not public.tem_permissao(gp.permissao_codigo))
      )
$function$;

revoke all on function public.cadeia_organizacao(text, uuid), public.alvo_na_minha_abrangencia(text, uuid),
  public.usuario_e_global(uuid), public.usuario_na_minha_abrangencia(uuid), public.grupo_concedivel(uuid)
  from public, anon;
grant execute on function public.cadeia_organizacao(text, uuid), public.alvo_na_minha_abrangencia(text, uuid),
  public.usuario_e_global(uuid), public.usuario_na_minha_abrangencia(uuid), public.grupo_concedivel(uuid)
  to authenticated;

-- ============================================================ E) Usuários: listas filtradas por abrangência
create or replace function public.listar_usuarios()
 returns table(id uuid, nome text, email text, grupo_id uuid, grupo_nome text, ativo boolean, ultimo_acesso timestamp with time zone, criado_em timestamp with time zone)
 language plpgsql
 stable security definer
 set search_path to 'public'
as $function$
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
    -- global vê todos; os demais veem a própria conta e os usuários da sua abrangência
    where public.tem_acesso_total_organizacao()
       or u.id = (select auth.uid())
       or public.usuario_na_minha_abrangencia(u.id)
    order by u.nome;
end;
$function$;

create or replace function public.listar_grupos_dos_usuarios()
 returns table(usuario_id uuid, grupos uuid[])
 language plpgsql
 stable security definer
 set search_path to 'public'
as $function$
begin
  perform public.exigir_alguma_permissao(array['usuarios.visualizar', 'usuarios.criar', 'usuarios.editar']);
  return query
    select u.id,
           array(select distinct t.x
                   from (select ug.grupo_id as x from public.usuario_grupos ug where ug.usuario_id = u.id
                         union
                         select u.grupo_id where u.grupo_id is not null) t
                  order by t.x)
    from public.usuarios u
    where public.tem_acesso_total_organizacao()
       or u.id = (select auth.uid())
       or public.usuario_na_minha_abrangencia(u.id);
end;
$function$;

create or replace function public.listar_vinculos_rotulados()
 returns table(usuario_id uuid, nivel text, alvo_id uuid, rotulo text)
 language plpgsql
 stable security definer
 set search_path to 'public'
as $function$
begin
  perform public.exigir_permissao('usuarios.visualizar');
  return query
    select v.usuario_id, v.nivel, v.alvo_id, public.rotulo_vinculo(v.nivel, v.alvo_id)
    from public.usuario_vinculos v
    where public.rotulo_vinculo(v.nivel, v.alvo_id) is not null
      and (public.tem_acesso_total_organizacao()
           or v.usuario_id = (select auth.uid())
           or public.usuario_na_minha_abrangencia(v.usuario_id))
    order by v.usuario_id, 4;
end;
$function$;

-- Grupos: quem não é global só enxerga os grupos que pode conceder; a contagem de usuários também respeita a abrangência
create or replace function public.listar_grupos()
 returns table(id uuid, nome text, descricao text, ativo boolean, sistema boolean, qtd_usuarios bigint, permissoes text[])
 language plpgsql
 stable security definer
 set search_path to 'public'
as $function$
begin
  perform public.exigir_alguma_permissao(array[
    'grupos.visualizar', 'grupos.criar', 'grupos.editar',
    'usuarios.visualizar', 'usuarios.criar', 'usuarios.editar'
  ]);
  return query
    select g.id, g.nome, g.descricao, g.ativo, g.sistema,
           (select count(*) from public.usuarios u
             where (u.grupo_id = g.id
                    or exists (select 1 from public.usuario_grupos ug
                                where ug.usuario_id = u.id and ug.grupo_id = g.id))
               and (public.tem_acesso_total_organizacao()
                    or u.id = (select auth.uid())
                    or public.usuario_na_minha_abrangencia(u.id))),
           coalesce(
             array(select gp.permissao_codigo from public.grupo_permissoes gp
                   where gp.grupo_id = g.id order by gp.permissao_codigo),
             '{}'::text[]
           )
    from public.grupos g
    where public.tem_acesso_total_organizacao() or public.grupo_concedivel(g.id)
    order by g.sistema desc, g.nome;
end;
$function$;

-- ============================================================ F) Usuários: alterar grupos (com as travas de hierarquia)
create or replace function public.atualizar_usuario_grupos(p_id uuid, p_nome text, p_grupos uuid[], p_ativo boolean)
 returns void
 language plpgsql
 security definer
 set search_path to 'public'
as $function$
declare
  v_usuario     public.usuarios;
  v_grupo_admin uuid;
  v_nome        text := btrim(coalesce(p_nome, ''));
  v_ativo       boolean;
  v_grupos      uuid[];
  v_principal   uuid;
  v_era_admin   boolean;
  v_sera_admin  boolean;
  v_global      boolean := public.tem_acesso_total_organizacao();
  v_uid         uuid := (select auth.uid());
  v_atuais      uuid[];
  v_g           uuid;
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
  if p_id = v_uid and not v_ativo then
    raise exception 'Você não pode desativar a sua própria conta.';
  end if;

  -- Grupos que o usuário já tem hoje
  select coalesce(array_agg(distinct t.x), '{}'::uuid[]) into v_atuais
  from (
    select ug.grupo_id as x from public.usuario_grupos ug where ug.usuario_id = p_id
    union
    select v_usuario.grupo_id where v_usuario.grupo_id is not null
  ) t;

  -- Travas da hierarquia (o administrador global não tem estas travas)
  if not v_global then
    if p_id = v_uid then
      -- A própria conta: pode mudar o nome, mas não os próprios grupos
      if (select coalesce(array_agg(x order by x), '{}'::uuid[]) from unnest(v_grupos) x)
         is distinct from (select coalesce(array_agg(x order by x), '{}'::uuid[]) from unnest(v_atuais) x) then
        raise exception 'Você não pode alterar os seus próprios grupos.' using errcode = '42501';
      end if;
    elsif not public.usuario_na_minha_abrangencia(p_id) then
      raise exception 'Este usuário está fora da sua abrangência.' using errcode = '42501';
    else
      -- Só concede grupos que ele mesmo pode conceder (ou que o usuário já tinha)
      foreach v_g in array v_grupos loop
        if not public.grupo_concedivel(v_g) and not (v_g = any (v_atuais)) then
          raise exception 'Você não pode conceder o grupo "%".',
            (select g.nome from public.grupos g where g.id = v_g) using errcode = '42501';
        end if;
      end loop;
      -- Grupos atuais que ele não pode conceder (e nem enxerga) ficam como estão
      select coalesce(array_agg(distinct t.x), '{}'::uuid[]) into v_grupos
      from (
        select unnest(v_grupos) as x
        union
        select a.x from unnest(v_atuais) as a(x) where not public.grupo_concedivel(a.x)
      ) t;
    end if;
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

-- ============================================================ G) Vínculos (com as travas de hierarquia)
create or replace function public.definir_vinculos(p_usuario uuid, p_vinculos jsonb)
 returns void
 language plpgsql
 security definer
 set search_path to 'public'
as $function$
declare
  v_item   jsonb;
  v_nivel  text;
  v_alvo   uuid;
  v_lista  jsonb := coalesce(p_vinculos, '[]'::jsonb);
  v_ok     boolean;
  v_global boolean := public.tem_acesso_total_organizacao();
begin
  perform public.exigir_permissao('usuarios.vinculos');

  if not exists (select 1 from public.usuarios u where u.id = p_usuario) then
    raise exception 'Usuário não encontrado.';
  end if;
  if jsonb_typeof(v_lista) <> 'array' then
    raise exception 'Vínculos inválidos.';
  end if;

  -- Quem não é global: nunca mexe nos próprios vínculos nem nos de quem está fora da sua abrangência
  if not v_global then
    if p_usuario = (select auth.uid()) then
      raise exception 'Você não pode alterar os seus próprios vínculos.' using errcode = '42501';
    end if;
    if not public.usuario_na_minha_abrangencia(p_usuario) then
      raise exception 'Este usuário está fora da sua abrangência.' using errcode = '42501';
    end if;
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
    -- Só concede vínculo dentro da própria abrangência (a transação inteira é desfeita se falhar)
    if not v_global and not public.alvo_na_minha_abrangencia(v_nivel, v_alvo) then
      raise exception 'O vínculo "%" está fora da sua abrangência.', public.rotulo_vinculo(v_nivel, v_alvo)
        using errcode = '42501';
    end if;
    insert into public.usuario_vinculos (usuario_id, nivel, alvo_id) values (p_usuario, v_nivel, v_alvo)
    on conflict do nothing;
  end loop;

  perform public.registrar_auditoria('vinculos_definidos', 'usuario', p_usuario,
            jsonb_build_object('vinculos', v_lista));
end;
$function$;

-- ============================================================ H) Grupos: só o administrador global cria, edita e exclui
create or replace function public.criar_grupo(p_nome text, p_descricao text, p_permissoes text[])
 returns uuid
 language plpgsql
 security definer
 set search_path to 'public'
as $function$
declare
  v_id   uuid;
  v_nome text := btrim(coalesce(p_nome, ''));
  v_desc text := nullif(btrim(coalesce(p_descricao, '')), '');
begin
  perform public.exigir_permissao('grupos.criar');
  if not public.tem_acesso_total_organizacao() then
    raise exception 'Somente o administrador global gerencia grupos.' using errcode = '42501';
  end if;

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

create or replace function public.atualizar_grupo(p_id uuid, p_nome text, p_descricao text, p_ativo boolean, p_permissoes text[])
 returns void
 language plpgsql
 security definer
 set search_path to 'public'
as $function$
declare
  v_grupo public.grupos;
  v_nome  text    := btrim(coalesce(p_nome, ''));
  v_desc  text    := nullif(btrim(coalesce(p_descricao, '')), '');
  v_ativo boolean := coalesce(p_ativo, true);
begin
  perform public.exigir_permissao('grupos.editar');
  if not public.tem_acesso_total_organizacao() then
    raise exception 'Somente o administrador global gerencia grupos.' using errcode = '42501';
  end if;

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

create or replace function public.excluir_grupo(p_id uuid)
 returns void
 language plpgsql
 security definer
 set search_path to 'public'
as $function$
declare
  v_grupo public.grupos;
begin
  perform public.exigir_permissao('grupos.excluir');
  if not public.tem_acesso_total_organizacao() then
    raise exception 'Somente o administrador global gerencia grupos.' using errcode = '42501';
  end if;

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

-- ============================================================ I) Organização: lista filtrada + gatilho de escopo
create or replace function public.listar_organizacao()
 returns table(nivel text, id uuid, parent_id uuid, nome text, descricao text, ativo boolean, cidade text, bairro text, qtd_filhos bigint, qtd_membros bigint)
 language plpgsql
 stable security definer
 set search_path to 'public'
as $function$
declare
  v_global boolean := public.tem_acesso_total_organizacao();
begin
  perform public.exigir_alguma_permissao(array['organizacao.visualizar', 'usuarios.vinculos', 'usuarios.editar']);
  return query
    with todos(tn, ti, tp, tnome, tdesc, tativo, tcid, tbai, tfil, tmem) as (
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
      from public.casas_oracao c
    ),
    -- Os vínculos de quem chama e os níveis acima deles (para a árvore poder ser desenhada até o item)
    meus_nos(mn, mi) as (
      select c.r_nivel, c.r_id
        from public.usuario_vinculos v
        cross join lateral public.cadeia_organizacao(v.nivel, v.alvo_id) c
       where v.usuario_id = (select auth.uid())
    )
    select t.tn, t.ti, t.tp, t.tnome, t.tdesc, t.tativo, t.tcid, t.tbai, t.tfil, t.tmem
      from todos t
     where v_global
        or public.alvo_na_minha_abrangencia(t.tn, t.ti)
        or exists (select 1 from meus_nos m where m.mn = t.tn and m.mi = t.ti);
end;
$function$;

-- Gatilho: quem não é global só cria/altera/exclui itens da organização dentro da própria abrangência.
-- (Funciona também para transferir_casa_oracao, salvar_organizacao e excluir_organizacao, sem reescrevê-las.
--  Rotinas do sistema sem usuário logado, como a restauração de backup, não passam por esta trava.)
create or replace function public.org_exigir_escopo()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_uid        uuid := (select auth.uid());
  v_nivel      text;
  v_pai_nivel  text;
  v_pai_novo   uuid;
  v_pai_velho  uuid;
  v_ativo_vel  boolean;
  v_ativo_nov  boolean;
begin
  if v_uid is null or public.tem_acesso_total_organizacao() then
    return coalesce(new, old);
  end if;

  v_nivel := case tg_table_name
    when 'estados' then 'ESTADO' when 'rrms' then 'RRM' when 'ras' then 'RA'
    when 'adms' then 'ADM' when 'setores' then 'SETOR' else 'CASA_ORACAO' end;

  -- Pai novo (INSERT/UPDATE) e pai antigo (UPDATE): nível acima + id
  if tg_op in ('INSERT', 'UPDATE') then
    if tg_table_name = 'rrms' then v_pai_nivel := 'ESTADO'; v_pai_novo := new.estado_id;
    elsif tg_table_name = 'ras' then v_pai_nivel := 'RRM'; v_pai_novo := new.rrm_id;
    elsif tg_table_name = 'adms' then v_pai_nivel := 'RA'; v_pai_novo := new.ra_id;
    elsif tg_table_name = 'setores' then v_pai_nivel := 'ADM'; v_pai_novo := new.adm_id;
    elsif tg_table_name = 'casas_oracao' then
      if new.setor_id is not null then v_pai_nivel := 'SETOR'; v_pai_novo := new.setor_id;
      else v_pai_nivel := 'ADM'; v_pai_novo := new.adm_id; end if;
    end if;
  end if;

  if tg_op = 'INSERT' then
    if v_nivel = 'ESTADO' or not public.alvo_na_minha_abrangencia(v_pai_nivel, v_pai_novo) then
      raise exception 'Você só pode criar itens dentro da sua abrangência.' using errcode = '42501';
    end if;
    return new;

  elsif tg_op = 'UPDATE' then
    if not public.alvo_na_minha_abrangencia(v_nivel, old.id) then
      raise exception 'Este item da organização está fora da sua abrangência.' using errcode = '42501';
    end if;
    -- Mudou de lugar (ex.: transferência de casa): o destino também precisa estar na abrangência
    if tg_table_name = 'rrms' then v_pai_velho := old.estado_id;
    elsif tg_table_name = 'ras' then v_pai_velho := old.rrm_id;
    elsif tg_table_name = 'adms' then v_pai_velho := old.ra_id;
    elsif tg_table_name = 'setores' then v_pai_velho := old.adm_id;
    elsif tg_table_name = 'casas_oracao' then v_pai_velho := coalesce(old.setor_id, old.adm_id);
    end if;
    if v_nivel <> 'ESTADO' and v_pai_velho is distinct from v_pai_novo
       and not public.alvo_na_minha_abrangencia(v_pai_nivel, v_pai_novo) then
      raise exception 'O destino está fora da sua abrangência.' using errcode = '42501';
    end if;
    -- Não inativa o item ao qual o próprio usuário está vinculado (ele perderia o acesso)
    execute 'select ($1).ativo, ($2).ativo' into v_ativo_vel, v_ativo_nov using old, new;
    if v_ativo_vel and not coalesce(v_ativo_nov, true)
       and exists (select 1 from public.usuario_vinculos v
                    where v.usuario_id = v_uid and v.nivel = v_nivel and v.alvo_id = old.id) then
      raise exception 'Você não pode inativar o item ao qual você está vinculado.' using errcode = '42501';
    end if;
    return new;

  else  -- DELETE
    if not public.alvo_na_minha_abrangencia(v_nivel, old.id) then
      raise exception 'Este item da organização está fora da sua abrangência.' using errcode = '42501';
    end if;
    return old;
  end if;
end;
$function$;

drop trigger if exists trg_org_escopo on public.estados;
create trigger trg_org_escopo before insert or update or delete on public.estados
  for each row execute function public.org_exigir_escopo();
drop trigger if exists trg_org_escopo on public.rrms;
create trigger trg_org_escopo before insert or update or delete on public.rrms
  for each row execute function public.org_exigir_escopo();
drop trigger if exists trg_org_escopo on public.ras;
create trigger trg_org_escopo before insert or update or delete on public.ras
  for each row execute function public.org_exigir_escopo();
drop trigger if exists trg_org_escopo on public.adms;
create trigger trg_org_escopo before insert or update or delete on public.adms
  for each row execute function public.org_exigir_escopo();
drop trigger if exists trg_org_escopo on public.setores;
create trigger trg_org_escopo before insert or update or delete on public.setores
  for each row execute function public.org_exigir_escopo();
drop trigger if exists trg_org_escopo on public.casas_oracao;
create trigger trg_org_escopo before insert or update or delete on public.casas_oracao
  for each row execute function public.org_exigir_escopo();

-- ============================================================ J) Grupo "Administrador Regional"
insert into public.grupos (nome, descricao, ativo, sistema)
select 'Administrador Regional',
       'Administra os usuários e a estrutura da própria região (os níveis a que está vinculado e abaixo). Não tem acesso global.',
       true, false
 where not exists (select 1 from public.grupos where nome = 'Administrador Regional');

insert into public.grupo_permissoes (grupo_id, permissao_codigo)
select g.id, p.codigo
  from public.grupos g
  join public.permissoes p on p.codigo in (
         'usuarios.visualizar', 'usuarios.criar', 'usuarios.editar', 'usuarios.vinculos',
         'organizacao.visualizar', 'organizacao.criar', 'organizacao.editar')
 where g.nome = 'Administrador Regional'
on conflict do nothing;

-- ============================================================ K) Verificação (se falhar, nada é aplicado)
do $$
begin
  if not exists (select 1 from public.permissoes where codigo = 'acesso.global') then
    raise exception 'Verificação falhou: permissão acesso.global ausente.';
  end if;
  if not exists (select 1 from public.grupo_permissoes gp join public.grupos g on g.id = gp.grupo_id
                  where g.sistema and g.nome = 'Administrador' and gp.permissao_codigo = 'acesso.global') then
    raise exception 'Verificação falhou: o grupo Administrador não recebeu o acesso global.';
  end if;
  if (select prosrc from pg_proc where oid = 'public.tem_acesso_total_organizacao()'::regprocedure) not like '%acesso.global%' then
    raise exception 'Verificação falhou: tem_acesso_total_organizacao não foi atualizada.';
  end if;
  if (select count(*) from pg_trigger where tgname = 'trg_org_escopo' and not tgisinternal) <> 6 then
    raise exception 'Verificação falhou: gatilhos da organização incompletos.';
  end if;
  if (select count(*) from public.grupo_permissoes gp join public.grupos g on g.id = gp.grupo_id
       where g.nome = 'Administrador Regional') <> 7 then
    raise exception 'Verificação falhou: grupo Administrador Regional incompleto.';
  end if;
  if to_regprocedure('public.grupo_concedivel(uuid)') is null
     or to_regprocedure('public.usuario_na_minha_abrangencia(uuid)') is null
     or to_regprocedure('public.alvo_na_minha_abrangencia(text,uuid)') is null then
    raise exception 'Verificação falhou: funções auxiliares ausentes.';
  end if;
end $$;

commit;
