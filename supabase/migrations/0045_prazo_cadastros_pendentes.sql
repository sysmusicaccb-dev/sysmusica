-- =============================================================================
-- SysMúsica — Migração 0045: prazo dos Cadastros Pendentes configurável
--
--  Hoje todo pedido do formulário público (/cadastro) vence 60 dias depois de enviado. Esta migração deixa
--  o Administrador mudar esse prazo na tela Cadastros Pendentes (botão com ícone de engrenagem).
--  O que faz:
--   A) Tabela cadastro_publico_config (uma única linha): prazo_dias, de 7 a 365 (padrão 60).
--   B) prazo_cadastro_dias(): lê o prazo; o valor padrão de expira_em dos novos pedidos passa a usá-la.
--   C) Permissão nova "cadastros.configurar" (só o Administrador recebe).
--   D) obter_config_cadastros(), previa_prazo_cadastros(dias) e salvar_config_cadastros(dias).
--  Regras ao salvar:
--   * O novo prazo vale para os pedidos NOVOS e para todos os que já estão PENDENTES (contado a partir do
--     envio de cada um). Pedidos já vencidos, aprovados ou recusados não mudam.
--   * Se o prazo diminuir e algum pedido pendente já passou dele, esse pedido vence na próxima limpeza diária
--     (e os dados dele são apagados). A tela mostra quantos são ANTES de confirmar (previa_prazo_cadastros).
--   * Tudo é registrado na Auditoria.
-- Rode UMA vez no SQL Editor do Supabase, ANTES do git push. Se der erro, rode:  rollback;
-- =============================================================================
begin;
set local check_function_bodies = off;

do $$
begin
  if to_regclass('public.cadastros_pendentes') is null
     or to_regprocedure('public.listar_cartoes(integer)') is null
     or to_regprocedure('public.exigir_permissao(text)') is null
     or to_regprocedure('public.registrar_auditoria(text, text, uuid, jsonb)') is null then
    raise exception 'Aplique primeiro as migrações até a 0044. Nada foi alterado.';
  end if;
  if to_regclass('public.cadastro_publico_config') is not null then
    raise exception 'A migração 0045 já foi aplicada. Nada foi alterado.';
  end if;
end $$;

-- A) Configuração (uma linha só; ninguém acessa a tabela direto, só as funções abaixo)
create table public.cadastro_publico_config (
  id            boolean primary key default true check (id),
  prazo_dias    integer not null default 60 check (prazo_dias between 7 and 365),
  atualizado_em timestamptz not null default now(),
  atualizado_por uuid
);
alter table public.cadastro_publico_config enable row level security;
revoke all on public.cadastro_publico_config from public, anon, authenticated;
insert into public.cadastro_publico_config (id, prazo_dias) values (true, 60);

-- B) Prazo atual (60 se a linha não existir). Usada como padrão do vencimento dos pedidos novos.
create or replace function public.prazo_cadastro_dias()
returns integer
language sql stable security definer set search_path to 'public'
as $$ select coalesce((select prazo_dias from public.cadastro_publico_config where id), 60) $$;

alter table public.cadastros_pendentes
  alter column expira_em set default (now() + make_interval(days => public.prazo_cadastro_dias()));

-- C) Permissão (igual a CATALOGO_PERMISSOES em src/lib/permissoes.ts). Só o Administrador recebe.
insert into public.permissoes (codigo, modulo, acao, descricao) values
  ('cadastros.configurar', 'Cadastros pendentes', 'Configurar', 'Alterar o prazo de validade dos pedidos do cadastro público')
on conflict (codigo) do update
  set modulo = excluded.modulo, acao = excluded.acao, descricao = excluded.descricao;

insert into public.grupo_permissoes (grupo_id, permissao_codigo)
select g.id, p.codigo
  from public.grupos g
  cross join public.permissoes p
 where g.sistema and g.nome = 'Administrador'
   and p.codigo = 'cadastros.configurar'
on conflict do nothing;

-- D) Funções do painel
create or replace function public.obter_config_cadastros()
returns jsonb
language plpgsql stable security definer set search_path to 'public'
as $$
begin
  perform public.exigir_permissao('cadastros.visualizar');
  return jsonb_build_object('prazo_dias', public.prazo_cadastro_dias(), 'minimo', 7, 'maximo', 365, 'padrao', 60);
end;
$$;

-- Quantos pedidos PENDENTES já passaram deste prazo (venceriam na próxima limpeza). Só leitura.
create or replace function public.previa_prazo_cadastros(p_dias integer)
returns integer
language plpgsql stable security definer set search_path to 'public'
as $$
declare v_qtd integer;
begin
  perform public.exigir_permissao('cadastros.configurar');
  if p_dias is null or p_dias < 7 or p_dias > 365 then
    raise exception 'O prazo deve ficar entre 7 e 365 dias.' using errcode = '22023';
  end if;
  select count(*) into v_qtd from public.cadastros_pendentes c
   where c.status = 'PENDENTE' and c.criado_em + make_interval(days => p_dias) < now();
  return v_qtd;
end;
$$;

create or replace function public.salvar_config_cadastros(p_dias integer)
returns jsonb
language plpgsql security definer set search_path to 'public'
as $$
declare
  v_antes   integer := public.prazo_cadastro_dias();
  v_atualiz integer;
  v_vencem  integer;
begin
  perform public.exigir_permissao('cadastros.configurar');
  if p_dias is null or p_dias < 7 or p_dias > 365 then
    raise exception 'O prazo deve ficar entre 7 e 365 dias.' using errcode = '22023';
  end if;

  insert into public.cadastro_publico_config (id, prazo_dias, atualizado_em, atualizado_por)
  values (true, p_dias, now(), (select auth.uid()))
  on conflict (id) do update
    set prazo_dias = excluded.prazo_dias, atualizado_em = now(), atualizado_por = excluded.atualizado_por;

  -- Os pedidos que já estão na fila passam a seguir o novo prazo (contado do envio de cada um)
  update public.cadastros_pendentes
     set expira_em = criado_em + make_interval(days => p_dias)
   where status = 'PENDENTE';
  get diagnostics v_atualiz = row_count;

  select count(*) into v_vencem from public.cadastros_pendentes
   where status = 'PENDENTE' and expira_em < now();

  perform public.registrar_auditoria('cadastro_prazo_alterado', 'cadastro_config', null,
            jsonb_build_object('prazo_antes', v_antes, 'prazo_depois', p_dias,
                               'pedidos_atualizados', v_atualiz, 'vencem_na_proxima_limpeza', v_vencem));
  return jsonb_build_object('prazo_dias', p_dias, 'atualizados', v_atualiz, 'vencerao_agora', v_vencem);
end;
$$;

revoke all on function public.prazo_cadastro_dias() from public, anon, authenticated;
revoke all on function public.obter_config_cadastros() from public, anon, authenticated;
revoke all on function public.previa_prazo_cadastros(integer) from public, anon, authenticated;
revoke all on function public.salvar_config_cadastros(integer) from public, anon, authenticated;
grant execute on function public.obter_config_cadastros() to authenticated;
grant execute on function public.previa_prazo_cadastros(integer) to authenticated;
grant execute on function public.salvar_config_cadastros(integer) to authenticated;

do $$
begin
  if has_function_privilege('anon', 'public.salvar_config_cadastros(integer)', 'execute')
     or has_function_privilege('anon', 'public.obter_config_cadastros()', 'execute')
     or has_function_privilege('anon', 'public.previa_prazo_cadastros(integer)', 'execute') then
    raise exception 'Permissões inesperadas para o papel anon. Nada foi alterado.';
  end if;
  if public.prazo_cadastro_dias() <> 60 then
    raise exception 'O prazo inicial deveria ser 60 dias. Nada foi alterado.';
  end if;
end $$;

commit;
select set_config('sysmusica.migracao_0045', 'ok', false);
