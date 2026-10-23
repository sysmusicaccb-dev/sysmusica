-- DIAGNÓSTICO (somente leitura, não grava nada): por que o Jerrivan vê o Ensaio de Jequié?
-- Rode no SQL Editor e me envie o resultado inteiro (exportar CSV ou copiar).

create or replace function pg_temp.diag()
returns table(secao text, conteudo text)
language plpgsql
as $f$
declare
  v_jer uuid;
  r record;
  v_txt text;
begin
  select u.id into v_jer from public.usuarios u where lower(u.email) = 'jerrivan@congregacao.org.br';

  -- 1) Eventos que mencionam Jequié (linha inteira) e se o Jerrivan os enxerga pela regra de abrangência
  perform set_config('request.jwt.claims', json_build_object('sub', v_jer, 'role', 'authenticated')::text, true);
  perform set_config('request.jwt.claim.sub', v_jer::text, true);
  for r in
    select e.id, to_jsonb(e) as linha from public.eventos e
     where to_jsonb(e)::text ilike '%jequi%'
        or e.id in (select ev.id from public.eventos ev
                     where to_jsonb(ev) ->> 'casa_oracao_id' in
                           (select c.id::text from public.casas_oracao c where c.nome ilike '%jequi%'))
  loop
    secao := '1_evento'; conteudo := r.linha::text; return next;
    begin
      execute 'select public.evento_na_abrangencia($1)::text' into v_txt using r.id;
    exception when others then v_txt := 'ERRO: ' || sqlerrm; end;
    secao := '1_evento_na_abrangencia_do_Jerrivan'; conteudo := r.id::text || ' => ' || coalesce(v_txt, 'null'); return next;
  end loop;

  -- 2) O que a lista da Portaria devolve para o Jerrivan
  begin
    for r in execute 'select to_jsonb(x) as j from public.listar_eventos_para_portaria() x' loop
      secao := '2_lista_portaria_do_Jerrivan'; conteudo := r.j::text; return next;
    end loop;
  exception when others then
    secao := '2_lista_portaria_do_Jerrivan'; conteudo := 'ERRO: ' || sqlerrm; return next;
  end;

  -- 3) Onde fica Jequié na estrutura (cadeia até o estado) e os vínculos do Jerrivan
  for r in
    select 'casa' as t, c.id, c.nome from public.casas_oracao c where c.nome ilike '%jequi%'
    union all select 'adm', a.id, a.nome from public.adms a where a.nome ilike '%jequi%'
    union all select 'setor', s.id, s.nome from public.setores s where s.nome ilike '%jequi%'
    union all select 'ra', ra.id, ra.nome from public.ras ra where ra.nome ilike '%jequi%'
  loop
    secao := '3_estrutura_jequie';
    conteudo := r.t || ' ' || r.nome || ' (' || r.id || ') cadeia: ' ||
      coalesce((select string_agg(public.rotulo_vinculo(c.r_nivel, c.r_id), ' > ')
                  from public.cadeia_organizacao(upper(case r.t when 'casa' then 'CASA_ORACAO' else r.t end), r.id) c), '?');
    return next;
  end loop;
  for r in select v.nivel, v.alvo_id from public.usuario_vinculos v where v.usuario_id = v_jer loop
    secao := '3_vinculo_Jerrivan'; conteudo := r.nivel || ' ' || coalesce(public.rotulo_vinculo(r.nivel, r.alvo_id), r.alvo_id::text); return next;
  end loop;

  -- 4) Código das funções que alimentam estas telas
  for r in
    select p.proname, pg_get_functiondef(p.oid) as def
      from pg_proc p join pg_namespace n on n.oid = p.pronamespace
     where n.nspname = 'public'
       and (p.proname in ('evento_na_abrangencia', 'listar_eventos_para_portaria', 'pode_ver_portaria')
            or p.proname ilike '%presenca%' or p.proname ilike '%evento%')
     order by p.proname
  loop
    secao := '4_funcao_' || r.proname; conteudo := r.def; return next;
  end loop;

  -- 5) Políticas de segurança (RLS) da tabela de eventos e de presenças
  for r in
    select tablename, policyname, permissive, cmd, qual from pg_policies
     where schemaname = 'public' and tablename in ('eventos', 'presencas', 'portarias')
  loop
    secao := '5_politica'; conteudo := r.tablename || ' | ' || r.policyname || ' | ' || r.permissive || ' | ' || r.cmd || ' | ' || coalesce(r.qual, ''); return next;
  end loop;
end
$f$;

select * from pg_temp.diag();
