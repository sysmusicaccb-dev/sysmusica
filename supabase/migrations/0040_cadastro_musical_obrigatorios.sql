-- =============================================================================
-- SysMúsica — Migração 0040: Cadastro Musical — campos obrigatórios, Batizado, documento e instrumento Órgão
--
--   * Estado civil passa a ser "Casado (a)", "Solteiro (a)", "Viúvo (a)" (os cadastros já gravados são convertidos).
--   * membros_cadastro ganha: batizado (Sim/Não), documento_frente_path e documento_verso_path.
--   * Bucket PRIVADO documentos-membros (frente e verso do documento de identificação):
--       - anexar / trocar / descartar: quem tem membros.criar ou membros.editar;
--       - VER o documento (URL temporária): só quem tem a permissão membros.cpf.
--   * cargos.somente_orgao: cargos que só podem usar o instrumento Órgão (Organista, Examinadora e Instrutora;
--     o Instrutor continua com instrumento livre). O banco recusa outro instrumento (gatilho trg_membros_somente_orgao). Para mudar a lista:
--         update public.cargos set somente_orgao = true|false where nome = '...';
--   * Cargo "Instrutor (a)" vira "Instrutor" e é criado o cargo "Instrutora".
--   * salvar_cadastro_musical passa a EXIGIR: CPF, data de nascimento, estado civil, sexo, batizado (e a data do
--     batismo quando for batizado), instrumento (nos cargos que usam instrumento) e a frente e o verso do documento.
--     (A função só é chamada para o cadastro completo; membros antigos sem cadastro continuam como estão.)
--
-- Tudo roda numa transação só: se der erro em qualquer ponto, NADA é alterado.
-- É seguro rodar mais de uma vez.
-- =============================================================================
begin;

-- 1) Cargos -----------------------------------------------------------------
alter table public.cargos add column if not exists somente_orgao boolean not null default false;
grant select (somente_orgao) on public.cargos to authenticated;

-- "Instrutor (a)" -> "Instrutor" (ninguém usa ainda; se já existir "Instrutor", não mexe)
update public.cargos c
   set nome = 'Instrutor'
 where c.nome = 'Instrutor (a)'
   and not exists (select 1 from public.cargos x where x.nome = 'Instrutor');

-- Novo cargo "Instrutora"
insert into public.cargos (nome, permite_instrumento, exige_instrumento, exige_cartao)
select 'Instrutora', true, true, false
 where not exists (select 1 from public.cargos x where x.nome = 'Instrutora');

-- Cargos travados no Órgão (Organista, Examinadora e Instrutora): o instrumento passa a ser obrigatório
update public.cargos
   set somente_orgao = true,
       permite_instrumento = true,
       exige_instrumento = true
 where public.normalizar_texto(nome) like 'organista%'
    or public.normalizar_texto(nome) like 'examinadora%'
    or public.normalizar_texto(nome) like 'instrutora%';

-- O Instrutor (masculino) NÃO é travado: toca qualquer instrumento (como era antes)
update public.cargos
   set somente_orgao = false,
       exige_instrumento = false
 where public.normalizar_texto(nome) = 'instrutor';

-- Confere os membros que já existem: ninguém pode estar com instrumento diferente de Órgão nesses cargos
do $$
declare v_qtd integer;
begin
  select count(*) into v_qtd
    from public.membros m
    join public.cargos c on c.id = m.cargo_id and c.somente_orgao
    join public.instrumentos i on i.id = m.instrumento_id
   where m.excluido_em is null
     and not public.instrumento_e_orgao(i.nome);
  if v_qtd > 0 then
    raise exception 'Existem % membro(s) em cargo travado no Órgão com outro instrumento. Corrija antes de rodar esta migração.', v_qtd;
  end if;
end $$;

-- Gatilho: o cargo travado só aceita instrumento Órgão (vale também para visitantes)
create or replace function public.membros_somente_orgao()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_somente boolean;
  v_cargo   text;
  v_instr   text;
begin
  -- Restauração de backup: os dados antigos entram como estavam
  if current_setting('sysmusica.restaurando', true) = 'sim' then
    return new;
  end if;
  if new.instrumento_id is null then
    return new; -- a obrigatoriedade do instrumento é conferida por outro gatilho
  end if;
  select c.somente_orgao, c.nome into v_somente, v_cargo from public.cargos c where c.id = new.cargo_id;
  if not coalesce(v_somente, false) then
    return new;
  end if;
  select i.nome into v_instr from public.instrumentos i where i.id = new.instrumento_id;
  if not public.instrumento_e_orgao(v_instr) then
    raise exception 'O cargo % só pode usar o instrumento Órgão.', v_cargo using errcode = '22023';
  end if;
  return new;
end;
$$;

drop trigger if exists trg_membros_somente_orgao on public.membros;
create trigger trg_membros_somente_orgao
  before insert or update of cargo_id, instrumento_id on public.membros
  for each row execute function public.membros_somente_orgao();

-- 2) Cadastro musical: novas colunas e estado civil ---------------------------
alter table public.membros_cadastro add column if not exists batizado boolean;
alter table public.membros_cadastro add column if not exists documento_frente_path text;
alter table public.membros_cadastro add column if not exists documento_verso_path text;

-- Quem já tinha data de batismo é batizado
update public.membros_cadastro set batizado = true where batizado is null and data_batismo is not null;

alter table public.membros_cadastro drop constraint if exists membros_cadastro_batizado_data;
alter table public.membros_cadastro add constraint membros_cadastro_batizado_data check (
  (batizado is not true or data_batismo is not null) and (batizado is not false or data_batismo is null)
);

-- Estado civil: apaga a regra antiga (qualquer nome), converte os valores e cria a nova
do $$
declare r record;
begin
  for r in
    select conname from pg_constraint
     where conrelid = 'public.membros_cadastro'::regclass and contype = 'c'
       and pg_get_constraintdef(oid) ilike '%estado_civil%'
  loop
    execute format('alter table public.membros_cadastro drop constraint %I', r.conname);
  end loop;
end $$;

update public.membros_cadastro set estado_civil = 'Casado (a)'   where estado_civil = 'Casado(a)';
update public.membros_cadastro set estado_civil = 'Solteiro (a)' where estado_civil = 'Solteiro(a)';
update public.membros_cadastro set estado_civil = 'Viúvo (a)'    where estado_civil = 'Viúvo(a)';

alter table public.membros_cadastro add constraint membros_cadastro_estado_civil_check
  check (estado_civil in ('Casado (a)', 'Solteiro (a)', 'Viúvo (a)'));

-- 3) Armazenamento PRIVADO dos documentos --------------------------------------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('documentos-membros', 'documentos-membros', false, 3145728, array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do update
   set public = false, file_size_limit = 3145728, allowed_mime_types = array['image/jpeg', 'image/png', 'image/webp'];

drop policy if exists documentos_membros_envio   on storage.objects;
drop policy if exists documentos_membros_leitura on storage.objects;
drop policy if exists documentos_membros_exclusao on storage.objects;

-- Anexar: quem cadastra ou edita membros
create policy documentos_membros_envio on storage.objects for insert to authenticated
  with check (bucket_id = 'documentos-membros' and public.tem_alguma_permissao(array['membros.criar', 'membros.editar']));
-- Ver o documento (URL temporária): só quem tem a permissão CPF (dado sensível)
create policy documentos_membros_leitura on storage.objects for select to authenticated
  using (bucket_id = 'documentos-membros' and public.tem_permissao('membros.cpf'));
-- Apagar (cadastro que falhou ou documento substituído)
create policy documentos_membros_exclusao on storage.objects for delete to authenticated
  using (bucket_id = 'documentos-membros' and public.tem_alguma_permissao(array['membros.criar', 'membros.editar']));

-- 4) Gravar o cadastro (agora com as exigências) ---------------------------------
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
  v_permite_instr boolean;
  v_cpf    text;
  v_nasc   date;
  v_instr  uuid;
  v_estado_civil    text := nullif(btrim(p_dados ->> 'estado_civil'), '');
  v_sexo            text := nullif(btrim(p_dados ->> 'sexo'), '');
  v_batizado        boolean := (p_dados ->> 'batizado')::boolean;
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
  v_doc_frente      text := nullif(btrim(p_dados ->> 'documento_frente_path'), '');
  v_doc_verso       text := nullif(btrim(p_dados ->> 'documento_verso_path'), '');
begin
  if not (public.tem_permissao('membros.criar') or public.tem_permissao('membros.editar')) then
    raise exception 'Você não tem permissão para salvar este cadastro.' using errcode = '42501';
  end if;

  select m.casa_oracao_id, m.cargo_id, m.cpf, m.data_nascimento, m.instrumento_id
    into v_casa, v_cargo, v_cpf, v_nasc, v_instr
    from public.membros m
   where m.id = p_membro and m.excluido_em is null;
  if not found then
    raise exception 'Membro não encontrado.' using errcode = 'P0002';
  end if;
  if v_casa is not null and not public.casa_oracao_na_abrangencia(v_casa) then
    raise exception 'Você não tem acesso a este cadastro.' using errcode = '42501';
  end if;

  -- Obrigatórios do Cadastro Musical (a tela confere antes; o banco é a segunda barreira)
  if v_cpf is null then
    raise exception 'O CPF é obrigatório. Quem tem a permissão CPF precisa preenchê-lo.' using errcode = '22023';
  end if;
  if v_nasc is null then
    raise exception 'Informe a data de nascimento.' using errcode = '22023';
  end if;
  if v_estado_civil is null then
    raise exception 'Informe o estado civil.' using errcode = '22023';
  end if;
  if v_sexo is null then
    raise exception 'Informe o sexo.' using errcode = '22023';
  end if;
  if v_batizado is null then
    raise exception 'Informe se a pessoa é batizada.' using errcode = '22023';
  end if;
  if v_batizado and v_data_batismo is null then
    raise exception 'Informe a data do batismo.' using errcode = '22023';
  end if;
  if not v_batizado then
    v_data_batismo := null; -- sem batismo, não guarda data
  end if;
  if v_data_batismo is not null and v_data_batismo < v_nasc then
    raise exception 'A data do batismo não pode ser anterior ao nascimento.' using errcode = '22023';
  end if;

  select c.permite_instrumento into v_permite_instr from public.cargos c where c.id = v_cargo;
  if coalesce(v_permite_instr, false) and v_instr is null then
    raise exception 'Informe o instrumento.' using errcode = '22023';
  end if;

  -- Documento (frente e verso): o arquivo precisa existir no armazenamento, na pasta do próprio membro
  if v_doc_frente is null then
    raise exception 'Anexe a frente do documento.' using errcode = '22023';
  end if;
  if v_doc_verso is null then
    raise exception 'Anexe o verso do documento.' using errcode = '22023';
  end if;
  if left(v_doc_frente, 37) <> p_membro::text || '/' or left(v_doc_verso, 37) <> p_membro::text || '/' then
    raise exception 'Documento inválido: envie o arquivo de novo.' using errcode = '22023';
  end if;
  if not exists (select 1 from storage.objects o where o.bucket_id = 'documentos-membros' and o.name = v_doc_frente) then
    raise exception 'O arquivo da frente do documento não foi encontrado. Envie de novo.' using errcode = '22023';
  end if;
  if not exists (select 1 from storage.objects o where o.bucket_id = 'documentos-membros' and o.name = v_doc_verso) then
    raise exception 'O arquivo do verso do documento não foi encontrado. Envie de novo.' using errcode = '22023';
  end if;

  -- Validações de formato
  if v_estado_civil not in ('Casado (a)', 'Solteiro (a)', 'Viúvo (a)') then
    raise exception 'Estado civil inválido.' using errcode = '22023';
  end if;
  if v_sexo not in ('Masculino', 'Feminino') then
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
    membro_id, estado_civil, sexo, batizado, data_batismo, selado, ddd, telefone, tem_whatsapp, whatsapp, email,
    cep, endereco, numero, complemento, uf, cartao_numero, cartao_emissao, cartao_validade,
    apresentado_em, apresentado_por, observacao, documento_frente_path, documento_verso_path
  ) values (
    p_membro, v_estado_civil, v_sexo, v_batizado, v_data_batismo, v_selado, v_ddd, v_telefone, v_tem_whatsapp, v_whatsapp, v_email,
    v_cep, v_endereco, v_numero, v_complemento, v_uf, v_cartao_numero, v_cartao_emissao, v_cartao_validade,
    v_apresentado_em, v_apresentado_por, v_observacao, v_doc_frente, v_doc_verso
  )
  on conflict (membro_id) do update set
    estado_civil = excluded.estado_civil, sexo = excluded.sexo, batizado = excluded.batizado,
    data_batismo = excluded.data_batismo,
    selado = excluded.selado, ddd = excluded.ddd, telefone = excluded.telefone,
    tem_whatsapp = excluded.tem_whatsapp, whatsapp = excluded.whatsapp, email = excluded.email,
    cep = excluded.cep, endereco = excluded.endereco, numero = excluded.numero,
    complemento = excluded.complemento, uf = excluded.uf, cartao_numero = excluded.cartao_numero,
    cartao_emissao = excluded.cartao_emissao, cartao_validade = excluded.cartao_validade,
    apresentado_em = excluded.apresentado_em, apresentado_por = excluded.apresentado_por,
    observacao = excluded.observacao,
    documento_frente_path = excluded.documento_frente_path, documento_verso_path = excluded.documento_verso_path,
    atualizado_em = now();
end;
$$;

revoke all on function public.salvar_cadastro_musical(uuid, jsonb) from public, anon;
grant execute on function public.salvar_cadastro_musical(uuid, jsonb) to authenticated;

commit;
