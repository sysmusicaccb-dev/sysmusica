-- TESTE da 0082 — SÓ LEITURA. Esperado: resultado OK.
select 'backup_aplicar aceita perfis_evento' as verificacao,
       'true' as esperado,
       (pg_get_functiondef('public.backup_aplicar(uuid,jsonb,jsonb)'::regprocedure) like '%''perfis_evento''%')::text as obtido,
       case when pg_get_functiondef('public.backup_aplicar(uuid,jsonb,jsonb)'::regprocedure) like '%''perfis_evento''%' then 'OK' else 'FALHOU' end as resultado
union all
select 'as demais tabelas continuam permitidas', 'true',
       (pg_get_functiondef('public.backup_aplicar(uuid,jsonb,jsonb)'::regprocedure) like '%''tipos_evento''%'
        and pg_get_functiondef('public.backup_aplicar(uuid,jsonb,jsonb)'::regprocedure) like '%''presencas_avulsas''%')::text,
       case when pg_get_functiondef('public.backup_aplicar(uuid,jsonb,jsonb)'::regprocedure) like '%''tipos_evento''%'
             and pg_get_functiondef('public.backup_aplicar(uuid,jsonb,jsonb)'::regprocedure) like '%''presencas_avulsas''%' then 'OK' else 'FALHOU' end;
