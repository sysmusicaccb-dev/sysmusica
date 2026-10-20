-- 0035: libera para usuarios logados as funcoes puras da janela da portaria
-- (so fazem conta com data/hora; sem acesso a dados). Corrige "permission denied for function portaria_encerrada".
do $$
declare f record; qtd int := 0;
begin
  for f in
    select p.oid::regprocedure as assinatura
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname in ('portaria_encerrada', 'portaria_janela_aberta')
  loop
    execute format('revoke all on function %s from public, anon', f.assinatura);
    execute format('grant execute on function %s to authenticated', f.assinatura);
    qtd := qtd + 1;
  end loop;
  if qtd = 0 then raise exception 'Funcoes da janela da portaria nao encontradas.'; end if;
  raise notice 'OK: % funcao(oes) liberada(s) para usuarios logados.', qtd;
end $$;
