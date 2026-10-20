-- 0034 — Ciclo de vida dos eventos: cancelar (só Administrador), encerrado só leitura e histórico
-- O estado do evento (Agendado, Em andamento, Encerrado, Arquivado) é CALCULADO pela data: não precisa de coluna.
--   Em andamento = de 2h antes até 3h depois do início (mesma janela da portaria); Encerrado = depois disso;
--   Arquivado = 30 dias depois de encerrado (só muda onde aparece nas telas; os dados continuam no banco).
-- Cancelado = decisão do Administrador, com motivo, guardada na própria linha do evento.
set local check_function_bodies = off;

do $$
begin
  if to_regclass('public.eventos') is null or to_regclass('public.presencas_avulsas') is null
     or to_regprocedure('public.portaria_encerrada(timestamptz, timestamptz)') is null
     or to_regprocedure('public.exigir_permissao(text)') is null then
    raise exception 'Aplique primeiro as migrações até a 0033. Nada foi alterado.';
  end if;
end $$;

-- A) Colunas do cancelamento
alter table public.eventos add column if not exists cancelado_em timestamptz;
alter table public.eventos add column if not exists cancelado_por uuid;
alter table public.eventos add column if not exists motivo_cancelamento text;
-- Leitura liberada coluna por coluna, como nas demais tabelas (gravar só pela função cancelar_evento)
grant select (cancelado_em, cancelado_por, motivo_cancelamento) on public.eventos to authenticated;

-- B) Permissão (igual a CATALOGO_PERMISSOES em src/lib/permissoes.ts); só o Administrador recebe
insert into public.permissoes (codigo, modulo, acao, descricao) values
  ('eventos.cancelar', 'Eventos', 'Cancelar',
   'Cancelar eventos (com motivo) e corrigir eventos já encerrados. Só o Administrador.')
on conflict (codigo) do update
  set modulo = excluded.modulo, acao = excluded.acao, descricao = excluded.descricao;

insert into public.grupo_permissoes (grupo_id, permissao_codigo)
select g.id, 'eventos.cancelar' from public.grupos g where g.sistema and g.nome = 'Administrador'
on conflict do nothing;

-- C) Cancelar evento: as portarias pendentes ou aprovadas dele deixam de valer (ficam como rejeitadas, no histórico)
create or replace function public.cancelar_evento(p_id uuid, p_motivo text)
returns void
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_uid    uuid := (select auth.uid());
  v_motivo text := nullif(btrim(coalesce(p_motivo, '')), '');
  v_e      public.eventos;
  r        record;
begin
  perform public.exigir_permissao('eventos.cancelar');
  if v_motivo is null or char_length(v_motivo) < 5 then
    raise exception 'Informe o motivo do cancelamento (mínimo de 5 caracteres).';
  end if;
  if char_length(v_motivo) > 250 then
    raise exception 'O motivo pode ter no máximo 250 caracteres.';
  end if;

  select * into v_e from public.eventos e where e.id = p_id and e.excluido_em is null for update;
  if not found then
    raise exception 'Evento não encontrado.';
  end if;
  if v_e.cancelado_em is not null then
    raise exception 'Este evento já está cancelado.';
  end if;

  update public.eventos
     set cancelado_em = now(), cancelado_por = v_uid, motivo_cancelamento = v_motivo
   where id = p_id;

  for r in select p.id, p.status from public.portarias p
            where p.evento_id = p_id and p.excluido_em is null and p.status in ('PENDENTE_APROVACAO', 'APROVADA') loop
    update public.portarias
       set status = 'REJEITADA', decidida_por = v_uid, decidida_em = now(),
           motivo_rejeicao = 'Evento cancelado: ' || v_motivo, decisao_controle_total = true
     where id = r.id;
    insert into public.portarias_historico (portaria_id, acao, status_anterior, status_novo, usuario_id, motivo)
    values (r.id, 'REJEITADA', r.status, 'REJEITADA', v_uid, 'Evento cancelado: ' || v_motivo);
  end loop;

  perform public.registrar_auditoria('evento_cancelado', 'evento', p_id, jsonb_build_object('motivo', v_motivo));
end;
$function$;

revoke all on function public.cancelar_evento(uuid, text) from public, anon;
grant execute on function public.cancelar_evento(uuid, text) to authenticated;

-- D) Excluir: só evento SEM presenças (com presenças, o Administrador cancela)
CREATE OR REPLACE FUNCTION public.excluir_evento(p_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  perform public.exigir_permissao('eventos.excluir');

  -- Evento com presenças é parte do histórico: não se exclui, só o Administrador cancela
  if exists (select 1 from public.presencas pr where pr.evento_id = p_id and pr.excluido_em is null)
     or exists (select 1 from public.presencas_avulsas a where a.evento_id = p_id and a.excluido_em is null) then
    raise exception 'Este evento já tem presenças registradas e não pode ser excluído. O Administrador pode cancelá-lo (o histórico fica guardado).';
  end if;

  update public.eventos set excluido_em = now() where id = p_id and excluido_em is null;
  if not found then
    raise exception 'Evento não encontrado.';
  end if;
end;
$function$;

-- E) Portaria: evento cancelado ou já encerrado não recebe portaria nova
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
      and not public.portaria_encerrada(e.data_evento)
      and public.casa_oracao_na_abrangencia(e.casa_oracao_id)
    order by e.data_evento desc
    limit 300;
end;
$function$;

CREATE OR REPLACE FUNCTION public.eventos_do_painel()
 RETURNS TABLE(id uuid, tipo text, local_evento text, data_evento timestamp with time zone, cidade text, casa_oracao_nome text)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  perform public.exigir_permissao('painel.visualizar');
  return query
    select e.id, e.tipo, e.local, e.data_evento, e.cidade, c.nome
      from public.eventos e
      left join public.casas_oracao c on c.id = e.casa_oracao_id
     where e.excluido_em is null
       and e.cancelado_em is null
       and public.evento_na_abrangencia(e.id)
       and e.data_evento between now() - interval '30 days' and now() + interval '30 days'
     order by abs(extract(epoch from (e.data_evento - now())))
     limit 40;
end;
$function$;

-- F) Evento encerrado fica só leitura: só o Administrador (permissão eventos.cancelar) altera
create or replace function public.eventos_bloquear_encerrado()
returns trigger
language plpgsql
set search_path to 'public'
as $function$
begin
  -- Restauração de backup e rotinas do sistema (sem usuário) não passam por esta regra
  if coalesce(current_setting('sysmusica.restaurando', true), '') <> '' or (select auth.uid()) is null then
    return new;
  end if;
  if tg_op = 'UPDATE' and public.portaria_encerrada(old.data_evento)
     and not public.tem_permissao('eventos.cancelar') then
    raise exception 'Este evento já foi encerrado. Só o Administrador pode alterá-lo.' using errcode = '42501';
  end if;
  return new;
end;
$function$;

drop trigger if exists trg_eventos_bloquear_encerrado on public.eventos;
create trigger trg_eventos_bloquear_encerrado before update on public.eventos
  for each row execute function public.eventos_bloquear_encerrado();

-- G) Conferência
do $$
begin
  if to_regprocedure('public.cancelar_evento(uuid, text)') is null
     or not exists (select 1 from public.permissoes where codigo = 'eventos.cancelar')
     or not exists (select 1 from pg_trigger where tgname = 'trg_eventos_bloquear_encerrado') then
    raise exception 'Teste falhou: objetos do ciclo de vida ausentes. Nada foi alterado.';
  end if;
  raise notice 'OK: ciclo de vida dos eventos instalado (cancelar, encerrado só leitura, excluir só sem presenças).';
end $$;
