-- ============================================================================
-- 0065 — Casas de Oração da região de Jequié (levantamento das fotos): coluna do CÓDIGO + importação
--
--  * casas_oracao ganha a coluna "codigo" (ex.: BR-04-0183), única quando preenchida;
--  * cria os setores que faltam na ADM Jequié (um por cidade: Jitaúna, Ibirataia, Wenceslau Guimarães, Manoel Vitorino),
--    seguindo o que já existe (setores Jequié, Gandú, Ipiaú);
--  * cria as casas que não existem e, nas que JÁ existem (mesmo nome ignorando acento/caixa/" - Central"), só grava o código.
-- Pode rodar mais de uma vez (não duplica). Para desfazer: 0065_reverter.sql
-- ============================================================================
alter table public.casas_oracao add column if not exists codigo text;
create unique index if not exists casas_oracao_codigo_unico on public.casas_oracao (upper(codigo)) where codigo is not null;

create temp table if not exists _imp_resumo (acao text, municipio text, nome text, codigo text);
truncate _imp_resumo;

do $imp$
declare
  v_adm uuid;
  r record;
  v_setor uuid;
  v_casa uuid;
begin
  select a.id into v_adm from public.adms a where lower(translate(a.nome,'áàâãäéèêëíìîïóòôõöúùûüçñÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇÑ','aaaaaeeeeiiiiooooouuuucnaaaaaeeeeiiiiooooouuuucn')) = 'jequie';
  if v_adm is null then raise exception 'ADM Jequié não encontrada; nada foi alterado.'; end if;

  -- 1) setores que faltam (um por cidade da planilha)
  for r in
    select distinct p.municipio
      from (values ('Gandu'), ('Ibirataia'), ('Ipiaú'), ('Jequié'), ('Jitaúna'), ('Manoel Vitorino'), ('Wenceslau Guimarães')) as p(municipio)
  loop
    if not exists (select 1 from public.setores s where s.adm_id = v_adm and lower(translate(s.nome,'áàâãäéèêëíìîïóòôõöúùûüçñÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇÑ','aaaaaeeeeiiiiooooouuuucnaaaaaeeeeiiiiooooouuuucn')) = lower(translate(r.municipio,'áàâãäéèêëíìîïóòôõöúùûüçñÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇÑ','aaaaaeeeeiiiiooooouuuucnaaaaaeeeeiiiiooooouuuucn'))) then
      insert into public.setores (adm_id, nome) values (v_adm, r.municipio);
      insert into _imp_resumo values ('SETOR CRIADO', r.municipio, r.municipio, null);
    end if;
  end loop;

  -- 2) casas
  for r in
    select * from (values
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
    ) as p(municipio, nome, codigo)
  loop
    select s.id into v_setor from public.setores s where s.adm_id = v_adm and lower(translate(s.nome,'áàâãäéèêëíìîïóòôõöúùûüçñÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇÑ','aaaaaeeeeiiiiooooouuuucnaaaaaeeeeiiiiooooouuuucn')) = lower(translate(r.municipio,'áàâãäéèêëíìîïóòôõöúùûüçñÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇÑ','aaaaaeeeeiiiiooooouuuucnaaaaaeeeeiiiiooooouuuucn')) limit 1;

    -- já existe na ADM (mesmo nome, sem acento/caixa/sufixo " - Central")?
    select c.id into v_casa from public.casas_oracao c
     where c.adm_id = v_adm and regexp_replace(lower(translate(c.nome,'áàâãäéèêëíìîïóòôõöúùûüçñÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇÑ','aaaaaeeeeiiiiooooouuuucnaaaaaeeeeiiiiooooouuuucn')), '\s*-\s*central$', '') = regexp_replace(lower(translate(r.nome,'áàâãäéèêëíìîïóòôõöúùûüçñÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇÑ','aaaaaeeeeiiiiooooouuuucnaaaaaeeeeiiiiooooouuuucn')), '\s*-\s*central$', '')
       and (c.setor_id is not distinct from v_setor or c.setor_id is null)
     order by (c.codigo is null) desc limit 1;

    if v_casa is not null then
      update public.casas_oracao set codigo = r.codigo where id = v_casa and codigo is null;
      insert into _imp_resumo values ('CÓDIGO GRAVADO (casa já existia)', r.municipio, r.nome, r.codigo);
    elsif exists (select 1 from public.casas_oracao c where upper(c.codigo) = upper(r.codigo)) then
      insert into _imp_resumo values ('IGNORADA (código já cadastrado)', r.municipio, r.nome, r.codigo);
    else
      insert into public.casas_oracao (adm_id, setor_id, nome, cidade, ativo, codigo)
      values (v_adm, v_setor, r.nome, r.municipio, true, r.codigo);
      insert into _imp_resumo values ('CASA CRIADA', r.municipio, r.nome, r.codigo);
    end if;
  end loop;
end
$imp$;

-- Resultado: quantas linhas de cada ação
select acao, count(*) as quantidade from _imp_resumo group by acao order by acao;
