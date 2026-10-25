-- TESTE da 0070 — NÃO GRAVA NADA (tudo é desfeito no final). Esperado: nenhuma linha FALHOU.
-- Usa o Master (todas as regiões) e o Jerrivan (Administrador Regional, SEM a permissão de resultado).

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

create or replace function pg_temp.teste70()
returns table(ordem int, verificacao text, esperado text, obtido text, resultado text)
language plpgsql as $f$
declare
  v_master uuid; v_jer uuid; v_reg uuid;
  v_m uuid; v_casa uuid; v_ficha uuid; v_ficha2 uuid; v_cat text; v_qtd int; v_fora uuid; v_ficha_fora uuid;
  n int := 0;
begin
  select u.id into v_master from public.usuarios u where lower(u.email) = 'levialencar@gmail.com';
  select u.id into v_jer    from public.usuarios u where lower(u.email) = 'jerrivan@congregacao.org.br';
  select g.id into v_reg    from public.grupos g where g.nome = 'Administrador Regional';
  begin
    -- ---------- Master ----------
    perform set_config('request.jwt.claims', json_build_object('sub', v_master, 'role', 'authenticated')::text, true);
    perform set_config('request.jwt.claim.sub', v_master::text, true);

    select m.id, m.casa_oracao_id into v_m, v_casa from public.membros m
     where m.excluido_em is null and m.categoria = 'RJM' and m.casa_oracao_id is not null limit 1;

    if v_m is null then
      n := n + 1; ordem := n; verificacao := 'Sem membro RJM no cadastro para testar'; esperado := '-'; obtido := 'n/a'; resultado := 'INFO'; return next;
    else
      v_ficha := public.salvar_ficha(null, 'M02', v_m, null, jsonb_build_object('nome', 'Teste', 'instrumento', 'Teste'));
      n := n + 1; ordem := n; verificacao := 'Master cria ficha M02'; esperado := 'id'; obtido := coalesce(v_ficha::text, 'nulo');
      resultado := case when v_ficha is not null then 'OK' else 'FALHOU' end; return next;

      select count(*) into v_qtd from public.listar_fichas('M02') f where f.id = v_ficha;
      n := n + 1; ordem := n; verificacao := 'Ficha aparece na lista'; esperado := '1'; obtido := v_qtd::text;
      resultado := case when v_qtd = 1 then 'OK' else 'FALHOU' end; return next;

      perform public.definir_resultado_ficha(v_ficha, 'APTO');
      select m.categoria into v_cat from public.membros m where m.id = v_m;
      n := n + 1; ordem := n; verificacao := 'Apto na M02 muda a categoria para CULTO_OFICIAL'; esperado := 'CULTO_OFICIAL'; obtido := coalesce(v_cat, 'nulo');
      resultado := case when v_cat = 'CULTO_OFICIAL' then 'OK' else 'FALHOU' end; return next;

      n := n + 1; ordem := n; verificacao := 'Ficha com resultado não pode mais ser alterada'; esperado := 'BLOQUEADO';
      obtido := pg_temp.tenta(format('select public.salvar_ficha(%L, %L, %L, null, %L::jsonb)', v_ficha, 'M02', v_m, '{"nome":"x"}'));
      resultado := case when obtido like 'BLOQUEADO%' then 'OK' else 'FALHOU' end; return next;

      n := n + 1; ordem := n; verificacao := 'Ficha que alterou o cadastro não pode ser excluída'; esperado := 'BLOQUEADO';
      obtido := pg_temp.tenta(format('select public.excluir_ficha(%L)', v_ficha));
      resultado := case when obtido like 'BLOQUEADO%' then 'OK' else 'FALHOU' end; return next;
    end if;

    -- ---------- Jerrivan (regional, sem fichas.resultado) ----------
    if v_jer is not null then
      insert into public.usuario_grupos (usuario_id, grupo_id) values (v_jer, v_reg) on conflict do nothing;
      perform set_config('request.jwt.claims', json_build_object('sub', v_jer, 'role', 'authenticated')::text, true);
      perform set_config('request.jwt.claim.sub', v_jer::text, true);

      n := n + 1; ordem := n; verificacao := 'Regional NÃO pode marcar resultado'; esperado := 'BLOQUEADO';
      obtido := case when v_ficha is null then 'n/a' else pg_temp.tenta(format('select public.definir_resultado_ficha(%L, %L)', v_ficha, 'NAO_APTO')) end;
      resultado := case when v_ficha is null then 'INFO' when obtido like 'BLOQUEADO%' then 'OK' else 'FALHOU' end; return next;

      -- ficha criada pelo Master numa casa FORA da região do Jerrivan: ele não pode ver
      select m.id into v_fora from public.membros m
       where m.excluido_em is null and m.casa_oracao_id is not null and not public.casa_oracao_na_abrangencia(m.casa_oracao_id) limit 1;
      if v_fora is null then
        n := n + 1; ordem := n; verificacao := 'Regional não vê ficha de outra região'; esperado := '-'; obtido := 'n/a (sem membro fora da região)'; resultado := 'INFO'; return next;
      else
        perform set_config('request.jwt.claims', json_build_object('sub', v_master, 'role', 'authenticated')::text, true);
        perform set_config('request.jwt.claim.sub', v_master::text, true);
        v_ficha_fora := public.salvar_ficha(null, 'M03', v_fora, null, '{"nome":"Fora"}'::jsonb);
        perform set_config('request.jwt.claims', json_build_object('sub', v_jer, 'role', 'authenticated')::text, true);
        perform set_config('request.jwt.claim.sub', v_jer::text, true);
        select count(*) into v_qtd from public.listar_fichas(null) f where f.id = v_ficha_fora;
        n := n + 1; ordem := n; verificacao := 'Regional não vê ficha de outra região na lista'; esperado := '0'; obtido := v_qtd::text;
        resultado := case when v_qtd = 0 then 'OK' else 'FALHOU' end; return next;
        n := n + 1; ordem := n; verificacao := 'Regional não abre ficha de outra região'; esperado := 'BLOQUEADO';
        obtido := pg_temp.tenta(format('select public.obter_ficha(%L)', v_ficha_fora));
        resultado := case when obtido like 'BLOQUEADO%' then 'OK' else 'FALHOU' end; return next;
        n := n + 1; ordem := n; verificacao := 'Regional não cria ficha em casa de outra região'; esperado := 'BLOQUEADO';
        obtido := pg_temp.tenta(format('select public.salvar_ficha(null, %L, %L, null, %L::jsonb)', 'M02', v_fora, '{"nome":"x"}'));
        resultado := case when obtido like 'BLOQUEADO%' then 'OK' else 'FALHOU' end; return next;
      end if;
    end if;

    raise exception using errcode = 'XX999', message = '__reverter__';
  exception when others then
    if sqlerrm <> '__reverter__' then raise; end if;
  end;
end
$f$;

select * from pg_temp.teste70();
