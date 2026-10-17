-- =====================================================================
-- SysMúsica — Migração 0005: editar e excluir registros da Portaria
--
-- O que esta migração faz:
--   * EXCLUSÃO LÓGICA de presenças (coluna excluido_em): o registro some da portaria, do
--     dashboard e dos relatórios, mas continua guardado no banco. Só a função excluir_presenca
--     marca a exclusão, e só para quem tem a permissão portaria.excluir;
--   * EDIÇÃO de presenças: só as colunas status, hora_entrada e hora_saida podem mudar
--     (nunca o membro nem o evento), e só para quem tem portaria.editar;
--   * regra no banco: a hora de saída não pode ser anterior à de entrada;
--   * a regra "uma entrada em aberto por membro/evento" ignora presenças excluídas, então dá
--     para registrar de novo o membro depois de excluir um registro errado.
--
-- É IDEMPOTENTE e roda em uma única transação. Aplique depois do 0004.
-- =====================================================================
begin;

-- ---------------------------------------------------------------------
-- 1) COLUNA DE EXCLUSÃO LÓGICA E REGRA DE HORÁRIOS
-- ---------------------------------------------------------------------
alter table public.presencas add column if not exists excluido_em timestamptz;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'presencas_saida_apos_entrada'
      and conrelid = 'public.presencas'::regclass
  ) then
    alter table public.presencas
      add constraint presencas_saida_apos_entrada
      check (hora_saida is null or hora_saida >= hora_entrada);
  end if;
end
$$;

-- No máximo UMA entrada em aberto (sem saída) por membro/evento, ignorando as excluídas
drop index if exists public.presencas_entrada_aberta_unica;
create unique index presencas_entrada_aberta_unica
  on public.presencas (membro_id, evento_id)
  where hora_saida is null and excluido_em is null;

-- ---------------------------------------------------------------------
-- 2) RLS: registros excluídos deixam de aparecer e de poder ser alterados.
--    Como a regra está na política, TODAS as telas (inclusive o dashboard) já respeitam.
-- ---------------------------------------------------------------------
drop policy if exists "presencas_select" on public.presencas;
drop policy if exists "presencas_update" on public.presencas;
drop policy if exists "presencas_delete" on public.presencas;

create policy "presencas_select" on public.presencas
  for select to authenticated
  using (
    excluido_em is null
    and public.tem_alguma_permissao(array[
      'portaria.visualizar', 'portaria.registrar', 'dashboard.visualizar'
    ])
  );
create policy "presencas_update" on public.presencas
  for update to authenticated
  using (excluido_em is null and public.tem_permissao('portaria.editar'))
  with check (public.tem_permissao('portaria.editar'));

-- ---------------------------------------------------------------------
-- 3) PRIVILÉGIOS: nada de DELETE direto; edição só nas colunas liberadas
-- ---------------------------------------------------------------------
revoke delete on public.presencas from authenticated;

revoke update on public.presencas from authenticated;
grant update (status, hora_entrada, hora_saida) on public.presencas to authenticated;

-- ---------------------------------------------------------------------
-- 4) EXCLUSÃO LÓGICA DE PRESENÇA (confere a permissão no banco)
-- ---------------------------------------------------------------------
create or replace function public.excluir_presenca(p_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.exigir_permissao('portaria.excluir');

  update public.presencas set excluido_em = now() where id = p_id and excluido_em is null;
  if not found then
    raise exception 'Registro de presença não encontrado.';
  end if;
end;
$$;

revoke all on function public.excluir_presenca(uuid) from public, anon;
grant execute on function public.excluir_presenca(uuid) to authenticated;

-- ---------------------------------------------------------------------
-- 5) RPC registrar_presenca_qr: a checagem de "entrada em aberto" ignora presenças excluídas
--    (create or replace mantém as permissões de execução já concedidas)
-- ---------------------------------------------------------------------
create or replace function public.registrar_presenca_qr(p_membro_id uuid, p_evento_id uuid)
returns public.presencas
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_presenca public.presencas;
begin
  -- Já existe uma entrada em aberto (sem saída) para este membro neste evento?
  if exists (
    select 1
    from public.presencas p
    where p.membro_id   = p_membro_id
      and p.evento_id   = p_evento_id
      and p.hora_saida  is null
      and p.excluido_em is null
  ) then
    raise exception 'Entrada já registrada para este membro neste evento (sem hora de saída).'
      using errcode = 'unique_violation';
  end if;

  -- Registra a entrada (hora_entrada usa o default now())
  insert into public.presencas (membro_id, evento_id, status)
  values (p_membro_id, p_evento_id, 'Presente')
  returning * into v_presenca;

  return v_presenca;
end;
$$;

commit;
