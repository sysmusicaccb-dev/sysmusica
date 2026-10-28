-- SÓ LEITURA. Mostra o que existe no banco da migração 0080.
select 'funcao' as tipo, p.proname as nome, pg_get_function_identity_arguments(p.oid) as argumentos
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
 where n.nspname = 'public'
   and p.proname in ('config_padrao_ensaio','cfg_bool','cfg_int','cfg_texto','cfg_lista','normalizar_config_perfil',
                     'config_ensaio_do_tipo','salvar_perfil_evento','listar_perfis_evento','duplicar_perfil_evento',
                     'obter_dados_ensaio','salvar_dados_ensaio','normalizar_campos_extras')
union all
select 'coluna', table_name, column_name
  from information_schema.columns
 where table_schema = 'public'
   and ((table_name = 'perfis_evento' and column_name = 'config')
     or (table_name = 'dados_ensaio_encarregados' and column_name = 'cargo')
     or (table_name = 'dados_ensaio' and column_name = 'extras'))
order by 1, 2;
