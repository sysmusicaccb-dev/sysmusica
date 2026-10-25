-- Teste da 0067 (rode no SQL Editor; nada fica gravado). Mostra uma linha por verificação: tudo deve dar OK.
create or replace function pg_temp.tenta(p_sql text) returns text language plpgsql as $$
begin
  begin
    execute p_sql;
    return 'OK';
  exception when others then
    return sqlstate;
  end;
end $$;

create or replace function pg_temp.rodar() returns table(n int, teste text, resultado text) language plpgsql as $$
declare arr jsonb := '[]'::jsonb;
  v_master uuid; v_outro uuid; v_r text; v_json jsonb; v_antigo text;
  c1 text := 'logo-' || replace(gen_random_uuid()::text, '-', '') || '.png';
  c2 text := 'logo-' || replace(gen_random_uuid()::text, '-', '') || '.svg';

begin
  begin -- tudo daqui até o fim é desfeito (subtransação)
  select u.id into v_master from auth.users u where lower(u.email) = 'levialencar@gmail.com' limit 1;
  select u.id into v_outro from auth.users u where lower(coalesce(u.email, '')) <> 'levialencar@gmail.com' limit 1;

  -- 1) sem linha: vale o padrão (null)
  perform set_config('request.jwt.claims', json_build_object('sub', v_master, 'role', 'authenticated')::text, true);
  arr := arr || jsonb_build_array(jsonb_build_object('n', 1, 'teste', 'sem logo gravada devolve nulo', 'resultado', case when public.marca_do_sistema() is null then 'OK' else 'ERRO' end));

  -- 2) Master tenta gravar sem o arquivo existir no armazenamento: recusa
  v_r := pg_temp.tenta(format('select public.salvar_marca_do_sistema(%L, %L, 256, 256, 5000)', c1, 'image/png'));
  arr := arr || jsonb_build_array(jsonb_build_object('n', 2, 'teste', 'arquivo inexistente é recusado (22023)', 'resultado', case when v_r = '22023' then 'OK' else 'ERRO '||v_r end));

  insert into storage.objects (bucket_id, name) values ('marca', c1), ('marca', c2);

  -- 3) Master grava
  select public.salvar_marca_do_sistema(c1, 'image/png', 256, 256, 5000) into v_antigo;
  v_json := public.marca_do_sistema();
  arr := arr || jsonb_build_array(jsonb_build_object('n', 3, 'teste', 'Master grava e a leitura devolve os dados', 'resultado', case when v_json->>'caminho' = c1 and (v_json->>'largura')::int = 256 and v_antigo is null then 'OK' else 'ERRO '||v_json::text end));

  -- 4) trocar devolve o caminho antigo
  select public.salvar_marca_do_sistema(c2, 'image/svg+xml', 512, 256, 3000) into v_antigo;
  arr := arr || jsonb_build_array(jsonb_build_object('n', 4, 'teste', 'trocar devolve o arquivo anterior para apagar', 'resultado', case when v_antigo = c1 then 'OK' else 'ERRO '||coalesce(v_antigo,'nulo') end));

  -- 5) validações
  v_r := pg_temp.tenta(format('select public.salvar_marca_do_sistema(%L, %L, 256, 256, 5000)', c2, 'image/gif'));
  arr := arr || jsonb_build_array(jsonb_build_object('n', 5, 'teste', 'tipo GIF recusado', 'resultado', case when v_r = '22023' then 'OK' else 'ERRO '||v_r end));
  v_r := pg_temp.tenta(format('select public.salvar_marca_do_sistema(%L, %L, 32, 256, 5000)', c2, 'image/png'));
  arr := arr || jsonb_build_array(jsonb_build_object('n', 6, 'teste', 'largura menor que 64 recusada', 'resultado', case when v_r = '22023' then 'OK' else 'ERRO '||v_r end));
  v_r := pg_temp.tenta(format('select public.salvar_marca_do_sistema(%L, %L, 256, 3000, 5000)', c2, 'image/png'));
  arr := arr || jsonb_build_array(jsonb_build_object('n', 7, 'teste', 'altura maior que 2048 recusada', 'resultado', case when v_r = '22023' then 'OK' else 'ERRO '||v_r end));
  v_r := pg_temp.tenta(format('select public.salvar_marca_do_sistema(%L, %L, 256, 256, 2000000)', c2, 'image/png'));
  arr := arr || jsonb_build_array(jsonb_build_object('n', 8, 'teste', 'arquivo acima de 1 MB recusado', 'resultado', case when v_r = '22023' then 'OK' else 'ERRO '||v_r end));
  v_r := pg_temp.tenta($q$select public.salvar_marca_do_sistema('../outro.png', 'image/png', 256, 256, 5000)$q$);
  arr := arr || jsonb_build_array(jsonb_build_object('n', 9, 'teste', 'nome de arquivo estranho recusado', 'resultado', case when v_r = '22023' then 'OK' else 'ERRO '||v_r end));

  -- 10) quem não é Master não grava nem restaura
  perform set_config('request.jwt.claims', json_build_object('sub', v_outro, 'role', 'authenticated')::text, true);
  v_r := pg_temp.tenta(format('select public.salvar_marca_do_sistema(%L, %L, 256, 256, 5000)', c1, 'image/png'));
  arr := arr || jsonb_build_array(jsonb_build_object('n', 10, 'teste', 'outra pessoa não grava (42501)', 'resultado', case when v_r = '42501' then 'OK' else 'ERRO '||v_r end));
  v_r := pg_temp.tenta('select public.restaurar_marca_padrao()');
  arr := arr || jsonb_build_array(jsonb_build_object('n', 11, 'teste', 'outra pessoa não restaura (42501)', 'resultado', case when v_r = '42501' then 'OK' else 'ERRO '||v_r end));
  -- 12) qualquer pessoa lê
  arr := arr || jsonb_build_array(jsonb_build_object('n', 12, 'teste', 'qualquer pessoa lê a logo atual', 'resultado', case when public.marca_do_sistema()->>'caminho' = c2 then 'OK' else 'ERRO' end));

  -- 13) Master restaura
  perform set_config('request.jwt.claims', json_build_object('sub', v_master, 'role', 'authenticated')::text, true);
  select public.restaurar_marca_padrao() into v_antigo;
  arr := arr || jsonb_build_array(jsonb_build_object('n', 13, 'teste', 'Master restaura o padrão e a leitura volta nula', 'resultado', case when v_antigo = c2 and public.marca_do_sistema() is null then 'OK' else 'ERRO' end));

  raise exception '__reverter__' using errcode = 'XX999';
  exception when sqlstate 'XX999' then null;
  end;
  return query select (x->>'n')::int, x->>'teste', x->>'resultado' from jsonb_array_elements(arr) x order by 1;
end $$;

select * from pg_temp.rodar();
