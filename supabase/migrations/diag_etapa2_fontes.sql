-- DIAGNÓSTICO (somente leitura, não grava nada): código das funções que faltam e gatilhos existentes.
-- Rode no SQL Editor e me envie o resultado inteiro (exportar CSV). Serve para completar a Etapa 2 (0058).

select 'funcao_' || p.proname as secao, pg_get_functiondef(p.oid) as conteudo
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
 where n.nspname = 'public'
   and p.proname in ('obter_qr_membro', 'regenerar_qr', 'desfazer_entrada_avulsa', 'excluir_portaria',
                     'registrar_entrada', 'excluir_hino', 'excluir_instrumento', 'listar_cidades_conhecidas',
                     'exigir_acesso_atendimento')
union all
select 'gatilho_' || c.relname, pg_get_triggerdef(t.oid)
  from pg_trigger t join pg_class c on c.oid = t.tgrelid join pg_namespace n on n.oid = c.relnamespace
 where n.nspname = 'public' and not t.tgisinternal
   and c.relname in ('eventos', 'portarias', 'presencas', 'presencas_avulsas', 'membros')
union all
select 'colunas_' || table_name, string_agg(column_name || ' ' || data_type, ', ' order by ordinal_position)
  from information_schema.columns
 where table_schema = 'public' and table_name in ('membros', 'presencas_avulsas')
 group by table_name
order by 1;
