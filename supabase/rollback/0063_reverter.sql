-- Reverte a 0063: devolve as funções à regra antiga e remove links.
do $rev$
declare r record; v_def text; v_novo text;
begin
  for r in select p.oid from pg_proc p where p.pronamespace = 'public'::regnamespace
     and p.proname in ('listar_cadastros_pendentes','obter_cadastro_pendente','contar_cadastros_pendentes','aprovar_cadastro_pendente','rejeitar_cadastro_pendente')
  loop
    v_def := pg_get_functiondef(r.oid);
    v_novo := replace(v_def, 'public.cadastro_pendente_visivel_r(c.casa_oracao_id, c.membro_id, c.origem_nivel, c.origem_id)',
                             'public.cadastro_pendente_visivel(c.casa_oracao_id, c.membro_id)');
    if v_novo <> v_def then execute v_novo; end if;
  end loop;
end $rev$;

-- registrar_cadastro_publico volta ao texto antigo (remove só os quatro trechos acrescentados)
do $rev2$
declare v_oid oid; v_def text; v_novo text;
begin
  select p.oid into v_oid from pg_proc p where p.pronamespace='public'::regnamespace and p.proname='registrar_cadastro_publico';
  v_def := pg_get_functiondef(v_oid);
  if position('v_link_cod' in v_def) = 0 then return; end if;
  v_novo := v_def;
  v_novo := replace(v_novo, E'\n  v_link public.cadastro_links%rowtype; v_link_cod text;', '');
  v_novo := regexp_replace(v_novo, E'\n  -- Link de cadastro da região \\(opcional\\).*?\n  end if;\n(?=\n|  )', '', 's');
  v_novo := regexp_replace(v_novo, E'  -- Com link da região: a casa escolhida.*?\n  end if;\n\n', '', 's');
  v_novo := regexp_replace(v_novo, E'  -- Marca a região de origem.*?\n  end if;\n\n', '', 's');
  execute v_novo;
end $rev2$;

drop function if exists public.desativar_link_cadastro(uuid);
drop function if exists public.criar_link_cadastro(text, uuid);
drop function if exists public.listar_links_cadastro();
drop function if exists public.opcoes_cadastro_link(text);
drop function if exists public.cadastro_pendente_visivel_r(uuid, uuid, text, uuid);
drop function if exists public.casa_na_regiao_do_link(uuid, text, uuid);
alter table public.cadastros_pendentes drop column if exists link_id, drop column if exists origem_nivel, drop column if exists origem_id;
drop table if exists public.cadastro_links;
