-- TESTE da 0083 — SÓ LEITURA. Esperado: nenhuma linha FALHOU.
select 'a função relatorio_ensaio existe' as verificacao, '1' as esperado,
       (select count(*) from pg_proc p join pg_namespace n on n.oid = p.pronamespace
         where n.nspname = 'public' and p.proname = 'relatorio_ensaio')::text as obtido,
       case when (select count(*) from pg_proc p join pg_namespace n on n.oid = p.pronamespace
                   where n.nspname = 'public' and p.proname = 'relatorio_ensaio') = 1 then 'OK' else 'FALHOU' end as resultado
union all
select 'usa as funções do painel e do ensaio', 'true',
       (pg_get_functiondef('public.relatorio_ensaio(uuid)'::regprocedure) like '%classificar_linha%'
        and pg_get_functiondef('public.relatorio_ensaio(uuid)'::regprocedure) like '%config_ensaio_do_tipo%')::text,
       case when pg_get_functiondef('public.relatorio_ensaio(uuid)'::regprocedure) like '%classificar_linha%'
             and pg_get_functiondef('public.relatorio_ensaio(uuid)'::regprocedure) like '%config_ensaio_do_tipo%' then 'OK' else 'FALHOU' end;
