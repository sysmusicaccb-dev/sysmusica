-- Sysmusica — Migração 0051: Painel ao Vivo só com eventos EM ANDAMENTO + encerramento manual do evento.
--  * Em andamento = da abertura da Portaria (2h antes) até 3h depois do início, a mesma janela de sempre.
--    Passou disso, o evento encerra SOZINHO (sem ninguém precisar finalizar).
--  * Quem aprova portarias (permissão portarias.aprovar; o controle total também) pode ENCERRAR ANTES, à mão.
--    O evento encerrado à mão sai do Painel, deixa de receber entradas na Portaria e vai para Eventos > Encerrados.
--  * Só o Administrador (eventos.cancelar) pode REABRIR um evento encerrado à mão, enquanto o horário ainda vale.
-- Não apaga nada: só acrescenta colunas e funções e troca duas listas (eventos do Painel e eventos para portaria).

do $$
begin
  if to_regclass('public.eventos') is null or to_regprocedure('public.portaria_janela_aberta(timestamptz, timestamptz)') is null
     or to_regprocedure('public.evento_na_abrangencia(uuid)') is null or to_regclass('public.presencas_avulsas') is null then
    raise exception 'Aplique primeiro as migrações até a 0050. Nada foi alterado.';
  end if;
end $$;

-- A) Colunas do encerramento manual (leitura liberada coluna por coluna; gravar só pela função encerrar_evento)
alter table public.eventos add column if not exists encerrado_em timestamptz;
alter table public.eventos add column if not exists encerrado_por uuid;
grant select (encerrado_em, encerrado_por) on public.eventos to authenticated;

-- B) Encerrar evento (quem aprova portarias): só evento EM ANDAMENTO, dentro da abrangência de quem encerra
create or replace function public.encerrar_evento(p_id uuid)
returns void
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_uid uuid := (select auth.uid());
  v_e   public.eventos;
begin
  if not (public.tem_permissao('portarias.aprovar') or public.tem_permissao('portarias.controle_total')) then
    raise exception 'Você não tem permissão para encerrar eventos.' using errcode = '42501';
  end if;

  select * into v_e from public.eventos e where e.id = p_id and e.excluido_em is null for update;
  if not found then
    raise exception 'Evento não encontrado.';
  end if;
  if not public.evento_na_abrangencia(p_id) then
    raise exception 'Este evento está fora da sua abrangência.' using errcode = '42501';
  end if;
  if v_e.cancelado_em is not null then
    raise exception 'Este evento foi cancelado.';
  end if;
  if v_e.encerrado_em is not null then
    raise exception 'Este evento já foi encerrado.';
  end if;
  if not public.portaria_janela_aberta(v_e.data_evento) then
    raise exception 'Só é possível encerrar um evento que está em andamento.';
  end if;

  update public.eventos set encerrado_em = now(), encerrado_por = v_uid where id = p_id;
  perform public.registrar_auditoria('evento_encerrado', 'evento', p_id, '{}'::jsonb);
end;
$function$;

-- C) Reabrir evento encerrado à mão (só o Administrador) enquanto o horário do evento ainda vale
create or replace function public.reabrir_evento(p_id uuid)
returns void
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_e public.eventos;
begin
  perform public.exigir_permissao('eventos.cancelar');

  select * into v_e from public.eventos e where e.id = p_id and e.excluido_em is null for update;
  if not found then
    raise exception 'Evento não encontrado.';
  end if;
  if v_e.encerrado_em is null then
    raise exception 'Este evento não foi encerrado à mão.';
  end if;
  if not public.portaria_janela_aberta(v_e.data_evento) then
    raise exception 'O horário deste evento já passou: ele continua encerrado.';
  end if;

  update public.eventos set encerrado_em = null, encerrado_por = null where id = p_id;
  perform public.registrar_auditoria('evento_reaberto', 'evento', p_id, '{}'::jsonb);
end;
$function$;

revoke all on function public.encerrar_evento(uuid), public.reabrir_evento(uuid) from public, anon;
grant execute on function public.encerrar_evento(uuid), public.reabrir_evento(uuid) to authenticated;

-- D) Evento encerrado à mão não recebe mais entradas (presença de membro nem avulsa/visitante).
--    Restauração de backup e rotinas do sistema (sem usuário) não passam por esta regra.
create or replace function public.presenca_bloquear_evento_encerrado()
returns trigger
language plpgsql
set search_path to 'public'
as $function$
begin
  if coalesce(current_setting('sysmusica.restaurando', true), '') <> '' or (select auth.uid()) is null then
    return new;
  end if;
  if exists (select 1 from public.eventos e where e.id = new.evento_id and e.encerrado_em is not null) then
    raise exception 'Este evento foi encerrado e não recebe mais entradas.';
  end if;
  return new;
end;
$function$;

drop trigger if exists trg_presencas_evento_encerrado on public.presencas;
create trigger trg_presencas_evento_encerrado before insert on public.presencas
  for each row execute function public.presenca_bloquear_evento_encerrado();

drop trigger if exists trg_presencas_avulsas_evento_encerrado on public.presencas_avulsas;
create trigger trg_presencas_avulsas_evento_encerrado before insert on public.presencas_avulsas
  for each row execute function public.presenca_bloquear_evento_encerrado();

-- E) Painel ao Vivo: só eventos EM ANDAMENTO (dentro da janela da Portaria, não cancelados, não encerrados à mão)
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
       and e.encerrado_em is null
       and public.portaria_janela_aberta(e.data_evento)
       and public.evento_na_abrangencia(e.id)
     order by abs(extract(epoch from (e.data_evento - now())))
     limit 40;
end;
$function$;

-- F) Eventos para criar portaria: evento encerrado à mão também sai da lista (o resto é igual à 0034)
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

-- G) Verificação: se algo estiver faltando, a migração inteira é desfeita.
do $$
begin
  if to_regprocedure('public.encerrar_evento(uuid)') is null or to_regprocedure('public.reabrir_evento(uuid)') is null then
    raise exception 'Verificação falhou: funções de encerramento ausentes.';
  end if;
  if not exists (select 1 from information_schema.columns
                  where table_schema = 'public' and table_name = 'eventos' and column_name = 'encerrado_em') then
    raise exception 'Verificação falhou: coluna encerrado_em ausente.';
  end if;
  if (select count(*) from pg_trigger
       where tgname in ('trg_presencas_evento_encerrado', 'trg_presencas_avulsas_evento_encerrado') and not tgisinternal) <> 2 then
    raise exception 'Verificação falhou: gatilhos das entradas ausentes.';
  end if;
  if (select prosrc from pg_proc where oid = 'public.eventos_do_painel()'::regprocedure) not like '%portaria_janela_aberta%'
     or (select prosrc from pg_proc where oid = 'public.listar_eventos_para_portaria()'::regprocedure) not like '%encerrado_em%' then
    raise exception 'Verificação falhou: as listas não foram atualizadas.';
  end if;
end $$;
