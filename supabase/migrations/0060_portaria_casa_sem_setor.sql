-- 0060 — Portaria para casa de oração SEM setor (ligada direto à ADM).
-- Antes: criar_portaria recusava e listar_eventos_para_portaria devolvia cidade vazia (evento desabilitado na tela).
-- Agora: o setor é opcional, como na Organização. O rótulo da portaria passa a ser "RA › ADM" (ou "RA › ADM › Setor").
-- O resto das duas funções continua IGUAL ao de produção. Seguro rodar mais de uma vez.
-- Reverter: supabase/rollback/0060_reverter.sql

begin;

create or replace function public.listar_eventos_para_portaria()
 returns table(id uuid, tipo text, data_evento timestamp with time zone, local text, cidade text, casa_oracao_id uuid)
 language plpgsql
 stable security definer
 set search_path to 'public'
as $function$
begin
  perform public.exigir_permissao('portarias.criar');
  return query
    select e.id, e.tipo, e.data_evento, e.local,
           -- rótulo sempre preenchido (casa sem setor mostra "RA › ADM"); o nome da casa é o último recurso
           coalesce(public.rotulo_setor(e.casa_oracao_id), c.nome),
           e.casa_oracao_id
    from public.eventos e
    join public.casas_oracao c on c.id = e.casa_oracao_id
    where e.excluido_em is null
      and e.cancelado_em is null
      and e.encerrado_em is null
      and not public.portaria_encerrada(e.data_evento)
      and public.casa_oracao_na_abrangencia(e.casa_oracao_id)
    order by e.data_evento desc
    limit 300;
end;
$function$;

create or replace function public.criar_portaria(p_evento_id uuid)
 returns uuid
 language plpgsql
 security definer
 set search_path to 'public'
as $function$
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
  if v_evento.cancelado_em is not null then
    raise exception 'Este evento foi cancelado e não pode receber portaria.';
  end if;
  if public.portaria_encerrada(v_evento.data_evento) then
    raise exception 'Este evento já foi encerrado e não pode receber uma nova portaria.';
  end if;
  if v_evento.casa_oracao_id is null then
    raise exception 'Escolha a casa de oração do evento (Eventos > Editar) antes de criar a portaria.';
  end if;
  -- (removido: exigência de setor — a casa pode ficar ligada direto à ADM)
  if not public.casa_oracao_na_abrangencia(v_evento.casa_oracao_id) then
    raise exception 'Este evento está fora da sua abrangência (casa de oração de outro setor).' using errcode = '42501';
  end if;

  if exists (select 1 from public.portarias p
             where p.evento_id = p_evento_id and p.excluido_em is null
               and p.status in ('PENDENTE_APROVACAO', 'APROVADA')) then
    raise exception 'Já existe uma portaria pendente ou aprovada para este evento.';
  end if;

  insert into public.portarias (evento_id, casa_oracao_id, cidade, criada_por, dia_criacao)
  values (p_evento_id, v_evento.casa_oracao_id,
          coalesce(public.rotulo_setor(v_evento.casa_oracao_id),
                   (select c.nome from public.casas_oracao c where c.id = v_evento.casa_oracao_id)),
          v_uid, v_dia)
  returning id into v_id;

  insert into public.portarias_historico (portaria_id, acao, status_novo, usuario_id)
  values (v_id, 'CRIADA', 'PENDENTE_APROVACAO', v_uid);

  perform public.registrar_auditoria('portaria_criada', 'portaria', v_id,
            jsonb_build_object('evento_id', p_evento_id,
                               'acima_do_limite', v_usadas >= public.limite_diario_portarias()));
  return v_id;
end;
$function$;

do $$
begin
  if (select prosrc from pg_proc where oid = 'public.criar_portaria(uuid)'::regprocedure) like '%ainda não tem setor%'
     or (select prosrc from pg_proc where oid = 'public.listar_eventos_para_portaria()'::regprocedure) like '%c.setor_id is not null%' then
    raise exception 'Verificação falhou: as funções de portaria não foram atualizadas.';
  end if;
end $$;

commit;
