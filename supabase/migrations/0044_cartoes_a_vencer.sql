-- =============================================================================
-- SysMúsica — Migração 0044: Cartões a vencer (Parte 9-B)
--
--  Alerta de vencimento do cartão de identificação (dados em membros_cadastro.cartao_validade).
--  O que esta migração faz:
--   A) Permissão nova "cartoes.visualizar" (só o Administrador recebe; os demais grupos são liberados
--      em Grupos e Permissões).
--   B) resumo_cartoes(p_dias): totais para o card do Dashboard (vencidos, a vencer no prazo, sem validade).
--   C) listar_cartoes(p_dias): lista para a tela "Cartões a Vencer".
--  Regras:
--   * Só membros ativos e não excluídos. Quem consulta só enxerga as Casas de Oração da sua abrangência.
--   * "Vencido" = validade anterior a hoje; "A vencer" = validade de hoje até hoje + p_dias.
--   * "Sem validade" = cargo que exige cartão (ex.: Encarregado, Examinadora) sem a validade informada.
--   * "Hoje" é sempre o dia no fuso America/Sao_Paulo (não o do servidor).
--   * Não altera nenhum dado; só cria a permissão e duas funções de leitura.
-- Rode UMA vez no SQL Editor do Supabase, ANTES do git push. Se der erro, rode:  rollback;
-- =============================================================================
begin;
set local check_function_bodies = off;

do $$
begin
  if to_regclass('public.membros') is null or to_regclass('public.membros_cadastro') is null
     or to_regclass('public.cargos') is null or to_regclass('public.casas_oracao') is null
     or to_regprocedure('public.exigir_permissao(text)') is null
     or to_regprocedure('public.casa_oracao_na_abrangencia(uuid)') is null
     or to_regprocedure('public.aprovar_cadastro_pendente(uuid, uuid, text, text, text, uuid)') is null then
    raise exception 'Aplique primeiro as migrações até a 0043. Nada foi alterado.';
  end if;
  if to_regprocedure('public.listar_cartoes(integer)') is not null then
    raise exception 'A migração 0044 já foi aplicada. Nada foi alterado.';
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- A) Permissão (igual a CATALOGO_PERMISSOES em src/lib/permissoes.ts). Só o Administrador recebe.
-- ---------------------------------------------------------------------------
insert into public.permissoes (codigo, modulo, acao, descricao) values
  ('cartoes.visualizar', 'Cartões', 'Visualizar', 'Ver os cartões de identificação vencidos, a vencer e sem validade informada')
on conflict (codigo) do update
  set modulo = excluded.modulo, acao = excluded.acao, descricao = excluded.descricao;

insert into public.grupo_permissoes (grupo_id, permissao_codigo)
select g.id, p.codigo
  from public.grupos g
  cross join public.permissoes p
 where g.sistema and g.nome = 'Administrador'
   and p.codigo = 'cartoes.visualizar'
on conflict do nothing;

-- ---------------------------------------------------------------------------
-- B) Totais do card do Dashboard
-- ---------------------------------------------------------------------------
create or replace function public.resumo_cartoes(p_dias integer default 30)
returns jsonb
language plpgsql stable security definer set search_path to 'public'
as $$
declare
  v_hoje date := (now() at time zone 'America/Sao_Paulo')::date;
  v_vencidos integer;
  v_a_vencer integer;
  v_sem      integer;
begin
  perform public.exigir_permissao('cartoes.visualizar');
  if p_dias is null or p_dias < 1 or p_dias > 365 then
    raise exception 'O prazo deve ficar entre 1 e 365 dias.' using errcode = '22023';
  end if;

  select count(*) filter (where mc.cartao_validade < v_hoje),
         count(*) filter (where mc.cartao_validade >= v_hoje and mc.cartao_validade <= v_hoje + p_dias),
         count(*) filter (where mc.cartao_validade is null and coalesce(g.exige_cartao, false))
    into v_vencidos, v_a_vencer, v_sem
    from public.membros m
    left join public.membros_cadastro mc on mc.membro_id = m.id
    left join public.cargos g on g.id = m.cargo_id
   where m.excluido_em is null
     and m.status = 'Ativo'
     and (m.casa_oracao_id is null or public.casa_oracao_na_abrangencia(m.casa_oracao_id));

  return jsonb_build_object('dias', p_dias, 'vencidos', v_vencidos, 'a_vencer', v_a_vencer, 'sem_validade', v_sem);
end;
$$;

-- ---------------------------------------------------------------------------
-- C) Lista da tela "Cartões a Vencer"
--    dias: negativo = já venceu há N dias; 0 = vence hoje; nulo = sem validade informada.
-- ---------------------------------------------------------------------------
create or replace function public.listar_cartoes(p_dias integer default 30)
returns table (
  membro_id uuid, nome text, cargo_nome text, casa_nome text,
  cartao_numero text, cartao_validade date, dias integer, situacao text
)
language plpgsql stable security definer set search_path to 'public'
as $$
declare
  v_hoje date := (now() at time zone 'America/Sao_Paulo')::date;
begin
  perform public.exigir_permissao('cartoes.visualizar');
  if p_dias is null or p_dias < 1 or p_dias > 365 then
    raise exception 'O prazo deve ficar entre 1 e 365 dias.' using errcode = '22023';
  end if;

  return query
    select m.id, m.nome, g.nome, ca.nome, mc.cartao_numero, mc.cartao_validade,
           (mc.cartao_validade - v_hoje)::integer,
           case when mc.cartao_validade is null then 'SEM_VALIDADE'
                when mc.cartao_validade < v_hoje then 'VENCIDO'
                else 'A_VENCER' end
      from public.membros m
      left join public.membros_cadastro mc on mc.membro_id = m.id
      left join public.cargos g on g.id = m.cargo_id
      left join public.casas_oracao ca on ca.id = m.casa_oracao_id
     where m.excluido_em is null
       and m.status = 'Ativo'
       and (m.casa_oracao_id is null or public.casa_oracao_na_abrangencia(m.casa_oracao_id))
       and (   mc.cartao_validade <= v_hoje + p_dias
            or (mc.cartao_validade is null and coalesce(g.exige_cartao, false)))
     order by case when mc.cartao_validade is null then 2 else 1 end,
              mc.cartao_validade asc, m.nome asc
     limit 1000;
end;
$$;

-- ---------------------------------------------------------------------------
-- Acessos: só usuários logados (e a função confere a permissão e a abrangência)
-- ---------------------------------------------------------------------------
revoke all on function public.resumo_cartoes(integer) from public, anon, authenticated;
revoke all on function public.listar_cartoes(integer) from public, anon, authenticated;
grant execute on function public.resumo_cartoes(integer) to authenticated;
grant execute on function public.listar_cartoes(integer) to authenticated;

do $$
begin
  if has_function_privilege('anon', 'public.resumo_cartoes(integer)', 'execute')
     or has_function_privilege('anon', 'public.listar_cartoes(integer)', 'execute') then
    raise exception 'Permissões inesperadas para o papel anon. Nada foi alterado.';
  end if;
  if not exists (select 1 from public.permissoes where codigo = 'cartoes.visualizar') then
    raise exception 'A permissão não foi criada. Nada foi alterado.';
  end if;
end $$;

commit;
select set_config('sysmusica.migracao_0044', 'ok', false);
