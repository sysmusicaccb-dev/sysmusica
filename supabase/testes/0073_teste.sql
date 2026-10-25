-- TESTE da 0073 (trava de etapa) — NÃO GRAVA NADA (tudo é desfeito no final). Esperado: nenhuma linha FALHOU.
-- Usa um membro qualquer (muda cargo/categoria só dentro do teste) e confere a regra de cada ficha.

create or replace function pg_temp.tenta(p_sql text)
returns text language plpgsql as $f$
begin
  begin
    execute p_sql;
    raise exception using errcode = 'XX999', message = '__reverter__';
  exception when others then
    if sqlerrm = '__reverter__' then return 'PERMITIDO'; end if;
    return 'BLOQUEADO: ' || sqlerrm;
  end;
end
$f$;

create or replace function pg_temp.teste73()
returns table(ordem int, verificacao text, esperado text, obtido text, resultado text)
language plpgsql as $f$
declare
  v_master uuid; v_m uuid; v_casa uuid; v_cargo_mus uuid; v_cargo_coop uuid; v_instr uuid; v_ficha uuid;
  n int := 0; v text;
begin
  select u.id into v_master from public.usuarios u where lower(u.email) = 'levialencar@gmail.com';
  select g.id into v_cargo_mus  from public.cargos g where public.normalizar_texto(g.nome) like 'musico%' limit 1;
  select g.id into v_cargo_coop from public.cargos g where public.normalizar_texto(g.nome) like 'cooperador%' limit 1;
  select i.id into v_instr from public.instrumentos i where public.normalizar_texto(i.nome) not like '%orgao%' limit 1;
  select m.id, m.casa_oracao_id into v_m, v_casa from public.membros m where m.excluido_em is null and m.casa_oracao_id is not null limit 1;

  begin
    perform set_config('request.jwt.claims', json_build_object('sub', v_master, 'role', 'authenticated')::text, true);
    perform set_config('request.jwt.claim.sub', v_master::text, true);
    if v_m is null or v_cargo_mus is null then
      n := n + 1; ordem := n; verificacao := 'Falta membro ou cargo Músico para testar'; esperado := '-'; obtido := 'n/a'; resultado := 'INFO'; return next;
      raise exception using errcode = 'XX999', message = '__reverter__';
    end if;

    -- ======== Músico SEM etapa ========
    update public.membros set cargo_id = v_cargo_mus, categoria = null, instrumento_id = v_instr where id = v_m;
    v := public.avaliar_elegibilidade_ficha('M01', v_m, '{}'::jsonb);
    n := n + 1; ordem := n; verificacao := 'Sem etapa PODE: ingresso no GEM (M01)'; esperado := 'pode'; obtido := coalesce(v, 'pode');
    resultado := case when v is null then 'OK' else 'FALHOU' end; return next;
    v := public.avaliar_elegibilidade_ficha('AVALIACAO_RJM', v_m, '{}'::jsonb);
    n := n + 1; ordem := n; verificacao := 'Sem etapa PODE: avaliação para RJM'; esperado := 'pode'; obtido := coalesce(v, 'pode');
    resultado := case when v is null then 'OK' else 'FALHOU' end; return next;
    v := public.avaliar_elegibilidade_ficha('M02', v_m, '{}'::jsonb);
    n := n + 1; ordem := n; verificacao := 'Sem etapa NÃO pode: M02 (Culto Oficial)'; esperado := 'motivo'; obtido := coalesce(v, 'pode');
    resultado := case when v is not null then 'OK' else 'FALHOU' end; return next;
    v := public.avaliar_elegibilidade_ficha('M07', v_m, '{}'::jsonb);
    n := n + 1; ordem := n; verificacao := 'Sem etapa NÃO pode: troca de instrumento (M07)'; esperado := 'motivo'; obtido := coalesce(v, 'pode');
    resultado := case when v is not null then 'OK' else 'FALHOU' end; return next;

    -- ======== RJM ========
    update public.membros set categoria = 'RJM' where id = v_m;
    v := public.avaliar_elegibilidade_ficha('M02', v_m, '{}'::jsonb);
    n := n + 1; ordem := n; verificacao := 'RJM PODE: M02 (Culto Oficial)'; esperado := 'pode'; obtido := coalesce(v, 'pode');
    resultado := case when v is null then 'OK' else 'FALHOU' end; return next;
    foreach v in array array['M01', 'ACOMPANHAMENTO_GEM', 'AVALIACAO_CANDIDATO', 'AVALIACAO_RJM', 'M03'] loop
      n := n + 1; ordem := n; verificacao := 'RJM NÃO pode: ' || v; esperado := 'motivo';
      obtido := coalesce(public.avaliar_elegibilidade_ficha(v, v_m, '{}'::jsonb), 'pode');
      resultado := case when obtido <> 'pode' then 'OK' else 'FALHOU' end; return next;
    end loop;

    -- ======== Culto Oficial ========
    update public.membros set categoria = 'CULTO_OFICIAL' where id = v_m;
    v := public.avaliar_elegibilidade_ficha('M03', v_m, '{}'::jsonb);
    n := n + 1; ordem := n; verificacao := 'Culto Oficial PODE: M03 (Oficialização)'; esperado := 'pode'; obtido := coalesce(v, 'pode');
    resultado := case when v is null then 'OK' else 'FALHOU' end; return next;
    v := public.avaliar_elegibilidade_ficha('M02', v_m, '{}'::jsonb);
    n := n + 1; ordem := n; verificacao := 'Culto Oficial NÃO pode: M02 (já passou)'; esperado := 'motivo'; obtido := coalesce(v, 'pode');
    resultado := case when v is not null then 'OK' else 'FALHOU' end; return next;

    -- ======== Oficializado ========
    update public.membros set categoria = 'OFICIALIZADO' where id = v_m;
    foreach v in array array['M01', 'ACOMPANHAMENTO_GEM', 'AVALIACAO_CANDIDATO', 'AVALIACAO_RJM', 'M02', 'M03', 'M05', 'PRE_AVALIACAO_ORGANISTA', 'EXAME_ORGANISTA'] loop
      n := n + 1; ordem := n; verificacao := 'Oficializado NÃO pode: ' || v; esperado := 'motivo';
      obtido := coalesce(public.avaliar_elegibilidade_ficha(v, v_m, '{}'::jsonb), 'pode');
      resultado := case when obtido <> 'pode' then 'OK' else 'FALHOU' end; return next;
    end loop;
    v := public.avaliar_elegibilidade_ficha('M07', v_m, '{}'::jsonb);
    n := n + 1; ordem := n; verificacao := 'Oficializado (com instrumento) PODE: troca de instrumento (M07)'; esperado := 'pode'; obtido := coalesce(v, 'pode');
    resultado := case when v is null then 'OK' else 'FALHOU' end; return next;
    v := public.avaliar_elegibilidade_ficha('NECESSIDADE_INSTRUMENTO', v_m, '{}'::jsonb);
    n := n + 1; ordem := n; verificacao := 'Oficializado PODE: necessidade de instrumentos'; esperado := 'pode'; obtido := coalesce(v, 'pode');
    resultado := case when v is null then 'OK' else 'FALHOU' end; return next;

    -- ======== Salvar e Apto passam pela trava ========
    n := n + 1; ordem := n; verificacao := 'salvar_ficha recusa M01 para Oficializado'; esperado := 'BLOQUEADO';
    obtido := pg_temp.tenta(format('select public.salvar_ficha(null, %L, %L, null, %L::jsonb)', 'M01', v_m, '{"nome":"x"}'));
    resultado := case when obtido like 'BLOQUEADO%' then 'OK' else 'FALHOU' end; return next;

    update public.membros set categoria = 'RJM' where id = v_m;
    v_ficha := public.salvar_ficha(null, 'M02', v_m, null, '{"nome":"x"}'::jsonb);
    n := n + 1; ordem := n; verificacao := 'salvar_ficha aceita M02 para quem está em RJM'; esperado := 'id'; obtido := coalesce(v_ficha::text, 'nulo');
    resultado := case when v_ficha is not null then 'OK' else 'FALHOU' end; return next;
    update public.membros set categoria = 'OFICIALIZADO' where id = v_m; -- a etapa mudou depois de criar a ficha
    n := n + 1; ordem := n; verificacao := 'Apto NÃO rebaixa quem virou Oficializado'; esperado := 'BLOQUEADO';
    obtido := pg_temp.tenta(format('select public.definir_resultado_ficha(%L, %L)', v_ficha, 'APTO'));
    resultado := case when obtido like 'BLOQUEADO%' then 'OK' else 'FALHOU' end; return next;

    -- ======== Cargo de ministério (Cooperador) conta como Oficializado ========
    if v_cargo_coop is not null then
      update public.membros set cargo_id = v_cargo_coop, categoria = null where id = v_m;
      v := public.avaliar_elegibilidade_ficha('M01', v_m, '{}'::jsonb);
      n := n + 1; ordem := n; verificacao := 'Cooperador (que toca) NÃO entra no GEM'; esperado := 'motivo'; obtido := coalesce(v, 'pode');
      resultado := case when v is not null then 'OK' else 'FALHOU' end; return next;
    end if;

    -- ======== Mesmo nome sem escolher a pessoa ========
    update public.membros set cargo_id = v_cargo_mus, categoria = 'OFICIALIZADO' where id = v_m;
    n := n + 1; ordem := n; verificacao := 'Ficha sem pessoa escolhida mas com nome já cadastrado é recusada'; esperado := 'BLOQUEADO';
    obtido := pg_temp.tenta(format('select public.salvar_ficha(null, %L, null, %L, jsonb_build_object(%L, (select nome from public.membros where id = %L)))', 'M01', v_casa, 'nome', v_m));
    resultado := case when obtido like 'BLOQUEADO%' then 'OK' else 'FALHOU' end; return next;

    raise exception using errcode = 'XX999', message = '__reverter__';
  exception when others then
    if sqlerrm <> '__reverter__' then raise; end if;
  end;
end
$f$;

select * from pg_temp.teste73();
