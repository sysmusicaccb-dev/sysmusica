-- Desfaz o 0077: volta o relógio fixo de 3 h, o encerrar_evento antigo (portarias.aprovar) e remove a configuração,
-- as permissões novas e o grupo Instrutor.
create or replace function public.portaria_encerrada(p_data timestamp with time zone, p_agora timestamp with time zone default now())
 returns boolean language sql immutable set search_path to 'public'
as $f$
  select p_data is not null and p_agora > p_data + interval '3 hours'
$f$;
create or replace function public.portaria_janela_aberta(p_data timestamp with time zone, p_agora timestamp with time zone default now())
 returns boolean language sql immutable set search_path to 'public'
as $f$
  select p_data is not null
     and p_agora >= p_data - interval '2 hours'
     and p_agora <= p_data + interval '3 hours'
$f$;

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

drop function if exists public.obter_config_eventos();
drop function if exists public.salvar_config_eventos(boolean, int);
drop function if exists public.modelos_dos_tipos_evento();
drop table if exists public.config_eventos;
delete from public.grupo_permissoes where permissao_codigo in ('eventos.encerrar_qualquer', 'eventos.encerrar_regional', 'eventos.encerrar_local', 'eventos.configurar');
delete from public.usuario_grupos where grupo_id in (select id from public.grupos where nome = 'Instrutor');
delete from public.grupos where nome = 'Instrutor';
delete from public.permissoes where codigo in ('eventos.encerrar_qualquer', 'eventos.encerrar_regional', 'eventos.encerrar_local', 'eventos.configurar');
