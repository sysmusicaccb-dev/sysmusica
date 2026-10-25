-- TESTE da 0069 — SÓ LEITURA, não grava nada. Esperado: nenhuma linha FALHOU.
select t.ordem, t.verificacao, t.esperado, t.obtido,
       case when t.esperado = t.obtido then 'OK' else 'FALHOU' end as resultado
from (values
  (1, 'Tabela antiga renomeada', 'sim',
     case when to_regclass('public.usuario_cidades') is null and to_regclass('public.usuario_cidades_aposentada') is not null then 'sim' else 'não' end),
  (2, 'Dados da tabela preservados (4 linhas)', '4',
     coalesce((select count(*)::text from public.usuario_cidades_aposentada), 'sem tabela')),
  (3, 'Função cidade_na_minha_abrangencia removida', 'sim',
     case when to_regprocedure('public.cidade_na_minha_abrangencia(text)') is null then 'sim' else 'não' end),
  (4, 'Função definir_abrangencia removida', 'sim',
     case when to_regprocedure('public.definir_abrangencia(uuid,text[])') is null then 'sim' else 'não' end),
  (5, 'Função listar_abrangencias removida', 'sim',
     case when to_regprocedure('public.listar_abrangencias()') is null then 'sim' else 'não' end),
  (6, 'backup_aplicar não cita mais a tabela antiga', 'sim',
     case when (select prosrc from pg_proc where oid = 'public.backup_aplicar(uuid,jsonb,jsonb)'::regprocedure) not ilike '%usuario_cidades%' then 'sim' else 'não' end),
  (7, 'listar_cidades_conhecidas não cita mais a tabela antiga', 'sim',
     case when (select prosrc from pg_proc where oid = 'public.listar_cidades_conhecidas()'::regprocedure) not ilike '%usuario_cidades%' then 'sim' else 'não' end),
  (8, 'Vínculos novos intactos (Master e portaria continuam com vínculos)', 'sim',
     case when (select count(distinct v.usuario_id) from public.usuario_vinculos v
                  join public.usuarios u on u.id = v.usuario_id
                 where lower(u.email) in ('levialencar@gmail.com', 'portariamusicaccb@gmail.com')) = 2 then 'sim' else 'não' end)
) as t(ordem, verificacao, esperado, obtido)
order by t.ordem;
