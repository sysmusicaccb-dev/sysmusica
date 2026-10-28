-- Volta a configuração de todos os perfis ao padrão do modelo. (Para desfazer a 0080 por completo, desfaça também
-- o código no Git: as funções salvar/obter_dados_ensaio novas continuam funcionando com os perfis no padrão.)
update public.perfis_evento set config = '{}'::jsonb;
