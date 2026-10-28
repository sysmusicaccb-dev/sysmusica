-- TESTE da 0080 — SÓ LEITURA. Esperado: nenhuma linha FALHOU.
select 'perfis_evento tem a coluna config' as verificacao, '1' as esperado, count(*)::text as obtido,
       case when count(*) = 1 then 'OK' else 'FALHOU' end as resultado
  from information_schema.columns where table_name = 'perfis_evento' and column_name = 'config'
union all
select 'quem atendeu / hino de abertura / cidade agora podem ficar vazios', '3 colunas liberadas', count(*)::text || ' liberadas',
       case when count(*) = 4 then 'OK' else 'FALHOU' end
  from information_schema.columns
 where is_nullable = 'YES' and ((table_name = 'dados_ensaio' and column_name in ('atende_cargo', 'atende_nome', 'hino_abertura_id'))
                                or (table_name = 'dados_ensaio_encarregados' and column_name = 'cidade_uf'))
union all
select 'encarregados tem a coluna cargo', '1', count(*)::text, case when count(*) = 1 then 'OK' else 'FALHOU' end
  from information_schema.columns where table_name = 'dados_ensaio_encarregados' and column_name = 'cargo'
union all
select 'padrão do Regional: só Ancião e palavra ligada', 'ANCIAO / true',
       (public.config_padrao_ensaio('REGIONAL') #>> '{quem_atendeu,cargos,0}') || ' / ' || (public.config_padrao_ensaio('REGIONAL') #>> '{palavra,ativo}'),
       case when (public.config_padrao_ensaio('REGIONAL') #>> '{quem_atendeu,cargos,0}') = 'ANCIAO'
             and (public.config_padrao_ensaio('REGIONAL') #>> '{palavra,ativo}') = 'true' then 'OK' else 'FALHOU' end
union all
select 'padrão do Local: palavra desligada', 'false', public.config_padrao_ensaio('LOCAL') #>> '{palavra,ativo}',
       case when (public.config_padrao_ensaio('LOCAL') #>> '{palavra,ativo}') = 'false' then 'OK' else 'FALHOU' end
union all
select 'normalização corrige limite, cargos e modo inválidos', '500 / 3 / pergunta',
       (public.normalizar_config_perfil('{"palavra":{"limite":99999},"encarregados":{"cargos":["XX"],"maximo":9},"hino_abertura":{"modo":"lixo"}}'::jsonb, 'LOCAL') #>> '{palavra,limite}')
       || ' / ' || (public.normalizar_config_perfil('{"encarregados":{"maximo":9}}'::jsonb, 'LOCAL') #>> '{encarregados,maximo}')
       || ' / ' || (public.normalizar_config_perfil('{"hino_abertura":{"modo":"lixo"}}'::jsonb, 'LOCAL') #>> '{hino_abertura,modo}'),
       case when (public.normalizar_config_perfil('{"palavra":{"limite":99999}}'::jsonb, 'LOCAL') #>> '{palavra,limite}') = '500'
             and (public.normalizar_config_perfil('{"encarregados":{"maximo":9}}'::jsonb, 'LOCAL') #>> '{encarregados,maximo}') = '3'
             and (public.normalizar_config_perfil('{"hino_abertura":{"modo":"lixo"}}'::jsonb, 'LOCAL') #>> '{hino_abertura,modo}') = 'pergunta' then 'OK' else 'FALHOU' end
union all
select 'as funções do ensaio seguem a configuração', 'true',
       (select (bool_and(p.prosrc like '%config_ensaio_do_tipo%'))::text from pg_proc p join pg_namespace n on n.oid = p.pronamespace and n.nspname = 'public'
         where p.proname in ('obter_dados_ensaio', 'salvar_dados_ensaio')),
       case when (select bool_and(p.prosrc like '%config_ensaio_do_tipo%') from pg_proc p join pg_namespace n on n.oid = p.pronamespace and n.nspname = 'public'
                   where p.proname in ('obter_dados_ensaio', 'salvar_dados_ensaio')) then 'OK' else 'FALHOU' end
union all
select 'cada tipo com perfil devolve configuração', '0 sem config', count(*)::text || ' sem config',
       case when count(*) = 0 then 'OK' else 'FALHOU' end
  from public.tipos_evento t where t.perfil_id is not null and public.config_ensaio_do_tipo(t.id) is null;
