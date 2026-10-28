-- TESTE da 0081 — SÓ LEITURA. Esperado: nenhuma linha FALHOU.
select 'dados_ensaio tem a coluna extras' as verificacao, '1' as esperado, count(*)::text as obtido,
       case when count(*) = 1 then 'OK' else 'FALHOU' end as resultado
  from information_schema.columns where table_name = 'dados_ensaio' and column_name = 'extras'
union all
select 'normalização: id repetido e lista com 1 opção são descartados', '1 campo',
       jsonb_array_length(public.normalizar_campos_extras('[{"id":"a1","nome":"Obs","tipo":"texto_longo"},{"id":"a1","nome":"Repetido","tipo":"numero"},{"id":"b2","nome":"Lista","tipo":"lista","opcoes":["x"]}]'::jsonb))::text || ' campo(s)',
       case when jsonb_array_length(public.normalizar_campos_extras('[{"id":"a1","nome":"Obs","tipo":"texto_longo"},{"id":"a1","nome":"Repetido","tipo":"numero"},{"id":"b2","nome":"Lista","tipo":"lista","opcoes":["x"]}]'::jsonb)) = 1 then 'OK' else 'FALHOU' end
union all
select 'normalização: no máximo 10 campos', '10',
       jsonb_array_length(public.normalizar_campos_extras((select jsonb_agg(jsonb_build_object('id', 'c' || g, 'nome', 'Campo ' || g, 'tipo', 'texto_curto')) from generate_series(1, 15) g)))::text,
       case when jsonb_array_length(public.normalizar_campos_extras((select jsonb_agg(jsonb_build_object('id', 'c' || g, 'nome', 'Campo ' || g, 'tipo', 'texto_curto')) from generate_series(1, 15) g))) = 10 then 'OK' else 'FALHOU' end
union all
select 'normalização: lista guarda as opções na ordem e sem repetir', 'a,b',
       (select string_agg(x, ',') from jsonb_array_elements_text(public.normalizar_campos_extras('[{"id":"l1","nome":"Lista","tipo":"lista","opcoes":["a","b","a"]}]'::jsonb) -> 0 -> 'opcoes') x),
       case when (select string_agg(x, ',') from jsonb_array_elements_text(public.normalizar_campos_extras('[{"id":"l1","nome":"Lista","tipo":"lista","opcoes":["a","b","a"]}]'::jsonb) -> 0 -> 'opcoes') x) = 'a,b' then 'OK' else 'FALHOU' end
union all
select 'o perfil guarda os campos extras', 'sim_nao',
       public.normalizar_config_perfil('{"campos_extras":[{"id":"c1","nome":"Obs","tipo":"sim_nao"}]}'::jsonb, 'LOCAL') #>> '{campos_extras,0,tipo}',
       case when (public.normalizar_config_perfil('{"campos_extras":[{"id":"c1","nome":"Obs","tipo":"sim_nao"}]}'::jsonb, 'LOCAL') #>> '{campos_extras,0,tipo}') = 'sim_nao' then 'OK' else 'FALHOU' end
union all
select 'obter e salvar do ensaio conhecem os campos extras', 'true',
       (select (bool_and(p.prosrc like '%extras%'))::text from pg_proc p join pg_namespace n on n.oid = p.pronamespace and n.nspname = 'public'
         where p.proname in ('obter_dados_ensaio', 'salvar_dados_ensaio')),
       case when (select bool_and(p.prosrc like '%extras%') from pg_proc p join pg_namespace n on n.oid = p.pronamespace and n.nspname = 'public'
                   where p.proname in ('obter_dados_ensaio', 'salvar_dados_ensaio')) then 'OK' else 'FALHOU' end
union all
select 'salvar_perfil_evento protege campo extra já preenchido', 'true',
       (select (p.prosrc like '%já foi preenchido em ensaios%')::text from pg_proc p join pg_namespace n on n.oid = p.pronamespace and n.nspname = 'public' where p.proname = 'salvar_perfil_evento'),
       case when (select p.prosrc like '%já foi preenchido em ensaios%' from pg_proc p join pg_namespace n on n.oid = p.pronamespace and n.nspname = 'public' where p.proname = 'salvar_perfil_evento') then 'OK' else 'FALHOU' end;
