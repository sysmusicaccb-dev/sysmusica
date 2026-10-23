-- DIAGNÓSTICO 2 (somente leitura, não grava nada): de onde vêm os eventos de Jequié nas telas
-- "Registrar Presença" (usa listar_portarias) e "Portaria" (consulta direta à tabela de eventos).
-- Rode no SQL Editor e me envie o resultado inteiro (exportar CSV ou copiar).

create or replace function pg_temp.tenta_texto(p_sql text)
returns text
language plpgsql
as $f$
declare v text;
begin
  execute p_sql into v;
  return v;
exception when others then
  return 'ERRO: ' || sqlerrm;
end
$f$;

create or replace function pg_temp.diag2()
returns table(secao text, conteudo text)
language plpgsql
as $f$
declare
  v_jer uuid;
  r record;
begin
  select u.id into v_jer from public.usuarios u where lower(u.email) = 'jerrivan@congregacao.org.br';

  -- A) Quem é o Jerrivan hoje (grupos e permissões que decidem acesso global)
  secao := 'A_grupos_do_Jerrivan';
  conteudo := coalesce((select string_agg(g.nome, ', ' order by g.nome)
                          from public.grupos g
                         where g.id = (select grupo_id from public.usuarios where id = v_jer)
                            or exists (select 1 from public.usuario_grupos ug where ug.usuario_id = v_jer and ug.grupo_id = g.id)), '(nenhum)');
  return next;
  secao := 'A_ele_tem_acesso_global_por_grupo';
  conteudo := public.usuario_e_global(v_jer)::text; return next;

  perform set_config('request.jwt.claims', json_build_object('sub', v_jer, 'role', 'authenticated')::text, true);
  perform set_config('request.jwt.claim.sub', v_jer::text, true);

  -- B) tem_acesso_total_organizacao() e o que a abrangência diz para a casa Cidade Nova (Jequié)
  secao := 'B_tem_acesso_total_organizacao'; conteudo := public.tem_acesso_total_organizacao()::text; return next;
  secao := 'B_na_abrangencia_casa_Cidade_Nova';
  conteudo := pg_temp.tenta_texto($q$select public.casa_oracao_na_abrangencia('581f2e61-7f1c-4d26-a4d6-4beff7c601ab')::text$q$);
  return next;

  -- C) O que listar_portarias() devolve para o Jerrivan (Registrar Presença usa esta lista)
  begin
    for r in execute 'select to_jsonb(x) as j from public.listar_portarias() x' loop
      secao := 'C_listar_portarias_do_Jerrivan'; conteudo := r.j::text; return next;
    end loop;
  exception when others then
    secao := 'C_listar_portarias_do_Jerrivan'; conteudo := 'ERRO: ' || sqlerrm; return next;
  end;

  -- D) Portarias existentes nos eventos de Jequié (quem criou, situação, casa)
  for r in
    select po.id, po.status, po.criada_por, u.nome as criador, po.casa_oracao_id, po.evento_id, po.excluido_em
      from public.portarias po
      left join public.usuarios u on u.id = po.criada_por
      join public.eventos e on e.id = po.evento_id
     where e.casa_oracao_id in ('581f2e61-7f1c-4d26-a4d6-4beff7c601ab', 'aa74d1c6-4b16-4882-a372-6605bee28e45', '149d8770-66dc-4b63-9732-baa7a87048fd')
        or e.cidade ilike 'jequi%'
  loop
    secao := 'D_portaria_de_evento_de_Jequie';
    conteudo := 'portaria ' || r.id || ' status=' || coalesce(r.status, '?') || ' criador=' || coalesce(r.criador, '?')
                || ' casa=' || coalesce(r.casa_oracao_id::text, 'NULL') || ' excluida=' || (r.excluido_em is not null)::text;
    return next;
  end loop;

  -- E) Consulta DIRETA à tabela de eventos, como o navegador faz (papel "authenticated", com as regras RLS)
  begin
    set local role authenticated;
    secao := 'E_eventos_visiveis_direto_total';
    conteudo := (select count(*)::text from public.eventos);
    return next;
    secao := 'E_eventos_visiveis_direto_de_Jequie';
    conteudo := (select count(*)::text from public.eventos e where e.cidade ilike 'jequi%'
                    or e.casa_oracao_id in ('581f2e61-7f1c-4d26-a4d6-4beff7c601ab', 'aa74d1c6-4b16-4882-a372-6605bee28e45', '149d8770-66dc-4b63-9732-baa7a87048fd'));
    return next;
    secao := 'E_presencas_visiveis_direto_total';
    conteudo := (select count(*)::text from public.presencas);
    return next;
    reset role;
  exception when others then
    reset role;
    secao := 'E_consulta_direta'; conteudo := 'ERRO: ' || sqlerrm; return next;
  end;

  -- F) Código das funções que decidem isso
  for r in
    select p.proname, pg_get_functiondef(p.oid) as def
      from pg_proc p join pg_namespace n on n.oid = p.pronamespace
     where n.nspname = 'public'
       and p.proname in ('listar_portarias', 'casa_oracao_na_abrangencia', 'casa_oracao_na_minha_abrangencia',
                         'minhas_cidades', 'minha_cota_portarias', 'cidade_na_abrangencia', 'portaria_janela_aberta')
     order by p.proname
  loop
    secao := 'F_funcao_' || r.proname; conteudo := r.def; return next;
  end loop;
end
$f$;

select * from pg_temp.diag2();
