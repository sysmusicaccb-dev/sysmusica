-- 0068 — Etapa 4 (varredura regional): lista de cidades conhecidas passa a respeitar a região.
-- ANTES: um administrador regional com "usuarios.editar" via as cidades de TODAS as regiões.
-- DEPOIS: ele vê só as cidades dos eventos e membros da própria abrangência; o Master (acesso global) vê tudo.
-- As demais funções "SEM_TRAVA" da varredura já são protegidas por gatilhos (0054/0057) ou por outra função
-- com trava, ou são de uso pessoal/público de propósito. Nada mais é alterado aqui.

create or replace function public.listar_cidades_conhecidas()
 returns table(cidade text)
 language plpgsql
 stable security definer
 set search_path to 'public'
as $function$
declare
  v_global boolean := public.tem_acesso_total_organizacao();
begin
  perform public.exigir_permissao('usuarios.editar');
  return query
    select distinct on (public.normalizar_texto(t.nome)) t.nome
    from (
      select btrim(e.cidade) as nome from public.eventos e
       where e.cidade is not null and e.excluido_em is null
         and (v_global or public.casa_oracao_na_abrangencia(e.casa_oracao_id))
      union all
      select btrim(m.cidade) from public.membros m
       where m.cidade is not null and m.excluido_em is null
         and (v_global or public.casa_oracao_na_abrangencia(m.casa_oracao_id))
      union all
      -- cidades antigas de abrangência (legado): só o acesso global enxerga
      select uc.cidade from public.usuario_cidades uc where v_global
    ) t
    where t.nome <> ''
    order by public.normalizar_texto(t.nome), t.nome;
end;
$function$;
