-- TESTE da 0075 (liberação para RJM) — NÃO GRAVA NADA (tudo é desfeito no final). Esperado: nenhuma linha FALHOU.

create or replace function pg_temp.teste75()
returns table(ordem int, verificacao text, esperado text, obtido text, resultado text)
language plpgsql as $f$
declare
  v_master uuid; v_m uuid; v_casa uuid; v_cargo_mus uuid; v_instr uuid; v_ficha uuid; v_cat text; v text;
  n int := 0;
begin
  select u.id into v_master from public.usuarios u where lower(u.email) = 'levialencar@gmail.com';
  select g.id into v_cargo_mus from public.cargos g where public.normalizar_texto(g.nome) like 'musico%' limit 1;
  select i.id into v_instr from public.instrumentos i where public.normalizar_texto(i.nome) not like '%orgao%' limit 1;
  select m.id, m.casa_oracao_id into v_m, v_casa from public.membros m where m.excluido_em is null and m.casa_oracao_id is not null limit 1;
  begin
    perform set_config('request.jwt.claims', json_build_object('sub', v_master, 'role', 'authenticated')::text, true);
    perform set_config('request.jwt.claim.sub', v_master::text, true);
    if v_m is null or v_cargo_mus is null then
      n := n + 1; ordem := n; verificacao := 'Falta membro ou cargo Músico para testar'; esperado := '-'; obtido := 'n/a'; resultado := 'INFO'; return next;
      raise exception using errcode = 'XX999', message = '__reverter__';
    end if;

    -- Candidato (sem categoria) aprovado na avaliação vira RJM
    update public.membros set cargo_id = v_cargo_mus, categoria = null, instrumento_id = v_instr where id = v_m;
    v_ficha := public.salvar_ficha(null, 'AVALIACAO_CANDIDATO', v_m, null, '{"nome":"Teste"}'::jsonb);
    perform public.definir_resultado_ficha(v_ficha, 'APTO');
    select categoria into v_cat from public.membros where id = v_m;
    n := n + 1; ordem := n; verificacao := 'Candidato Apto vira RJM'; esperado := 'RJM'; obtido := coalesce(v_cat, 'nulo');
    resultado := case when v_cat = 'RJM' then 'OK' else 'FALHOU' end; return next;

    -- Quem já está em RJM não entra mais no GEM, e a mensagem diz que é só para candidatos
    v := public.avaliar_elegibilidade_ficha('M01', v_m, '{}'::jsonb);
    n := n + 1; ordem := n; verificacao := 'RJM não entra no GEM (mensagem)'; esperado := 'O GEM é só para candidatos...'; obtido := coalesce(v, 'pode');
    resultado := case when v like 'O GEM é só para candidatos%' then 'OK' else 'FALHOU' end; return next;

    -- Quem já está em RJM não faz mais a avaliação de candidato
    v := public.avaliar_elegibilidade_ficha('AVALIACAO_CANDIDATO', v_m, '{}'::jsonb);
    n := n + 1; ordem := n; verificacao := 'RJM não refaz avaliação de candidato'; esperado := 'motivo'; obtido := coalesce(v, 'pode');
    resultado := case when v is not null then 'OK' else 'FALHOU' end; return next;

    -- Segue a escada: RJM pode M02
    v := public.avaliar_elegibilidade_ficha('M02', v_m, '{}'::jsonb);
    n := n + 1; ordem := n; verificacao := 'RJM PODE M02 (Culto Oficial)'; esperado := 'pode'; obtido := coalesce(v, 'pode');
    resultado := case when v is null then 'OK' else 'FALHOU' end; return next;

    -- Não apto não muda o cadastro
    update public.membros set categoria = null where id = v_m;
    v_ficha := public.salvar_ficha(null, 'AVALIACAO_RJM', v_m, null, '{"nome":"Teste"}'::jsonb);
    perform public.definir_resultado_ficha(v_ficha, 'NAO_APTO');
    select categoria into v_cat from public.membros where id = v_m;
    n := n + 1; ordem := n; verificacao := 'Não apto não muda o cadastro'; esperado := 'nulo'; obtido := coalesce(v_cat, 'nulo');
    resultado := case when v_cat is null then 'OK' else 'FALHOU' end; return next;

    raise exception using errcode = 'XX999', message = '__reverter__';
  exception when others then
    if sqlerrm <> '__reverter__' then raise; end if;
  end;
end
$f$;

select * from pg_temp.teste75();
