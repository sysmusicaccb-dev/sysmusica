-- Reverte a 0060: volta ao comportamento anterior (casa sem setor não pode receber portaria).
begin;
CREATE OR REPLACE FUNCTION public.listar_eventos_para_portaria()
 RETURNS TABLE(id uuid, tipo text, data_evento timestamp with time zone, local text, cidade text, casa_oracao_id uuid)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  perform public.exigir_permissao('portarias.criar');
  return query
    select e.id, e.tipo, e.data_evento, e.local,
           case when c.setor_id is not null then public.rotulo_setor(e.casa_oracao_id) end,
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

CREATE OR REPLACE FUNCTION public.criar_portaria(p_evento_id uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
  if v_evento.cancelado_em is not null then
    raise exception 'Este evento foi cancelado e não pode receber portaria.';
  end if;
  if public.portaria_encerrada(v_evento.data_evento) then
    raise exception 'Este evento já foi encerrado e não pode receber uma nova portaria.';
  end if;
  if v_evento.casa_oracao_id is null then
    raise exception 'Escolha a casa de oração do evento (Eventos > Editar) antes de criar a portaria.';
  end if;

  select c.setor_id into v_setor from public.casas_oracao c where c.id = v_evento.casa_oracao_id;
  if v_setor is null then
    raise exception 'A casa de oração deste evento ainda não tem setor. Peça a um administrador para vinculá-la a um setor (Administração > Organização).';
  end if;
  if not public.casa_oracao_na_abrangencia(v_evento.casa_oracao_id) then
    raise exception 'Este evento está fora da sua abrangência (casa de oração de outro setor).' using errcode = '42501';
  end if;

  if exists (select 1 from public.portarias p
             where p.evento_id = p_evento_id and p.excluido_em is null
               and p.status in ('PENDENTE_APROVACAO', 'APROVADA')) then
    raise exception 'Já existe uma portaria pendente ou aprovada para este evento.';
  end if;

  insert into public.portarias (evento_id, casa_oracao_id, cidade, criada_por, dia_criacao)
  values (p_evento_id, v_evento.casa_oracao_id, public.rotulo_setor(v_evento.casa_oracao_id), v_uid, v_dia)
  returning id into v_id;

  insert into public.portarias_historico (portaria_id, acao, status_novo, usuario_id)
  values (v_id, 'CRIADA', 'PENDENTE_APROVACAO', v_uid);

  perform public.registrar_auditoria('portaria_criada', 'portaria', v_id,
            jsonb_build_object('evento_id', p_evento_id,
                               'acima_do_limite', v_usadas >= public.limite_diario_portarias()));
  return v_id;
end;
$function$;
commit;
