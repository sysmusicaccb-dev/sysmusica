-- SÓ LEITURA. Mostra como o backup funciona hoje (para incluir os perfis de evento).
select 'funcao' as tipo, p.proname as nome, pg_get_functiondef(p.oid) as conteudo
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
 where n.nspname = 'public' and p.proname like 'backup%'
union all
select 'colunas_perfis_evento', column_name, data_type || ' / ' || is_nullable
  from information_schema.columns
 where table_schema = 'public' and table_name = 'perfis_evento'
union all
select 'tabelas_com_backup_no_nome', table_name, ''
  from information_schema.tables
 where table_schema = 'public' and table_name like '%backup%'
order by 1, 2;
