-- TESTE da 0074 — NÃO GRAVA NADA (tudo é desfeito no final). Esperado: nenhuma linha FALHOU.

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

create or replace function pg_temp.teste74()
returns table(ordem int, verificacao text, esperado text, obtido text, resultado text)
language plpgsql as $f$
declare
  v_master uuid; v_casa uuid; n int := 0; v text;
begin
  select u.id into v_master from public.usuarios u where lower(u.email) = 'levialencar@gmail.com';
  select m.casa_oracao_id into v_casa from public.membros m where m.excluido_em is null and m.casa_oracao_id is not null limit 1;
  begin
    perform set_config('request.jwt.claims', json_build_object('sub', v_master, 'role', 'authenticated')::text, true);
    perform set_config('request.jwt.claim.sub', v_master::text, true);

    foreach v in array array['M01','M02','M03','M05','M07','AVALIACAO_RJM','AVALIACAO_CANDIDATO','PRE_AVALIACAO_ORGANISTA','EXAME_ORGANISTA','ACOMPANHAMENTO_GEM'] loop
      n := n + 1; ordem := n; verificacao := 'Sem pessoa do cadastro: ' || v; esperado := 'BLOQUEADO';
      obtido := pg_temp.tenta(format('select public.salvar_ficha(null, %L, null, %L, %L::jsonb)', v, v_casa, '{"nome":"Fulano"}'));
      resultado := case when obtido like 'BLOQUEADO: Escolha a pessoa no cadastro%' then 'OK' else 'FALHOU' end; return next;
    end loop;

    n := n + 1; ordem := n; verificacao := 'Necessidade de instrumentos continua aceitando só a Casa'; esperado := 'PERMITIDO';
    obtido := pg_temp.tenta(format('select public.salvar_ficha(null, %L, null, %L, %L::jsonb)', 'NECESSIDADE_INSTRUMENTO', v_casa, '{"nome":"Beneficiário"}'));
    resultado := case when obtido = 'PERMITIDO' then 'OK' else 'FALHOU' end; return next;

    raise exception using errcode = 'XX999', message = '__reverter__';
  exception when others then
    if sqlerrm <> '__reverter__' then raise; end if;
  end;
end
$f$;

select * from pg_temp.teste74();
