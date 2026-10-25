-- TESTE da 0072 — NÃO GRAVA NADA. Esperado: nenhuma linha FALHOU.
-- Master lê os dados de um membro; o resultado não traz CPF nem QR; o Jerrivan não lê membro de outra região.

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

create or replace function pg_temp.teste72()
returns table(ordem int, verificacao text, esperado text, obtido text, resultado text)
language plpgsql as $f$
declare
  v_master uuid; v_jer uuid; v_m uuid; v_fora uuid; v_res jsonb; n int := 0;
begin
  select u.id into v_master from public.usuarios u where lower(u.email) = 'levialencar@gmail.com';
  select u.id into v_jer    from public.usuarios u where lower(u.email) = 'jerrivan@congregacao.org.br';

  perform set_config('request.jwt.claims', json_build_object('sub', v_master, 'role', 'authenticated')::text, true);
  perform set_config('request.jwt.claim.sub', v_master::text, true);
  select m.id into v_m from public.membros m where m.excluido_em is null and m.casa_oracao_id is not null limit 1;
  v_res := public.dados_do_membro_para_ficha(v_m);
  n := n + 1; ordem := n; verificacao := 'Master lê nome e Casa do membro'; esperado := 'nome e casa_nome';
  obtido := coalesce(v_res ->> 'nome', 'nulo') || ' / ' || coalesce(v_res ->> 'casa_nome', 'nulo');
  resultado := case when v_res ->> 'nome' is not null and v_res ->> 'casa_nome' is not null then 'OK' else 'FALHOU' end; return next;

  n := n + 1; ordem := n; verificacao := 'Resultado NÃO traz CPF, QR nem documentos'; esperado := 'sem cpf/qr_secret/documento';
  obtido := (select string_agg(k, ',') from jsonb_object_keys(v_res) k where k ilike '%cpf%' or k ilike '%qr%' or k ilike 'documento%');
  resultado := case when obtido is null then 'OK' else 'FALHOU' end; obtido := coalesce(obtido, 'nenhum'); return next;

  if v_jer is not null then
    perform set_config('request.jwt.claims', json_build_object('sub', v_jer, 'role', 'authenticated')::text, true);
    perform set_config('request.jwt.claim.sub', v_jer::text, true);
    -- procura um membro que o Jerrivan NÃO enxerga
    select m.id into v_fora from public.membros m
     where m.excluido_em is null and m.casa_oracao_id is not null
       and not public.ficha_visivel(m.casa_oracao_id) limit 1;
    if v_fora is null then
      n := n + 1; ordem := n; verificacao := 'Regional não lê membro de outra região'; esperado := '-'; obtido := 'sem membro de outra região para testar'; resultado := 'INFO'; return next;
    else
      n := n + 1; ordem := n; verificacao := 'Regional não lê membro de outra região'; esperado := 'BLOQUEADO';
      obtido := pg_temp.tenta(format('select public.dados_do_membro_para_ficha(%L)', v_fora));
      resultado := case when obtido like 'BLOQUEADO%' then 'OK' else 'FALHOU' end; return next;
    end if;
  end if;
end
$f$;

select * from pg_temp.teste72();
