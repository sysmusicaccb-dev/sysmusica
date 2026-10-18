-- =====================================================================
-- SysMúsica — Migração 0012: hierarquia organizacional (Estado > Região > Setor > Comum)
--   * Cadastros gerenciados pelo sistema: estados, regiões, setores e comuns (igrejas/salões).
--     "Setor 1" de uma região é outro cadastro que o "Setor 1" de outra região.
--   * Vínculos dos usuários em QUALQUER nível (estado, região, setor ou comum): o acesso desce em
--     cascata. Sem vínculo, o usuário não vê nada.
--   * ACESSO POR REGIÃO: membros, eventos, presenças, portarias e fotografias só são vistos e alterados
--     dentro dos vínculos do usuário (regra aplicada no banco, não só na tela). Quem tem a permissão
--     "Acesso total à organização" (Administrador) ou "Controle total de portarias" não tem restrição.
--   * A abrangência por cidade (migração 0007) é SUBSTITUÍDA por esta.
--   * Transferência de comum entre setores com histórico e auditoria.
--   * Dados atuais: as congregações dos membros e os locais dos eventos viram COMUNS SEM SETOR
--     (a administração vincula cada uma ao setor certo em Administração > Organização).
-- Ao final, a migração TESTA as funções e as regras de acesso como Administrador: se algo falhar,
-- tudo é desfeito.
-- Requer as migrações 0007 a 0010. Idempotente, uma única transação.
-- =====================================================================
begin;

do $$
begin
  if to_regprocedure('public.cidade_na_minha_abrangencia(text)') is null
     or to_regprocedure('public.exigir_acesso_atendimento(uuid)') is null
     or to_regprocedure('public.validar_registro_presenca(uuid,uuid,uuid)') is null then
    raise exception 'Aplique primeiro as migrações 0007, 0008, 0009 e 0010.';
  end if;
end $$;

-- 1) PERMISSÕES (iguais a CATALOGO_PERMISSOES em src/lib/permissoes.ts); só o Administrador recebe
insert into public.permissoes (codigo, modulo, acao, descricao) values
  ('organizacao.visualizar',  'Organização', 'Visualizar',   'Ver estados, regiões, setores e comuns'),
  ('organizacao.criar',       'Organização', 'Criar',        'Cadastrar estados, regiões, setores e comuns'),
  ('organizacao.editar',      'Organização', 'Editar',       'Renomear, ativar e inativar estados, regiões, setores e comuns'),
  ('organizacao.transferir',  'Organização', 'Transferir',   'Mudar uma comum de setor (fica registrado)'),
  ('organizacao.acesso_total','Organização', 'Acesso total', 'Ver e atuar em TODAS as regiões, setores e comuns (sem restrição organizacional)'),
  ('usuarios.vinculos',       'Usuários',    'Vínculos',     'Definir os vínculos organizacionais (estado, região, setor ou comum) dos usuários')
on conflict (codigo) do update
  set modulo = excluded.modulo, acao = excluded.acao, descricao = excluded.descricao;

insert into public.grupo_permissoes (grupo_id, permissao_codigo)
select g.id, p.codigo
from public.grupos g cross join public.permissoes p
where g.sistema and g.nome = 'Administrador'
on conflict do nothing;

-- 2) TABELAS DA HIERARQUIA (sem acesso direto: só pelas funções abaixo)
create table if not exists public.estados (
  id        uuid primary key default gen_random_uuid(),
  nome      text not null,
  ativo     boolean not null default true,
  criado_em timestamptz not null default now()
);
create table if not exists public.regioes (
  id        uuid primary key default gen_random_uuid(),
  estado_id uuid not null references public.estados (id),
  nome      text not null,
  descricao text,
  ativo     boolean not null default true,
  criado_em timestamptz not null default now()
);
create table if not exists public.setores (
  id        uuid primary key default gen_random_uuid(),
  regiao_id uuid not null references public.regioes (id),
  nome      text not null,
  descricao text,
  ativo     boolean not null default true,
  criado_em timestamptz not null default now()
);
create table if not exists public.comuns (
  id        uuid primary key default gen_random_uuid(),
  setor_id  uuid references public.setores (id),   -- nulo = ainda sem setor
  nome      text not null,
  cidade    text,
  bairro    text,
  ativo     boolean not null default true,
  criado_em timestamptz not null default now()
);

create index if not exists idx_regioes_estado on public.regioes (estado_id);
create index if not exists idx_setores_regiao on public.setores (regiao_id);
create index if not exists idx_comuns_setor   on public.comuns (setor_id);

-- Nomes únicos dentro do nível pai (as funções ainda comparam sem acento e sem diferenciar maiúsculas)
create unique index if not exists estados_nome_unico on public.estados (lower(nome));
create unique index if not exists regioes_nome_unico on public.regioes (estado_id, lower(nome));
create unique index if not exists setores_nome_unico on public.setores (regiao_id, lower(nome));
create unique index if not exists comuns_nome_unico
  on public.comuns (coalesce(setor_id, '00000000-0000-0000-0000-000000000000'::uuid), lower(nome));

-- Histórico das transferências de comum (só acréscimo)
create table if not exists public.comuns_historico (
  id             uuid primary key default gen_random_uuid(),
  comum_id       uuid not null references public.comuns (id),
  setor_anterior uuid,
  setor_novo     uuid,
  usuario_id     uuid,
  ocorrido_em    timestamptz not null default now(),
  justificativa  text
);
drop trigger if exists trg_comuns_historico_somente_acrescimo on public.comuns_historico;
create trigger trg_comuns_historico_somente_acrescimo
  before update or delete on public.comuns_historico
  for each row execute function public.auditoria_somente_acrescimo();

-- Vínculos dos usuários: o usuário pode ser ligado a um estado, região, setor ou comum
create table if not exists public.usuario_vinculos (
  usuario_id uuid not null references public.usuarios (id) on delete cascade,
  nivel      text not null check (nivel in ('ESTADO', 'REGIAO', 'SETOR', 'COMUM')),
  alvo_id    uuid not null,
  primary key (usuario_id, nivel, alvo_id)
);

alter table public.estados          enable row level security;
alter table public.regioes          enable row level security;
alter table public.setores          enable row level security;
alter table public.comuns           enable row level security;
alter table public.comuns_historico enable row level security;
alter table public.usuario_vinculos enable row level security;
revoke all on public.estados, public.regioes, public.setores, public.comuns,
              public.comuns_historico, public.usuario_vinculos from anon, authenticated;

-- 3) DADOS INICIAIS: Bahia, regiões Salvador e Jequié, Setor 1 a 5 em cada uma (editáveis pela tela)
insert into public.estados (nome)
select 'Bahia' where not exists (select 1 from public.estados e where lower(e.nome) = 'bahia');

insert into public.regioes (estado_id, nome)
select e.id, r.nome
from public.estados e
cross join (values ('Salvador'), ('Jequié')) as r(nome)
where lower(e.nome) = 'bahia'
  and not exists (select 1 from public.regioes x where x.estado_id = e.id and lower(x.nome) = lower(r.nome));

insert into public.setores (regiao_id, nome)
select g.id, 'Setor ' || n.i
from public.regioes g
join public.estados e on e.id = g.estado_id and lower(e.nome) = 'bahia'
cross join generate_series(1, 5) as n(i)
where lower(g.nome) in ('salvador', 'jequié')
  and not exists (select 1 from public.setores s where s.regiao_id = g.id and lower(s.nome) = lower('Setor ' || n.i));

-- Comuns a partir das congregações dos membros e dos locais dos eventos (sem setor; sem repetir nomes)
insert into public.comuns (nome)
select distinct on (public.normalizar_texto(t.nome)) t.nome
from (
  select btrim(m.congregacao) as nome from public.membros m
   where m.excluido_em is null and nullif(btrim(coalesce(m.congregacao, '')), '') is not null
  union all
  select btrim(e.local) from public.eventos e
   where e.excluido_em is null and nullif(btrim(coalesce(e.local, '')), '') is not null
) t
where not exists (select 1 from public.comuns c where public.normalizar_texto(c.nome) = public.normalizar_texto(t.nome))
order by public.normalizar_texto(t.nome), t.nome;

-- 4) MEMBROS e EVENTOS: coluna da comum + ligação automática pelo nome dos dados atuais
alter table public.membros add column if not exists comum_id uuid references public.comuns (id);
alter table public.eventos add column if not exists comum_id uuid references public.comuns (id);
create index if not exists idx_membros_comum on public.membros (comum_id);
create index if not exists idx_eventos_comum on public.eventos (comum_id);

-- As colunas de membros têm permissão por coluna: libera a nova (a linha em si continua sob RLS)
grant select (comum_id), insert (comum_id), update (comum_id) on public.membros to authenticated;
grant update (comum_id) on public.eventos to authenticated;

update public.membros m
   set comum_id = x.comum_id
  from (
    select m2.id as membro_id, (array_agg(c.id))[1] as comum_id, count(*) as qtd
    from public.membros m2
    join public.comuns c
      on public.normalizar_texto(c.nome) = public.normalizar_texto(btrim(coalesce(m2.congregacao, '')))
    where m2.comum_id is null
    group by m2.id
  ) x
 where x.membro_id = m.id and x.qtd = 1;

update public.eventos e
   set comum_id = x.comum_id
  from (
    select e2.id as evento_id, (array_agg(c.id))[1] as comum_id, count(*) as qtd
    from public.eventos e2
    join public.comuns c
      on public.normalizar_texto(c.nome) = public.normalizar_texto(btrim(coalesce(e2.local, '')))
    where e2.comum_id is null
    group by e2.id
  ) x
 where x.evento_id = e.id and x.qtd = 1;

-- 5) PORTARIAS: a comum do evento define o setor (a coluna cidade vira só um rótulo "Região › Setor")
alter table public.portarias add column if not exists comum_id uuid references public.comuns (id);
alter table public.portarias alter column cidade drop not null;
create index if not exists idx_portarias_comum on public.portarias (comum_id);

update public.portarias p set comum_id = e.comum_id
  from public.eventos e
 where e.id = p.evento_id and p.comum_id is null and e.comum_id is not null;

-- 6) ABRANGÊNCIA POR VÍNCULO ORGANIZACIONAL
-- A comum (ativa, com setor, região e estado ativos) está dentro dos vínculos de quem está logado?
create or replace function public.comum_na_minha_abrangencia(p_comum uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select p_comum is not null and exists (
    select 1
    from public.comuns c
    join public.setores s on s.id = c.setor_id
    join public.regioes r on r.id = s.regiao_id
    join public.estados e on e.id = r.estado_id
    join public.usuario_vinculos v
      on v.usuario_id = (select auth.uid())
     and ((v.nivel = 'COMUM'  and v.alvo_id = c.id)
       or (v.nivel = 'SETOR'  and v.alvo_id = s.id)
       or (v.nivel = 'REGIAO' and v.alvo_id = r.id)
       or (v.nivel = 'ESTADO' and v.alvo_id = e.id))
    where c.id = p_comum and c.ativo and s.ativo and r.ativo and e.ativo
  )
$$;

-- Quem não tem restrição organizacional: "Acesso total à organização" ou "Controle total de portarias"
create or replace function public.tem_acesso_total_organizacao()
returns boolean language sql stable security definer set search_path = public as $$
  select public.tem_permissao('organizacao.acesso_total') or public.tem_permissao('portarias.controle_total')
$$;

-- A comum está na abrangência de quem está logado (ou ele não tem restrição)?
create or replace function public.comum_na_abrangencia(p_comum uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select public.tem_acesso_total_organizacao() or public.comum_na_minha_abrangencia(p_comum)
$$;

-- O evento é de uma comum da abrangência de quem está logado? (usada nas regras de presenças)
create or replace function public.evento_na_abrangencia(p_evento uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.eventos e
    where e.id = p_evento and public.comum_na_abrangencia(e.comum_id)
  )
$$;

-- Rótulo "Região › Setor" da comum (nulo se a comum não tem setor)
create or replace function public.rotulo_setor(p_comum uuid)
returns text language sql stable security definer set search_path = public as $$
  select r.nome || ' › ' || s.nome
  from public.comuns c
  join public.setores s on s.id = c.setor_id
  join public.regioes r on r.id = s.regiao_id
  where c.id = p_comum
$$;

-- Rótulo de um vínculo: "Bahia", "Bahia › Salvador", "Salvador › Setor 1" ou "Salvador › Setor 1 › Comum"
create or replace function public.rotulo_vinculo(p_nivel text, p_alvo uuid)
returns text language sql stable security definer set search_path = public as $$
  select case p_nivel
    when 'ESTADO' then (select e.nome from public.estados e where e.id = p_alvo)
    when 'REGIAO' then (select e.nome || ' › ' || r.nome
                          from public.regioes r join public.estados e on e.id = r.estado_id where r.id = p_alvo)
    when 'SETOR'  then (select r.nome || ' › ' || s.nome
                          from public.setores s join public.regioes r on r.id = s.regiao_id where s.id = p_alvo)
    when 'COMUM'  then (select coalesce(r.nome || ' › ' || s.nome || ' › ', '') || c.nome
                          from public.comuns c
                          left join public.setores s on s.id = c.setor_id
                          left join public.regioes r on r.id = s.regiao_id
                         where c.id = p_alvo)
  end
$$;

-- A tela de portarias avisa o aprovador sem vínculo: agora lista os vínculos (antes eram as cidades)
create or replace function public.minhas_cidades()
returns text[] language sql stable security definer set search_path = public as $$
  select coalesce(array_agg(public.rotulo_vinculo(v.nivel, v.alvo_id)
                            order by public.rotulo_vinculo(v.nivel, v.alvo_id)), '{}'::text[])
  from public.usuario_vinculos v
  where v.usuario_id = (select auth.uid())
    and public.rotulo_vinculo(v.nivel, v.alvo_id) is not null
$$;

-- 7) MEMBROS: a comum escolhida dá o nome da congregação; sem comum, tenta ligar pelo nome digitado
create or replace function public.membros_sincroniza_comum()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_id  uuid;
  v_qtd int;
begin
  if new.comum_id is not null and (tg_op = 'INSERT' or new.comum_id is distinct from old.comum_id) then
    select c.nome into new.congregacao from public.comuns c where c.id = new.comum_id;
    if not found then
      raise exception 'Comum não encontrada.';
    end if;
  elsif tg_op = 'INSERT' or new.congregacao is distinct from old.congregacao then
    select (array_agg(c.id))[1], count(*) into v_id, v_qtd
    from public.comuns c
    where public.normalizar_texto(c.nome) = public.normalizar_texto(btrim(coalesce(new.congregacao, '')));
    new.comum_id := case when v_qtd = 1 then v_id else null end;
  end if;

  -- Quem tem acesso por região precisa ligar o membro a uma comum (senão ele sumiria da própria lista)
  if new.comum_id is null and (select auth.uid()) is not null and not public.tem_acesso_total_organizacao() then
    raise exception 'Não encontrei a comum "%". Use o nome exato de uma comum cadastrada em Administração > Organização.',
      coalesce(new.congregacao, '');
  end if;
  return new;
end;
$$;

drop trigger if exists trg_membros_sincroniza_comum on public.membros;
create trigger trg_membros_sincroniza_comum
  before insert or update of comum_id, congregacao on public.membros
  for each row execute function public.membros_sincroniza_comum();

-- Renomear uma comum renomeia a congregação dos membros dela
create or replace function public.comuns_propaga_nome()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.nome is distinct from old.nome then
    update public.membros set congregacao = new.nome where comum_id = new.id;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_comuns_propaga_nome on public.comuns;
create trigger trg_comuns_propaga_nome
  after update of nome on public.comuns
  for each row execute function public.comuns_propaga_nome();

-- 8) EVENTOS: a comum só pode ser escolhida ou trocada dentro da abrangência; as portarias acompanham
create or replace function public.eventos_valida_comum()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if (select auth.uid()) is null then
    return new;   -- SQL Editor / rotinas internas: sem restrição
  end if;

  -- Quem tem acesso por região precisa escolher a comum (senão o evento sumiria da própria lista)
  if new.comum_id is null and not public.tem_acesso_total_organizacao()
     and (tg_op = 'INSERT' or old.comum_id is not null) then
    raise exception 'Escolha a comum do evento.';
  end if;

  if tg_op = 'INSERT' then
    if new.comum_id is not null and not public.comum_na_abrangencia(new.comum_id) then
      raise exception 'Esta comum está fora da sua abrangência.' using errcode = '42501';
    end if;
  elsif new.comum_id is distinct from old.comum_id then
    if (new.comum_id is not null and not public.comum_na_abrangencia(new.comum_id))
       or (old.comum_id is not null and not public.comum_na_abrangencia(old.comum_id)) then
      raise exception 'Você não pode mudar a comum deste evento: ela está fora da sua abrangência.'
        using errcode = '42501';
    end if;
    update public.portarias
       set comum_id = new.comum_id, cidade = public.rotulo_setor(new.comum_id)
     where evento_id = new.id and excluido_em is null;
    perform public.registrar_auditoria('evento_comum_alterada', 'evento', new.id,
              jsonb_build_object('de', old.comum_id, 'para', new.comum_id));
  end if;
  return new;
end;
$$;

drop trigger if exists trg_eventos_valida_comum on public.eventos;
create trigger trg_eventos_valida_comum
  before insert or update of comum_id on public.eventos
  for each row execute function public.eventos_valida_comum();

-- 9) CONSULTAS DA TELA
-- Árvore completa (tela de Organização e vínculos de usuários)
create or replace function public.listar_organizacao()
returns table (
  nivel text, id uuid, parent_id uuid, nome text, descricao text, ativo boolean,
  cidade text, bairro text, qtd_filhos bigint, qtd_membros bigint
)
language plpgsql stable security definer set search_path = public as $$
begin
  perform public.exigir_alguma_permissao(array['organizacao.visualizar', 'usuarios.vinculos', 'usuarios.editar']);
  return query
    select 'ESTADO'::text, e.id, null::uuid, e.nome, null::text, e.ativo, null::text, null::text,
           (select count(*) from public.regioes r where r.estado_id = e.id), 0::bigint
    from public.estados e
    union all
    select 'REGIAO'::text, r.id, r.estado_id, r.nome, r.descricao, r.ativo, null::text, null::text,
           (select count(*) from public.setores s where s.regiao_id = r.id), 0::bigint
    from public.regioes r
    union all
    select 'SETOR'::text, s.id, s.regiao_id, s.nome, s.descricao, s.ativo, null::text, null::text,
           (select count(*) from public.comuns c where c.setor_id = s.id), 0::bigint
    from public.setores s
    union all
    select 'COMUM'::text, c.id, c.setor_id, c.nome, null::text, c.ativo, c.cidade, c.bairro, 0::bigint,
           (select count(*) from public.membros m where m.comum_id = c.id and m.excluido_em is null)
    from public.comuns c;
end;
$$;

-- Lista para os seletores de comum (eventos e membros): só o que o usuário pode usar (acesso total vê tudo)
create or replace function public.listar_organizacao_para_selecao()
returns table (nivel text, id uuid, parent_id uuid, nome text)
language plpgsql stable security definer set search_path = public as $$
declare
  v_total boolean;
begin
  if not public.tem_acesso() then
    raise exception 'Sem acesso.' using errcode = '42501';
  end if;
  v_total := public.tem_acesso_total_organizacao();

  return query
    with ok as (
      select c.id as comum_id, c.nome as comum_nome, c.setor_id as setor_id
      from public.comuns c
      where c.ativo and (v_total or public.comum_na_minha_abrangencia(c.id))
    ),
    sset as (
      select s.id as setor_id, s.regiao_id as regiao_id, s.nome as setor_nome
      from public.setores s
      where s.ativo and (v_total or s.id in (select ok.setor_id from ok))
    ),
    rset as (
      select r.id as regiao_id, r.estado_id as estado_id, r.nome as regiao_nome
      from public.regioes r
      where r.ativo and (v_total or r.id in (select sset.regiao_id from sset))
    ),
    eset as (
      select e.id as estado_id, e.nome as estado_nome
      from public.estados e
      where e.ativo and (v_total or e.id in (select rset.estado_id from rset))
    )
    select 'ESTADO'::text, eset.estado_id, null::uuid, eset.estado_nome from eset
    union all
    select 'REGIAO'::text, rset.regiao_id, rset.estado_id, rset.regiao_nome from rset
    union all
    select 'SETOR'::text, sset.setor_id, sset.regiao_id, sset.setor_nome from sset
    union all
    select 'COMUM'::text, ok.comum_id, ok.setor_id, ok.comum_nome from ok;
end;
$$;

-- Eventos que o usuário pode transformar em portaria: só os das suas comuns; "cidade" traz o rótulo
-- "Região › Setor" (nulo se a comum ainda não tem setor, e então o evento aparece desabilitado)
create or replace function public.listar_eventos_para_portaria()
returns table (
  id uuid, tipo text, data_evento timestamptz, local text, cidade text, comum_id uuid
)
language plpgsql stable security definer set search_path = public as $$
begin
  perform public.exigir_permissao('portarias.criar');
  return query
    select e.id, e.tipo, e.data_evento, e.local,
           case when c.setor_id is not null then public.rotulo_setor(e.comum_id) end,
           e.comum_id
    from public.eventos e
    join public.comuns c on c.id = e.comum_id
    where e.excluido_em is null
      and public.comum_na_abrangencia(e.comum_id)
    order by e.data_evento desc
    limit 300;
end;
$$;

-- Vínculos de todos os usuários, com o rótulo (tela de usuários; exige usuarios.visualizar)
create or replace function public.listar_vinculos_rotulados()
returns table (usuario_id uuid, nivel text, alvo_id uuid, rotulo text)
language plpgsql stable security definer set search_path = public as $$
begin
  perform public.exigir_permissao('usuarios.visualizar');
  return query
    select v.usuario_id, v.nivel, v.alvo_id, public.rotulo_vinculo(v.nivel, v.alvo_id)
    from public.usuario_vinculos v
    where public.rotulo_vinculo(v.nivel, v.alvo_id) is not null
    order by v.usuario_id, 4;
end;
$$;

-- 10) CADASTRO DA ORGANIZAÇÃO (criar, renomear, ativar e inativar; a transferência é outra função)
create or replace function public.salvar_organizacao(
  p_nivel text, p_id uuid, p_parent uuid, p_nome text, p_descricao text,
  p_ativo boolean, p_cidade text, p_bairro text
)
returns uuid language plpgsql security definer set search_path = public as $$
declare
  v_novo   boolean := p_id is null;
  v_nome   text    := btrim(regexp_replace(coalesce(p_nome, ''), '\s+', ' ', 'g'));
  v_desc   text    := nullif(btrim(coalesce(p_descricao, '')), '');
  v_cidade text    := nullif(btrim(coalesce(p_cidade, '')), '');
  v_bairro text    := nullif(btrim(coalesce(p_bairro, '')), '');
  v_id     uuid;
  v_pai    uuid;
begin
  if p_nivel is null or p_nivel not in ('ESTADO', 'REGIAO', 'SETOR', 'COMUM') then
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

  elsif p_nivel = 'REGIAO' then
    v_pai := case when v_novo then p_parent else (select x.estado_id from public.regioes x where x.id = p_id) end;
    if v_pai is null or not exists (select 1 from public.estados e where e.id = v_pai) then
      raise exception 'Escolha o estado da região.';
    end if;
    if exists (select 1 from public.regioes x
                where x.estado_id = v_pai and x.id is distinct from p_id
                  and public.normalizar_texto(x.nome) = public.normalizar_texto(v_nome)) then
      raise exception 'Já existe uma região com este nome neste estado.';
    end if;
    if v_novo then
      insert into public.regioes (estado_id, nome, descricao) values (v_pai, v_nome, v_desc) returning id into v_id;
    else
      update public.regioes set nome = v_nome, descricao = v_desc, ativo = coalesce(p_ativo, ativo)
       where id = p_id returning id into v_id;
    end if;

  elsif p_nivel = 'SETOR' then
    v_pai := case when v_novo then p_parent else (select x.regiao_id from public.setores x where x.id = p_id) end;
    if v_pai is null or not exists (select 1 from public.regioes r where r.id = v_pai) then
      raise exception 'Escolha a região do setor.';
    end if;
    if exists (select 1 from public.setores x
                where x.regiao_id = v_pai and x.id is distinct from p_id
                  and public.normalizar_texto(x.nome) = public.normalizar_texto(v_nome)) then
      raise exception 'Já existe um setor com este nome nesta região.';
    end if;
    if v_novo then
      insert into public.setores (regiao_id, nome, descricao) values (v_pai, v_nome, v_desc) returning id into v_id;
    else
      update public.setores set nome = v_nome, descricao = v_desc, ativo = coalesce(p_ativo, ativo)
       where id = p_id returning id into v_id;
    end if;

  else  -- COMUM
    v_pai := case when v_novo then p_parent else (select x.setor_id from public.comuns x where x.id = p_id) end;
    if v_novo and (v_pai is null or not exists (select 1 from public.setores s where s.id = v_pai)) then
      raise exception 'Escolha o setor da comum.';
    end if;
    if exists (select 1 from public.comuns x
                where x.setor_id is not distinct from v_pai and x.id is distinct from p_id
                  and public.normalizar_texto(x.nome) = public.normalizar_texto(v_nome)) then
      raise exception 'Já existe uma comum com este nome neste setor.';
    end if;
    if v_novo then
      insert into public.comuns (setor_id, nome, cidade, bairro) values (v_pai, v_nome, v_cidade, v_bairro)
      returning id into v_id;
    else
      update public.comuns set nome = v_nome, cidade = v_cidade, bairro = v_bairro, ativo = coalesce(p_ativo, ativo)
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

-- Transfere uma comum para outro setor (permissão própria; fica no histórico e na auditoria)
create or replace function public.transferir_comum(p_comum uuid, p_setor uuid, p_justificativa text)
returns void language plpgsql security definer set search_path = public as $$
declare
  v_c    public.comuns;
  v_just text := nullif(btrim(coalesce(p_justificativa, '')), '');
begin
  perform public.exigir_permissao('organizacao.transferir');

  select * into v_c from public.comuns c where c.id = p_comum for update;
  if not found then
    raise exception 'Comum não encontrada.';
  end if;
  if not exists (select 1 from public.setores s where s.id = p_setor and s.ativo) then
    raise exception 'Escolha um setor ativo de destino.';
  end if;
  if v_c.setor_id is not distinct from p_setor then
    raise exception 'A comum já pertence a este setor.';
  end if;
  if v_just is not null and char_length(v_just) > 300 then
    raise exception 'A justificativa pode ter no máximo 300 caracteres.';
  end if;
  if exists (select 1 from public.comuns x
              where x.setor_id = p_setor and x.id <> p_comum
                and public.normalizar_texto(x.nome) = public.normalizar_texto(v_c.nome)) then
    raise exception 'O setor de destino já tem uma comum com este nome.';
  end if;

  update public.comuns set setor_id = p_setor where id = p_comum;
  -- As portarias seguem a comum do evento: só o rótulo precisa ser atualizado
  update public.portarias p set cidade = public.rotulo_setor(p.comum_id)
   where p.comum_id = p_comum and p.excluido_em is null;

  insert into public.comuns_historico (comum_id, setor_anterior, setor_novo, usuario_id, justificativa)
  values (p_comum, v_c.setor_id, p_setor, (select auth.uid()), v_just);

  perform public.registrar_auditoria('comum_transferida', 'comum', p_comum,
            jsonb_build_object('setor_anterior', v_c.setor_id, 'setor_novo', p_setor, 'justificativa', v_just));
end;
$$;

-- Define os vínculos de um usuário (substitui a lista anterior). p_vinculos = [{"nivel":"SETOR","alvo_id":"..."}]
create or replace function public.definir_vinculos(p_usuario uuid, p_vinculos jsonb)
returns void language plpgsql security definer set search_path = public as $$
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
      when 'REGIAO' then exists (select 1 from public.regioes x where x.id = v_alvo)
      when 'SETOR'  then exists (select 1 from public.setores x where x.id = v_alvo)
      when 'COMUM'  then exists (select 1 from public.comuns x where x.id = v_alvo)
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

-- 11) PORTARIAS E PRESENÇAS: tudo passa a olhar a COMUM do evento (e não mais a cidade)
create or replace function public.pode_ver_portaria(p_id uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.portarias p
    where p.id = p_id and p.excluido_em is null
      and (
        p.criada_por = (select auth.uid())
        or public.tem_permissao('portarias.visualizar')
        or (public.tem_permissao('portarias.aprovar') and public.comum_na_abrangencia(p.comum_id))
        or (public.tem_permissao('portaria.registrar') and p.status = 'APROVADA'
            and public.comum_na_abrangencia(p.comum_id))
      )
  )
$$;

create or replace function public.criar_portaria(p_evento_id uuid)
returns uuid language plpgsql security definer set search_path = public as $$
declare
  v_uid    uuid := (select auth.uid());
  v_dia    date := (now() at time zone 'America/Sao_Paulo')::date;
  v_evento public.eventos;
  v_usadas int;
  v_total  boolean;
  v_setor  uuid;
  v_id     uuid;
begin
  perform public.exigir_permissao('portarias.criar');
  v_total := public.tem_permissao('portarias.controle_total');

  -- Serializa as criações do MESMO usuário no MESMO dia (a 2ª requisição espera e recota)
  perform pg_advisory_xact_lock(hashtextextended('portarias:' || v_uid::text || ':' || v_dia::text, 0));

  select count(*)::int into v_usadas
  from public.portarias p
  where p.criada_por = v_uid and p.dia_criacao = v_dia;   -- inclui rejeitadas e excluídas

  if not v_total and v_usadas >= public.limite_diario_portarias() then
    raise exception 'Você atingiu o limite máximo de % portarias criadas hoje. Novas criações estarão disponíveis no próximo dia.',
      public.limite_diario_portarias();
  end if;

  select * into v_evento from public.eventos e where e.id = p_evento_id and e.excluido_em is null;
  if not found then
    raise exception 'Evento não encontrado.';
  end if;
  if v_evento.comum_id is null then
    raise exception 'Escolha a comum do evento (Eventos > Editar) antes de criar a portaria.';
  end if;

  select c.setor_id into v_setor from public.comuns c where c.id = v_evento.comum_id;
  if v_setor is null then
    raise exception 'A comum deste evento ainda não tem setor. Peça a um administrador para vinculá-la a um setor (Administração > Organização).';
  end if;
  if not public.comum_na_abrangencia(v_evento.comum_id) then
    raise exception 'Este evento está fora da sua abrangência (comum de outro setor).' using errcode = '42501';
  end if;

  if exists (select 1 from public.portarias p
             where p.evento_id = p_evento_id and p.excluido_em is null
               and p.status in ('PENDENTE_APROVACAO', 'APROVADA')) then
    raise exception 'Já existe uma portaria pendente ou aprovada para este evento.';
  end if;

  insert into public.portarias (evento_id, comum_id, cidade, criada_por, dia_criacao)
  values (p_evento_id, v_evento.comum_id, public.rotulo_setor(v_evento.comum_id), v_uid, v_dia)
  returning id into v_id;

  insert into public.portarias_historico (portaria_id, acao, status_novo, usuario_id)
  values (v_id, 'CRIADA', 'PENDENTE_APROVACAO', v_uid);

  perform public.registrar_auditoria('portaria_criada', 'portaria', v_id,
            jsonb_build_object('evento_id', p_evento_id,
                               'acima_do_limite', v_usadas >= public.limite_diario_portarias()));
  return v_id;
end;
$$;

-- Aprovar/rejeitar: a própria portaria só com Controle total; fora do vínculo só com acesso total.
create or replace function public.decidir_portaria(p_id uuid, p_aprovar boolean, p_motivo text)
returns void language plpgsql security definer set search_path = public as $$
declare
  v_uid     uuid := (select auth.uid());
  v_p       public.portarias;
  v_motivo  text := nullif(btrim(coalesce(p_motivo, '')), '');
  v_novo    text;
  v_propria boolean;
  v_fora    boolean;
begin
  perform public.exigir_permissao('portarias.aprovar');

  select * into v_p from public.portarias p where p.id = p_id and p.excluido_em is null for update;
  if not found then
    raise exception 'Portaria não encontrada.';
  end if;
  if v_p.status <> 'PENDENTE_APROVACAO' then
    raise exception 'Esta portaria já foi decidida e não pode mais ser alterada.';
  end if;

  v_propria := v_p.criada_por = v_uid;
  v_fora    := not public.comum_na_minha_abrangencia(v_p.comum_id);

  if v_propria and not public.tem_permissao('portarias.controle_total') then
    raise exception 'Você não pode aprovar ou rejeitar uma portaria criada por você.' using errcode = '42501';
  end if;
  if v_fora and not public.tem_acesso_total_organizacao() then
    raise exception 'Esta portaria está fora da sua abrangência de atuação (setor).' using errcode = '42501';
  end if;

  if not p_aprovar and (v_motivo is null or char_length(v_motivo) < 5) then
    raise exception 'Informe o motivo da rejeição (mínimo de 5 caracteres).';
  end if;
  if v_motivo is not null and char_length(v_motivo) > 300 then
    raise exception 'O motivo pode ter no máximo 300 caracteres.';
  end if;

  v_novo := case when p_aprovar then 'APROVADA' else 'REJEITADA' end;

  update public.portarias
     set status = v_novo, decidida_por = v_uid, decidida_em = now(),
         motivo_rejeicao = case when p_aprovar then null else v_motivo end,
         decisao_controle_total = (v_propria or v_fora)
   where id = p_id;

  insert into public.portarias_historico (portaria_id, acao, status_anterior, status_novo, usuario_id, motivo)
  values (p_id, v_novo, v_p.status, v_novo, v_uid,
          case when v_propria or v_fora then concat_ws(' · ', 'Decisão por controle total', v_motivo) else v_motivo end);

  perform public.registrar_auditoria('portaria_' || lower(v_novo), 'portaria', p_id,
            jsonb_build_object('status_anterior', v_p.status, 'motivo', v_motivo,
                               'controle_total', (v_propria or v_fora)));
end;
$$;

-- Listagem: "cidade" agora traz "Região › Setor" (a tela continua usando o mesmo campo)
create or replace function public.listar_portarias()
returns table (
  id uuid, evento_id uuid, status text, cidade text,
  criada_em timestamptz, criada_por uuid, criador_nome text,
  decidida_em timestamptz, decisor_nome text, motivo_rejeicao text,
  evento_tipo text, evento_data timestamptz, evento_local text, evento_finalidade text,
  pode_decidir boolean, pode_excluir boolean
)
language plpgsql stable security definer set search_path = public as $$
declare
  v_uid    uuid := (select auth.uid());
  v_aprova boolean;
  v_exclui boolean;
  v_ctotal boolean;
begin
  perform public.exigir_alguma_permissao(array[
    'portarias.visualizar', 'portarias.criar', 'portarias.aprovar', 'portaria.registrar'
  ]);
  v_aprova := public.tem_permissao('portarias.aprovar');
  v_exclui := public.tem_permissao('portarias.excluir');
  v_ctotal := public.tem_permissao('portarias.controle_total');

  return query
    select p.id, p.evento_id, p.status, coalesce(public.rotulo_setor(p.comum_id), p.cidade),
           p.criada_em, p.criada_por, cr.nome,
           p.decidida_em, de.nome, p.motivo_rejeicao,
           ev.tipo, ev.data_evento, ev.local, fi.nome,
           (v_aprova and p.status = 'PENDENTE_APROVACAO'
              and (p.criada_por <> v_uid or v_ctotal)
              and public.comum_na_abrangencia(p.comum_id)),
           ((v_exclui or (p.criada_por = v_uid and p.status = 'PENDENTE_APROVACAO'))
              and not exists (select 1 from public.presencas pr
                              where pr.portaria_id = p.id and pr.excluido_em is null))
    from public.portarias p
    left join public.usuarios cr on cr.id = p.criada_por
    left join public.usuarios de on de.id = p.decidida_por
    left join public.eventos ev on ev.id = p.evento_id
    left join public.finalidades_evento fi on fi.id = ev.finalidade_id
    where public.pode_ver_portaria(p.id)
    order by p.criada_em desc;
end;
$$;

create or replace function public.exigir_acesso_atendimento(p_portaria_id uuid)
returns void language plpgsql security definer set search_path = public as $$
declare
  v_p public.portarias;
begin
  perform public.exigir_permissao('portaria.registrar');
  select * into v_p from public.portarias p where p.id = p_portaria_id and p.excluido_em is null;
  if not found or v_p.status <> 'APROVADA' or not public.comum_na_abrangencia(v_p.comum_id) then
    raise exception 'Portaria indisponível para você.' using errcode = '42501';
  end if;
end;
$$;

create or replace function public.validar_registro_presenca(
  p_portaria_id uuid, p_evento_id uuid, p_membro_id uuid
)
returns void language plpgsql security definer set search_path = public as $$
declare
  v_p         public.portarias;
  v_m         record;
  v_existente record;
begin
  perform public.exigir_permissao('portaria.registrar');

  select * into v_p from public.portarias p where p.id = p_portaria_id and p.excluido_em is null;
  if not found then
    raise exception 'Portaria não encontrada.';
  end if;
  if v_p.status <> 'APROVADA' then
    raise exception 'Esta portaria não está aprovada (situação: %). Só portarias aprovadas registram presenças.',
      case v_p.status when 'PENDENTE_APROVACAO' then 'pendente de aprovação'
                      when 'REJEITADA' then 'rejeitada' else v_p.status end;
  end if;
  if v_p.evento_id <> p_evento_id then
    raise exception 'A portaria não corresponde ao evento informado.';
  end if;
  if not public.comum_na_abrangencia(v_p.comum_id) then
    raise exception 'Você não tem acesso a esta portaria (fora da sua abrangência).' using errcode = '42501';
  end if;

  select m.status, m.excluido_em into v_m from public.membros m where m.id = p_membro_id;
  if not found then
    raise exception 'Cadastro do membro não encontrado.';
  end if;
  if v_m.excluido_em is not null then
    raise exception 'Cadastro do membro não encontrado.';
  end if;
  if v_m.status <> 'Ativo' then
    raise exception 'O cadastro do membro está inativo.';
  end if;

  -- Duplicidade por EVENTO (inclui registros antigos, sem portaria)
  select pr.hora_entrada, pr.status, pr.portaria_id into v_existente
  from public.presencas pr
  where pr.membro_id = p_membro_id
    and pr.evento_id = p_evento_id
    and pr.excluido_em is null
    and (pr.hora_saida is null or pr.portaria_id = p_portaria_id)
  order by pr.hora_entrada
  limit 1;
  if found then
    raise exception 'Este músico já possui uma entrada registrada neste evento às % (situação: %)%.',
      to_char(v_existente.hora_entrada at time zone 'America/Sao_Paulo', 'HH24"h"MI'),
      v_existente.status,
      case when v_existente.portaria_id is null then ', registro antigo feito antes das portarias' else '' end;
  end if;
end;
$$;

-- 12) ATENDIMENTO E FOTOGRAFIAS: o membro só é encontrado dentro da abrangência de quem atende
create or replace function public.cartao_membro(p_portaria_id uuid, p_membro_id uuid)
returns table (
  membro_id uuid, nome text, congregacao text, cargo text, instrumento text,
  cidade text, bairro text, status text, foto_path text, ja_registrado_em timestamptz
)
language sql stable security definer set search_path = public as $$
  select m.id, m.nome, m.congregacao, c.nome, i.nome, m.cidade, m.bairro, m.status, m.foto_path,
         (select min(pr.hora_entrada)
            from public.presencas pr
            join public.portarias po on po.id = p_portaria_id
           where pr.membro_id = m.id
             and pr.excluido_em is null
             and (pr.portaria_id = po.id or pr.evento_id = po.evento_id))
  from public.membros m
  left join public.cargos c on c.id = m.cargo_id
  left join public.instrumentos i on i.id = m.instrumento_id
  where m.id = p_membro_id and m.excluido_em is null
    and public.comum_na_abrangencia(m.comum_id)
$$;

create or replace function public.listar_membros_para_foto()
returns table (id uuid, nome text, congregacao text, foto_path text)
language plpgsql stable security definer set search_path = public as $$
begin
  perform public.exigir_permissao('membros.foto');
  return query
    select m.id, m.nome, m.congregacao, m.foto_path
    from public.membros m
    where m.excluido_em is null and public.comum_na_abrangencia(m.comum_id)
    order by m.nome;
end;
$$;

-- 13) ACESSO POR REGIÃO NAS TABELAS: políticas RESTRITIVAS (somam-se às regras de permissão que já existem:
--     o usuário precisa passar nas duas). Quem tem acesso total passa em todas.
drop policy if exists "regiao_membros" on public.membros;
create policy "regiao_membros" on public.membros
  as restrictive for all to authenticated
  using (public.comum_na_abrangencia(comum_id))
  with check (public.comum_na_abrangencia(comum_id));

drop policy if exists "regiao_eventos" on public.eventos;
create policy "regiao_eventos" on public.eventos
  as restrictive for all to authenticated
  using (public.comum_na_abrangencia(comum_id))
  with check (public.comum_na_abrangencia(comum_id));

drop policy if exists "regiao_presencas" on public.presencas;
create policy "regiao_presencas" on public.presencas
  as restrictive for all to authenticated
  using (public.evento_na_abrangencia(evento_id))
  with check (public.evento_na_abrangencia(evento_id));

-- 14) PERMISSÕES DE EXECUÇÃO
-- As funções usadas pelas políticas acima precisam ser executáveis por quem consulta as tabelas
-- (elas só respondem sim/não sobre a abrangência do próprio usuário)
revoke all on function public.comum_na_abrangencia(uuid), public.evento_na_abrangencia(uuid) from public, anon;
grant execute on function public.comum_na_abrangencia(uuid), public.evento_na_abrangencia(uuid) to authenticated;

revoke all on function
  public.comum_na_minha_abrangencia(uuid), public.tem_acesso_total_organizacao(),
  public.rotulo_setor(uuid), public.rotulo_vinculo(text, uuid),
  public.membros_sincroniza_comum(), public.comuns_propaga_nome(), public.eventos_valida_comum()
  from public, anon, authenticated;

revoke all on function
  public.listar_organizacao(), public.listar_organizacao_para_selecao(),
  public.listar_eventos_para_portaria(), public.listar_vinculos_rotulados(),
  public.salvar_organizacao(text, uuid, uuid, text, text, boolean, text, text),
  public.transferir_comum(uuid, uuid, text), public.definir_vinculos(uuid, jsonb)
  from public, anon;
grant execute on function
  public.listar_organizacao(), public.listar_organizacao_para_selecao(),
  public.listar_eventos_para_portaria(), public.listar_vinculos_rotulados(),
  public.salvar_organizacao(text, uuid, uuid, text, text, boolean, text, text),
  public.transferir_comum(uuid, uuid, text), public.definir_vinculos(uuid, jsonb)
  to authenticated;

-- 15) VERIFICAÇÃO DE SEGURANÇA: roda as consultas e as regras de acesso como Administrador.
--     Se alguma falhar, a migração INTEIRA é desfeita (nada fica alterado).
do $$
declare
  v_admin   uuid;
  v_dono_m  int;
  v_dono_e  int;
  v_dono_p  int;
  v_ve_m    int;
  v_ve_e    int;
  v_ve_p    int;
begin
  if (select count(*) from public.setores) < 10 then
    raise exception 'Verificação falhou: os setores iniciais não foram criados. Nada foi alterado.';
  end if;

  select u.id into v_admin
  from public.usuarios u join public.grupos g on g.id = u.grupo_id
  where g.sistema and g.nome = 'Administrador' and u.ativo
  limit 1;

  if v_admin is null then
    return;  -- ainda não há administrador: nada a verificar
  end if;

  perform set_config('request.jwt.claims', json_build_object('sub', v_admin, 'role', 'authenticated')::text, true);

  if not public.tem_acesso_total_organizacao() then
    raise exception 'Verificação falhou: o Administrador não recebeu o acesso total à organização. Nada foi alterado.';
  end if;

  perform count(*) from public.listar_organizacao();
  perform count(*) from public.listar_organizacao_para_selecao();
  perform count(*) from public.listar_eventos_para_portaria();
  perform count(*) from public.listar_portarias();
  perform count(*) from public.listar_vinculos_rotulados();
  perform public.minhas_cidades();

  -- O Administrador precisa continuar vendo TUDO nas tabelas, agora com as regras por região
  select count(*) into v_dono_m from public.membros where excluido_em is null;
  select count(*) into v_dono_e from public.eventos where excluido_em is null;
  select count(*) into v_dono_p from public.presencas where excluido_em is null;

  execute 'set local role authenticated';
  select count(*) into v_ve_m from public.membros;
  select count(*) into v_ve_e from public.eventos;
  select count(*) into v_ve_p from public.presencas;
  execute 'reset role';

  if v_ve_m <> v_dono_m or v_ve_e <> v_dono_e or v_ve_p <> v_dono_p then
    raise exception 'Verificação falhou: o Administrador deixaria de ver dados (membros %/%, eventos %/%, presenças %/%). Nada foi alterado.',
      v_ve_m, v_dono_m, v_ve_e, v_dono_e, v_ve_p, v_dono_p;
  end if;

  perform set_config('request.jwt.claims', '', true);
end $$;

commit;
