-- 0033 — Entradas sem cadastro (presencas_avulsas) passam a entrar no backup e na restauração
-- Só acrescenta a tabela na lista permitida da função backup_aplicar (o resto da função não muda).
do $$
declare
  v_def  text;
  v_ant  text := '(''presencas'',           array[''id''],                              true,  false, '''')';
  v_novo text;
begin
  select pg_get_functiondef(p.oid) into v_def
    from pg_proc p
   where p.pronamespace = 'public'::regnamespace and p.proname = 'backup_aplicar';
  if v_def is null then
    raise exception 'A função backup_aplicar não foi encontrada. Nada foi alterado.';
  end if;
  if v_def like '%presencas_avulsas%' then
    raise notice 'backup_aplicar já aceita presencas_avulsas. Nada a fazer.';
    return;
  end if;
  if position(v_ant in v_def) = 0 then
    raise exception 'Não encontrei a linha de presencas na lista da backup_aplicar. Nada foi alterado.';
  end if;
  -- presencas_avulsas usa exclusão lógica (excluido_em), como presencas
  v_novo := v_ant || E',\n      (''presencas_avulsas'',   array[''id''],                              true,  false, '''')';
  execute replace(v_def, v_ant, v_novo);
  if pg_get_functiondef('public.backup_aplicar(uuid, jsonb, jsonb)'::regprocedure) not like '%presencas_avulsas%' then
    raise exception 'A atualização da backup_aplicar não foi aplicada. Nada foi alterado.';
  end if;
  raise notice 'OK: presencas_avulsas agora entra no backup e na restauração.';
end $$;
