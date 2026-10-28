-- Tira os campos extras de todos os perfis (os valores já gravados em dados_ensaio.extras ficam guardados).
-- Para desfazer por completo, desfaça também o código no Git.
update public.perfis_evento set config = config - 'campos_extras';
