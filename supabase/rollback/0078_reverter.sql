-- Desfaz o 0078: volta à regra do 0077 (Secretário: Regional e tipos sem Local; Instrutor: todo ensaio Local).
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

update public.permissoes set acao = 'Encerrar Ensaio Regional',
       descricao = 'Encerrar o Ensaio Regional e os eventos que não são ensaio local. Função do Secretário da Música.'
 where codigo = 'eventos.encerrar_regional';
update public.permissoes set acao = 'Encerrar ensaio local', descricao = 'Encerrar o Ensaio Local e os Ensaios Técnicos. Função do Instrutor.'
 where codigo = 'eventos.encerrar_local';
