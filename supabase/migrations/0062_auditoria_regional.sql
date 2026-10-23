-- 0062 — Isolamento regional (Etapa 3): a Auditoria passa a mostrar a cada pessoa só o que é da sua região.
-- Um registro de auditoria é visível para quem NÃO tem acesso global quando:
--   (a) foi feito por ele mesmo ou por usuário da abrangência dele; OU
--   (b) trata de item que está na abrangência dele (evento, portaria, membro, presença, estrutura da Organização, usuário).
-- Ações globais (catálogos, grupos, backup) só o Administrador global enxerga. O administrador global continua vendo tudo.
-- A lista de usuários do filtro também respeita a região. O Administrador Regional passa a ter "auditoria.visualizar".
-- Seguro rodar mais de uma vez. Reverter: supabase/rollback/0062_reverter.sql

begin;

-- A) Este registro de auditoria está na abrangência de quem chama?
create or replace function public.auditoria_na_abrangencia(p_entidade text, p_entidade_id uuid, p_usuario uuid)
returns boolean
language sql
stable
security definer
set search_path to 'public'
as $function$
  select public.tem_acesso_total_organizacao()
      or (p_usuario is not null and (p_usuario = (select auth.uid()) or public.usuario_na_minha_abrangencia(p_usuario)))
      or (p_entidade_id is not null and case p_entidade
            when 'estado'      then public.alvo_na_minha_abrangencia('ESTADO', p_entidade_id)
            when 'rrm'         then public.alvo_na_minha_abrangencia('RRM', p_entidade_id)
            when 'ra'          then public.alvo_na_minha_abrangencia('RA', p_entidade_id)
            when 'adm'         then public.alvo_na_minha_abrangencia('ADM', p_entidade_id)
            when 'setor'       then public.alvo_na_minha_abrangencia('SETOR', p_entidade_id)
            when 'casa_oracao' then public.alvo_na_minha_abrangencia('CASA_ORACAO', p_entidade_id)
            when 'usuario'     then public.usuario_na_minha_abrangencia(p_entidade_id)
            when 'evento'      then public.evento_na_abrangencia(p_entidade_id)
            when 'portaria'    then exists (select 1 from public.portarias x where x.id = p_entidade_id
                                             and public.casa_oracao_na_abrangencia(x.casa_oracao_id))
            when 'membro'      then exists (select 1 from public.membros x where x.id = p_entidade_id
                                             and public.casa_oracao_na_abrangencia(x.casa_oracao_id))
            when 'presenca'    then exists (select 1 from public.presencas x where x.id = p_entidade_id
                                             and public.evento_na_abrangencia(x.evento_id))
            else false
          end)
$function$;

revoke all on function public.auditoria_na_abrangencia(text, uuid, uuid) from public, anon;
grant execute on function public.auditoria_na_abrangencia(text, uuid, uuid) to authenticated;

-- B) listar_auditoria: o resto é IGUAL ao de produção; entra o filtro de abrangência
create or replace function public.listar_auditoria(p_inicio timestamp with time zone, p_fim timestamp with time zone, p_usuario uuid, p_entidade text, p_acao text, p_busca text, p_limite integer, p_deslocamento integer)
 returns table(id text, ocorrido_em timestamp with time zone, usuario_id uuid, usuario_nome text, acao text, entidade text, entidade_id uuid, detalhes jsonb, total bigint)
 language plpgsql
 stable security definer
 set search_path to 'public'
as $function$
declare
  v_lim   int  := least(greatest(coalesce(p_limite, 50), 1), 2000);
  v_off   int  := greatest(coalesce(p_deslocamento, 0), 0);
  v_busca text := nullif(btrim(coalesce(p_busca, '')), '');
  v_like  text;
begin
  perform public.exigir_permissao('auditoria.visualizar');
  -- A busca é texto simples (os símbolos de coringa são tratados como letras)
  v_like := case when v_busca is null then null
                 else '%' || replace(replace(replace(v_busca, '\', '\\'), '%', '\%'), '_', '\_') || '%' end;

  return query
    select a.id::text, a.ocorrido_em, a.usuario_id, u.nome, a.acao, a.entidade, a.entidade_id, a.detalhes,
           count(*) over ()
    from public.auditoria a
    left join public.usuarios u on u.id = a.usuario_id
    where public.auditoria_na_abrangencia(a.entidade, a.entidade_id, a.usuario_id)
      and (p_inicio is null or a.ocorrido_em >= p_inicio)
      and (p_fim is null or a.ocorrido_em < p_fim)
      and (p_usuario is null or a.usuario_id = p_usuario)
      and (nullif(p_entidade, '') is null or a.entidade = p_entidade)
      and (nullif(p_acao, '') is null or a.acao = p_acao)
      and (v_like is null or a.detalhes::text ilike v_like or coalesce(u.nome, '') ilike v_like)
    order by a.ocorrido_em desc, a.id desc
    limit v_lim offset v_off;
end;
$function$;

-- C) opcoes_auditoria: usuários, entidades e ações só do que a pessoa pode ver
create or replace function public.opcoes_auditoria()
 returns table(tipo text, valor text, rotulo text)
 language plpgsql
 stable security definer
 set search_path to 'public'
as $function$
begin
  perform public.exigir_permissao('auditoria.visualizar');
  return query
    select 'USUARIO'::text, u.id::text, u.nome from public.usuarios u
     where public.tem_acesso_total_organizacao() or u.id = (select auth.uid()) or public.usuario_na_minha_abrangencia(u.id)
    union all
    select 'ENTIDADE'::text, x.entidade, x.entidade
      from (select distinct a.entidade from public.auditoria a
             where public.auditoria_na_abrangencia(a.entidade, a.entidade_id, a.usuario_id)) x
    union all
    select 'ACAO'::text, y.acao, y.acao
      from (select distinct a.acao from public.auditoria a
             where public.auditoria_na_abrangencia(a.entidade, a.entidade_id, a.usuario_id)) y;
end;
$function$;

-- D) O Administrador Regional passa a poder abrir a Auditoria (agora só vê a região dele)
insert into public.grupo_permissoes (grupo_id, permissao_codigo)
select g.id, 'auditoria.visualizar'
  from public.grupos g
 where g.nome = 'Administrador Regional'
   and exists (select 1 from public.permissoes p where p.codigo = 'auditoria.visualizar')
on conflict do nothing;

do $$
begin
  if (select prosrc from pg_proc where oid = 'public.listar_auditoria(timestamptz,timestamptz,uuid,text,text,text,integer,integer)'::regprocedure)
       not like '%auditoria_na_abrangencia%'
     or (select prosrc from pg_proc where oid = 'public.opcoes_auditoria()'::regprocedure) not like '%auditoria_na_abrangencia%' then
    raise exception 'Verificação falhou: as funções de auditoria não foram atualizadas.';
  end if;
end $$;

commit;
