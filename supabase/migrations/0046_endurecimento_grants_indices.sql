-- =============================================================================
-- SysMúsica — Migração 0046: endurecimento de acessos e índices (resultado da auditoria)
--
--  O que faz (nada aqui muda o que as telas mostram ou gravam):
--   A) Tira dos papéis "anon" e "authenticated" os privilégios TRUNCATE, TRIGGER e REFERENCES nas tabelas.
--      (TRUNCATE ignora as regras de linha do RLS; o sistema nunca precisa dele pelo navegador.)
--   B) Tira do visitante sem login ("anon") a execução de funções internas (gatilhos e auxiliares).
--      Continua liberada para o visitante apenas opcoes_cadastro_publico (formulário público).
--      Usuários logados e o servidor (service_role) mantêm tudo como estava.
--   C) Cria índices que faltavam em 15 chaves estrangeiras (deixa consultas e exclusões mais rápidas).
-- Rode UMA vez no SQL Editor do Supabase, ANTES do git push. Pode rodar de novo sem problema.
-- Se der erro, rode:  rollback;
-- =============================================================================
begin;

do $$
begin
  if to_regclass('public.cadastro_publico_config') is null then
    raise exception 'Aplique primeiro as migrações até a 0045. Nada foi alterado.';
  end if;
end $$;

-- A) Privilégios perigosos em todas as tabelas do schema public
do $$
declare t record;
begin
  for t in select c.relname from pg_class c join pg_namespace n on n.oid = c.relnamespace
            where n.nspname = 'public' and c.relkind in ('r', 'p') loop
    execute format('revoke truncate, trigger, references on table public.%I from anon, authenticated', t.relname);
  end loop;
end $$;

-- B) Funções: sem execução para o visitante sem login (exceto a do formulário público)
do $$
declare f record;
begin
  for f in select p.oid::regprocedure as assinatura, p.proname
             from pg_proc p join pg_namespace n on n.oid = p.pronamespace
            where n.nspname = 'public' and p.prokind = 'f'
              and has_function_privilege('anon', p.oid, 'execute')
              and p.proname <> 'opcoes_cadastro_publico' loop
    execute format('revoke execute on function %s from public, anon', f.assinatura);
    -- quem já usava continua usando: usuário logado e servidor
    execute format('grant execute on function %s to authenticated, service_role', f.assinatura);
  end loop;
end $$;

-- C) Índices das chaves estrangeiras sem índice
create index if not exists idx_cadastros_pendentes_membro on public.cadastros_pendentes (membro_id);
create index if not exists idx_cadastros_pendentes_instrumento on public.cadastros_pendentes (instrumento_id);
create index if not exists idx_cadastros_pendentes_cargo on public.cadastros_pendentes (cargo_id);
create index if not exists idx_dados_ensaio_hino_abertura on public.dados_ensaio (hino_abertura_id);
create index if not exists idx_dados_ensaio_hinos_hino on public.dados_ensaio_hinos (hino_id);
create index if not exists idx_grupo_permissoes_permissao on public.grupo_permissoes (permissao_codigo);
create index if not exists idx_membros_origem_casa on public.membros (origem_casa_oracao_id);
create index if not exists idx_portarias_decidida_por on public.portarias (decidida_por);
create index if not exists idx_presencas_linha on public.presencas (linha_codigo);
create index if not exists idx_presencas_instrumento on public.presencas (instrumento_id);
create index if not exists idx_presencas_avulsas_linha on public.presencas_avulsas (linha_codigo);
create index if not exists idx_presencas_avulsas_instrumento on public.presencas_avulsas (instrumento_id);
create index if not exists idx_presencas_avulsas_origem_casa on public.presencas_avulsas (origem_casa_oracao_id);
create index if not exists idx_qr_historico_membro on public.qr_historico (membro_id);
create index if not exists idx_rrms_estado on public.rrms (estado_id);

-- Conferência: nada pode sobrar para o visitante além da função do formulário público
do $$
declare restantes text;
begin
  select string_agg(p.proname, ', ') into restantes
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.prokind = 'f'
     and has_function_privilege('anon', p.oid, 'execute') and p.proname <> 'opcoes_cadastro_publico';
  if restantes is not null then
    raise exception 'Ainda executáveis por anon: %. Nada foi alterado.', restantes;
  end if;
end $$;

commit;
select set_config('sysmusica.migracao_0046', 'ok', false);
