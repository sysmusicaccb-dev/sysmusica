-- TESTE da 0059 — NÃO GRAVA NADA. Esperado: nenhuma linha FALHOU.
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

create or replace function pg_temp.teste3()
returns table(ordem int, verificacao text, esperado text, obtido text, resultado text)
language plpgsql as $f$
declare
  v_jer uuid; v_reg uuid; v_me uuid; v_md uuid; v_po uuid; v_pod uuid; n int := 0;
begin
  select u.id into v_jer from public.usuarios u where lower(u.email) = 'jerrivan@congregacao.org.br';
  select g.id into v_reg from public.grupos g where g.nome = 'Administrador Regional';
  begin
    insert into public.usuario_grupos (usuario_id, grupo_id) values (v_jer, v_reg) on conflict do nothing;
    insert into public.grupo_permissoes (grupo_id, permissao_codigo)
      select v_reg, p.codigo from public.permissoes p
       where p.codigo in ('membros.qr', 'membros.qr_revogar', 'portaria.registrar') on conflict do nothing;
    perform set_config('request.jwt.claims', json_build_object('sub', v_jer, 'role', 'authenticated')::text, true);
    perform set_config('request.jwt.claim.sub', v_jer::text, true);

    select m.id into v_me from public.membros m where m.excluido_em is null and not public.casa_oracao_na_abrangencia(m.casa_oracao_id) limit 1;
    select m.id into v_md from public.membros m where m.excluido_em is null and public.casa_oracao_na_abrangencia(m.casa_oracao_id) limit 1;
    select p.id into v_po from public.portarias p where p.excluido_em is null and not public.casa_oracao_na_abrangencia(p.casa_oracao_id) limit 1;
    select p.id into v_pod from public.portarias p where p.excluido_em is null and public.casa_oracao_na_abrangencia(p.casa_oracao_id) limit 1;

    n := n + 1; ordem := n; verificacao := 'obter_qr_membro de outra região'; esperado := 'BLOQUEADO';
    obtido := case when v_me is null then 'n/a (sem membro fora da região)' else pg_temp.tenta(format('select public.obter_qr_membro(%L)', v_me)) end;
    resultado := case when v_me is null then 'INFO' when obtido like 'BLOQUEADO%abrang%' then 'OK' else 'FALHOU' end; return next;

    n := n + 1; ordem := n; verificacao := 'regenerar_qr de outra região'; esperado := 'BLOQUEADO';
    obtido := case when v_me is null then 'n/a (sem membro fora da região)' else pg_temp.tenta(format('select public.regenerar_qr(%L, %L)', v_me, 'teste de isolamento regional')) end;
    resultado := case when v_me is null then 'INFO' when obtido like 'BLOQUEADO%abrang%' then 'OK' else 'FALHOU' end; return next;

    n := n + 1; ordem := n; verificacao := 'registrar_entrada em portaria de outra região'; esperado := 'BLOQUEADO';
    obtido := case when v_po is null or v_md is null then 'n/a' else pg_temp.tenta(format('select public.registrar_entrada(%L, %L)', v_po, v_md)) end;
    resultado := case when v_po is null or v_md is null then 'INFO' when obtido like 'BLOQUEADO: Portaria indispon%' then 'OK' else 'FALHOU' end; return next;

    n := n + 1; ordem := n; verificacao := 'obter_qr_membro da PRÓPRIA região (deve continuar permitido)'; esperado := 'PERMITIDO';
    obtido := case when v_md is null then 'n/a (sem membro na região)' else pg_temp.tenta(format('select public.obter_qr_membro(%L)', v_md)) end;
    resultado := case when v_md is null then 'INFO' when obtido = 'PERMITIDO' then 'OK' else 'FALHOU' end; return next;

    n := n + 1; ordem := n; verificacao := 'regenerar_qr da PRÓPRIA região (deve continuar permitido)'; esperado := 'PERMITIDO';
    obtido := case when v_md is null then 'n/a (sem membro na região)' else pg_temp.tenta(format('select public.regenerar_qr(%L, %L)', v_md, 'teste de isolamento regional')) end;
    resultado := case when v_md is null then 'INFO' when obtido = 'PERMITIDO' then 'OK' else 'FALHOU' end; return next;

    raise exception using errcode = 'XX999', message = '__reverter__';
  exception when others then
    if sqlerrm <> '__reverter__' then raise; end if;
  end;
end $f$;

select * from pg_temp.teste3();
