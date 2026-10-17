-- =====================================================================
-- SysMúsica — Migração 0004: finalidade do evento, exclusão lógica e exclusões protegidas
--
-- O que esta migração faz:
--   * cria o catálogo de FINALIDADES de evento (reaproveitável) e já cadastra 4 exemplos;
--   * liga cada evento a uma finalidade (eventos.finalidade_id);
--   * EXCLUSÃO LÓGICA de membros e eventos (coluna excluido_em): o registro some das telas, mas o
--     histórico de presenças é preservado. Só as funções excluir_membro / excluir_evento marcam
--     a exclusão, e só para quem tem a permissão de excluir;
--   * EXCLUSÃO DE INSTRUMENTO protegida: bloqueada enquanto algum membro usar o instrumento;
--   * fecha o DELETE direto nas tabelas (membros, eventos, instrumentos): só pelas funções;
--   * libera a edição de eventos (colunas tipo, data_evento, local e finalidade_id).
--
-- É IDEMPOTENTE e roda em uma única transação. Aplique depois do 0003.
-- =====================================================================
begin;

-- ---------------------------------------------------------------------
-- 1) FINALIDADES DE EVENTO
--    O nome é único sem diferenciar maiúsculas/minúsculas. O formulário de evento cria
--    finalidades novas automaticamente quando a pessoa digita uma que ainda não existe.
-- ---------------------------------------------------------------------
create table if not exists public.finalidades_evento (
  id        uuid        primary key default gen_random_uuid(),
  nome      text        not null,
  criado_em timestamptz not null default now()
);

create unique index if not exists finalidades_evento_nome_lower_unico
  on public.finalidades_evento (lower(nome));

-- Exemplos informados pelo usuário (reexecutar não duplica)
insert into public.finalidades_evento (nome) values
  ('Reunião Geral para Músicos e Organistas'),
  ('Reunião Geral para Músicos, Organistas, Examinadoras, Instrutores (as), Encarregados Locais e Regionais'),
  ('Reunião Geral para Examinadoras, Encarregados Locais e Regionais'),
  ('Reunião Geral para Instrutores (as), Examinadoras, Encarregados Locais e Regionais')
on conflict do nothing;

-- ---------------------------------------------------------------------
-- 2) NOVAS COLUNAS
--    finalidade_id: eventos antigos ficam sem finalidade (nula) até serem editados.
--    excluido_em: preenchido quando o registro é excluído (exclusão lógica).
-- ---------------------------------------------------------------------
alter table public.eventos
  add column if not exists finalidade_id uuid references public.finalidades_evento (id) on delete set null;
alter table public.eventos  add column if not exists excluido_em timestamptz;
alter table public.membros  add column if not exists excluido_em timestamptz;

create index if not exists idx_eventos_finalidade_id on public.eventos (finalidade_id);

-- ---------------------------------------------------------------------
-- 3) RLS: FINALIDADES
--    Leitura para qualquer usuário ativo; criar finalidade só junto com o cadastro/edição de eventos.
--    (Editar/excluir finalidades terá tela própria numa próxima etapa.)
-- ---------------------------------------------------------------------
alter table public.finalidades_evento enable row level security;

drop policy if exists "finalidades_select" on public.finalidades_evento;
drop policy if exists "finalidades_insert" on public.finalidades_evento;

create policy "finalidades_select" on public.finalidades_evento
  for select to authenticated using (public.tem_acesso());
create policy "finalidades_insert" on public.finalidades_evento
  for insert to authenticated
  with check (public.tem_alguma_permissao(array['eventos.criar', 'eventos.editar']));

revoke all on public.finalidades_evento from anon;
revoke update, delete on public.finalidades_evento from authenticated;

-- ---------------------------------------------------------------------
-- 4) RLS: registros excluídos (exclusão lógica) deixam de aparecer e de poder ser alterados.
--    Como a regra está na política, TODAS as telas (inclusive o dashboard) já respeitam.
-- ---------------------------------------------------------------------
drop policy if exists "membros_select" on public.membros;
drop policy if exists "membros_update" on public.membros;
drop policy if exists "membros_delete" on public.membros;
drop policy if exists "eventos_select" on public.eventos;
drop policy if exists "eventos_update" on public.eventos;
drop policy if exists "eventos_delete" on public.eventos;
drop policy if exists "instrumentos_delete" on public.instrumentos;

create policy "membros_select" on public.membros
  for select to authenticated
  using (
    excluido_em is null
    and public.tem_alguma_permissao(array[
      'membros.visualizar', 'portaria.visualizar', 'portaria.registrar', 'dashboard.visualizar'
    ])
  );
create policy "membros_update" on public.membros
  for update to authenticated
  using (excluido_em is null and public.tem_permissao('membros.editar'))
  with check (public.tem_permissao('membros.editar'));

create policy "eventos_select" on public.eventos
  for select to authenticated
  using (
    excluido_em is null
    and public.tem_alguma_permissao(array[
      'eventos.visualizar', 'portaria.visualizar', 'portaria.registrar', 'dashboard.visualizar'
    ])
  );
create policy "eventos_update" on public.eventos
  for update to authenticated
  using (excluido_em is null and public.tem_permissao('eventos.editar'))
  with check (public.tem_permissao('eventos.editar'));

-- ---------------------------------------------------------------------
-- 5) PRIVILÉGIOS DAS TABELAS
--    - nada de DELETE direto em membros, eventos e instrumentos (só pelas funções abaixo);
--    - membros: a coluna excluido_em precisa ser legível (a política usa) mas nunca é gravável;
--    - eventos: só estas colunas podem ser alteradas.
-- ---------------------------------------------------------------------
revoke delete on public.membros, public.eventos, public.instrumentos from authenticated;

revoke select on public.membros from authenticated;
grant select (id, nome, congregacao, cargo_id, data_nascimento, instrumento_id, status, data_cadastro, excluido_em)
  on public.membros to authenticated;

revoke update on public.eventos from authenticated;
grant update (tipo, data_evento, local, finalidade_id) on public.eventos to authenticated;

-- ---------------------------------------------------------------------
-- 6) FUNÇÕES DE EXCLUSÃO (conferem a permissão no banco)
-- ---------------------------------------------------------------------

-- Exclusão lógica de membro: some das telas; o histórico de presenças é mantido
create or replace function public.excluir_membro(p_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.exigir_permissao('membros.excluir');

  update public.membros set excluido_em = now() where id = p_id and excluido_em is null;
  if not found then
    raise exception 'Membro não encontrado.';
  end if;
end;
$$;

-- Exclusão lógica de evento: some das telas; as presenças registradas são mantidas
create or replace function public.excluir_evento(p_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.exigir_permissao('eventos.excluir');

  update public.eventos set excluido_em = now() where id = p_id and excluido_em is null;
  if not found then
    raise exception 'Evento não encontrado.';
  end if;
end;
$$;

-- Exclusão de instrumento: bloqueada enquanto algum membro (não excluído) usar o instrumento
create or replace function public.excluir_instrumento(p_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_nome text;
  v_qtd  bigint;
begin
  perform public.exigir_permissao('instrumentos.excluir');

  select nome into v_nome from public.instrumentos where id = p_id for update;
  if not found then
    raise exception 'Instrumento não encontrado.';
  end if;

  select count(*) into v_qtd
  from public.membros m
  where m.instrumento_id = p_id and m.excluido_em is null;
  if v_qtd > 0 then
    raise exception 'O instrumento "%" está em uso por % membro(s). Troque o instrumento deles antes de excluir.', v_nome, v_qtd;
  end if;

  delete from public.instrumentos where id = p_id;
end;
$$;

-- Renomear um instrumento para o nome de uma família (ex: "Madeiras") continua proibido
create or replace function public.instrumentos_validar_nome()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if exists (
    select 1 from public.familias f
    where public.normalizar_texto(f.nome) = public.normalizar_texto(new.nome)
  ) then
    raise exception '"%" é uma família de instrumentos. Informe o instrumento (ex.: Clarinete).', new.nome
      using errcode = 'check_violation';
  end if;
  return new;
end;
$$;

drop trigger if exists trg_instrumentos_validar_nome on public.instrumentos;
create trigger trg_instrumentos_validar_nome
  before update of nome on public.instrumentos
  for each row execute function public.instrumentos_validar_nome();

-- Só usuários logados executam as funções de exclusão
revoke all on function
  public.excluir_membro(uuid),
  public.excluir_evento(uuid),
  public.excluir_instrumento(uuid)
  from public, anon;
grant execute on function
  public.excluir_membro(uuid),
  public.excluir_evento(uuid),
  public.excluir_instrumento(uuid)
  to authenticated;

commit;
