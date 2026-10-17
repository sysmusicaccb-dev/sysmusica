-- =====================================================================
-- SysMúsica — Migração 0006: identidade do membro (CPF, localidade, QR Code) e auditoria base
--
-- O que esta migração faz:
--   * CPF: coluna protegida (a aplicação só lê a versão mascarada), validada pelos dígitos
--     verificadores e ÚNICA entre os membros não excluídos. O CPF completo só é lido pela função
--     obter_cpf_membro (permissão membros.cpf) e cada consulta fica registrada na auditoria.
--     Só quem tem membros.cpf consegue informar ou alterar o CPF;
--   * Cidade e bairro do membro (a coluna congregacao continua sendo a comum/congregação);
--   * atualizado_em: data da última alteração, atualizada automaticamente;
--   * QR Code: o membro mantém o mesmo código (qr_secret) para sempre, salvo substituição
--     administrativa (função regenerar_qr: exige permissão, justificativa e fica na auditoria).
--     O código antigo é guardado só como hash (qr_historico) para reconhecer um QR revogado;
--   * auditoria: tabela só de acréscimo (ninguém altera nem apaga registros).
--
-- É IDEMPOTENTE e roda em uma única transação. Aplique depois do 0005.
-- =====================================================================
begin;

-- ---------------------------------------------------------------------
-- 1) NOVAS PERMISSÕES (mantenha igual a CATALOGO_PERMISSOES em src/lib/permissoes.ts)
-- ---------------------------------------------------------------------
insert into public.permissoes (codigo, modulo, acao, descricao) values
  ('membros.cpf',        'Membros', 'CPF',                 'Ver e informar o CPF completo dos membros'),
  ('membros.qr',         'Membros', 'QR Code',             'Ver, copiar e baixar o QR Code do membro'),
  ('membros.qr_revogar', 'Membros', 'Substituir QR Code',  'Revogar e substituir o QR Code de um membro (com justificativa)')
on conflict (codigo) do update
  set modulo = excluded.modulo, acao = excluded.acao, descricao = excluded.descricao;

-- O grupo Administrador (protegido) sempre recebe TODAS as permissões do catálogo
insert into public.grupo_permissoes (grupo_id, permissao_codigo)
select g.id, p.codigo
from public.grupos g
cross join public.permissoes p
where g.sistema and g.nome = 'Administrador'
on conflict do nothing;

-- ---------------------------------------------------------------------
-- 2) CPF: validação pelos dígitos verificadores
--    (mantenha igual a validarCpf em src/lib/cpf.ts: há testes dos dois lados)
-- ---------------------------------------------------------------------
create or replace function public.cpf_valido(p_cpf text)
returns boolean
language plpgsql
immutable
as $$
declare
  soma  int;
  resto int;
  i     int;
begin
  -- Exatamente 11 dígitos e não pode ser uma sequência repetida (111.111.111-11 etc.)
  if p_cpf is null or p_cpf !~ '^[0-9]{11}$' or p_cpf ~ '^(.)\1{10}$' then
    return false;
  end if;

  -- Primeiro dígito verificador (pesos 10 a 2)
  soma := 0;
  for i in 1..9 loop
    soma := soma + substr(p_cpf, i, 1)::int * (11 - i);
  end loop;
  resto := (soma * 10) % 11;
  if resto = 10 then resto := 0; end if;
  if resto <> substr(p_cpf, 10, 1)::int then return false; end if;

  -- Segundo dígito verificador (pesos 11 a 2)
  soma := 0;
  for i in 1..10 loop
    soma := soma + substr(p_cpf, i, 1)::int * (12 - i);
  end loop;
  resto := (soma * 10) % 11;
  if resto = 10 then resto := 0; end if;

  return resto = substr(p_cpf, 11, 1)::int;
end;
$$;

-- ---------------------------------------------------------------------
-- 3) NOVAS COLUNAS EM MEMBROS
--    cpf_mascarado é uma coluna GERADA pelo banco: é a única versão do CPF que a tela lê.
-- ---------------------------------------------------------------------
alter table public.membros add column if not exists cpf    text;
alter table public.membros add column if not exists cidade text;
alter table public.membros add column if not exists bairro text;
alter table public.membros add column if not exists atualizado_em timestamptz not null default now();
alter table public.membros
  add column if not exists cpf_mascarado text
  generated always as (case when cpf is null then null else '***.***.***-' || right(cpf, 2) end) stored;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'membros_cpf_valido' and conrelid = 'public.membros'::regclass
  ) then
    alter table public.membros
      add constraint membros_cpf_valido check (cpf is null or public.cpf_valido(cpf));
  end if;
end
$$;

-- Um CPF por membro (os excluídos liberam o CPF)
create unique index if not exists membros_cpf_unico
  on public.membros (cpf)
  where cpf is not null and excluido_em is null;

-- ---------------------------------------------------------------------
-- 4) GATILHO: protege o CPF e mantém atualizado_em
--    Quem não tem membros.cpf não informa nem altera o CPF (vale para usuários logados no sistema;
--    manutenções feitas direto pelo painel do banco não são bloqueadas).
-- ---------------------------------------------------------------------
create or replace function public.membros_antes_de_gravar()
returns trigger
language plpgsql
set search_path = public
as $$
declare
  v_logado boolean := (select auth.uid()) is not null;
begin
  if v_logado then
    if tg_op = 'INSERT' then
      if new.cpf is not null and not public.tem_permissao('membros.cpf') then
        raise exception 'Você não tem permissão para informar o CPF.' using errcode = '42501';
      end if;
    elsif new.cpf is distinct from old.cpf and not public.tem_permissao('membros.cpf') then
      raise exception 'Você não tem permissão para alterar o CPF.' using errcode = '42501';
    end if;
  end if;

  if tg_op = 'UPDATE' then
    new.atualizado_em := now();
  end if;
  return new;
end;
$$;

drop trigger if exists trg_membros_antes_de_gravar on public.membros;
create trigger trg_membros_antes_de_gravar
  before insert or update on public.membros
  for each row execute function public.membros_antes_de_gravar();

-- ---------------------------------------------------------------------
-- 5) PRIVILÉGIOS DAS COLUNAS (o CPF completo e o qr_secret NUNCA são lidos diretamente)
--    O revoke vem ANTES do grant, pois revogar o privilégio da tabela remove os das colunas.
-- ---------------------------------------------------------------------
revoke select on public.membros from authenticated;
grant select (id, nome, congregacao, cargo_id, data_nascimento, instrumento_id, status,
              data_cadastro, excluido_em, cidade, bairro, atualizado_em, cpf_mascarado)
  on public.membros to authenticated;

revoke update on public.membros from authenticated;
grant update (nome, congregacao, cargo_id, data_nascimento, instrumento_id, status,
              cidade, bairro, cpf)
  on public.membros to authenticated;

-- ---------------------------------------------------------------------
-- 6) AUDITORIA (base): tabela só de acréscimo
--    A tela de consulta da auditoria virá em uma etapa futura.
-- ---------------------------------------------------------------------
create table if not exists public.auditoria (
  id          uuid        primary key default gen_random_uuid(),
  ocorrido_em timestamptz not null default now(),
  usuario_id  uuid,                                   -- quem fez (nulo = operação interna)
  acao        text        not null,                   -- ex: qr_substituido, cpf_visualizado
  entidade    text        not null,                   -- ex: membro
  entidade_id uuid,
  detalhes    jsonb       not null default '{}'::jsonb
);

create index if not exists idx_auditoria_entidade on public.auditoria (entidade, entidade_id, ocorrido_em desc);

alter table public.auditoria enable row level security;
revoke all on public.auditoria from anon, authenticated;

-- Só acréscimo: nenhuma alteração nem exclusão de registros da auditoria
create or replace function public.auditoria_somente_acrescimo()
returns trigger
language plpgsql
as $$
begin
  raise exception 'Os registros de auditoria não podem ser alterados nem excluídos.';
end;
$$;

drop trigger if exists trg_auditoria_somente_acrescimo on public.auditoria;
create trigger trg_auditoria_somente_acrescimo
  before update or delete on public.auditoria
  for each row execute function public.auditoria_somente_acrescimo();

-- Uso interno: as funções abaixo chamam esta para registrar (não é exposta ao navegador)
create or replace function public.registrar_auditoria(
  p_acao text, p_entidade text, p_entidade_id uuid, p_detalhes jsonb default '{}'::jsonb
)
returns void
language sql
security definer
set search_path = public
as $$
  insert into public.auditoria (usuario_id, acao, entidade, entidade_id, detalhes)
  values ((select auth.uid()), p_acao, p_entidade, p_entidade_id, coalesce(p_detalhes, '{}'::jsonb))
$$;

revoke all on function public.registrar_auditoria(text, text, uuid, jsonb) from public, anon, authenticated;

-- ---------------------------------------------------------------------
-- 7) HISTÓRICO DE QR CODES REVOGADOS
--    Guarda só o HASH (sha256) do código antigo: serve para reconhecer um QR revogado numa leitura,
--    sem manter o código em si.
-- ---------------------------------------------------------------------
create table if not exists public.qr_historico (
  id            uuid        primary key default gen_random_uuid(),
  membro_id     uuid        not null references public.membros (id) on delete cascade,
  token_hash    text        not null,
  revogado_em   timestamptz not null default now(),
  revogado_por  uuid,
  justificativa text        not null
);

create unique index if not exists qr_historico_hash_unico on public.qr_historico (token_hash);

alter table public.qr_historico enable row level security;
revoke all on public.qr_historico from anon, authenticated;

-- ---------------------------------------------------------------------
-- 8) FUNÇÕES DA TELA (conferem a permissão no banco e registram na auditoria)
-- ---------------------------------------------------------------------

-- CPF completo de um membro (permissão membros.cpf); a consulta fica registrada
create or replace function public.obter_cpf_membro(p_id uuid)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_cpf text;
begin
  perform public.exigir_permissao('membros.cpf');

  select m.cpf into v_cpf from public.membros m where m.id = p_id and m.excluido_em is null;
  if not found then
    raise exception 'Membro não encontrado.';
  end if;

  perform public.registrar_auditoria('cpf_visualizado', 'membro', p_id, '{}'::jsonb);
  return v_cpf;
end;
$$;

-- Código do QR Code de um membro (permissão membros.qr); a consulta fica registrada
create or replace function public.obter_qr_membro(p_id uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_token uuid;
begin
  perform public.exigir_permissao('membros.qr');

  select m.qr_secret into v_token from public.membros m where m.id = p_id and m.excluido_em is null;
  if not found then
    raise exception 'Membro não encontrado.';
  end if;

  perform public.registrar_auditoria('qr_visualizado', 'membro', p_id, '{}'::jsonb);
  return v_token;
end;
$$;

-- Substitui o QR Code: o código antigo deixa de funcionar na hora (permissão membros.qr_revogar,
-- justificativa obrigatória, histórico e auditoria). Devolve o novo código.
create or replace function public.regenerar_qr(p_id uuid, p_justificativa text)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_membro public.membros;
  v_novo   uuid := gen_random_uuid();
  v_just   text := btrim(coalesce(p_justificativa, ''));
begin
  perform public.exigir_permissao('membros.qr_revogar');

  if char_length(v_just) < 10 then
    raise exception 'Informe a justificativa (mínimo de 10 caracteres).';
  end if;
  if char_length(v_just) > 300 then
    raise exception 'A justificativa pode ter no máximo 300 caracteres.';
  end if;

  select * into v_membro from public.membros where id = p_id and excluido_em is null for update;
  if not found then
    raise exception 'Membro não encontrado.';
  end if;

  insert into public.qr_historico (membro_id, token_hash, revogado_por, justificativa)
  values (
    p_id,
    encode(sha256(convert_to(v_membro.qr_secret::text, 'UTF8')), 'hex'),
    (select auth.uid()),
    v_just
  );

  update public.membros set qr_secret = v_novo where id = p_id;

  perform public.registrar_auditoria('qr_substituido', 'membro', p_id,
                                     jsonb_build_object('justificativa', v_just));
  return v_novo;
end;
$$;

-- Só usuários logados executam estas funções
revoke all on function
  public.obter_cpf_membro(uuid),
  public.obter_qr_membro(uuid),
  public.regenerar_qr(uuid, text)
  from public, anon;
grant execute on function
  public.obter_cpf_membro(uuid),
  public.obter_qr_membro(uuid),
  public.regenerar_qr(uuid, text)
  to authenticated;

commit;
