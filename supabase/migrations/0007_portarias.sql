-- =====================================================================
-- SysMúsica — Migração 0007: fluxo de criação e aprovação de portarias
--   * Portaria nasce PENDENTE_APROVACAO; só APROVADA registra presenças; rejeitar exige motivo;
--     ninguém aprova a própria portaria.
--   * Cota: 4 portarias CRIADAS por usuário por dia (dia local America/Sao_Paulo); rejeitar ou
--     excluir não devolve; criações simultâneas são serializadas (pg_advisory_xact_lock).
--   * Abrangência PROVISÓRIA por cidade (aguarda definição administrativa): aprovar e registrar
--     presença só nas cidades marcadas para o usuário. Nenhum cargo (nem Administrador) vê "tudo".
--   * Presenças exigem portaria aprovada, validado por gatilho (vale para qualquer caminho).
-- Idempotente, uma única transação. Aplique depois do 0006.
-- =====================================================================
begin;

-- 1) PERMISSÕES (iguais a CATALOGO_PERMISSOES em src/lib/permissoes.ts); só o Administrador recebe
insert into public.permissoes (codigo, modulo, acao, descricao) values
  ('portarias.visualizar', 'Gestão de portarias', 'Visualizar', 'Ver todas as portarias (de qualquer criador)'),
  ('portarias.criar',      'Gestão de portarias', 'Criar',      'Criar portarias (até 4 por dia) para eventos existentes'),
  ('portarias.aprovar',    'Gestão de portarias', 'Aprovar',    'Aprovar ou rejeitar portarias da própria abrangência (nunca as que criou)'),
  ('portarias.excluir',    'Gestão de portarias', 'Excluir',    'Excluir portarias sem presenças (a cota diária não é devolvida)')
on conflict (codigo) do update
  set modulo = excluded.modulo, acao = excluded.acao, descricao = excluded.descricao;

insert into public.grupo_permissoes (grupo_id, permissao_codigo)
select g.id, p.codigo
from public.grupos g cross join public.permissoes p
where g.sistema and g.nome = 'Administrador'
on conflict do nothing;

-- Limite diário (único lugar onde o número existe)
create or replace function public.limite_diario_portarias()
returns int language sql immutable as $$ select 4 $$;

-- 2) EVENTOS: cidade + leitura também para quem cria/aprova portarias
alter table public.eventos add column if not exists cidade text;

revoke update on public.eventos from authenticated;
grant update (tipo, data_evento, local, finalidade_id, cidade) on public.eventos to authenticated;

drop policy if exists "eventos_select" on public.eventos;
create policy "eventos_select" on public.eventos
  for select to authenticated
  using (
    excluido_em is null
    and public.tem_alguma_permissao(array[
      'eventos.visualizar', 'portaria.visualizar', 'portaria.registrar', 'dashboard.visualizar',
      'portarias.visualizar', 'portarias.criar', 'portarias.aprovar'
    ])
  );

-- 3) ABRANGÊNCIA POR CIDADE (tabela só acessada pelas funções abaixo)
create table if not exists public.usuario_cidades (
  usuario_id uuid not null references public.usuarios (id) on delete cascade,
  cidade     text not null,
  primary key (usuario_id, cidade)
);
alter table public.usuario_cidades enable row level security;
revoke all on public.usuario_cidades from anon, authenticated;

-- A cidade está na abrangência de quem está logado? (ignora acento e maiúsculas)
create or replace function public.cidade_na_abrangencia(p_cidade text)
returns boolean language sql stable security definer set search_path = public as $$
  select p_cidade is not null and exists (
    select 1 from public.usuario_cidades uc
    where uc.usuario_id = (select auth.uid())
      and public.normalizar_texto(uc.cidade) = public.normalizar_texto(p_cidade)
  )
$$;

create or replace function public.minhas_cidades()
returns text[] language sql stable security definer set search_path = public as $$
  select coalesce(array_agg(uc.cidade order by uc.cidade), '{}'::text[])
  from public.usuario_cidades uc
  where uc.usuario_id = (select auth.uid())
$$;

create or replace function public.listar_abrangencias()
returns table (usuario_id uuid, cidades text[])
language plpgsql stable security definer set search_path = public as $$
begin
  perform public.exigir_permissao('usuarios.visualizar');
  return query
    select uc.usuario_id, array_agg(uc.cidade order by uc.cidade)
    from public.usuario_cidades uc
    group by uc.usuario_id;
end;
$$;

-- Define as cidades de um usuário (substitui a lista anterior); exige usuarios.editar
create or replace function public.definir_abrangencia(p_usuario_id uuid, p_cidades text[])
returns void language plpgsql security definer set search_path = public as $$
declare
  v_cidade text;
  v_limpa  text;
  v_vistas text[] := '{}';
begin
  perform public.exigir_permissao('usuarios.editar');
  if not exists (select 1 from public.usuarios u where u.id = p_usuario_id) then
    raise exception 'Usuário não encontrado.';
  end if;

  delete from public.usuario_cidades uc where uc.usuario_id = p_usuario_id;

  foreach v_cidade in array coalesce(p_cidades, '{}'::text[]) loop
    v_limpa := btrim(regexp_replace(coalesce(v_cidade, ''), '\s+', ' ', 'g'));
    if v_limpa = '' then continue; end if;
    if char_length(v_limpa) > 80 then
      raise exception 'O nome da cidade pode ter no máximo 80 caracteres.';
    end if;
    -- ignora repetidas (sem acento e sem diferenciar maiúsculas)
    if public.normalizar_texto(v_limpa) = any (v_vistas) then continue; end if;
    v_vistas := v_vistas || public.normalizar_texto(v_limpa);
    insert into public.usuario_cidades (usuario_id, cidade) values (p_usuario_id, v_limpa);
  end loop;

  perform public.registrar_auditoria('abrangencia_definida', 'usuario', p_usuario_id,
            jsonb_build_object('cidades', to_jsonb(coalesce(p_cidades, '{}'::text[]))));
end;
$$;

-- Cidades já conhecidas (eventos, membros, abrangências), para sugerir na tela
create or replace function public.listar_cidades_conhecidas()
returns table (cidade text)
language plpgsql stable security definer set search_path = public as $$
begin
  perform public.exigir_permissao('usuarios.editar');
  return query
    select distinct on (public.normalizar_texto(t.nome)) t.nome
    from (
      select btrim(e.cidade) as nome from public.eventos e where e.cidade is not null and e.excluido_em is null
      union all
      select btrim(m.cidade) from public.membros m where m.cidade is not null and m.excluido_em is null
      union all
      select uc.cidade from public.usuario_cidades uc
    ) t
    where t.nome <> ''
    order by public.normalizar_texto(t.nome), t.nome;
end;
$$;

-- 4) PORTARIAS
create table if not exists public.portarias (
  id              uuid        primary key default gen_random_uuid(),
  evento_id       uuid        not null references public.eventos (id),
  cidade          text        not null,   -- cidade do evento na criação (define a abrangência)
  status          text        not null default 'PENDENTE_APROVACAO'
                    check (status in ('PENDENTE_APROVACAO', 'APROVADA', 'REJEITADA')),
  criada_por      uuid        not null references public.usuarios (id),
  criada_em       timestamptz not null default now(),
  dia_criacao     date        not null default ((now() at time zone 'America/Sao_Paulo')::date),
  decidida_por    uuid        references public.usuarios (id),
  decidida_em     timestamptz,
  motivo_rejeicao text,
  excluido_em     timestamptz,
  constraint portarias_decisao_coerente check (
    (status = 'PENDENTE_APROVACAO' and decidida_por is null and decidida_em is null)
    or (status <> 'PENDENTE_APROVACAO' and decidida_por is not null and decidida_em is not null)
  ),
  constraint portarias_rejeicao_com_motivo check (
    status <> 'REJEITADA' or char_length(coalesce(motivo_rejeicao, '')) >= 5
  ),
  -- Ninguém decide a própria portaria (barreira final, no banco)
  constraint portarias_decisor_diferente check (decidida_por is distinct from criada_por)
);

-- Uma portaria ativa (pendente ou aprovada) por evento
create unique index if not exists portarias_evento_ativa_unica
  on public.portarias (evento_id)
  where status in ('PENDENTE_APROVACAO', 'APROVADA') and excluido_em is null;

-- Cota diária: conta TODAS as criadas, inclusive rejeitadas e excluídas
create index if not exists idx_portarias_cota on public.portarias (criada_por, dia_criacao);

alter table public.portarias enable row level security;
revoke all on public.portarias from anon, authenticated;

-- Histórico de cada portaria (só acréscimo)
create table if not exists public.portarias_historico (
  id              uuid        primary key default gen_random_uuid(),
  portaria_id     uuid        not null references public.portarias (id),
  acao            text        not null check (acao in ('CRIADA', 'APROVADA', 'REJEITADA', 'EXCLUIDA')),
  status_anterior text,
  status_novo     text,
  usuario_id      uuid,
  ocorrido_em     timestamptz not null default now(),
  motivo          text
);
create index if not exists idx_portarias_historico on public.portarias_historico (portaria_id, ocorrido_em);
alter table public.portarias_historico enable row level security;
revoke all on public.portarias_historico from anon, authenticated;

drop trigger if exists trg_portarias_historico_somente_acrescimo on public.portarias_historico;
create trigger trg_portarias_historico_somente_acrescimo
  before update or delete on public.portarias_historico
  for each row execute function public.auditoria_somente_acrescimo();

-- Quem vê uma portaria: o criador, quem tem portarias.visualizar, o aprovador da cidade
-- e o atendente da cidade (somente se APROVADA)
create or replace function public.pode_ver_portaria(p_id uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.portarias p
    where p.id = p_id and p.excluido_em is null
      and (
        p.criada_por = (select auth.uid())
        or public.tem_permissao('portarias.visualizar')
        or (public.tem_permissao('portarias.aprovar') and public.cidade_na_abrangencia(p.cidade))
        or (public.tem_permissao('portaria.registrar') and p.status = 'APROVADA'
            and public.cidade_na_abrangencia(p.cidade))
      )
  )
$$;

-- 5) CRIAR PORTARIA (portarias.criar + cota diária)
create or replace function public.criar_portaria(p_evento_id uuid)
returns uuid language plpgsql security definer set search_path = public as $$
declare
  v_uid    uuid := (select auth.uid());
  v_dia    date := (now() at time zone 'America/Sao_Paulo')::date;
  v_evento public.eventos;
  v_usadas int;
  v_id     uuid;
begin
  perform public.exigir_permissao('portarias.criar');

  -- Serializa as criações do MESMO usuário no MESMO dia (a 2ª requisição espera e recota)
  perform pg_advisory_xact_lock(hashtextextended('portarias:' || v_uid::text || ':' || v_dia::text, 0));

  select count(*)::int into v_usadas
  from public.portarias p
  where p.criada_por = v_uid and p.dia_criacao = v_dia;   -- inclui rejeitadas e excluídas

  if v_usadas >= public.limite_diario_portarias() then
    raise exception 'Você atingiu o limite máximo de % portarias criadas hoje. Novas criações estarão disponíveis no próximo dia.',
      public.limite_diario_portarias();
  end if;

  select * into v_evento from public.eventos e where e.id = p_evento_id and e.excluido_em is null;
  if not found then
    raise exception 'Evento não encontrado.';
  end if;
  if nullif(btrim(coalesce(v_evento.cidade, '')), '') is null then
    raise exception 'Informe a cidade do evento (Eventos > Editar) antes de criar a portaria.';
  end if;
  if exists (select 1 from public.portarias p
             where p.evento_id = p_evento_id and p.excluido_em is null
               and p.status in ('PENDENTE_APROVACAO', 'APROVADA')) then
    raise exception 'Já existe uma portaria pendente ou aprovada para este evento.';
  end if;

  insert into public.portarias (evento_id, cidade, criada_por, dia_criacao)
  values (p_evento_id, btrim(v_evento.cidade), v_uid, v_dia)
  returning id into v_id;

  insert into public.portarias_historico (portaria_id, acao, status_novo, usuario_id)
  values (v_id, 'CRIADA', 'PENDENTE_APROVACAO', v_uid);

  perform public.registrar_auditoria('portaria_criada', 'portaria', v_id,
            jsonb_build_object('evento_id', p_evento_id));
  return v_id;
end;
$$;

create or replace function public.minha_cota_portarias()
returns table (usadas int, limite int, restantes int)
language plpgsql stable security definer set search_path = public as $$
declare
  v_usadas int;
begin
  perform public.exigir_permissao('portarias.criar');
  select count(*)::int into v_usadas
  from public.portarias p
  where p.criada_por = (select auth.uid())
    and p.dia_criacao = (now() at time zone 'America/Sao_Paulo')::date;
  return query select v_usadas, public.limite_diario_portarias(),
                      greatest(public.limite_diario_portarias() - v_usadas, 0);
end;
$$;

-- 6) APROVAR / REJEITAR (portarias.aprovar + abrangência + nunca a própria)
create or replace function public.decidir_portaria(p_id uuid, p_aprovar boolean, p_motivo text)
returns void language plpgsql security definer set search_path = public as $$
declare
  v_uid    uuid := (select auth.uid());
  v_p      public.portarias;
  v_motivo text := nullif(btrim(coalesce(p_motivo, '')), '');
  v_novo   text;
begin
  perform public.exigir_permissao('portarias.aprovar');

  select * into v_p from public.portarias p where p.id = p_id and p.excluido_em is null for update;
  if not found then
    raise exception 'Portaria não encontrada.';
  end if;
  if v_p.status <> 'PENDENTE_APROVACAO' then
    raise exception 'Esta portaria já foi decidida e não pode mais ser alterada.';
  end if;
  if v_p.criada_por = v_uid then
    raise exception 'Você não pode aprovar ou rejeitar uma portaria criada por você.' using errcode = '42501';
  end if;
  if not public.cidade_na_abrangencia(v_p.cidade) then
    raise exception 'Esta portaria está fora da sua abrangência de atuação.' using errcode = '42501';
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
         motivo_rejeicao = case when p_aprovar then null else v_motivo end
   where id = p_id;

  insert into public.portarias_historico (portaria_id, acao, status_anterior, status_novo, usuario_id, motivo)
  values (p_id, v_novo, v_p.status, v_novo, v_uid, v_motivo);

  perform public.registrar_auditoria('portaria_' || lower(v_novo), 'portaria', p_id,
            jsonb_build_object('status_anterior', v_p.status, 'motivo', v_motivo));
end;
$$;

-- 7) EXCLUIR PORTARIA (lógica; a cota NÃO é devolvida). Quem tem portarias.excluir exclui qualquer
--    portaria sem presenças; o criador exclui a própria enquanto pendente.
create or replace function public.excluir_portaria(p_id uuid)
returns void language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := (select auth.uid());
  v_p   public.portarias;
begin
  select * into v_p from public.portarias p where p.id = p_id and p.excluido_em is null for update;
  if not found then
    raise exception 'Portaria não encontrada.';
  end if;
  if not (public.tem_permissao('portarias.excluir')
          or (v_p.criada_por = v_uid and v_p.status = 'PENDENTE_APROVACAO')) then
    raise exception 'Você não tem permissão para excluir esta portaria.' using errcode = '42501';
  end if;
  if exists (select 1 from public.presencas pr where pr.portaria_id = p_id and pr.excluido_em is null) then
    raise exception 'Esta portaria já tem presenças registradas e não pode ser excluída.';
  end if;

  update public.portarias set excluido_em = now() where id = p_id;
  insert into public.portarias_historico (portaria_id, acao, status_anterior, status_novo, usuario_id)
  values (p_id, 'EXCLUIDA', v_p.status, v_p.status, v_uid);
  perform public.registrar_auditoria('portaria_excluida', 'portaria', p_id, '{}'::jsonb);
end;
$$;

-- 8) CONSULTAS DA TELA (já filtradas pela visibilidade; informam o que o usuário pode fazer)
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
begin
  perform public.exigir_alguma_permissao(array[
    'portarias.visualizar', 'portarias.criar', 'portarias.aprovar', 'portaria.registrar'
  ]);
  v_aprova := public.tem_permissao('portarias.aprovar');
  v_exclui := public.tem_permissao('portarias.excluir');

  return query
    select p.id, p.evento_id, p.status, p.cidade,
           p.criada_em, p.criada_por, cr.nome,
           p.decidida_em, de.nome, p.motivo_rejeicao,
           ev.tipo, ev.data_evento, ev.local, fi.nome,
           (v_aprova and p.status = 'PENDENTE_APROVACAO' and p.criada_por <> v_uid
              and public.cidade_na_abrangencia(p.cidade)),
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

create or replace function public.historico_portaria(p_id uuid)
returns table (acao text, status_anterior text, status_novo text,
               usuario_nome text, ocorrido_em timestamptz, motivo text)
language plpgsql stable security definer set search_path = public as $$
begin
  if not public.pode_ver_portaria(p_id) then
    raise exception 'Portaria não encontrada.';
  end if;
  return query
    select h.acao, h.status_anterior, h.status_novo, u.nome, h.ocorrido_em, h.motivo
    from public.portarias_historico h
    left join public.usuarios u on u.id = h.usuario_id
    where h.portaria_id = p_id
    order by h.ocorrido_em, h.id;
end;
$$;

-- 9) PRESENÇAS: só em portaria APROVADA, validado no banco
alter table public.presencas add column if not exists portaria_id    uuid references public.portarias (id);
alter table public.presencas add column if not exists registrado_por uuid;
alter table public.presencas
  add column if not exists origem text not null default 'MANUAL' check (origem in ('MANUAL', 'QR'));

create index if not exists idx_presencas_portaria_id on public.presencas (portaria_id);

-- Um registro por membro em cada portaria (presenças antigas, sem portaria, não são afetadas)
create unique index if not exists presencas_membro_portaria_unica
  on public.presencas (membro_id, portaria_id)
  where portaria_id is not null and excluido_em is null;

-- Todas as regras do registro de presença (lança erro com mensagem clara)
create or replace function public.validar_registro_presenca(
  p_portaria_id uuid, p_evento_id uuid, p_membro_id uuid
)
returns void language plpgsql security definer set search_path = public as $$
declare
  v_p         public.portarias;
  v_m         record;
  v_existente timestamptz;
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
  if not public.cidade_na_abrangencia(v_p.cidade) then
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

  select pr.hora_entrada into v_existente
  from public.presencas pr
  where pr.membro_id = p_membro_id and pr.portaria_id = p_portaria_id and pr.excluido_em is null
  limit 1;
  if found then
    raise exception 'Este músico já possui uma entrada registrada nesta portaria às %.',
      to_char(v_existente at time zone 'America/Sao_Paulo', 'HH24"h"MI');
  end if;
end;
$$;

-- Gatilho: toda presença nova de usuário logado passa pela validação. Quem registrou e a origem
-- são definidos aqui (o cliente não escolhe); a hora de entrada é a do servidor.
create or replace function public.presencas_antes_de_inserir()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if (select auth.uid()) is not null then
    if new.portaria_id is null then
      raise exception 'Selecione uma portaria aprovada para registrar a presença.';
    end if;
    perform public.validar_registro_presenca(new.portaria_id, new.evento_id, new.membro_id);
    new.registrado_por := (select auth.uid());
    new.origem := coalesce(nullif(current_setting('sysmusica.origem', true), ''), 'MANUAL');
  end if;
  return new;
end;
$$;

drop trigger if exists trg_presencas_antes_de_inserir on public.presencas;
create trigger trg_presencas_antes_de_inserir
  before insert on public.presencas
  for each row execute function public.presencas_antes_de_inserir();

-- O cliente só informa estas colunas ao criar uma presença
revoke insert on public.presencas from authenticated;
grant insert (membro_id, evento_id, status, portaria_id) on public.presencas to authenticated;

-- Registro de entrada (a leitura de QR Code usará origem 'QR'); as regras vêm do gatilho
create or replace function public.registrar_entrada(
  p_portaria_id uuid, p_membro_id uuid, p_origem text default 'MANUAL'
)
returns public.presencas language plpgsql security definer set search_path = public as $$
declare
  v_evento   uuid;
  v_presenca public.presencas;
begin
  if p_origem not in ('MANUAL', 'QR') then
    raise exception 'Origem de registro inválida.';
  end if;
  select p.evento_id into v_evento from public.portarias p where p.id = p_portaria_id and p.excluido_em is null;
  if not found then
    raise exception 'Portaria não encontrada.';
  end if;

  perform set_config('sysmusica.origem', p_origem, true);
  insert into public.presencas (membro_id, evento_id, status, portaria_id)
  values (p_membro_id, v_evento, 'Presente', p_portaria_id)
  returning * into v_presenca;
  return v_presenca;
end;
$$;

-- A função antiga (sem portaria) deixa de existir: ela contornaria a aprovação
drop function if exists public.registrar_presenca_qr(uuid, uuid);

-- 10) PERMISSÕES DE EXECUÇÃO: internas só o banco usa; as da tela, só usuários logados
revoke all on function
  public.limite_diario_portarias(), public.cidade_na_abrangencia(text), public.pode_ver_portaria(uuid),
  public.validar_registro_presenca(uuid, uuid, uuid), public.presencas_antes_de_inserir()
  from public, anon, authenticated;

revoke all on function
  public.minhas_cidades(), public.listar_abrangencias(), public.definir_abrangencia(uuid, text[]),
  public.listar_cidades_conhecidas(), public.criar_portaria(uuid), public.minha_cota_portarias(),
  public.decidir_portaria(uuid, boolean, text), public.excluir_portaria(uuid), public.listar_portarias(),
  public.historico_portaria(uuid), public.registrar_entrada(uuid, uuid, text)
  from public, anon;
grant execute on function
  public.minhas_cidades(), public.listar_abrangencias(), public.definir_abrangencia(uuid, text[]),
  public.listar_cidades_conhecidas(), public.criar_portaria(uuid), public.minha_cota_portarias(),
  public.decidir_portaria(uuid, boolean, text), public.excluir_portaria(uuid), public.listar_portarias(),
  public.historico_portaria(uuid), public.registrar_entrada(uuid, uuid, text)
  to authenticated;

commit;
