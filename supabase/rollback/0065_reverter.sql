-- Reverte a 0065: remove as casas criadas pela importação (as que ainda não têm membros/eventos), tira os códigos
-- das que já existiam, remove os setores criados que ficaram vazios e apaga a coluna do código.
-- Atenção: casa que já tem membro ou evento NÃO é apagada (o banco recusa); nesse caso me avise.
delete from public.casas_oracao c
 where c.codigo in (select codigo from (values ('BR-04-0183'), ('BR-04-0437'), ('BR-04-0780'), ('BR-04-0828'), ('BR-04-0864'), ('BR-04-0981'), ('BR-04-1064'), ('BR-04-1166'), ('BR-04-1212'), ('BR-04-1226'), ('BR-04-1227'), ('BR-04-1514'), ('BR-04-1961'), ('BR-04-2378'), ('BR-04-2382'), ('BR-04-2460'), ('BR-04-0675'), ('BR-04-1980'), ('BR-04-0465'), ('BR-04-1115'), ('BR-04-1333'), ('BR-04-1698'), ('BR-04-0796'), ('BR-04-1037'), ('BR-04-1336'), ('BR-04-1834'), ('BR-04-0129'), ('BR-04-1453'), ('BR-04-1570'), ('BR-04-0556'), ('BR-04-0979'), ('BR-04-1338'), ('BR-04-2354')) v(codigo))
   and c.criado_em > now() - interval '1 year'
   and regexp_replace(lower(translate(c.nome,'áàâãäéèêëíìîïóòôõöúùûüçñÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇÑ','aaaaaeeeeiiiiooooouuuucnaaaaaeeeeiiiiooooouuuucn')), '\s*-\s*central$', '') not in ('cidade nova', 'jequiezinho', 'mutirao');
update public.casas_oracao set codigo = null where codigo like 'BR-04-%';
delete from public.setores s
 where lower(translate(s.nome,'áàâãäéèêëíìîïóòôõöúùûüçñÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇÑ','aaaaaeeeeiiiiooooouuuucnaaaaaeeeeiiiiooooouuuucn')) in ('jitauna', 'ibirataia', 'wenceslau guimaraes', 'manoel vitorino')
   and not exists (select 1 from public.casas_oracao c where c.setor_id = s.id);
drop index if exists public.casas_oracao_codigo_unico;
alter table public.casas_oracao drop column if exists codigo;
