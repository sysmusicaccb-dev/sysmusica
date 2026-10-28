-- 0078: o Secretário da Música encerra QUALQUER evento; o Instrutor encerra só o Ensaio Local (não os Ensaios Técnicos).
-- Administrador e Administrador Regional continuam encerrando qualquer evento. Só troca encerrar_evento e os textos das permissões.
-- Seguro rodar mais de uma vez. Para desfazer: 0078_reverter.sql

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
  -- Quem encerra:
  --   Administrador e Administrador Regional (eventos.encerrar_qualquer) ... qualquer evento
  --   Secretário da Música (eventos.encerrar_regional) ....................... qualquer evento
  --   Instrutor (eventos.encerrar_local) ..................................... só o Ensaio Local (os Ensaios Técnicos são do Secretário)
  select t.modelo_ensaio::text into v_modelo from public.tipos_evento t
   where public.normalizar_texto(t.nome) = public.normalizar_texto(v_e.tipo) limit 1;
  v_ok := public.tem_permissao('eventos.encerrar_qualquer')
          or public.tem_permissao('eventos.encerrar_regional')
          or (coalesce(v_modelo, '') = 'LOCAL'
              and public.normalizar_texto(v_e.tipo) not like 'ensaio tecnico%'
              and public.tem_permissao('eventos.encerrar_local'));
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

update public.permissoes set acao = 'Encerrar qualquer evento (Secretário da Música)',
       descricao = 'Encerrar qualquer evento em andamento (e a portaria dele). Função do Secretário da Música.'
 where codigo = 'eventos.encerrar_regional';
update public.permissoes set acao = 'Encerrar Ensaio Local (Instrutor)',
       descricao = 'Encerrar o Ensaio Local (não inclui os Ensaios Técnicos). Função do Instrutor.'
 where codigo = 'eventos.encerrar_local';
