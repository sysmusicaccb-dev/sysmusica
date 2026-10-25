-- Reverte a 0070: remove as funções, a tabela de fichas, as permissões e o grupo Secretário da Música.
-- ATENÇÃO: apaga TODAS as fichas guardadas. Faça um backup antes, se já houver fichas.
drop function if exists public.buscar_membros_para_ficha(text);
drop function if exists public.definir_resultado_ficha(uuid, text);
drop function if exists public.excluir_ficha(uuid);
drop function if exists public.salvar_ficha(uuid, text, uuid, uuid, jsonb);
drop function if exists public.obter_ficha(uuid);
drop function if exists public.listar_fichas(text, integer);
drop function if exists public.ficha_visivel(uuid);
drop table if exists public.fichas_musicais;

delete from public.grupo_permissoes where permissao_codigo like 'fichas.%';
delete from public.usuario_grupos where grupo_id in (select id from public.grupos where nome = 'Secretário da Música');
delete from public.grupos where nome = 'Secretário da Música';
delete from public.permissoes where codigo like 'fichas.%';
