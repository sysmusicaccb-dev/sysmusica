-- =====================================================================
-- SysMúsica — Migração 0009: controle total de portarias
-- Nova permissão "portarias.controle_total". Quem a tem (o grupo Administrador, por padrão):
--   * aprova ou rejeita QUALQUER portaria, inclusive a que criou e a de outra cidade;
--   * cria portarias sem o limite diário de 4;
--   * vê e atende em todas as portarias, sem depender da cidade marcada no usuário.
-- Todo uso fica registrado: histórico da portaria ("Decisão por controle total"), coluna
-- decisao_controle_total e auditoria. Quem NÃO tem a permissão continua com todas as regras.
-- Requer a migração 0007. Idempotente, uma única transação.
-- =====================================================================
begin;

do $$
begin
  if to_regclass('public.portarias') is null then
    raise exception 'Aplique primeiro a migração 0007_portarias.sql.';
  end if;
end $$;

-- 1) PERMISSÃO (igual a CATALOGO_PERMISSOES em src/lib/permissoes.ts); o Administrador recebe
insert into public.permissoes (codigo, modulo, acao, descricao) values
  ('portarias.controle_total', 'Gestão de portarias', 'Controle total',
   'Aprovar e atender em qualquer portaria (inclusive as que criou), sem limite diário e sem restrição de abrangência. Todo uso é registrado.')
on conflict (codigo) do update
  set modulo = excluded.modulo, acao = excluded.acao, descricao = excluded.descricao;

insert into public.grupo_permissoes (grupo_id, permissao_codigo)
select g.id, p.codigo
from public.grupos g cross join public.permissoes p
where g.sistema and g.nome = 'Administrador'
on conflict do nothing;

-- 2) MARCA DA DECISÃO: a regra "ninguém decide a própria portaria" passa a admitir a exceção do controle total
alter table public.portarias add column if not exists decisao_controle_total boolean not null default false;

alter table public.portarias drop constraint if exists portarias_decisor_diferente;
alter table public.portarias add constraint portarias_decisor_diferente
  check (decidida_por is distinct from criada_por or decisao_controle_total);

-- 3) ABRANGÊNCIA: a regra antiga (só as cidades do usuário) vira "cidade_na_minha_abrangencia";
--    "cidade_na_abrangencia" (usada por todo o resto) passa a liberar tudo para o controle total.
create or replace function public.cidade_na_minha_abrangencia(p_cidade text)
returns boolean language sql stable security definer set search_path = public as $$
  select p_cidade is not null and exists (
    select 1 from public.usuario_cidades uc
    where uc.usuario_id = (select auth.uid())
      and public.normalizar_texto(uc.cidade) = public.normalizar_texto(p_cidade)
  )
$$;

create or replace function public.cidade_na_abrangencia(p_cidade text)
returns boolean language sql stable security definer set search_path = public as $$
  select public.tem_permissao('portarias.controle_total') or public.cidade_na_minha_abrangencia(p_cidade)
$$;

-- 4) CRIAR PORTARIA: o controle total não tem o limite diário (a contagem continua sendo feita)
create or replace function public.criar_portaria(p_evento_id uuid)
returns uuid language plpgsql security definer set search_path = public as $$
declare
  v_uid    uuid := (select auth.uid());
  v_dia    date := (now() at time zone 'America/Sao_Paulo')::date;
  v_evento public.eventos;
  v_usadas int;
  v_total  boolean;
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
            jsonb_build_object('evento_id', p_evento_id,
                               'acima_do_limite', v_usadas >= public.limite_diario_portarias()));
  return v_id;
end;
$$;

-- Cota do dia: o controle total aparece como "sem limite" (muda o formato da resposta, por isso recria a função)
drop function if exists public.minha_cota_portarias();
create function public.minha_cota_portarias()
returns table (usadas int, limite int, restantes int, ilimitada boolean)
language plpgsql stable security definer set search_path = public as $$
declare
  v_usadas int;
  v_total  boolean;
begin
  perform public.exigir_permissao('portarias.criar');
  v_total := public.tem_permissao('portarias.controle_total');

  select count(*)::int into v_usadas
  from public.portarias p
  where p.criada_por = (select auth.uid())
    and p.dia_criacao = (now() at time zone 'America/Sao_Paulo')::date;

  return query select v_usadas, public.limite_diario_portarias(),
                      case when v_total then public.limite_diario_portarias()
                           else greatest(public.limite_diario_portarias() - v_usadas, 0) end,
                      v_total;
end;
$$;

-- 5) APROVAR / REJEITAR: o controle total decide qualquer portaria e deixa a marca no histórico
create or replace function public.decidir_portaria(p_id uuid, p_aprovar boolean, p_motivo text)
returns void language plpgsql security definer set search_path = public as $$
declare
  v_uid     uuid := (select auth.uid());
  v_p       public.portarias;
  v_motivo  text := nullif(btrim(coalesce(p_motivo, '')), '');
  v_novo    text;
  v_total   boolean;
  v_excecao boolean;
begin
  perform public.exigir_permissao('portarias.aprovar');
  v_total := public.tem_permissao('portarias.controle_total');

  select * into v_p from public.portarias p where p.id = p_id and p.excluido_em is null for update;
  if not found then
    raise exception 'Portaria não encontrada.';
  end if;
  if v_p.status <> 'PENDENTE_APROVACAO' then
    raise exception 'Esta portaria já foi decidida e não pode mais ser alterada.';
  end if;

  -- Exceção: portaria criada por quem decide ou fora da abrangência dele. Só o controle total pode.
  v_excecao := (v_p.criada_por = v_uid) or not public.cidade_na_minha_abrangencia(v_p.cidade);
  if v_excecao and not v_total then
    if v_p.criada_por = v_uid then
      raise exception 'Você não pode aprovar ou rejeitar uma portaria criada por você.' using errcode = '42501';
    end if;
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
         motivo_rejeicao = case when p_aprovar then null else v_motivo end,
         decisao_controle_total = (v_excecao and v_total)
   where id = p_id;

  insert into public.portarias_historico (portaria_id, acao, status_anterior, status_novo, usuario_id, motivo)
  values (p_id, v_novo, v_p.status, v_novo, v_uid,
          case when v_excecao then concat_ws(' · ', 'Decisão por controle total', v_motivo) else v_motivo end);

  perform public.registrar_auditoria('portaria_' || lower(v_novo), 'portaria', p_id,
            jsonb_build_object('status_anterior', v_p.status, 'motivo', v_motivo, 'controle_total', v_excecao));
end;
$$;

-- 6) LISTAGEM: o botão de aprovar aparece também na portaria própria para o controle total
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
  v_total  boolean;
begin
  perform public.exigir_alguma_permissao(array[
    'portarias.visualizar', 'portarias.criar', 'portarias.aprovar', 'portaria.registrar'
  ]);
  v_aprova := public.tem_permissao('portarias.aprovar');
  v_exclui := public.tem_permissao('portarias.excluir');
  v_total  := public.tem_permissao('portarias.controle_total');

  return query
    select p.id, p.evento_id, p.status, p.cidade,
           p.criada_em, p.criada_por, cr.nome,
           p.decidida_em, de.nome, p.motivo_rejeicao,
           ev.tipo, ev.data_evento, ev.local, fi.nome,
           (v_aprova and p.status = 'PENDENTE_APROVACAO'
              and (p.criada_por <> v_uid or v_total)
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

-- 7) PERMISSÕES DE EXECUÇÃO
revoke all on function public.cidade_na_minha_abrangencia(text) from public, anon, authenticated;
revoke all on function public.minha_cota_portarias() from public, anon;
grant execute on function public.minha_cota_portarias() to authenticated;

commit;
