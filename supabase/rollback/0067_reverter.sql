-- Desfaz a 0067: volta tudo para a clave de sol padrão e remove a tabela, as funções e as regras do bucket.
-- (Os arquivos já enviados ao bucket "marca" ficam lá; apague pelo painel do Supabase se quiser.)
drop function if exists public.restaurar_marca_padrao();
drop function if exists public.salvar_marca_do_sistema(text, text, int, int, int);
drop function if exists public.marca_do_sistema();
drop table if exists public.marca_sistema;
drop policy if exists marca_master_inserir on storage.objects;
drop policy if exists marca_master_atualizar on storage.objects;
drop policy if exists marca_master_apagar on storage.objects;
