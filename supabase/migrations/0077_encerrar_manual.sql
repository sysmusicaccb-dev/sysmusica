-- ============================================================================
-- Sysmusica — 0077: ENCERRAMENTO MANUAL DO EVENTO (e da portaria) + configuração de "encerrar sozinho"
--  1) Quem encerra, por tipo de evento (novas permissões):
--       eventos.encerrar_qualquer  -> Administrador e Administrador Regional (qualquer evento)
--       eventos.encerrar_regional  -> Secretário da Música (Ensaio Regional e tipos sem "Local")
--       eventos.encerrar_local     -> grupo novo "Instrutor" (Ensaio Local e Ensaios Técnicos)
--       eventos.configurar         -> Administrador (tela Eventos > Configurações)
--     Antes, quem tinha "portarias.aprovar" encerrava; agora só quem tem as permissões acima.
--  2) Configuração global: encerrar sozinho (sim/não) e quantas horas depois do INÍCIO do evento. Padrão: sim, 24 h.
--     As funções portaria_janela_aberta / portaria_encerrada (usadas em todo o sistema) passam a ler essa configuração.
--  3) Encerrar o evento encerra a portaria: o banco já bloqueia novas entradas; a tela tira a portaria da lista.
-- Seguro rodar mais de uma vez. Para desfazer: 0077_reverter.sql
-- ============================================================================

do $$
begin
  if to_regclass('public.tipos_evento') is null or to_regprocedure('public.encerrar_evento(uuid)') is null
     or to_regprocedure('public.portaria_janela_aberta(timestamptz, timestamptz)') is null then
    raise exception 'Faltam objetos das migrações anteriores. Nada foi alterado.';
  end if;
end $$;

-- 1) Configuração global --------------------------------------------------------------------------------
create table if not exists public.config_eventos (
  id                 int primary key default 1 check (id = 1),   -- sempre uma linha só
  encerra_sozinho    boolean not null default true,
  horas_apos_inicio  int not null default 24 check (horas_apos_inicio between 1 and 720),
  atualizado_em      timestamptz not null default now(),
  atualizado_por     uuid
);
insert into public.config_eventos (id) values (1) on conflict (id) do nothing;
alter table public.config_eventos enable row level security;
revoke all on public.config_eventos from anon, authenticated;   -- só as funções abaixo mexem

create or replace function public.obter_config_eventos()
returns table(encerra_sozinho boolean, horas_apos_inicio int)
language sql stable security definer set search_path = public
as $f$
  select c.encerra_sozinho, c.horas_apos_inicio from public.config_eventos c where c.id = 1
$f$;

create or replace function public.salvar_config_eventos(p_encerra_sozinho boolean, p_horas int)
returns void
language plpgsql security definer set search_path = public
as $f$
begin
  perform public.exigir_permissao('eventos.configurar');
  if p_encerra_sozinho is null then raise exception 'Informe se o evento encerra sozinho.'; end if;
  if p_horas is null or p_horas < 1 or p_horas > 720 then
    raise exception 'Informe de 1 a 720 horas.';
  end if;
  update public.config_eventos
     set encerra_sozinho = p_encerra_sozinho, horas_apos_inicio = p_horas, atualizado_em = now(), atualizado_por = (select auth.uid())
   where id = 1;
  begin
    perform public.registrar_auditoria('config_eventos_alterada', 'config_eventos', '00000000-0000-0000-0000-000000000001'::uuid,
              jsonb_build_object('encerra_sozinho', p_encerra_sozinho, 'horas', p_horas));
  exception when others then
    null; -- a auditoria não pode impedir de salvar a configuração
  end;
end
$f$;

-- Tipo do evento -> modelo (Local/Regional): a tela usa para mostrar o botão Encerrar só a quem pode
create or replace function public.modelos_dos_tipos_evento()
returns table(nome text, modelo text)
language sql stable security definer set search_path = public
as $f$
  select t.nome, t.modelo_ensaio::text from public.tipos_evento t
$f$;

revoke all on function public.obter_config_eventos(), public.salvar_config_eventos(boolean, int), public.modelos_dos_tipos_evento()
  from public, anon;
grant execute on function public.obter_config_eventos(), public.salvar_config_eventos(boolean, int), public.modelos_dos_tipos_evento()
  to authenticated;

-- 2) O relógio da portaria passa a ler a configuração (a assinatura continua a mesma; antes era fixo em 3 h) --
create or replace function public.portaria_encerrada(p_data timestamp with time zone, p_agora timestamp with time zone default now())
returns boolean
language sql stable security definer set search_path = public
as $f$
  select p_data is not null and coalesce(
    (select c.encerra_sozinho and p_agora > p_data + make_interval(hours => c.horas_apos_inicio)
       from public.config_eventos c where c.id = 1),
    p_agora > p_data + interval '24 hours')
$f$;

create or replace function public.portaria_janela_aberta(p_data timestamp with time zone, p_agora timestamp with time zone default now())
returns boolean
language sql stable security definer set search_path = public
as $f$
  select p_data is not null
     and p_agora >= p_data - interval '2 hours'
     and not public.portaria_encerrada(p_data, p_agora)
$f$;

-- 3) Permissões e grupos -------------------------------------------------------------------------------------
insert into public.permissoes (codigo, modulo, acao, descricao) values
  ('eventos.encerrar_qualquer', 'Eventos', 'Encerrar qualquer evento', 'Encerrar qualquer evento em andamento (e a portaria dele).'),
  ('eventos.encerrar_regional', 'Eventos', 'Encerrar Ensaio Regional', 'Encerrar o Ensaio Regional e os eventos que não são ensaio local. Função do Secretário da Música.'),
  ('eventos.encerrar_local',    'Eventos', 'Encerrar ensaio local',    'Encerrar o Ensaio Local e os Ensaios Técnicos. Função do Instrutor.'),
  ('eventos.configurar',        'Eventos', 'Configurar',               'Configurar se o evento encerra sozinho e depois de quantas horas.')
on conflict (codigo) do nothing;

insert into public.grupos (nome, descricao, ativo, sistema)
select 'Instrutor', 'Vê os eventos da região e encerra o Ensaio Local e os Ensaios Técnicos (e a portaria deles).', true, false
 where not exists (select 1 from public.grupos where nome = 'Instrutor');

insert into public.grupo_permissoes (grupo_id, permissao_codigo)
select g.id, p.codigo from public.grupos g join public.permissoes p
  on p.codigo in ('eventos.encerrar_qualquer', 'eventos.encerrar_regional', 'eventos.encerrar_local', 'eventos.configurar')
 where g.nome = 'Administrador' and g.sistema
on conflict do nothing;

insert into public.grupo_permissoes (grupo_id, permissao_codigo)
select g.id, p.codigo from public.grupos g join public.permissoes p on p.codigo = 'eventos.encerrar_qualquer'
 where g.nome = 'Administrador Regional'
on conflict do nothing;

insert into public.grupo_permissoes (grupo_id, permissao_codigo)
select g.id, p.codigo from public.grupos g join public.permissoes p on p.codigo in ('eventos.visualizar', 'eventos.encerrar_regional')
 where g.nome = 'Secretário da Música'
on conflict do nothing;

insert into public.grupo_permissoes (grupo_id, permissao_codigo)
select g.id, p.codigo from public.grupos g join public.permissoes p on p.codigo in ('eventos.visualizar', 'eventos.encerrar_local')
 where g.nome = 'Instrutor'
on conflict do nothing;

-- 4) Encerrar evento com a regra por tipo ------------------------------------------------------------------
create or replace function public.encerrar_evento(p_id uuid)
returns void
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_uid uuid := (select auth.uid());
  v_e   public.eventos;
  v_modelo text;
  v_ok  boolean;
begin
  select * into v_e from public.eventos e where e.id = p_id and e.excluido_em is null for update;
  if not found then
    raise exception 'Evento não encontrado.';
  end if;
  -- Quem encerra depende do tipo do evento (campo "Dados do Ensaio" do Tipo do Evento):
  --   Administrador e Administrador Regional (eventos.encerrar_qualquer) ........ qualquer evento
  --   Ensaio LOCAL (inclui os Ensaios Técnicos) ................................. Instrutor (eventos.encerrar_local)
  --   Ensaio REGIONAL e demais tipos (Treinamento, Reunião Musical, Outro...) .... Secretário da Música (eventos.encerrar_regional)
  select t.modelo_ensaio::text into v_modelo from public.tipos_evento t
   where public.normalizar_texto(t.nome) = public.normalizar_texto(v_e.tipo) limit 1;
  v_ok := public.tem_permissao('eventos.encerrar_qualquer')
          or (coalesce(v_modelo, '') = 'LOCAL' and public.tem_permissao('eventos.encerrar_local'))
          or (coalesce(v_modelo, '') <> 'LOCAL' and public.tem_permissao('eventos.encerrar_regional'));
  if not v_ok then
    raise exception 'Você não tem permissão para encerrar este tipo de evento.' using errcode = '42501';
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

do $$
begin
  if to_regprocedure('public.obter_config_eventos()') is null or to_regprocedure('public.salvar_config_eventos(boolean,integer)') is null
     or not exists (select 1 from public.grupos where nome = 'Instrutor') then
    raise exception 'Verificação falhou: objetos da 0077 ausentes.';
  end if;
end
$$;
