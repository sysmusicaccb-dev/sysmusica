-- TESTE da 0071 — NÃO GRAVA NADA. Esperado: nenhuma linha FALHOU.
-- Master vê todas as Casas; Jerrivan (Administrador Regional) vê só as da região dele.

create or replace function pg_temp.teste71()
returns table(ordem int, verificacao text, esperado text, obtido text, resultado text)
language plpgsql as $f$
declare
  v_master uuid; v_jer uuid; v_total int; v_n int; n int := 0;
begin
  select u.id into v_master from public.usuarios u where lower(u.email) = 'levialencar@gmail.com';
  select u.id into v_jer    from public.usuarios u where lower(u.email) = 'jerrivan@congregacao.org.br';
  select count(*) into v_total from public.casas_oracao;

  perform set_config('request.jwt.claims', json_build_object('sub', v_master, 'role', 'authenticated')::text, true);
  perform set_config('request.jwt.claim.sub', v_master::text, true);
  select count(*) into v_n from public.listar_casas_para_ficha();
  n := n + 1; ordem := n; verificacao := 'Master vê todas as Casas de Oração'; esperado := v_total::text; obtido := v_n::text;
  resultado := case when v_n = v_total then 'OK' else 'FALHOU' end; return next;

  if v_jer is not null then
    perform set_config('request.jwt.claims', json_build_object('sub', v_jer, 'role', 'authenticated')::text, true);
    perform set_config('request.jwt.claim.sub', v_jer::text, true);
    select count(*) into v_n from public.listar_casas_para_ficha();
    n := n + 1; ordem := n; verificacao := 'Regional vê só as Casas da região dele (menos que o total)'; esperado := '< ' || v_total;
    obtido := v_n::text; resultado := case when v_n < v_total and v_n > 0 then 'OK' else 'FALHOU' end; return next;
  end if;
end
$f$;

select * from pg_temp.teste71();
