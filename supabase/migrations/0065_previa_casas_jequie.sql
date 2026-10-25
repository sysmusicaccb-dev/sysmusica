-- ============================================================================
-- PRÉVIA (SOMENTE LEITURA) da importação das casas de Jequié e região — NÃO GRAVA NADA.
-- Mostra, para cada linha da planilha, o que a 0065 vai fazer: CRIAR a casa, ou só GRAVAR O CÓDIGO numa casa que já existe.
-- ============================================================================
with planilha(municipio, nome, codigo) as (values
  ('Jequié', 'Joaquim Romão', 'BR-04-0183'),
  ('Jequié', 'Jequiezinho', 'BR-04-0437'),
  ('Jequié', 'Mandacaru - Itaigara', 'BR-04-0780'),
  ('Jequié', 'Km 3', 'BR-04-0828'),
  ('Jequié', 'Povoado Cachoeirinha', 'BR-04-0864'),
  ('Jequié', 'Loteamento Jardim Tropical', 'BR-04-0981'),
  ('Jequié', 'Cidade Nova - Central', 'BR-04-1064'),
  ('Jequié', 'Curral Novo', 'BR-04-1166'),
  ('Jequié', 'Povoado Barragem de Pedra', 'BR-04-1212'),
  ('Jequié', 'Jequiezinho - Pau Ferro', 'BR-04-1226'),
  ('Jequié', 'Mutirão', 'BR-04-1227'),
  ('Jequié', 'Brasil Novo', 'BR-04-1514'),
  ('Jequié', 'Povoado Rio do Antonio', 'BR-04-1961'),
  ('Jequié', 'Loteamento Zimbrunes', 'BR-04-2378'),
  ('Jequié', 'Posto Manoel Antonio', 'BR-04-2382'),
  ('Jequié', 'Distrito Florestal', 'BR-04-2460'),
  ('Gandu', 'Francisco Teotônio Calheira - Central', 'BR-04-0675'),
  ('Gandu', 'Residencial Manoel Dantas Cardoso', 'BR-04-1980'),
  ('Ipiaú', 'Euclides Neto', 'BR-04-0465'),
  ('Ipiaú', 'Centro - Central', 'BR-04-1115'),
  ('Ipiaú', 'Japumirim', 'BR-04-1333'),
  ('Ipiaú', 'Residência ACM', 'BR-04-1698'),
  ('Jitaúna', 'Centro - Central', 'BR-04-0796'),
  ('Jitaúna', 'Povoado Barra Avenida', 'BR-04-1037'),
  ('Jitaúna', 'Povoado Itajuru', 'BR-04-1336'),
  ('Jitaúna', 'Adelino Henrique Santana', 'BR-04-1834'),
  ('Ibirataia', 'Centro - Central', 'BR-04-0129'),
  ('Wenceslau Guimarães', 'Povoado de Daramão', 'BR-04-1453'),
  ('Wenceslau Guimarães', 'Pantaleão - Central', 'BR-04-1570'),
  ('Manoel Vitorino', 'Centro - Central', 'BR-04-0556'),
  ('Manoel Vitorino', 'Distrito Catingal', 'BR-04-0979'),
  ('Manoel Vitorino', 'Lagoa das Pedras', 'BR-04-1338'),
  ('Manoel Vitorino', 'Povoado Jequiezinho', 'BR-04-2354')
),
adm as (
  select a.id from public.adms a where lower(translate(a.nome,'áàâãäéèêëíìîïóòôõöúùûüçñÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇÑ','aaaaaeeeeiiiiooooouuuucnaaaaaeeeeiiiiooooouuuucn')) = 'jequie'
),
alvo as (  -- cada linha da planilha com o setor (cidade) onde a casa vai ficar
  select p.*, (select id from adm) as adm_id,
         (select s.id from public.setores s where s.adm_id = (select id from adm) and lower(translate(s.nome,'áàâãäéèêëíìîïóòôõöúùûüçñÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇÑ','aaaaaeeeeiiiiooooouuuucnaaaaaeeeeiiiiooooouuuucn')) = lower(translate(p.municipio,'áàâãäéèêëíìîïóòôõöúùûüçñÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇÑ','aaaaaeeeeiiiiooooouuuucnaaaaaeeeeiiiiooooouuuucn')) limit 1) as setor_id
    from planilha p
),
ja as (  -- casa que já existe na ADM (mesmo nome, ignorando acento, caixa e o sufixo " - Central")
  select a.codigo as cod_planilha, c.id as casa_id, c.nome as casa_nome
    from alvo a join public.casas_oracao c on c.adm_id = a.adm_id
   where regexp_replace(lower(translate(c.nome,'áàâãäéèêëíìîïóòôõöúùûüçñÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇÑ','aaaaaeeeeiiiiooooouuuucnaaaaaeeeeiiiiooooouuuucn')), '\s*-\s*central$', '') = regexp_replace(lower(translate(a.nome,'áàâãäéèêëíìîïóòôõöúùûüçñÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇÑ','aaaaaeeeeiiiiooooouuuucnaaaaaeeeeiiiiooooouuuucn')), '\s*-\s*central$', '') and (a.setor_id is null or c.setor_id is not distinct from a.setor_id or c.setor_id is null)
)
select case when j.casa_id is null then 'CRIAR' else 'JÁ EXISTE (só grava o código)' end as acao,
       a.municipio, a.nome as nome_na_planilha, a.codigo,
       coalesce((select s.nome from public.setores s where s.id = a.setor_id), '(setor será criado: ' || a.municipio || ')') as setor,
       j.casa_nome as casa_ja_cadastrada
  from alvo a left join ja j on j.cod_planilha = a.codigo
 order by 1, a.municipio, a.nome;
