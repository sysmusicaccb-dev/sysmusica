-- =============================================================================
-- SysMúsica — Migração 0038: Cadastro Musical (dados pessoais do músico/organista)
--
--   * Tabela PROTEGIDA membros_cadastro: estado civil, sexo, batismo, selado, telefone, WhatsApp, e-mail,
--     endereço e cartão de identificação. Ninguém lê nem grava a tabela direto (sem permissão para
--     anon/authenticated e sem policy): só as funções abaixo, que conferem a permissão e a abrangência.
--   * obter_cadastro_musical(membro)  -> JSON com os dados (ou null se o membro ainda não tem cadastro)
--   * salvar_cadastro_musical(membro, json) -> grava/atualiza (permissão membros.criar ou membros.editar)
--   * cargos.exige_cartao: define quais cargos exigem o cartão de identificação (configurável por SQL).
--   * Sem permissão nova: criar/editar membros já cobre este cadastro.
--
-- OBS. para futuros administradores: esta tabela ainda NÃO entra no backup/restauração da tela Backup
-- (a lista de tabelas permitidas fica na função backup_aplicar). Incluir numa etapa própria.
-- É seguro rodar mais de uma vez.
-- =============================================================================

-- 1) Cartão de identificação por cargo ---------------------------------------
alter table public.cargos add column if not exists exige_cartao boolean not null default false;
grant select (exige_cartao) on public.cargos to authenticated;

update public.cargos
   set exige_cartao = true
 where public.normalizar_texto(nome) in ('encarregado regional', 'encarregado local', 'examinadora');

-- 2) Tabela protegida ---------------------------------------------------------
create table if not exists public.membros_cadastro (
  membro_id        uuid primary key references public.membros (id) on delete cascade,
  estado_civil     text check (estado_civil in ('Casado(a)', 'Solteiro(a)', 'Viúvo(a)')),
  sexo             text check (sexo in ('Masculino', 'Feminino')),
  data_batismo     date,
  selado           boolean,
  ddd              text check (ddd ~ '^[0-9]{2}$'),
  telefone         text check (telefone ~ '^[0-9]{8,9}$'),
  tem_whatsapp     boolean,
  whatsapp         text check (whatsapp ~ '^[0-9]{10,11}$'),
  email            text,
  cep              text check (cep ~ '^[0-9]{8}$'),
  endereco         text,
  numero           text,
  complemento      text,
  uf               text check (uf ~ '^[A-Z]{2}$'),
  cartao_numero    text,
  cartao_emissao   date,
  cartao_validade  date,
  apresentado_em   date,
  apresentado_por  text,
  observacao       text,
  criado_em        timestamptz not null default now(),
  atualizado_em    timestamptz not null default now(),
  constraint membros_cadastro_cartao_datas check (
    cartao_emissao is null or cartao_validade is null or cartao_emissao <= cartao_validade
  )
);

alter table public.membros_cadastro enable row level security;
revoke all on public.membros_cadastro from public, anon, authenticated;

-- 3) Ler o cadastro ----------------------------------------------------------
create or replace function public.obter_cadastro_musical(p_membro uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path to 'public'
as $$
declare
  v_casa uuid;
  v_res  jsonb;
begin
  if not (public.tem_permissao('membros.editar') or public.tem_permissao('membros.criar')) then
    raise exception 'Você não tem permissão para ver este cadastro.' using errcode = '42501';
  end if;

  select m.casa_oracao_id into v_casa
    from public.membros m
   where m.id = p_membro and m.excluido_em is null;
  if not found then
    raise exception 'Membro não encontrado.' using errcode = 'P0002';
  end if;
  if v_casa is not null and not public.casa_oracao_na_abrangencia(v_casa) then
    raise exception 'Você não tem acesso a este cadastro.' using errcode = '42501';
  end if;

  select to_jsonb(c) - 'membro_id' - 'criado_em' - 'atualizado_em'
    into v_res
    from public.membros_cadastro c
   where c.membro_id = p_membro;
  return v_res; -- null quando o membro ainda não tem o cadastro preenchido
end;
$$;

-- 4) Gravar o cadastro -------------------------------------------------------
create or replace function public.salvar_cadastro_musical(p_membro uuid, p_dados jsonb)
returns void
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_casa   uuid;
  v_cargo  uuid;
  v_exige  boolean;
  v_estado_civil    text := nullif(btrim(p_dados ->> 'estado_civil'), '');
  v_sexo            text := nullif(btrim(p_dados ->> 'sexo'), '');
  v_data_batismo    date := nullif(btrim(p_dados ->> 'data_batismo'), '')::date;
  v_selado          boolean := (p_dados ->> 'selado')::boolean;
  v_ddd             text := nullif(btrim(p_dados ->> 'ddd'), '');
  v_telefone        text := nullif(btrim(p_dados ->> 'telefone'), '');
  v_tem_whatsapp    boolean := (p_dados ->> 'tem_whatsapp')::boolean;
  v_whatsapp        text := nullif(btrim(p_dados ->> 'whatsapp'), '');
  v_email           text := nullif(btrim(p_dados ->> 'email'), '');
  v_cep             text := nullif(btrim(p_dados ->> 'cep'), '');
  v_endereco        text := nullif(btrim(p_dados ->> 'endereco'), '');
  v_numero          text := nullif(btrim(p_dados ->> 'numero'), '');
  v_complemento     text := nullif(btrim(p_dados ->> 'complemento'), '');
  v_uf              text := nullif(btrim(p_dados ->> 'uf'), '');
  v_cartao_numero   text := nullif(btrim(p_dados ->> 'cartao_numero'), '');
  v_cartao_emissao  date := nullif(btrim(p_dados ->> 'cartao_emissao'), '')::date;
  v_cartao_validade date := nullif(btrim(p_dados ->> 'cartao_validade'), '')::date;
  v_apresentado_em  date := nullif(btrim(p_dados ->> 'apresentado_em'), '')::date;
  v_apresentado_por text := nullif(btrim(p_dados ->> 'apresentado_por'), '');
  v_observacao      text := nullif(btrim(p_dados ->> 'observacao'), '');
begin
  if not (public.tem_permissao('membros.criar') or public.tem_permissao('membros.editar')) then
    raise exception 'Você não tem permissão para salvar este cadastro.' using errcode = '42501';
  end if;

  select m.casa_oracao_id, m.cargo_id into v_casa, v_cargo
    from public.membros m
   where m.id = p_membro and m.excluido_em is null;
  if not found then
    raise exception 'Membro não encontrado.' using errcode = 'P0002';
  end if;
  if v_casa is not null and not public.casa_oracao_na_abrangencia(v_casa) then
    raise exception 'Você não tem acesso a este cadastro.' using errcode = '42501';
  end if;

  -- Validações com mensagem clara (as regras da tabela são a segunda barreira)
  if v_estado_civil is not null and v_estado_civil not in ('Casado(a)', 'Solteiro(a)', 'Viúvo(a)') then
    raise exception 'Estado civil inválido.' using errcode = '22023';
  end if;
  if v_sexo is not null and v_sexo not in ('Masculino', 'Feminino') then
    raise exception 'Sexo inválido.' using errcode = '22023';
  end if;
  if v_ddd is not null and v_ddd !~ '^[0-9]{2}$' then
    raise exception 'O DDD deve ter 2 números.' using errcode = '22023';
  end if;
  if v_telefone is not null and v_telefone !~ '^[0-9]{8,9}$' then
    raise exception 'O telefone deve ter 8 ou 9 números.' using errcode = '22023';
  end if;
  if v_whatsapp is not null and v_whatsapp !~ '^[0-9]{10,11}$' then
    raise exception 'O WhatsApp deve ter o DDD e 8 ou 9 números.' using errcode = '22023';
  end if;
  if v_email is not null and v_email !~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$' then
    raise exception 'O e-mail informado não é válido.' using errcode = '22023';
  end if;
  if v_cep is not null and v_cep !~ '^[0-9]{8}$' then
    raise exception 'O CEP deve ter 8 números.' using errcode = '22023';
  end if;
  if v_uf is not null and v_uf !~ '^[A-Z]{2}$' then
    raise exception 'Estado (UF) inválido.' using errcode = '22023';
  end if;
  if v_cartao_emissao is not null and v_cartao_validade is not null and v_cartao_emissao > v_cartao_validade then
    raise exception 'A validade do cartão não pode ser anterior à emissão.' using errcode = '22023';
  end if;

  -- Cargos que exigem o cartão de identificação (coluna cargos.exige_cartao)
  select c.exige_cartao into v_exige from public.cargos c where c.id = v_cargo;
  if coalesce(v_exige, false) and (v_cartao_numero is null or v_cartao_validade is null) then
    raise exception 'Este cargo exige o número e a validade do cartão de identificação.' using errcode = '22023';
  end if;

  -- Sem WhatsApp: não guarda número de WhatsApp
  if v_tem_whatsapp is not true then
    v_whatsapp := null;
  end if;

  insert into public.membros_cadastro as c (
    membro_id, estado_civil, sexo, data_batismo, selado, ddd, telefone, tem_whatsapp, whatsapp, email,
    cep, endereco, numero, complemento, uf, cartao_numero, cartao_emissao, cartao_validade,
    apresentado_em, apresentado_por, observacao
  ) values (
    p_membro, v_estado_civil, v_sexo, v_data_batismo, v_selado, v_ddd, v_telefone, v_tem_whatsapp, v_whatsapp, v_email,
    v_cep, v_endereco, v_numero, v_complemento, v_uf, v_cartao_numero, v_cartao_emissao, v_cartao_validade,
    v_apresentado_em, v_apresentado_por, v_observacao
  )
  on conflict (membro_id) do update set
    estado_civil = excluded.estado_civil, sexo = excluded.sexo, data_batismo = excluded.data_batismo,
    selado = excluded.selado, ddd = excluded.ddd, telefone = excluded.telefone,
    tem_whatsapp = excluded.tem_whatsapp, whatsapp = excluded.whatsapp, email = excluded.email,
    cep = excluded.cep, endereco = excluded.endereco, numero = excluded.numero,
    complemento = excluded.complemento, uf = excluded.uf, cartao_numero = excluded.cartao_numero,
    cartao_emissao = excluded.cartao_emissao, cartao_validade = excluded.cartao_validade,
    apresentado_em = excluded.apresentado_em, apresentado_por = excluded.apresentado_por,
    observacao = excluded.observacao, atualizado_em = now();
end;
$$;

-- 5) Quem pode chamar --------------------------------------------------------
revoke all on function public.obter_cadastro_musical(uuid) from public, anon;
revoke all on function public.salvar_cadastro_musical(uuid, jsonb) from public, anon;
grant execute on function public.obter_cadastro_musical(uuid) to authenticated;
grant execute on function public.salvar_cadastro_musical(uuid, jsonb) to authenticated;
