-- SÓ LEITURA. Rode e me mande os 4 resultados (cada bloco é uma aba de resultado; se o editor mostrar só o último, rode um por vez).

-- 1) Funções do relógio da portaria (onde está a regra das "3 horas")
select p.proname, pg_get_functiondef(p.oid) as definicao
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace and n.nspname = 'public'
 where p.proname in ('portaria_janela_aberta', 'portaria_encerrada');

-- 2) Todas as funções do sistema que usam essas regras de horário
select p.proname
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace and n.nspname = 'public'
 where p.prosrc ilike '%portaria_janela_aberta%' or p.prosrc ilike '%portaria_encerrada%'
 order by 1;

-- 3) Grupos e quem tem hoje a permissão de encerrar (portarias.aprovar / controle total)
select g.nome as grupo, string_agg(gp.permissao_codigo, ', ' order by gp.permissao_codigo) as permissoes_de_encerrar
  from public.grupos g
  left join public.grupo_permissoes gp on gp.grupo_id = g.id and gp.permissao_codigo in ('portarias.aprovar', 'portarias.controle_total', 'eventos.cancelar')
 group by g.nome order by g.nome;

-- 4) Tipos de evento (como o sistema sabe se é Ensaio Regional ou Local)
select * from public.tipos_evento order by 1 limit 30;
