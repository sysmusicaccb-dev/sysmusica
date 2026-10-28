-- TESTE da 0078 — SÓ LEITURA. Esperado: nenhuma linha FALHOU.
select 'encerrar_evento tem a regra nova (Secretário em todos; Instrutor sem Ensaio Técnico)' as verificacao, 'true' as esperado,
       (p.prosrc like '%ensaio tecnico%' and p.prosrc like '%encerrar_regional%')::text as obtido,
       case when p.prosrc like '%ensaio tecnico%' and p.prosrc like '%encerrar_regional%' then 'OK' else 'FALHOU' end as resultado
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace and n.nspname = 'public' where p.proname = 'encerrar_evento'
union all
select 'Secretário da Música tem eventos.encerrar_regional', '1', count(*)::text, case when count(*) = 1 then 'OK' else 'FALHOU' end
  from public.grupo_permissoes gp join public.grupos g on g.id = gp.grupo_id where g.nome = 'Secretário da Música' and gp.permissao_codigo = 'eventos.encerrar_regional'
union all
select 'Instrutor tem eventos.encerrar_local', '1', count(*)::text, case when count(*) = 1 then 'OK' else 'FALHOU' end
  from public.grupo_permissoes gp join public.grupos g on g.id = gp.grupo_id where g.nome = 'Instrutor' and gp.permissao_codigo = 'eventos.encerrar_local'
union all
select 'Administrador Regional tem eventos.encerrar_qualquer', '1', count(*)::text, case when count(*) = 1 then 'OK' else 'FALHOU' end
  from public.grupo_permissoes gp join public.grupos g on g.id = gp.grupo_id where g.nome = 'Administrador Regional' and gp.permissao_codigo = 'eventos.encerrar_qualquer';
