-- =====================================================================
-- SysMúsica — Migração 0021: verificação automática dos backups
--   * Cada backup passa a guardar o resultado da verificação: situação (pendente, ok ou falhou), quando foi
--     verificado, por quem (vazio = pelo sistema, automaticamente) e o detalhe do problema, se houver.
--   * Os backups que já existem ficam como "pendente" até serem verificados.
-- Requer a migração 0020. Idempotente, uma única transação.
-- Ao final, a migração TESTA que um valor inválido é recusado: se algo falhar, tudo é desfeito.
-- =====================================================================
begin;

do $$
begin
  if to_regclass('public.backup_arquivos') is null then
    raise exception 'Aplique primeiro a migração 0020 (backup).';
  end if;
end $$;

alter table public.backup_arquivos
  add column if not exists verificacao text not null default 'pendente'
    check (verificacao in ('pendente', 'ok', 'falhou')),
  add column if not exists verificado_em timestamptz,
  add column if not exists verificado_por uuid,
  add column if not exists verificacao_detalhe text;

-- VERIFICAÇÃO DE SEGURANÇA: um valor inválido precisa ser recusado. Se falhar, a migração INTEIRA é desfeita.
do $$
declare
  v_bloqueou boolean := false;
begin
  begin
    insert into public.backup_arquivos (tipo, situacao, verificacao) values ('manual', 'falhou', 'xyz');
    raise exception 'sysmusica_sem_bloqueio';
  exception when others then
    if sqlstate = '23514' then
      v_bloqueou := true;
    elsif sqlerrm <> 'sysmusica_sem_bloqueio' then
      raise exception 'Verificação falhou (teste da verificação): %', sqlerrm;
    end if;
  end;

  if not v_bloqueou then
    raise exception 'Verificação falhou: o banco aceitou uma situação de verificação inválida. Nada foi alterado.';
  end if;

  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'backup_arquivos' and column_name = 'verificado_em'
  ) then
    raise exception 'Verificação falhou: as colunas da verificação não foram criadas. Nada foi alterado.';
  end if;
end $$;

commit;
