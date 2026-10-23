-- Reverte a 0062: a Auditoria volta a mostrar tudo para quem tem a permissão; o Regional perde auditoria.visualizar.
begin;
delete from public.grupo_permissoes gp using public.grupos g
 where g.id = gp.grupo_id and g.nome = 'Administrador Regional' and gp.permissao_codigo = 'auditoria.visualizar';

create or replace function public.opcoes_auditoria() returns table(tipo text, valor text, rotulo text) language plpgsql stable security definer set search_path to 'public' as $function$
begin
  perform public.exigir_permissao('auditoria.visualizar');
  return query
    select 'USUARIO'::text, u.id::text, u.nome from public.usuarios u
    union all
    select 'ENTIDADE'::text, x.entidade, x.entidade from (select distinct a.entidade from public.auditoria a) x
    union all
    select 'ACAO'::text, y.acao, y.acao from (select distinct a.acao from public.auditoria a) y;
end; $function$;

create or replace function public.listar_auditoria(p_inicio timestamp with time zone, p_fim timestamp with time zone, p_usuario uuid, p_entidade text, p_acao text, p_busca text, p_limite integer, p_deslocamento integer)
 returns table(id text, ocorrido_em timestamp with time zone, usuario_id uuid, usuario_nome text, acao text, entidade text, entidade_id uuid, detalhes jsonb, total bigint)
 language plpgsql stable security definer set search_path to 'public' as $function$
declare
  v_lim   int  := least(greatest(coalesce(p_limite, 50), 1), 2000);
  v_off   int  := greatest(coalesce(p_deslocamento, 0), 0);
  v_busca text := nullif(btrim(coalesce(p_busca, '')), '');
  v_like  text;
begin
  perform public.exigir_permissao('auditoria.visualizar');
  v_like := case when v_busca is null then null
                 else '%' || replace(replace(replace(v_busca, '\', '\\'), '%', '\%'), '_', '\_') || '%' end;
  return query
    select a.id::text, a.ocorrido_em, a.usuario_id, u.nome, a.acao, a.entidade, a.entidade_id, a.detalhes, count(*) over ()
    from public.auditoria a left join public.usuarios u on u.id = a.usuario_id
    where (p_inicio is null or a.ocorrido_em >= p_inicio)
      and (p_fim is null or a.ocorrido_em < p_fim)
      and (p_usuario is null or a.usuario_id = p_usuario)
      and (nullif(p_entidade, '') is null or a.entidade = p_entidade)
      and (nullif(p_acao, '') is null or a.acao = p_acao)
      and (v_like is null or a.detalhes::text ilike v_like or coalesce(u.nome, '') ilike v_like)
    order by a.ocorrido_em desc, a.id desc
    limit v_lim offset v_off;
end; $function$;

drop function if exists public.auditoria_na_abrangencia(text, uuid, uuid);
commit;
