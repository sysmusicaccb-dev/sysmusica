-- TESTE da 0056 — NÃO GRAVA NADA. Simula o Jerrivan (Administrador Regional) e o Levi e conta as portarias que cada um enxerga.
-- Esperado: nenhuma linha FALHOU.

create or replace function pg_temp.teste_portarias()
returns table(verificacao text, esperado text, obtido text, resultado text)
language plpgsql
as $f$
declare
  v_jer uuid; v_levi uuid; v_reg uuid; v_n text;
begin
  select u.id into v_jer from public.usuarios u where lower(u.email) = 'jerrivan@congregacao.org.br';
  select u.id into v_levi from public.usuarios u where lower(u.email) = 'levialencar@gmail.com';
  select g.id into v_reg from public.grupos g where g.nome = 'Administrador Regional';
  begin
    insert into public.usuario_grupos (usuario_id, grupo_id) values (v_jer, v_reg) on conflict do nothing;

    perform set_config('request.jwt.claims', json_build_object('sub', v_jer, 'role', 'authenticated')::text, true);
    perform set_config('request.jwt.claim.sub', v_jer::text, true);
    select count(*)::text into v_n from public.listar_portarias() x
     where not exists (select 1 from public.portarias p where p.id = x.id and public.casa_oracao_na_abrangencia(p.casa_oracao_id));
    verificacao := 'Jerrivan: portarias listadas FORA da região dele'; esperado := '0'; obtido := v_n;
    resultado := case when obtido = esperado then 'OK' else 'FALHOU' end; return next;

    select count(*)::text into v_n from public.listar_portarias() x
     where x.evento_local ilike '%jequi%' or x.cidade ilike '%jequi%' or x.cidade ilike '%lauro%';
    verificacao := 'Jerrivan: portarias de Jequié ou Lauro de Freitas listadas'; esperado := '0'; obtido := v_n;
    resultado := case when obtido = esperado then 'OK' else 'FALHOU' end; return next;

    select count(*)::text into v_n from public.listar_portarias();
    verificacao := 'Jerrivan: total de portarias que ele enxerga (conferir)'; esperado := 'INFO'; obtido := v_n;
    resultado := 'INFO'; return next;

    perform set_config('request.jwt.claims', json_build_object('sub', v_levi, 'role', 'authenticated')::text, true);
    perform set_config('request.jwt.claim.sub', v_levi::text, true);
    select count(*)::text into v_n from public.listar_portarias();
    verificacao := 'Levi (global): total de portarias (deve ser todas)'; esperado := 'INFO'; obtido := v_n;
    resultado := 'INFO'; return next;
    select (select count(*) from public.portarias where excluido_em is null)::text into v_n;
    verificacao := 'Total real de portarias no banco (igual ao do Levi)'; esperado := 'INFO'; obtido := v_n;
    resultado := 'INFO'; return next;

    raise exception using errcode = 'XX999', message = '__reverter__';
  exception when others then
    if sqlerrm <> '__reverter__' then raise; end if;
  end;
end
$f$;

select * from pg_temp.teste_portarias();
