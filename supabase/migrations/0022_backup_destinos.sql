-- =====================================================================
-- SysMúsica — Migração 0022: destinos do backup (hoje: "Servidor local" por túnel da Cloudflare)
--   * Tabela backup_destinos: uma linha por tipo de destino, com o endereço, os segredos CRIPTOGRAFADOS pela
--     aplicação (Client ID, Client Secret e chave de assinatura), se o envio automático está ligado e o resultado
--     do último envio. Ninguém (anon/authenticated) lê a tabela: só o servidor do sistema, com a chave secreta.
-- Requer a migração 0020. Idempotente, uma única transação.
-- Ao final, a migração TESTA que um tipo inválido é recusado e que anon/authenticated não têm acesso:
-- se algo falhar, tudo é desfeito.
-- =====================================================================
begin;

do $$
begin
  if to_regclass('public.backup_arquivos') is null then
    raise exception 'Aplique primeiro a migração 0020 (backup).';
  end if;
end $$;

create table if not exists public.backup_destinos (
  id                    uuid primary key default gen_random_uuid(),
  tipo                  text not null unique check (tipo in ('servidor_local')),
  ativo                 boolean not null default false,
  endereco              text,
  config_cifrado        text,
  ultimo_envio_em       timestamptz,
  ultimo_envio_situacao text check (ultimo_envio_situacao in ('ok', 'falhou')),
  ultimo_envio_detalhe  text,
  atualizado_em         timestamptz not null default now(),
  atualizado_por        uuid
);

alter table public.backup_destinos enable row level security;
revoke all on public.backup_destinos from anon, authenticated;

-- VERIFICAÇÃO DE SEGURANÇA: se qualquer teste falhar, a migração INTEIRA é desfeita.
do $$
declare
  v_bloqueou boolean := false;
begin
  -- 1) um tipo inválido precisa ser recusado
  begin
    insert into public.backup_destinos (tipo) values ('xyz');
    raise exception 'sysmusica_sem_bloqueio';
  exception when others then
    if sqlstate = '23514' then
      v_bloqueou := true;
    elsif sqlerrm <> 'sysmusica_sem_bloqueio' then
      raise exception 'Verificação falhou (teste do tipo): %', sqlerrm;
    end if;
  end;
  if not v_bloqueou then
    raise exception 'Verificação falhou: o banco aceitou um tipo de destino inválido. Nada foi alterado.';
  end if;

  -- 2) usuários comuns não podem ler nem gravar a tabela
  if has_table_privilege('anon', 'public.backup_destinos', 'select')
     or has_table_privilege('authenticated', 'public.backup_destinos', 'select')
     or has_table_privilege('anon', 'public.backup_destinos', 'insert')
     or has_table_privilege('authenticated', 'public.backup_destinos', 'insert') then
    raise exception 'Verificação falhou: anon/authenticated ainda têm acesso a backup_destinos. Nada foi alterado.';
  end if;

  -- 3) a proteção por linha (RLS) precisa estar ligada
  if not exists (
    select 1 from pg_class c join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relname = 'backup_destinos' and c.relrowsecurity
  ) then
    raise exception 'Verificação falhou: a proteção por linha (RLS) não está ligada. Nada foi alterado.';
  end if;
end $$;

commit;
