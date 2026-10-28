-- TESTE da 0079 — SÓ LEITURA. Esperado: nenhuma linha FALHOU.
select 'perfis iniciais (Local, Regional, Técnico)' as verificacao, '3' as esperado, count(*)::text as obtido,
       case when count(*) = 3 then 'OK' else 'FALHOU' end as resultado
  from public.perfis_evento where lower(nome) in ('ensaio local', 'ensaio regional', 'ensaio técnico')
union all
select 'Ensaio Técnico tem o mesmo comportamento base do Local', 'LOCAL', coalesce(max(modelo_base), '-'),
       case when max(modelo_base) = 'LOCAL' then 'OK' else 'FALHOU' end
  from public.perfis_evento where lower(nome) = 'ensaio técnico'
union all
select 'tipos com modelo e sem perfil', '0', count(*)::text, case when count(*) = 0 then 'OK' else 'FALHOU' end
  from public.tipos_evento where modelo_ensaio is not null and perfil_id is null
union all
select 'as 6 funções existem', '6', count(*)::text, case when count(*) = 6 then 'OK' else 'FALHOU' end
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace and n.nspname = 'public'
 where p.proname in ('listar_perfis_evento','perfis_dos_tipos_evento','salvar_perfil_evento','duplicar_perfil_evento','excluir_perfil_evento','vincular_perfil_tipo_evento')
union all
select 'tabela fechada para o navegador (sem acesso direto)', '0', count(*)::text, case when count(*) = 0 then 'OK' else 'FALHOU' end
  from information_schema.role_table_grants where table_name = 'perfis_evento' and grantee in ('anon', 'authenticated');
