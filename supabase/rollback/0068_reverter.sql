-- Reverte a 0068: volta a função listar_cidades_conhecidas ao formato anterior (sem filtro de região).
create or replace function public.listar_cidades_conhecidas()
 returns table(cidade text)
 language plpgsql
 stable security definer
 set search_path to 'public'
as $function$
begin
  perform public.exigir_permissao('usuarios.editar');
  return query
    select distinct on (public.normalizar_texto(t.nome)) t.nome
    from (
      select btrim(e.cidade) as nome from public.eventos e where e.cidade is not null and e.excluido_em is null
      union all
      select btrim(m.cidade) from public.membros m where m.cidade is not null and m.excluido_em is null
      union all
      select uc.cidade from public.usuario_cidades uc
    ) t
    where t.nome <> ''
    order by public.normalizar_texto(t.nome), t.nome;
end;
$function$;
