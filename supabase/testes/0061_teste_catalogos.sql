-- TESTE da 0061 — NÃO GRAVA NADA. Esperado: nenhuma linha FALHOU.
create or replace function pg_temp.tenta(p_sql text) returns text language plpgsql as $f$
begin
  begin
    execute p_sql;
    raise exception using errcode = 'XX999', message = '__reverter__';
  exception when others then
    if sqlerrm = '__reverter__' then return 'PERMITIDO'; end if;
    return 'BLOQUEADO: ' || sqlerrm;
  end;
end $f$;

create or replace function pg_temp.teste4()
returns table(ordem int, verificacao text, esperado text, obtido text, resultado text)
language plpgsql as $f$
declare
  v_jer uuid; v_adm uuid; v_reg uuid; v_n int := 0; v_t text; v_id uuid; v_r text;
begin
  select u.id into v_jer from public.usuarios u where lower(u.email) = 'jerrivan@congregacao.org.br';
  select u.id into v_adm from public.usuarios u where lower(u.email) = 'levialencar@gmail.com';
  select g.id into v_reg from public.grupos g where g.nome = 'Administrador Regional';
  begin
    insert into public.usuario_grupos (usuario_id, grupo_id) values (v_jer, v_reg) on conflict do nothing;
    -- pior caso: dá ao Regional as permissões de catálogo só nesta simulação
    insert into public.grupo_permissoes (grupo_id, permissao_codigo)
      select v_reg, p.codigo from public.permissoes p where p.codigo ~ '^(instrumentos|familias|hinos|tipoevento|tipos_evento)\.' and p.codigo not like '%.visualizar' on conflict do nothing;

    perform set_config('request.jwt.claims', json_build_object('sub', v_jer, 'role', 'authenticated')::text, true);
    perform set_config('request.jwt.claim.sub', v_jer::text, true);

    foreach v_t in array array['instrumentos', 'familias', 'hinos', 'tipos_evento'] loop
      v_n := v_n + 1; ordem := v_n; verificacao := 'Regional ALTERA ' || v_t; esperado := 'BLOQUEADO';
      if to_regclass('public.' || v_t) is null then
        obtido := 'n/a (tabela não existe)'; resultado := 'INFO';
      else
        execute format('select id from public.%I limit 1', v_t) into v_id;
        if v_id is null then obtido := 'n/a (tabela vazia)'; resultado := 'INFO';
        else
          obtido := pg_temp.tenta(format('update public.%I set nome = nome where id = %L', v_t, v_id));
          resultado := case when obtido like 'BLOQUEADO: Este cadastro é compartilhado%' then 'OK' else 'FALHOU' end;
        end if;
      end if;
      return next;
    end loop;

    v_n := v_n + 1; ordem := v_n; verificacao := 'Regional EXCLUI instrumento'; esperado := 'BLOQUEADO';
    select id into v_id from public.instrumentos limit 1;
    obtido := case when v_id is null then 'n/a (tabela vazia)' else pg_temp.tenta(format('delete from public.instrumentos where id = %L', v_id)) end;
    resultado := case when v_id is null then 'INFO' when obtido like 'BLOQUEADO%' then 'OK' else 'FALHOU' end; return next;

    v_n := v_n + 1; ordem := v_n; verificacao := 'Regional pode conceder Secretaria (deve continuar permitido)'; esperado := 'true';
    obtido := coalesce((select public.grupo_concedivel(g.id)::text from public.grupos g where g.nome = 'Secretaria'), 'n/a');
    resultado := case when obtido = 'true' then 'OK' else 'FALHOU' end; return next;

    v_n := v_n + 1; ordem := v_n; verificacao := 'Regional pode conceder o grupo Administrador'; esperado := 'false';
    obtido := coalesce((select public.grupo_concedivel(g.id)::text from public.grupos g where g.sistema and g.nome = 'Administrador'), 'n/a');
    resultado := case when obtido = 'false' then 'OK' else 'FALHOU' end; return next;

    -- Administrador global continua podendo
    perform set_config('request.jwt.claims', json_build_object('sub', v_adm, 'role', 'authenticated')::text, true);
    perform set_config('request.jwt.claim.sub', v_adm::text, true);
    v_n := v_n + 1; ordem := v_n; verificacao := 'Administrador ALTERA instrumento (deve continuar permitido)'; esperado := 'PERMITIDO';
    select id into v_id from public.instrumentos limit 1;
    obtido := case when v_id is null then 'n/a (tabela vazia)' else pg_temp.tenta(format('update public.instrumentos set nome = nome where id = %L', v_id)) end;
    resultado := case when v_id is null then 'INFO' when obtido = 'PERMITIDO' then 'OK' else 'FALHOU' end; return next;

    raise exception using errcode = 'XX999', message = '__reverter__';
  exception when others then
    if sqlerrm <> '__reverter__' then raise; end if;
  end;
end $f$;

select * from pg_temp.teste4();
