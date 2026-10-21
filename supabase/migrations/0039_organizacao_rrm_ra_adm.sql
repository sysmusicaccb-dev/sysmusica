-- =============================================================================
-- SysMúsica — 0039: nova árvore da Organização
--
--   ESTADO › RRM › RA › ADM › [Setor] › Casa de Oração
--
--   RRM = Reunião Regional Ministerial   RA = Regional Administrativa   ADM = Administração
--   O Setor é OPCIONAL: uma casa de oração pode ficar ligada direto à ADM.
--
-- O que muda no banco
--   - tabelas novas: rrms e adms; "regioes" passa a se chamar "ras" (as regiões de hoje são RAs)
--   - setores passam a ficar dentro de uma ADM; casas_oracao ganham adm_id (obrigatório) e setor_id vira opcional
--   - usuario_vinculos aceita os níveis RRM, RA e ADM (REGIAO vira RA)
--   - a regra de abrangência (casa_oracao_na_minha_abrangencia) e todas as funções da hierarquia são reescritas
--
-- Dados de teste existentes
--   - a região "Jequié" vira RA dentro da RRM "Vitória da Conquista" e ganha a ADM "Ipiaú"
--   - as demais regiões ficam numa RRM provisória "(a definir)" e cada uma ganha uma ADM provisória
--     "ADM <nome> (a definir)"; renomeie ou mova pela tela Organização depois
--   - setores e casas continuam onde estavam (dentro da ADM da própria região)
--
-- Segurança: a migração roda numa transação única. Antes e depois ela compara, usuário por usuário, QUAIS casas de
-- oração cada um enxerga; se qualquer resultado mudar, ela aborta e nada é alterado.
--
-- Rodar UMA vez no SQL Editor do Supabase, ANTES do git push.
-- =============================================================================
begin;

-- Durante a migração a auditoria linha a linha fica pausada (as mudanças abaixo são estruturais)
select set_config('sysmusica.restaurando', 'sim', true);

-- ---------------------------------------------------------------------------
-- 0. Conferências e "fotografia" do acesso ANTES da mudança
-- ---------------------------------------------------------------------------
do $$
begin
  if exists (select 1 from public.casas_oracao c where c.setor_id is null) then
    raise exception 'Há casa(s) de oração sem setor. Ligue-as a um setor (Organização › transferir) antes de rodar esta migração.';
  end if;
end $$;

create temp table _vis_antes on commit drop as
select v.usuario_id, c.id as casa_id
from public.usuario_vinculos v
cross join public.casas_oracao c
join public.setores s on s.id = c.setor_id
join public.regioes r on r.id = s.regiao_id
join public.estados e on e.id = r.estado_id
where c.ativo and s.ativo and r.ativo and e.ativo
  and ((v.nivel = 'CASA_ORACAO' and v.alvo_id = c.id)
    or (v.nivel = 'SETOR'       and v.alvo_id = s.id)
    or (v.nivel = 'REGIAO'      and v.alvo_id = r.id)
    or (v.nivel = 'ESTADO'      and v.alvo_id = e.id));

create temp table _qtd_antes on commit drop as
select (select count(*) from public.estados)       as estados,
       (select count(*) from public.regioes)       as regioes,
       (select count(*) from public.setores)       as setores,
       (select count(*) from public.casas_oracao)  as casas,
       (select count(*) from public.usuario_vinculos) as vinculos;

-- ---------------------------------------------------------------------------
-- 1. RRM (nova)
-- ---------------------------------------------------------------------------
create table public.rrms (
  id        uuid primary key default gen_random_uuid(),
  estado_id uuid not null references public.estados (id),
  nome      text not null,
  descricao text,
  ativo     boolean not null default true,
  criado_em timestamptz not null default now()
);
alter table public.rrms enable row level security;
revoke all on table public.rrms from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 2. As regiões de hoje viram RAs (ligadas a uma RRM)
-- ---------------------------------------------------------------------------
alter table public.regioes add column rrm_id uuid;

-- Jequié fica na RRM "Vitória da Conquista"
insert into public.rrms (estado_id, nome)
select distinct r.estado_id, 'Vitória da Conquista'
from public.regioes r
where public.normalizar_texto(r.nome) = public.normalizar_texto('Jequié');

update public.regioes r
   set rrm_id = m.id
  from public.rrms m
 where m.estado_id = r.estado_id and m.nome = 'Vitória da Conquista'
   and public.normalizar_texto(r.nome) = public.normalizar_texto('Jequié');

-- As demais ficam numa RRM provisória (uma por estado)
insert into public.rrms (estado_id, nome)
select distinct r.estado_id, '(a definir)' from public.regioes r where r.rrm_id is null;

update public.regioes r
   set rrm_id = m.id
  from public.rrms m
 where r.rrm_id is null and m.estado_id = r.estado_id and m.nome = '(a definir)';

alter table public.regioes drop column estado_id;            -- a chave estrangeira antiga sai junto
alter table public.regioes alter column rrm_id set not null;
alter table public.regioes add constraint ras_rrm_id_fkey foreign key (rrm_id) references public.rrms (id);
alter table public.regioes rename to ras;
alter table public.ras rename constraint regioes_pkey to ras_pkey;

-- ---------------------------------------------------------------------------
-- 3. ADM (nova): uma por RA existente, para abrigar os setores e as casas atuais
-- ---------------------------------------------------------------------------
create table public.adms (
  id        uuid primary key default gen_random_uuid(),
  ra_id     uuid not null references public.ras (id),
  nome      text not null,
  descricao text,
  ativo     boolean not null default true,
  criado_em timestamptz not null default now()
);
alter table public.adms enable row level security;
revoke all on table public.adms from public, anon, authenticated;

insert into public.adms (ra_id, nome)
select r.id,
       case when public.normalizar_texto(r.nome) = public.normalizar_texto('Jequié')
            then 'Ipiaú'
            else left('ADM ' || r.nome || ' (a definir)', 80) end
from public.ras r;

-- ---------------------------------------------------------------------------
-- 4. Setores passam a ficar dentro de uma ADM
-- ---------------------------------------------------------------------------
alter table public.setores add column adm_id uuid;
update public.setores s set adm_id = a.id from public.adms a where a.ra_id = s.regiao_id;
alter table public.setores alter column adm_id set not null;
alter table public.setores add constraint setores_adm_id_fkey foreign key (adm_id) references public.adms (id);
alter table public.setores drop column regiao_id;            -- a chave estrangeira antiga sai junto

-- ---------------------------------------------------------------------------
-- 5. Casas de oração: ADM obrigatória, setor opcional
-- ---------------------------------------------------------------------------
alter table public.casas_oracao add column adm_id uuid;
update public.casas_oracao c set adm_id = s.adm_id from public.setores s where s.id = c.setor_id;
alter table public.casas_oracao alter column adm_id set not null;
alter table public.casas_oracao add constraint casas_oracao_adm_id_fkey foreign key (adm_id) references public.adms (id);

alter table public.casas_oracao_historico add column adm_anterior uuid;
alter table public.casas_oracao_historico add column adm_novo uuid;

create index if not exists casas_oracao_adm_id_idx on public.casas_oracao (adm_id);
create index if not exists setores_adm_id_idx on public.setores (adm_id);
create index if not exists adms_ra_id_idx on public.adms (ra_id);
create index if not exists ras_rrm_id_idx on public.ras (rrm_id);

-- O setor de uma casa precisa ser da MESMA ADM da casa (nenhuma rota consegue gravar o contrário)
create or replace function public.casas_oracao_valida_hierarquia()
returns trigger language plpgsql set search_path to 'public' as $$
begin
  if new.setor_id is not null
     and not exists (select 1 from public.setores s where s.id = new.setor_id and s.adm_id = new.adm_id) then
    raise exception 'O setor escolhido não pertence à ADM desta casa de oração.';
  end if;
  return new;
end;
$$;

create trigger trg_casas_oracao_hierarquia
  before insert or update of adm_id, setor_id on public.casas_oracao
  for each row execute function public.casas_oracao_valida_hierarquia();

-- Um setor não muda de ADM (isso deixaria as casas dele em outra ADM)
create or replace function public.setores_bloqueia_troca_de_adm()
returns trigger language plpgsql set search_path to 'public' as $$
begin
  if new.adm_id is distinct from old.adm_id then
    raise exception 'Um setor não pode mudar de ADM. Crie o setor na ADM de destino e transfira as casas de oração.';
  end if;
  return new;
end;
$$;

create trigger trg_setores_sem_troca_de_adm
  before update of adm_id on public.setores
  for each row execute function public.setores_bloqueia_troca_de_adm();

-- Auditoria das tabelas novas (mesma função das demais)
create trigger trg_auditar after insert or update or delete on public.rrms
  for each row execute function public.auditar_tabela();
create trigger trg_auditar after insert or update or delete on public.adms
  for each row execute function public.auditar_tabela();

-- ---------------------------------------------------------------------------
-- 6. Vínculos de usuário: novos níveis (REGIAO vira RA)
-- ---------------------------------------------------------------------------
alter table public.usuario_vinculos drop constraint usuario_vinculos_nivel_check;
update public.usuario_vinculos set nivel = 'RA' where nivel = 'REGIAO';
alter table public.usuario_vinculos add constraint usuario_vinculos_nivel_check
  check (nivel in ('ESTADO', 'RRM', 'RA', 'ADM', 'SETOR', 'CASA_ORACAO'));

-- ---------------------------------------------------------------------------
-- 7. Regra de abrangência: o ponto central de segurança
--    Quem tem vínculo em QUALQUER nível enxerga tudo abaixo dele. Qualquer item inativo no caminho bloqueia.
-- ---------------------------------------------------------------------------
create or replace function public.casa_oracao_na_minha_abrangencia(p_casa_oracao uuid)
returns boolean
language sql stable security definer set search_path to 'public'
as $$
  select p_casa_oracao is not null and exists (
    select 1
    from public.casas_oracao c
    join public.adms a   on a.id  = c.adm_id
    join public.ras ra   on ra.id = a.ra_id
    join public.rrms rr  on rr.id = ra.rrm_id
    join public.estados e on e.id = rr.estado_id
    left join public.setores s on s.id = c.setor_id
    join public.usuario_vinculos v
      on v.usuario_id = (select auth.uid())
     and ((v.nivel = 'CASA_ORACAO' and v.alvo_id = c.id)
       or (v.nivel = 'SETOR'       and v.alvo_id = s.id)
       or (v.nivel = 'ADM'         and v.alvo_id = a.id)
       or (v.nivel = 'RA'          and v.alvo_id = ra.id)
       or (v.nivel = 'RRM'         and v.alvo_id = rr.id)
       or (v.nivel = 'ESTADO'      and v.alvo_id = e.id))
    where c.id = p_casa_oracao
      and c.ativo and a.ativo and ra.ativo and rr.ativo and e.ativo
      and (c.setor_id is null or s.ativo)
  )
$$;

-- Rótulos legíveis
create or replace function public.rotulo_setor(p_casa_oracao uuid)
returns text
language sql stable security definer set search_path to 'public'
as $$
  select concat_ws(' › ', ra.nome, a.nome, s.nome)
  from public.casas_oracao c
  join public.adms a  on a.id  = c.adm_id
  join public.ras ra  on ra.id = a.ra_id
  left join public.setores s on s.id = c.setor_id
  where c.id = p_casa_oracao
$$;

create or replace function public.rotulo_vinculo(p_nivel text, p_alvo uuid)
returns text
language sql stable security definer set search_path to 'public'
as $$
  select case p_nivel
    when 'ESTADO' then (select e.nome from public.estados e where e.id = p_alvo)
    when 'RRM' then (select concat_ws(' › ', e.nome, rr.nome)
                       from public.rrms rr join public.estados e on e.id = rr.estado_id where rr.id = p_alvo)
    when 'RA'  then (select concat_ws(' › ', rr.nome, ra.nome)
                       from public.ras ra join public.rrms rr on rr.id = ra.rrm_id where ra.id = p_alvo)
    when 'ADM' then (select concat_ws(' › ', ra.nome, a.nome)
                       from public.adms a join public.ras ra on ra.id = a.ra_id where a.id = p_alvo)
    when 'SETOR' then (select concat_ws(' › ', ra.nome, a.nome, s.nome)
                         from public.setores s join public.adms a on a.id = s.adm_id
                         join public.ras ra on ra.id = a.ra_id where s.id = p_alvo)
    when 'CASA_ORACAO' then (select concat_ws(' › ', ra.nome, a.nome, s.nome, c.nome)
                               from public.casas_oracao c
                               join public.adms a on a.id = c.adm_id
                               join public.ras ra on ra.id = a.ra_id
                               left join public.setores s on s.id = c.setor_id
                              where c.id = p_alvo)
  end
$$;

-- ---------------------------------------------------------------------------
-- 8. Listagens da árvore
-- ---------------------------------------------------------------------------
-- Árvore completa (tela de Organização e vínculos). parent_id: estado -> nulo; RRM -> estado; RA -> RRM; ADM -> RA;
-- setor -> ADM; casa de oração -> setor (se tiver) ou ADM.
create or replace function public.listar_organizacao()
returns table (nivel text, id uuid, parent_id uuid, nome text, descricao text, ativo boolean,
               cidade text, bairro text, qtd_filhos bigint, qtd_membros bigint)
language plpgsql stable security definer set search_path to 'public'
as $$
begin
  perform public.exigir_alguma_permissao(array['organizacao.visualizar', 'usuarios.vinculos', 'usuarios.editar']);
  return query
    select 'ESTADO'::text, e.id, null::uuid, e.nome, null::text, e.ativo, null::text, null::text,
           (select count(*) from public.rrms x where x.estado_id = e.id), 0::bigint
    from public.estados e
    union all
    select 'RRM'::text, rr.id, rr.estado_id, rr.nome, rr.descricao, rr.ativo, null::text, null::text,
           (select count(*) from public.ras x where x.rrm_id = rr.id), 0::bigint
    from public.rrms rr
    union all
    select 'RA'::text, ra.id, ra.rrm_id, ra.nome, ra.descricao, ra.ativo, null::text, null::text,
           (select count(*) from public.adms x where x.ra_id = ra.id), 0::bigint
    from public.ras ra
    union all
    select 'ADM'::text, a.id, a.ra_id, a.nome, a.descricao, a.ativo, null::text, null::text,
           (select count(*) from public.setores x where x.adm_id = a.id)
           + (select count(*) from public.casas_oracao x where x.adm_id = a.id and x.setor_id is null), 0::bigint
    from public.adms a
    union all
    select 'SETOR'::text, s.id, s.adm_id, s.nome, s.descricao, s.ativo, null::text, null::text,
           (select count(*) from public.casas_oracao x where x.setor_id = s.id), 0::bigint
    from public.setores s
    union all
    select 'CASA_ORACAO'::text, c.id, coalesce(c.setor_id, c.adm_id), c.nome, null::text, c.ativo, c.cidade, c.bairro, 0::bigint,
           (select count(*) from public.membros m where m.casa_oracao_id = c.id and m.excluido_em is null)
    from public.casas_oracao c;
end;
$$;

-- Só o que o usuário pode usar (seletor de casa de oração). Quem tem acesso total vê tudo que está ativo.
create or replace function public.listar_organizacao_para_selecao()
returns table (nivel text, id uuid, parent_id uuid, nome text)
language plpgsql stable security definer set search_path to 'public'
as $$
declare
  v_total boolean;
begin
  if not public.tem_acesso() then
    raise exception 'Sem acesso.' using errcode = '42501';
  end if;
  v_total := public.tem_acesso_total_organizacao();

  return query
    with ok as (
      select c.id as casa_id, c.nome as casa_nome, c.setor_id as setor_id, c.adm_id as adm_id
      from public.casas_oracao c
      where c.ativo and (v_total or public.casa_oracao_na_minha_abrangencia(c.id))
    ),
    sset as (
      select s.id as setor_id, s.adm_id as adm_id, s.nome as setor_nome
      from public.setores s
      where s.ativo and (v_total or s.id in (select ok.setor_id from ok))
    ),
    aset as (
      select a.id as adm_id, a.ra_id as ra_id, a.nome as adm_nome
      from public.adms a
      where a.ativo and (v_total or a.id in (select ok.adm_id from ok))
    ),
    raset as (
      select ra.id as ra_id, ra.rrm_id as rrm_id, ra.nome as ra_nome
      from public.ras ra
      where ra.ativo and (v_total or ra.id in (select aset.ra_id from aset))
    ),
    rrset as (
      select rr.id as rrm_id, rr.estado_id as estado_id, rr.nome as rrm_nome
      from public.rrms rr
      where rr.ativo and (v_total or rr.id in (select raset.rrm_id from raset))
    ),
    eset as (
      select e.id as estado_id, e.nome as estado_nome
      from public.estados e
      where e.ativo and (v_total or e.id in (select rrset.estado_id from rrset))
    )
    select 'ESTADO'::text, eset.estado_id, null::uuid, eset.estado_nome from eset
    union all
    select 'RRM'::text, rrset.rrm_id, rrset.estado_id, rrset.rrm_nome from rrset
    union all
    select 'RA'::text, raset.ra_id, raset.rrm_id, raset.ra_nome from raset
    union all
    select 'ADM'::text, aset.adm_id, aset.ra_id, aset.adm_nome from aset
    union all
    select 'SETOR'::text, sset.setor_id, sset.adm_id, sset.setor_nome from sset
    union all
    select 'CASA_ORACAO'::text, ok.casa_id, coalesce(ok.setor_id, ok.adm_id), ok.casa_nome from ok;
end;
$$;

-- Origens possíveis de um visitante (tudo que está ativo no caminho inteiro)
create or replace function public.listar_origens_visitante()
returns table (nivel text, id uuid, parent_id uuid, nome text)
language plpgsql stable security definer set search_path to 'public'
as $$
begin
  perform public.exigir_permissao('portaria.cadastrar_visitante');
  return query
    select 'ESTADO'::text, e.id, null::uuid, e.nome
      from public.estados e where e.ativo
    union all
    select 'RRM'::text, rr.id, rr.estado_id, rr.nome
      from public.rrms rr join public.estados e on e.id = rr.estado_id
     where rr.ativo and e.ativo
    union all
    select 'RA'::text, ra.id, ra.rrm_id, ra.nome
      from public.ras ra
      join public.rrms rr on rr.id = ra.rrm_id
      join public.estados e on e.id = rr.estado_id
     where ra.ativo and rr.ativo and e.ativo
    union all
    select 'ADM'::text, a.id, a.ra_id, a.nome
      from public.adms a
      join public.ras ra on ra.id = a.ra_id
      join public.rrms rr on rr.id = ra.rrm_id
      join public.estados e on e.id = rr.estado_id
     where a.ativo and ra.ativo and rr.ativo and e.ativo
    union all
    select 'SETOR'::text, s.id, s.adm_id, s.nome
      from public.setores s
      join public.adms a on a.id = s.adm_id
      join public.ras ra on ra.id = a.ra_id
      join public.rrms rr on rr.id = ra.rrm_id
      join public.estados e on e.id = rr.estado_id
     where s.ativo and a.ativo and ra.ativo and rr.ativo and e.ativo
    union all
    select 'CASA_ORACAO'::text, c.id, coalesce(c.setor_id, c.adm_id), c.nome
      from public.casas_oracao c
      join public.adms a on a.id = c.adm_id
      join public.ras ra on ra.id = a.ra_id
      join public.rrms rr on rr.id = ra.rrm_id
      join public.estados e on e.id = rr.estado_id
      left join public.setores s on s.id = c.setor_id
     where c.ativo and a.ativo and ra.ativo and rr.ativo and e.ativo and (c.setor_id is null or s.ativo);
end;
$$;

-- ---------------------------------------------------------------------------
-- 9. Cadastro, edição, exclusão e transferência
-- ---------------------------------------------------------------------------
create or replace function public.salvar_organizacao(
  p_nivel text, p_id uuid, p_parent uuid, p_nome text, p_descricao text, p_ativo boolean, p_cidade text, p_bairro text)
returns uuid
language plpgsql security definer set search_path to 'public'
as $$
declare
  v_novo   boolean := p_id is null;
  v_nome   text    := btrim(regexp_replace(coalesce(p_nome, ''), '\s+', ' ', 'g'));
  v_desc   text    := nullif(btrim(coalesce(p_descricao, '')), '');
  v_cidade text    := nullif(btrim(coalesce(p_cidade, '')), '');
  v_bairro text    := nullif(btrim(coalesce(p_bairro, '')), '');
  v_id     uuid;
  v_pai    uuid;
  v_setor  uuid;
  v_adm    uuid;
begin
  if p_nivel is null or p_nivel not in ('ESTADO', 'RRM', 'RA', 'ADM', 'SETOR', 'CASA_ORACAO') then
    raise exception 'Nível inválido.';
  end if;
  if v_novo then
    perform public.exigir_permissao('organizacao.criar');
  else
    perform public.exigir_permissao('organizacao.editar');
  end if;

  if char_length(v_nome) < 2 or char_length(v_nome) > 80 then
    raise exception 'O nome deve ter entre 2 e 80 caracteres.';
  end if;
  if v_desc is not null and char_length(v_desc) > 200 then
    raise exception 'A descrição pode ter no máximo 200 caracteres.';
  end if;
  if (v_cidade is not null and char_length(v_cidade) > 80) or (v_bairro is not null and char_length(v_bairro) > 80) then
    raise exception 'Cidade e bairro podem ter no máximo 80 caracteres.';
  end if;

  if p_nivel = 'ESTADO' then
    if exists (select 1 from public.estados x
                where x.id is distinct from p_id
                  and public.normalizar_texto(x.nome) = public.normalizar_texto(v_nome)) then
      raise exception 'Já existe um estado com este nome.';
    end if;
    if v_novo then
      insert into public.estados (nome) values (v_nome) returning id into v_id;
    else
      update public.estados set nome = v_nome, ativo = coalesce(p_ativo, ativo) where id = p_id returning id into v_id;
    end if;

  elsif p_nivel = 'RRM' then
    v_pai := case when v_novo then p_parent else (select x.estado_id from public.rrms x where x.id = p_id) end;
    if v_pai is null or not exists (select 1 from public.estados e where e.id = v_pai) then
      raise exception 'Escolha o estado da RRM.';
    end if;
    if exists (select 1 from public.rrms x
                where x.estado_id = v_pai and x.id is distinct from p_id
                  and public.normalizar_texto(x.nome) = public.normalizar_texto(v_nome)) then
      raise exception 'Já existe uma RRM com este nome neste estado.';
    end if;
    if v_novo then
      insert into public.rrms (estado_id, nome, descricao) values (v_pai, v_nome, v_desc) returning id into v_id;
    else
      update public.rrms set nome = v_nome, descricao = v_desc, ativo = coalesce(p_ativo, ativo)
       where id = p_id returning id into v_id;
    end if;

  elsif p_nivel = 'RA' then
    v_pai := case when v_novo then p_parent else (select x.rrm_id from public.ras x where x.id = p_id) end;
    if v_pai is null or not exists (select 1 from public.rrms r where r.id = v_pai) then
      raise exception 'Escolha a RRM da RA.';
    end if;
    if exists (select 1 from public.ras x
                where x.rrm_id = v_pai and x.id is distinct from p_id
                  and public.normalizar_texto(x.nome) = public.normalizar_texto(v_nome)) then
      raise exception 'Já existe uma RA com este nome nesta RRM.';
    end if;
    if v_novo then
      insert into public.ras (rrm_id, nome, descricao) values (v_pai, v_nome, v_desc) returning id into v_id;
    else
      update public.ras set nome = v_nome, descricao = v_desc, ativo = coalesce(p_ativo, ativo)
       where id = p_id returning id into v_id;
    end if;

  elsif p_nivel = 'ADM' then
    v_pai := case when v_novo then p_parent else (select x.ra_id from public.adms x where x.id = p_id) end;
    if v_pai is null or not exists (select 1 from public.ras r where r.id = v_pai) then
      raise exception 'Escolha a RA da ADM.';
    end if;
    if exists (select 1 from public.adms x
                where x.ra_id = v_pai and x.id is distinct from p_id
                  and public.normalizar_texto(x.nome) = public.normalizar_texto(v_nome)) then
      raise exception 'Já existe uma ADM com este nome nesta RA.';
    end if;
    if v_novo then
      insert into public.adms (ra_id, nome, descricao) values (v_pai, v_nome, v_desc) returning id into v_id;
    else
      update public.adms set nome = v_nome, descricao = v_desc, ativo = coalesce(p_ativo, ativo)
       where id = p_id returning id into v_id;
    end if;

  elsif p_nivel = 'SETOR' then
    v_pai := case when v_novo then p_parent else (select x.adm_id from public.setores x where x.id = p_id) end;
    if v_pai is null or not exists (select 1 from public.adms a where a.id = v_pai) then
      raise exception 'Escolha a ADM do setor.';
    end if;
    if exists (select 1 from public.setores x
                where x.adm_id = v_pai and x.id is distinct from p_id
                  and public.normalizar_texto(x.nome) = public.normalizar_texto(v_nome)) then
      raise exception 'Já existe um setor com este nome nesta ADM.';
    end if;
    if v_novo then
      insert into public.setores (adm_id, nome, descricao) values (v_pai, v_nome, v_desc) returning id into v_id;
    else
      update public.setores set nome = v_nome, descricao = v_desc, ativo = coalesce(p_ativo, ativo)
       where id = p_id returning id into v_id;
    end if;

  else  -- CASA_ORACAO: o "pai" de uma casa nova é uma ADM (casa sem setor) ou um setor
    if v_novo then
      if p_parent is not null and exists (select 1 from public.setores s where s.id = p_parent) then
        v_setor := p_parent;
        select s.adm_id into v_adm from public.setores s where s.id = p_parent;
      elsif p_parent is not null and exists (select 1 from public.adms a where a.id = p_parent) then
        v_setor := null;
        v_adm := p_parent;
      else
        raise exception 'Escolha a ADM (ou o setor) da casa de oração.';
      end if;
    else
      select c.adm_id, c.setor_id into v_adm, v_setor from public.casas_oracao c where c.id = p_id;
    end if;
    if exists (select 1 from public.casas_oracao x
                where x.adm_id is not distinct from v_adm and x.id is distinct from p_id
                  and public.normalizar_texto(x.nome) = public.normalizar_texto(v_nome)) then
      raise exception 'Já existe uma casa de oração com este nome nesta ADM.';
    end if;
    if v_novo then
      insert into public.casas_oracao (adm_id, setor_id, nome, cidade, bairro)
      values (v_adm, v_setor, v_nome, v_cidade, v_bairro)
      returning id into v_id;
    else
      update public.casas_oracao set nome = v_nome, cidade = v_cidade, bairro = v_bairro, ativo = coalesce(p_ativo, ativo)
       where id = p_id returning id into v_id;
    end if;
  end if;

  if v_id is null then
    raise exception 'Cadastro não encontrado.';
  end if;

  perform public.registrar_auditoria(
    case when v_novo then 'organizacao_criada' else 'organizacao_alterada' end,
    'organizacao', v_id,
    jsonb_build_object('nivel', p_nivel, 'nome', v_nome, 'ativo', p_ativo));
  return v_id;
end;
$$;

create or replace function public.excluir_organizacao(p_nivel text, p_id uuid)
returns void
language plpgsql security definer set search_path to 'public'
as $$
declare
  v_nome text;
  v_qtd  bigint;
  v_qtd2 bigint;
begin
  perform public.exigir_permissao('organizacao.excluir');

  if p_nivel is null or p_nivel not in ('ESTADO', 'RRM', 'RA', 'ADM', 'SETOR', 'CASA_ORACAO') then
    raise exception 'Nível inválido.';
  end if;

  -- Trava o item e lê o nome (para as mensagens e a auditoria)
  if p_nivel = 'ESTADO' then
    select e.nome into v_nome from public.estados e where e.id = p_id for update;
  elsif p_nivel = 'RRM' then
    select r.nome into v_nome from public.rrms r where r.id = p_id for update;
  elsif p_nivel = 'RA' then
    select r.nome into v_nome from public.ras r where r.id = p_id for update;
  elsif p_nivel = 'ADM' then
    select a.nome into v_nome from public.adms a where a.id = p_id for update;
  elsif p_nivel = 'SETOR' then
    select s.nome into v_nome from public.setores s where s.id = p_id for update;
  else
    select c.nome into v_nome from public.casas_oracao c where c.id = p_id for update;
  end if;
  if v_nome is null then
    raise exception 'Cadastro não encontrado.';
  end if;

  -- Usuários vinculados a este item perderiam o acesso sem aviso: a exclusão é bloqueada
  select count(*) into v_qtd from public.usuario_vinculos v where v.nivel = p_nivel and v.alvo_id = p_id;
  if v_qtd > 0 then
    raise exception '"%" ainda tem % usuário(s) vinculado(s). Retire o vínculo em Administração > Usuários antes de excluir.',
      v_nome, v_qtd;
  end if;

  if p_nivel = 'ESTADO' then
    select count(*) into v_qtd from public.rrms x where x.estado_id = p_id;
    if v_qtd > 0 then
      raise exception 'O estado "%" ainda tem % RRM(s). Exclua as RRMs antes.', v_nome, v_qtd;
    end if;
    delete from public.estados where id = p_id;

  elsif p_nivel = 'RRM' then
    select count(*) into v_qtd from public.ras x where x.rrm_id = p_id;
    if v_qtd > 0 then
      raise exception 'A RRM "%" ainda tem % RA(s). Exclua as RAs antes.', v_nome, v_qtd;
    end if;
    delete from public.rrms where id = p_id;

  elsif p_nivel = 'RA' then
    select count(*) into v_qtd from public.adms x where x.ra_id = p_id;
    if v_qtd > 0 then
      raise exception 'A RA "%" ainda tem % ADM(s). Exclua as ADMs antes.', v_nome, v_qtd;
    end if;
    delete from public.ras where id = p_id;

  elsif p_nivel = 'ADM' then
    select count(*) into v_qtd from public.setores x where x.adm_id = p_id;
    select count(*) into v_qtd2 from public.casas_oracao x where x.adm_id = p_id;
    if v_qtd > 0 or v_qtd2 > 0 then
      raise exception 'A ADM "%" ainda tem % setor(es) e % casa(s) de oração. Transfira ou exclua antes.', v_nome, v_qtd, v_qtd2;
    end if;
    delete from public.adms where id = p_id;

  elsif p_nivel = 'SETOR' then
    select count(*) into v_qtd from public.casas_oracao x where x.setor_id = p_id;
    if v_qtd > 0 then
      raise exception 'O setor "%" ainda tem % casa(s) de oração. Transfira as casas de oração para outro local antes de excluir.', v_nome, v_qtd;
    end if;
    delete from public.setores where id = p_id;

  else  -- CASA_ORACAO
    select count(*) into v_qtd from public.membros x where x.casa_oracao_id = p_id and x.excluido_em is null;
    if v_qtd > 0 then
      raise exception 'A casa de oração "%" ainda tem % membro(s). Mude os membros para outra casa de oração (ou exclua-os) antes.', v_nome, v_qtd;
    end if;
    select count(*) into v_qtd from public.eventos x where x.casa_oracao_id = p_id and x.excluido_em is null;
    if v_qtd > 0 then
      raise exception 'A casa de oração "%" ainda tem % evento(s). Mude a casa de oração dos eventos (ou exclua-os) antes.', v_nome, v_qtd;
    end if;
    select count(*) into v_qtd from public.portarias x where x.casa_oracao_id = p_id;
    if v_qtd > 0 then
      raise exception 'A casa de oração "%" tem % portaria(s) no histórico e não pode ser excluída. Use Inativar.', v_nome, v_qtd;
    end if;

    -- Membros e eventos já excluídos (exclusão lógica) deixam de apontar para a casa de oração
    perform set_config('sysmusica.org_excluindo', 'sim', true);
    update public.membros set casa_oracao_id = null where casa_oracao_id = p_id;
    update public.eventos set casa_oracao_id = null where casa_oracao_id = p_id;
    perform set_config('sysmusica.org_excluindo', '', true);

    delete from public.casas_oracao where id = p_id;
  end if;

  perform public.registrar_auditoria('organizacao_excluida', 'organizacao', p_id,
            jsonb_build_object('nivel', p_nivel, 'nome', v_nome));
end;
$$;

-- Transferência: o destino pode ser um SETOR (a casa entra nele) ou uma ADM (a casa fica sem setor)
drop function if exists public.transferir_casa_oracao(uuid, uuid, text);
create function public.transferir_casa_oracao(p_casa_oracao uuid, p_destino uuid, p_justificativa text)
returns void
language plpgsql security definer set search_path to 'public'
as $$
declare
  v_c     public.casas_oracao;
  v_setor uuid;
  v_adm   uuid;
  v_just  text := nullif(btrim(coalesce(p_justificativa, '')), '');
begin
  perform public.exigir_permissao('organizacao.transferir');

  select * into v_c from public.casas_oracao c where c.id = p_casa_oracao for update;
  if not found then
    raise exception 'Casa de Oração não encontrada.';
  end if;

  if exists (select 1 from public.setores s join public.adms a on a.id = s.adm_id
              where s.id = p_destino and s.ativo and a.ativo) then
    v_setor := p_destino;
    select s.adm_id into v_adm from public.setores s where s.id = p_destino;
  elsif exists (select 1 from public.adms a where a.id = p_destino and a.ativo) then
    v_setor := null;
    v_adm := p_destino;
  else
    raise exception 'Escolha uma ADM ou um setor ativo de destino.';
  end if;

  if v_c.adm_id is not distinct from v_adm and v_c.setor_id is not distinct from v_setor then
    raise exception 'A casa de oração já está neste local.';
  end if;
  if v_just is not null and char_length(v_just) > 300 then
    raise exception 'A justificativa pode ter no máximo 300 caracteres.';
  end if;
  if exists (select 1 from public.casas_oracao x
              where x.adm_id = v_adm and x.id <> p_casa_oracao
                and public.normalizar_texto(x.nome) = public.normalizar_texto(v_c.nome)) then
    raise exception 'O destino já tem uma casa de oração com este nome.';
  end if;

  update public.casas_oracao set adm_id = v_adm, setor_id = v_setor where id = p_casa_oracao;
  -- As portarias seguem a casa de oração do evento: só o rótulo precisa ser atualizado
  update public.portarias p set cidade = public.rotulo_setor(p.casa_oracao_id)
   where p.casa_oracao_id = p_casa_oracao and p.excluido_em is null;

  insert into public.casas_oracao_historico
    (casa_oracao_id, setor_anterior, setor_novo, adm_anterior, adm_novo, usuario_id, justificativa)
  values (p_casa_oracao, v_c.setor_id, v_setor, v_c.adm_id, v_adm, (select auth.uid()), v_just);

  perform public.registrar_auditoria('casa_oracao_transferida', 'casa_oracao', p_casa_oracao,
            jsonb_build_object('setor_anterior', v_c.setor_id, 'setor_novo', v_setor,
                               'adm_anterior', v_c.adm_id, 'adm_novo', v_adm, 'justificativa', v_just));
end;
$$;
revoke all on function public.transferir_casa_oracao(uuid, uuid, text) from public, anon;
grant execute on function public.transferir_casa_oracao(uuid, uuid, text) to authenticated;

-- Vínculos do usuário
create or replace function public.definir_vinculos(p_usuario uuid, p_vinculos jsonb)
returns void
language plpgsql security definer set search_path to 'public'
as $$
declare
  v_item  jsonb;
  v_nivel text;
  v_alvo  uuid;
  v_lista jsonb := coalesce(p_vinculos, '[]'::jsonb);
  v_ok    boolean;
begin
  perform public.exigir_permissao('usuarios.vinculos');

  if not exists (select 1 from public.usuarios u where u.id = p_usuario) then
    raise exception 'Usuário não encontrado.';
  end if;
  if jsonb_typeof(v_lista) <> 'array' then
    raise exception 'Vínculos inválidos.';
  end if;

  delete from public.usuario_vinculos where usuario_id = p_usuario;

  for v_item in select * from jsonb_array_elements(v_lista) loop
    v_nivel := v_item ->> 'nivel';
    v_alvo  := (v_item ->> 'alvo_id')::uuid;
    v_ok := case v_nivel
      when 'ESTADO' then exists (select 1 from public.estados x where x.id = v_alvo)
      when 'RRM'    then exists (select 1 from public.rrms x where x.id = v_alvo)
      when 'RA'     then exists (select 1 from public.ras x where x.id = v_alvo)
      when 'ADM'    then exists (select 1 from public.adms x where x.id = v_alvo)
      when 'SETOR'  then exists (select 1 from public.setores x where x.id = v_alvo)
      when 'CASA_ORACAO' then exists (select 1 from public.casas_oracao x where x.id = v_alvo)
      else false
    end;
    if not v_ok then
      raise exception 'Vínculo inválido: o cadastro escolhido não existe mais.';
    end if;
    insert into public.usuario_vinculos (usuario_id, nivel, alvo_id) values (p_usuario, v_nivel, v_alvo)
    on conflict do nothing;
  end loop;

  perform public.registrar_auditoria('vinculos_definidos', 'usuario', p_usuario,
            jsonb_build_object('vinculos', v_lista));
end;
$$;

-- ---------------------------------------------------------------------------
-- 10. Portaria: busca de origem e cadastro de visitante
-- ---------------------------------------------------------------------------
create or replace function public.buscar_localidades(p_termo text)
returns table (comum_id uuid, nome text, caminho text)
language plpgsql stable security definer set search_path to 'public'
as $$
declare
  v_t text := regexp_replace(public.normalizar_texto(coalesce(p_termo, '')), '[%_\\]', '', 'g');
begin
  perform public.exigir_permissao('portaria.registrar');
  if char_length(v_t) < 2 then
    return;
  end if;
  return query
    select c.id, c.nome, concat_ws(' › ', e.nome, ra.nome, a.nome, s.nome)
      from public.casas_oracao c
      join public.adms a on a.id = c.adm_id
      join public.ras ra on ra.id = a.ra_id
      join public.rrms rr on rr.id = ra.rrm_id
      join public.estados e on e.id = rr.estado_id
      left join public.setores s on s.id = c.setor_id
     where c.ativo and a.ativo and ra.ativo and rr.ativo and e.ativo and (c.setor_id is null or s.ativo)
       and (public.normalizar_texto(c.nome) like v_t || '%' or public.normalizar_texto(c.nome) like '% ' || v_t || '%')
     order by (public.normalizar_texto(c.nome) like v_t || '%') desc, c.nome
     limit 15;
end;
$$;

create or replace function public.cadastrar_visitante(
  p_portaria_id uuid, p_nome text, p_cargo_id uuid, p_instrumento_id uuid,
  p_origem_casa_oracao_id uuid, p_membro_id uuid, p_foto_path text)
returns uuid
language plpgsql security definer set search_path to 'public'
as $$
declare
  v_p          public.portarias;
  v_casa_oracao      text;
  v_nome       text := btrim(regexp_replace(coalesce(p_nome, ''), '\s+', ' ', 'g'));
  v_origem     record;
  v_permite    boolean;
  v_exige      boolean;
  v_nome_cargo text;
  v_id         uuid;
begin
  perform public.exigir_permissao('portaria.cadastrar_visitante');
  perform public.exigir_acesso_atendimento(p_portaria_id);   -- aprovada e dentro da abrangência de quem atende

  select * into v_p from public.portarias p where p.id = p_portaria_id;
  select c.nome into v_casa_oracao from public.casas_oracao c where c.id = v_p.casa_oracao_id;
  if v_casa_oracao is null then
    raise exception 'A casa de oração desta portaria não foi encontrada.';
  end if;

  if p_membro_id is null or exists (select 1 from public.membros m where m.id = p_membro_id) then
    raise exception 'Não foi possível cadastrar: identificador inválido. Tente novamente.';
  end if;
  perform public.validar_foto_membro(p_membro_id, p_foto_path);   -- foto obrigatória

  if char_length(v_nome) < 5 or char_length(v_nome) > 120 or position(' ' in v_nome) = 0 then
    raise exception 'Digite o nome completo do visitante (nome e sobrenome).';
  end if;

  select c.permite_instrumento, c.exige_instrumento, c.nome into v_permite, v_exige, v_nome_cargo
  from public.cargos c where c.id = p_cargo_id;
  if not found then
    raise exception 'Escolha o cargo ou ministério do visitante.';
  end if;

  if p_instrumento_id is not null then
    if not v_permite then
      raise exception 'Este cargo não usa instrumento.';
    end if;
    if not exists (select 1 from public.instrumentos i where i.id = p_instrumento_id) then
      raise exception 'Instrumento não encontrado.';
    end if;
  elsif coalesce(v_exige, false) then
    raise exception 'O cargo % exige o instrumento. Escolha o instrumento na lista.', v_nome_cargo;
  end if;

  -- A origem precisa ser uma casa de oração cadastrada e ativa, com ADM, RA, RRM e estado ativos (setor, se houver, ativo)
  select c.nome as casa_oracao, c.cidade as cidade, ra.nome as regiao into v_origem
  from public.casas_oracao c
  join public.adms a on a.id = c.adm_id
  join public.ras ra on ra.id = a.ra_id
  join public.rrms rr on rr.id = ra.rrm_id
  join public.estados e on e.id = rr.estado_id
  left join public.setores s on s.id = c.setor_id
  where c.id = p_origem_casa_oracao_id and c.ativo and a.ativo and ra.ativo and rr.ativo and e.ativo
    and (c.setor_id is null or s.ativo);
  if not found then
    raise exception 'Escolha a igreja de origem na lista (estado, RRM, RA, ADM, setor e casa de oração). Se ela não aparecer, peça a um administrador para cadastrá-la em Organização.';
  end if;

  if exists (
    select 1 from public.membros m
    where m.casa_oracao_id = v_p.casa_oracao_id and m.excluido_em is null
      and public.normalizar_texto(m.nome) = public.normalizar_texto(v_nome)
  ) then
    raise exception 'Já existe um membro com este nome nesta casa de oração. Busque pelo nome completo em vez de cadastrar de novo.';
  end if;

  insert into public.membros
    (id, nome, congregacao, cargo_id, instrumento_id, status, casa_oracao_id, cidade, bairro, visitante,
     origem_casa_oracao_id, foto_path)
  values
    (p_membro_id, v_nome, v_casa_oracao, p_cargo_id, p_instrumento_id, 'Ativo', v_p.casa_oracao_id,
     coalesce(v_origem.cidade, v_origem.regiao), v_origem.casa_oracao, true, p_origem_casa_oracao_id, p_foto_path)
  returning id into v_id;

  perform public.registrar_auditoria('visitante_cadastrado', 'membro', v_id,
            jsonb_build_object('portaria_id', p_portaria_id, 'casa_oracao_id', v_p.casa_oracao_id,
                               'origem_casa_oracao_id', p_origem_casa_oracao_id, 'rotulo', v_nome));
  return v_id;
end;
$$;

-- ---------------------------------------------------------------------------
-- 11. Relatórios (as colunas e os parâmetros continuam os mesmos: "regiao" agora é a RA)
-- ---------------------------------------------------------------------------
create or replace function public.relatorio_eventos(
  p_inicio timestamptz, p_fim timestamptz, p_regiao uuid, p_setor uuid, p_casa_oracao uuid, p_limite integer)
returns table (tipo text, data_evento timestamptz, local_evento text, finalidade text, cidade text, regiao text,
               setor text, casa_oracao text, registros bigint, presentes bigint, portaria text, total bigint)
language plpgsql stable security definer set search_path to 'public'
as $$
declare
  v_lim int := least(greatest(coalesce(p_limite, 5000), 1), 20000);
begin
  perform public.exigir_permissao('eventos.visualizar');

  return query
    select ev.tipo, ev.data_evento, ev.local, fi.nome, ev.cidade,
           r.nome, s.nome, c.nome,
           (select count(*) from public.presencas pr
             where pr.evento_id = ev.id and pr.excluido_em is null),
           (select count(*) from public.presencas pr
             where pr.evento_id = ev.id and pr.excluido_em is null and pr.status = 'Presente'),
           (select case po.status when 'APROVADA' then 'Aprovada' when 'PENDENTE_APROVACAO' then 'Pendente'
                                  when 'REJEITADA' then 'Rejeitada' end
              from public.portarias po
             where po.evento_id = ev.id and po.excluido_em is null
             order by po.criada_em desc limit 1),
           count(*) over ()
    from public.eventos ev
    left join public.finalidades_evento fi on fi.id = ev.finalidade_id
    left join public.casas_oracao c on c.id = ev.casa_oracao_id
    left join public.setores s on s.id = c.setor_id
    left join public.adms a on a.id = c.adm_id
    left join public.ras r on r.id = a.ra_id
    where ev.excluido_em is null
      and public.casa_oracao_na_abrangencia(ev.casa_oracao_id)
      and (p_inicio is null or ev.data_evento >= p_inicio)
      and (p_fim is null or ev.data_evento < p_fim)
      and (p_regiao is null or r.id = p_regiao)
      and (p_setor is null or s.id = p_setor)
      and (p_casa_oracao is null or c.id = p_casa_oracao)
    order by ev.data_evento desc, ev.id
    limit v_lim;
end;
$$;

create or replace function public.relatorio_membros(
  p_regiao uuid, p_setor uuid, p_casa_oracao uuid, p_cargo uuid, p_instrumento uuid,
  p_status text, p_visitante text, p_limite integer)
returns table (nome text, cargo text, instrumento text, familia text, regiao text, setor text, casa_oracao text,
               cidade text, bairro text, status text, visitante boolean, data_nascimento date,
               cadastrado_em timestamptz, cpf_parcial text, total bigint)
language plpgsql stable security definer set search_path to 'public'
as $$
declare
  v_lim int := least(greatest(coalesce(p_limite, 5000), 1), 20000);
  v_cpf boolean;
begin
  perform public.exigir_permissao('membros.visualizar');
  v_cpf := public.tem_permissao('membros.cpf');

  return query
    select m.nome, ca.nome, i.nome, f.nome, r.nome, s.nome, c.nome,
           m.cidade, m.bairro, m.status, m.visitante, m.data_nascimento,
           m.data_cadastro,
           case when v_cpf then m.cpf_mascarado end,
           count(*) over ()
    from public.membros m
    left join public.casas_oracao c on c.id = m.casa_oracao_id
    left join public.setores s on s.id = c.setor_id
    left join public.adms a on a.id = c.adm_id
    left join public.ras r on r.id = a.ra_id
    left join public.cargos ca on ca.id = m.cargo_id
    left join public.instrumentos i on i.id = m.instrumento_id
    left join public.familias f on f.id = i.familia_id
    where m.excluido_em is null
      and public.casa_oracao_na_abrangencia(m.casa_oracao_id)
      and (p_regiao is null or r.id = p_regiao)
      and (p_setor is null or s.id = p_setor)
      and (p_casa_oracao is null or c.id = p_casa_oracao)
      and (p_cargo is null or m.cargo_id = p_cargo)
      and (p_instrumento is null or m.instrumento_id = p_instrumento)
      and (nullif(p_status, '') is null or m.status = p_status)
      and (nullif(p_visitante, '') is null
           or (p_visitante = 'sim' and m.visitante)
           or (p_visitante = 'nao' and not m.visitante))
    order by m.nome
    limit v_lim;
end;
$$;

create or replace function public.relatorio_presencas(
  p_inicio timestamptz, p_fim timestamptz, p_evento uuid, p_regiao uuid, p_setor uuid, p_casa_oracao uuid,
  p_status text, p_limite integer)
returns table (evento_tipo text, evento_data timestamptz, evento_local text, evento_finalidade text, regiao text,
               setor text, casa_oracao text, membro_nome text, membro_casa_oracao text, cargo text, instrumento text,
               familia text, cidade text, bairro text, visitante boolean, status text, hora_entrada timestamptz,
               hora_saida timestamptz, origem text, registrado_por text, total bigint)
language plpgsql stable security definer set search_path to 'public'
as $$
declare
  v_lim int := least(greatest(coalesce(p_limite, 5000), 1), 20000);
begin
  perform public.exigir_permissao('portaria.visualizar');

  return query
    select ev.tipo, ev.data_evento, ev.local, fi.nome,
           r.nome, s.nome, c.nome,
           m.nome, m.congregacao, ca.nome, i.nome, f.nome,
           m.cidade, m.bairro, m.visitante,
           pr.status, pr.hora_entrada, pr.hora_saida,
           case when pr.portaria_id is null then 'ANTIGO' else pr.origem end,
           u.nome,
           count(*) over ()
    from public.presencas pr
    join public.eventos ev on ev.id = pr.evento_id and ev.excluido_em is null
    join public.membros m on m.id = pr.membro_id
    left join public.finalidades_evento fi on fi.id = ev.finalidade_id
    left join public.casas_oracao c on c.id = ev.casa_oracao_id
    left join public.setores s on s.id = c.setor_id
    left join public.adms a on a.id = c.adm_id
    left join public.ras r on r.id = a.ra_id
    left join public.cargos ca on ca.id = m.cargo_id
    left join public.instrumentos i on i.id = m.instrumento_id
    left join public.familias f on f.id = i.familia_id
    left join public.usuarios u on u.id = pr.registrado_por
    where pr.excluido_em is null
      and public.casa_oracao_na_abrangencia(ev.casa_oracao_id)
      and (p_inicio is null or ev.data_evento >= p_inicio)
      and (p_fim is null or ev.data_evento < p_fim)
      and (p_evento is null or pr.evento_id = p_evento)
      and (p_regiao is null or r.id = p_regiao)
      and (p_setor is null or s.id = p_setor)
      and (p_casa_oracao is null or c.id = p_casa_oracao)
      and (nullif(p_status, '') is null or pr.status = p_status)
    order by ev.data_evento desc, ev.id, m.nome
    limit v_lim;
end;
$$;

create or replace function public.relatorio_presenca_portaria(p_portaria uuid)
returns jsonb
language plpgsql stable security definer set search_path to 'public'
as $$
declare
  v_po     record;
  v_evento jsonb;
  v_dados  jsonb;
begin
  if not (public.tem_permissao('portaria.visualizar') or public.tem_permissao('portarias.visualizar')) then
    raise exception 'Você não tem permissão para ver este relatório.' using errcode = '42501';
  end if;

  select po.id, po.status, po.evento_id, po.criada_em, po.decidida_em,
         uc.nome as criador, ud.nome as decisor
    into v_po
    from public.portarias po
    left join public.usuarios uc on uc.id = po.criada_por
    left join public.usuarios ud on ud.id = po.decidida_por
   where po.id = p_portaria and po.excluido_em is null;
  if v_po.id is null then
    raise exception 'Portaria não encontrada.';
  end if;
  if not public.evento_na_abrangencia(v_po.evento_id) then
    raise exception 'Relatório indisponível para você.' using errcode = '42501';
  end if;

  select jsonb_build_object('id', e.id, 'tipo', e.tipo, 'local', e.local, 'data_evento', e.data_evento,
                            'cidade', e.cidade, 'finalidade', fi.nome, 'casa_oracao', c.nome,
                            'setor', s.nome, 'regiao', r.nome, 'cancelado', e.cancelado_em is not null)
    into v_evento
    from public.eventos e
    left join public.finalidades_evento fi on fi.id = e.finalidade_id
    left join public.casas_oracao c on c.id = e.casa_oracao_id
    left join public.setores s on s.id = c.setor_id
    left join public.adms a on a.id = c.adm_id
    left join public.ras r on r.id = a.ra_id
   where e.id = v_po.evento_id;

  with base as (
    -- membros cadastrados com presença
    select m.nome, cg.nome as cargo, pr.hora_entrada, pr.toca, pr.linha_codigo, m.categoria,
           coalesce(pr.instrumento_id, m.instrumento_id) as instrumento_id,
           coalesce(co.nome, nullif(m.congregacao, '')) as origem, false as sem_cadastro
      from public.presencas pr
      join public.membros m on m.id = pr.membro_id
      left join public.cargos cg on cg.id = m.cargo_id
      left join public.casas_oracao co on co.id = m.origem_casa_oracao_id
     where pr.evento_id = v_po.evento_id and pr.excluido_em is null and pr.status = 'Presente'
    union all
    -- entradas SEM cadastro (a linha e o instrumento já vêm escolhidos na Portaria)
    select null::text, null::text, a.hora_entrada, a.toca, a.linha_codigo, null::text, a.instrumento_id,
           coalesce(co.nome, nullif(a.origem_texto, '')), true
      from public.presencas_avulsas a
      left join public.casas_oracao co on co.id = a.origem_casa_oracao_id
     where a.evento_id = v_po.evento_id and a.excluido_em is null
  ), calc as (
    select b.*, i.nome as instrumento, i.familia_id,
           coalesce(b.linha_codigo, public.classificar_linha(b.cargo, b.categoria, i.nome)) as linha
      from base b
      left join public.instrumentos i on i.id = b.instrumento_id
  ), grupos as (
    select l.codigo, l.bloco, l.rotulo, l.ordem, g.qtd, g.itens
      from public.linhas_painel l
      join lateral (
        select count(*) as qtd,
               jsonb_agg(jsonb_build_object('nome', c.nome, 'cargo', c.cargo, 'instrumento', c.instrumento,
                                            'toca', c.toca, 'origem', c.origem, 'entrada', c.hora_entrada,
                                            'sem_cadastro', c.sem_cadastro)
                         order by c.sem_cadastro, c.nome, c.hora_entrada) as itens
          from calc c where c.linha = l.codigo
      ) g on g.qtd > 0
  ), por_bloco as (
    select gr.bloco, sum(gr.qtd) as qtd, min(gr.ordem) as ordem from grupos gr group by gr.bloco
  ), por_familia as (
    -- quem toca, por família (mesma regra do Painel ao vivo; órgão fica com as organistas)
    select coalesce(f.nome, 'Sem família') as familia, count(*) as qtd
      from calc c
      join public.linhas_painel l on l.codigo = c.linha
      left join public.familias f on f.id = c.familia_id
     where c.instrumento_id is not null
       and not public.instrumento_e_orgao(c.instrumento)
       and (c.toca is true or (c.toca is null and l.toca_sempre))
     group by 1
  )
  select jsonb_build_object(
           'total', (select count(*) from calc),
           'sem_cadastro', (select count(*) from calc where sem_cadastro),
           'blocos', coalesce((select jsonb_agg(jsonb_build_object('bloco', b.bloco, 'qtd', b.qtd) order by b.ordem)
                                 from por_bloco b), '[]'::jsonb),
           'familias', coalesce((select jsonb_agg(jsonb_build_object('familia', f.familia, 'qtd', f.qtd) order by f.familia)
                                   from por_familia f), '[]'::jsonb),
           'grupos', coalesce((select jsonb_agg(jsonb_build_object('codigo', g.codigo, 'bloco', g.bloco, 'rotulo', g.rotulo,
                                                                   'qtd', g.qtd, 'itens', g.itens) order by g.ordem)
                                 from grupos g), '[]'::jsonb))
    into v_dados;

  return v_dados || jsonb_build_object(
    'evento', v_evento,
    'portaria', jsonb_build_object('status', v_po.status, 'criada_por', v_po.criador, 'criada_em', v_po.criada_em,
                                   'decidida_por', v_po.decisor, 'decidida_em', v_po.decidida_em),
    'gerado_em', now());
end;
$$;

-- ---------------------------------------------------------------------------
-- 12. Auditoria e Backup conhecem as tabelas novas
-- ---------------------------------------------------------------------------
create or replace function public.auditar_tabela()
returns trigger
language plpgsql security definer set search_path to 'public'
as $$
declare
  v_sens   text[] := array['cpf', 'qr_secret', 'cpf_mascarado', 'token_hash'];
  v_ruido  text[] := array['atualizado_em'];
  v_ref    jsonb;
  v_mud    jsonb;
  v_det    jsonb;
  v_acao   text;
  v_id     uuid;
  v_ent    text;
  v_rotulo text;
begin
  -- Restauração de backup em andamento: não registra linha a linha
  if current_setting('sysmusica.restaurando', true) = 'sim' then
    if tg_op = 'DELETE' then
      return old;
    end if;
    return new;
  end if;

  -- Nome da entidade no singular (igual ao das ações já registradas por funções do sistema)
  v_ent := case tg_table_name
    when 'membros' then 'membro'
    when 'eventos' then 'evento'
    when 'presencas' then 'presenca'
    when 'instrumentos' then 'instrumento'
    when 'cargos' then 'cargo'
    when 'familias' then 'familia'
    when 'finalidades_evento' then 'finalidade'
    when 'usuarios' then 'usuario'
    when 'grupos' then 'grupo'
    when 'grupo_permissoes' then 'grupo_permissao'
    when 'usuario_vinculos' then 'vinculo'
    when 'estados' then 'estado'
    when 'rrms' then 'rrm'
    when 'ras' then 'ra'
    when 'adms' then 'adm'
    when 'setores' then 'setor'
    when 'casas_oracao' then 'casa_oracao'
    else tg_table_name
  end;

  v_ref := case when tg_op = 'DELETE' then to_jsonb(old) else to_jsonb(new) end;
  begin
    v_id := (v_ref ->> 'id')::uuid;
  exception when others then
    v_id := null;
  end;

  if tg_op = 'INSERT' then
    v_acao := 'registro_criado';
    v_det := jsonb_build_object('depois', public.auditoria_limpar(to_jsonb(new)));
  elsif tg_op = 'DELETE' then
    v_acao := 'registro_excluido';
    v_det := jsonb_build_object('antes', public.auditoria_limpar(to_jsonb(old)));
  else
    select coalesce(jsonb_object_agg(n.key,
             case when n.key = any (v_sens) then to_jsonb('(alterado)'::text)
                  else jsonb_build_object('de', o.value, 'para', n.value) end), '{}'::jsonb)
      into v_mud
    from jsonb_each(to_jsonb(new)) as n
    left join jsonb_each(to_jsonb(old)) as o on o.key = n.key
    where n.value is distinct from o.value and n.key <> all (v_ruido);

    if v_mud = '{}'::jsonb then
      return new;   -- nada relevante mudou (por exemplo, só a data de atualização)
    end if;

    -- Exclusão lógica: a linha ganhou a data de exclusão
    v_acao := case when (to_jsonb(old) ->> 'excluido_em') is null and (to_jsonb(new) ->> 'excluido_em') is not null
                   then 'registro_excluido' else 'registro_alterado' end;
    v_det := jsonb_build_object('mudancas', v_mud)
             || case when v_acao = 'registro_excluido' then jsonb_build_object('logica', true) else '{}'::jsonb end;
  end if;

  -- Rótulo legível: nome, tipo, e-mail ou local; presenças e vínculos usam o nome do membro/usuário
  v_rotulo := coalesce(v_ref ->> 'nome', v_ref ->> 'tipo', v_ref ->> 'email', v_ref ->> 'local');
  if v_rotulo is null then
    begin
      if v_ref ? 'membro_id' then
        select m.nome into v_rotulo from public.membros m where m.id = (v_ref ->> 'membro_id')::uuid;
      elsif v_ref ? 'usuario_id' then
        select u.nome into v_rotulo from public.usuarios u where u.id = (v_ref ->> 'usuario_id')::uuid;
      end if;
    exception when others then
      v_rotulo := null;
    end;
  end if;
  if v_rotulo is not null then
    v_det := v_det || jsonb_build_object('rotulo', v_rotulo);
  end if;

  insert into public.auditoria (usuario_id, acao, entidade, entidade_id, detalhes)
  values ((select auth.uid()), v_acao, v_ent, v_id, v_det);

  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end;
$$;

create or replace function public.backup_aplicar(p_usuario uuid, p_operacoes jsonb, p_resumo jsonb)
returns jsonb
language plpgsql security definer set search_path to 'public'
as $$
declare
  v_op        jsonb;
  v_tabela    text;
  v_acao      text;
  v_linhas    jsonb;
  v_colunas   text[];
  v_def       record;
  v_cols      text;
  v_bcols     text;
  v_set       text;
  v_pk_cond   text;
  v_extra     text;
  v_n         bigint;
  v_ignorados bigint;
  v_resultado jsonb := '[]'::jsonb;
begin
  if p_operacoes is null or jsonb_typeof(p_operacoes) <> 'array' then
    raise exception 'Operações inválidas.';
  end if;

  perform set_config('sysmusica.restaurando', 'sim', true);

  for v_op in select * from jsonb_array_elements(p_operacoes) loop
    v_tabela := v_op ->> 'tabela';
    v_acao   := v_op ->> 'acao';
    v_linhas := coalesce(v_op -> 'linhas', '[]'::jsonb);

    select t.* into v_def
    from (values
      ('estados',             array['id'],                              false, false, ''),
      ('rrms',                array['id'],                              false, false, ''),
      ('ras',                 array['id'],                              false, false, ''),
      ('adms',                array['id'],                              false, false, ''),
      ('setores',             array['id'],                              false, false, ''),
      ('casas_oracao',        array['id'],                              false, false, ''),
      ('familias',            array['id'],                              false, false, ''),
      ('cargos',              array['id'],                              false, false, ''),
      ('finalidades_evento',  array['id'],                              false, false, ''),
      ('instrumentos',        array['id'],                              false, false, ''),
      ('grupos',              array['id'],                              false, false, ''),
      ('grupo_permissoes',    array['grupo_id', 'permissao_codigo'],    false, false, ''),
      ('usuarios',            array['id'],                              false, false, 'login'),
      ('usuario_grupos',      array['usuario_id', 'grupo_id'],          false, false, ''),
      ('usuario_vinculos',    array['usuario_id', 'nivel', 'alvo_id'],  false, false, ''),
      ('membros',             array['id'],                              true,  false, ''),
      ('eventos',             array['id'],                              true,  false, ''),
      ('portarias',           array['id'],                              true,  false, ''),
      ('portarias_historico', array['id'],                              false, true,  ''),
      ('presencas',           array['id'],                              true,  false, ''),
      ('presencas_avulsas',   array['id'],                              true,  false, '')
    ) as t(tabela, pk, soft, so_inserir, extra)
    where t.tabela = v_tabela;
    if not found then
      raise exception 'Tabela não permitida na restauração: %', coalesce(v_tabela, '(vazia)');
    end if;

    if v_acao is null or v_acao not in ('inserir', 'atualizar', 'excluir_logico', 'excluir') then
      raise exception 'Ação inválida na restauração: %', coalesce(v_acao, '(vazia)');
    end if;
    if v_def.so_inserir and v_acao <> 'inserir' then
      raise exception 'A tabela % só aceita devolver registros apagados.', v_tabela;
    end if;
    if v_acao = 'excluir_logico' and not v_def.soft then
      raise exception 'A tabela % não usa exclusão lógica.', v_tabela;
    end if;
    if v_acao = 'excluir' and v_def.soft then
      raise exception 'Os itens da tabela % são excluídos logicamente.', v_tabela;
    end if;
    if jsonb_typeof(v_linhas) <> 'array' then
      raise exception 'Linhas inválidas em %.', v_tabela;
    end if;
    if jsonb_array_length(v_linhas) = 0 then
      continue;
    end if;

    select coalesce(array_agg(x), '{}'::text[]) into v_colunas
    from jsonb_array_elements_text(coalesce(v_op -> 'colunas', '[]'::jsonb)) as x;

    if not (v_def.pk <@ v_colunas) then
      raise exception 'Faltam as colunas de identificação em %.', v_tabela;
    end if;

    -- Só colunas que existem e podem ser gravadas (as geradas ficam de fora)
    select string_agg(quote_ident(c.column_name), ', ' order by c.ordinal_position),
           string_agg(format('b.%I', c.column_name), ', ' order by c.ordinal_position),
           string_agg(format('%1$I = b.%1$I', c.column_name), ', ' order by c.ordinal_position)
             filter (where c.column_name <> all (v_def.pk))
      into v_cols, v_bcols, v_set
    from information_schema.columns c
    where c.table_schema = 'public' and c.table_name = v_tabela
      and c.is_generated = 'NEVER' and c.column_name = any (v_colunas);

    select string_agg(format('c.%1$I = b.%1$I', k), ' and ') into v_pk_cond from unnest(v_def.pk) as k;

    v_ignorados := 0;

    if v_acao = 'inserir' then
      -- Usuários só voltam se a conta de login ainda existir (a senha não é guardada no backup)
      v_extra := case when v_def.extra = 'login' then 'where exists (select 1 from auth.users a where a.id = b.id)' else '' end;
      execute format(
        'insert into public.%1$I (%2$s) select %3$s from jsonb_populate_recordset(null::public.%1$I, $1) b %4$s',
        v_tabela, v_cols, v_bcols, v_extra) using v_linhas;
      get diagnostics v_n = row_count;
      v_ignorados := jsonb_array_length(v_linhas) - v_n;

    elsif v_acao = 'atualizar' then
      if v_set is null then
        v_n := 0;
      else
        execute format(
          'update public.%1$I c set %2$s from jsonb_populate_recordset(null::public.%1$I, $1) b where %3$s',
          v_tabela, v_set, v_pk_cond) using v_linhas;
        get diagnostics v_n = row_count;
      end if;

    elsif v_acao = 'excluir_logico' then
      execute format(
        'update public.%1$I c set excluido_em = now() from jsonb_populate_recordset(null::public.%1$I, $1) b where %2$s and c.excluido_em is null',
        v_tabela, v_pk_cond) using v_linhas;
      get diagnostics v_n = row_count;

    else
      execute format(
        'delete from public.%1$I c using jsonb_populate_recordset(null::public.%1$I, $1) b where %2$s',
        v_tabela, v_pk_cond) using v_linhas;
      get diagnostics v_n = row_count;
    end if;

    v_resultado := v_resultado || jsonb_build_object(
      'tabela', v_tabela, 'acao', v_acao, 'afetados', v_n, 'ignorados', v_ignorados);
  end loop;

  perform set_config('sysmusica.restaurando', '', true);

  -- Uma única entrada resumida na auditoria (a auditoria linha a linha ficou pausada)
  insert into public.auditoria (usuario_id, acao, entidade, entidade_id, detalhes)
  values (p_usuario, 'backup_restaurado', 'backup', null,
          coalesce(p_resumo, '{}'::jsonb) || jsonb_build_object('operacoes', v_resultado));

  return v_resultado;
end;
$$;

-- ---------------------------------------------------------------------------
-- 13. Prova de que NINGUÉM ganhou nem perdeu acesso: compara antes e depois, usuário por usuário
-- ---------------------------------------------------------------------------
do $$
declare
  v_a record;
  v_dif bigint;
  v_extra bigint;
begin
  select * into v_a from _qtd_antes;

  if (select count(*) from public.estados) <> v_a.estados
     or (select count(*) from public.ras) <> v_a.regioes
     or (select count(*) from public.setores) <> v_a.setores
     or (select count(*) from public.casas_oracao) <> v_a.casas
     or (select count(*) from public.usuario_vinculos) <> v_a.vinculos then
    raise exception 'Migração abortada: a quantidade de itens mudou. Nada foi alterado.';
  end if;

  create temp table _vis_depois on commit drop as
  select v.usuario_id, c.id as casa_id
  from public.usuario_vinculos v
  cross join public.casas_oracao c
  join public.adms a on a.id = c.adm_id
  join public.ras ra on ra.id = a.ra_id
  join public.rrms rr on rr.id = ra.rrm_id
  join public.estados e on e.id = rr.estado_id
  left join public.setores s on s.id = c.setor_id
  where c.ativo and a.ativo and ra.ativo and rr.ativo and e.ativo and (c.setor_id is null or s.ativo)
    and ((v.nivel = 'CASA_ORACAO' and v.alvo_id = c.id)
      or (v.nivel = 'SETOR'       and v.alvo_id = s.id)
      or (v.nivel = 'ADM'         and v.alvo_id = a.id)
      or (v.nivel = 'RA'          and v.alvo_id = ra.id)
      or (v.nivel = 'RRM'         and v.alvo_id = rr.id)
      or (v.nivel = 'ESTADO'      and v.alvo_id = e.id));

  select count(*) into v_dif from (select * from _vis_antes except select * from _vis_depois) x;
  select count(*) into v_extra from (select * from _vis_depois except select * from _vis_antes) x;
  if v_dif > 0 or v_extra > 0 then
    raise exception 'Migração abortada: o acesso de usuários mudaria (% perderiam, % ganhariam acesso a casas). Nada foi alterado.', v_dif, v_extra;
  end if;
end $$;

select set_config('sysmusica.restaurando', '', true);

commit;
