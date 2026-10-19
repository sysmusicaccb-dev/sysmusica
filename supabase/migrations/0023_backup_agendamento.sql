-- =====================================================================
-- SysMúsica — Migração 0023: agendamento dos backups (diário, semanal, quinzenal e mensal)
--   * Tabela backup_agendamento (uma única linha): chave geral, tipos ligados, quantos backups guardar de cada
--     tipo (retenção), dia da semana do semanal e dia do mês do mensal, e o resultado da última execução.
--   * Só o servidor do sistema (chave secreta) lê e grava: anon/authenticated não têm acesso.
-- Requer a migração 0020. Idempotente, uma única transação.
-- Ao final, a migração TESTA que valores inválidos são recusados e que usuários comuns não têm acesso:
-- se algo falhar, tudo é desfeito.
-- =====================================================================
begin;

do $$
begin
  if to_regclass('public.backup_arquivos') is null then
    raise exception 'Aplique primeiro a migração 0020 (backup).';
  end if;
end $$;

create table if not exists public.backup_agendamento (
  id                    int primary key default 1 check (id = 1),
  ativo                 boolean not null default false,
  diario_ativo          boolean not null default true,
  diario_retencao       int not null default 7  check (diario_retencao between 1 and 90),
  semanal_ativo         boolean not null default true,
  semanal_retencao      int not null default 5  check (semanal_retencao between 1 and 90),
  semanal_dia           int not null default 0  check (semanal_dia between 0 and 6),
  quinzenal_ativo       boolean not null default true,
  quinzenal_retencao    int not null default 3  check (quinzenal_retencao between 1 and 90),
  mensal_ativo          boolean not null default true,
  mensal_retencao       int not null default 12 check (mensal_retencao between 1 and 90),
  mensal_dia            int not null default 1  check (mensal_dia between 1 and 28),
  ultimo_em             timestamptz,
  ultimo_resultado      text check (ultimo_resultado in ('ok', 'falhou', 'pulado')),
  ultimo_detalhe        text,
  ultima_verificacao_em timestamptz,
  atualizado_em         timestamptz not null default now(),
  atualizado_por        uuid
);
insert into public.backup_agendamento (id) values (1) on conflict (id) do nothing;

alter table public.backup_agendamento enable row level security;
revoke all on public.backup_agendamento from anon, authenticated;

-- VERIFICAÇÃO DE SEGURANÇA: se qualquer teste falhar, a migração INTEIRA é desfeita.
do $$
declare
  v_bloqueou boolean := false;
begin
  -- 1) uma retenção inválida (zero) precisa ser recusada
  begin
    update public.backup_agendamento set diario_retencao = 0 where id = 1;
    raise exception 'sysmusica_sem_bloqueio';
  exception when others then
    if sqlstate = '23514' then
      v_bloqueou := true;
    elsif sqlerrm <> 'sysmusica_sem_bloqueio' then
      raise exception 'Verificação falhou (teste da retenção): %', sqlerrm;
    end if;
  end;
  if not v_bloqueou then
    raise exception 'Verificação falhou: o banco aceitou uma retenção inválida. Nada foi alterado.';
  end if;

  -- 2) usuários comuns não podem ler nem gravar a tabela
  if has_table_privilege('anon', 'public.backup_agendamento', 'select')
     or has_table_privilege('authenticated', 'public.backup_agendamento', 'select')
     or has_table_privilege('anon', 'public.backup_agendamento', 'update')
     or has_table_privilege('authenticated', 'public.backup_agendamento', 'update') then
    raise exception 'Verificação falhou: anon/authenticated ainda têm acesso a backup_agendamento. Nada foi alterado.';
  end if;

  -- 3) a proteção por linha (RLS) precisa estar ligada e a linha única precisa existir
  if not exists (
    select 1 from pg_class c join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relname = 'backup_agendamento' and c.relrowsecurity
  ) then
    raise exception 'Verificação falhou: a proteção por linha (RLS) não está ligada. Nada foi alterado.';
  end if;
  if not exists (select 1 from public.backup_agendamento where id = 1) then
    raise exception 'Verificação falhou: a linha de configuração não foi criada. Nada foi alterado.';
  end if;
end $$;

commit;
