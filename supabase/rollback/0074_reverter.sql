-- Desfaz o 0074: volta salvar_ficha ao que era no 0073 (aceitava ficha sem pessoa).

create or replace function public.salvar_ficha(p_id uuid, p_tipo text, p_membro uuid, p_casa uuid, p_dados jsonb)
returns uuid
language plpgsql security definer set search_path = public
as $f$
declare
  v_casa uuid := p_casa;
  v_f    public.fichas_musicais;
  v_id   uuid;
  v_motivo text;
begin
  if p_id is null then
    perform public.exigir_permissao('fichas.criar');
  else
    perform public.exigir_permissao('fichas.editar');
  end if;
  if p_tipo is null or p_tipo not in ('M01', 'M02', 'M03', 'M05', 'M07', 'AVALIACAO_RJM', 'AVALIACAO_CANDIDATO',
       'PRE_AVALIACAO_ORGANISTA', 'EXAME_ORGANISTA', 'ACOMPANHAMENTO_GEM', 'NECESSIDADE_INSTRUMENTO') then
    raise exception 'Tipo de ficha inválido.';
  end if;
  if p_dados is null or jsonb_typeof(p_dados) <> 'object' or char_length(p_dados::text) > 30000 then
    raise exception 'Dados da ficha inválidos ou grandes demais.';
  end if;

  if p_membro is not null then
    select coalesce(m.casa_oracao_id, p_casa) into v_casa
      from public.membros m where m.id = p_membro and m.excluido_em is null;
    if not found then raise exception 'Membro não encontrado.'; end if;
  end if;
  if v_casa is null then raise exception 'Informe a Casa de Oração.'; end if;
  if not public.ficha_visivel(v_casa) then
    raise exception 'Esta Casa de Oração está fora da sua abrangência.' using errcode = '42501';
  end if;

  -- Trava de etapa: a pessoa precisa estar na etapa certa para esta ficha (ex.: Oficializado não entra em GEM, RJM, Culto Oficial)
  v_motivo := public.avaliar_elegibilidade_ficha(p_tipo, p_membro, p_dados);
  if v_motivo is not null then
    raise exception '%', v_motivo using errcode = '22023';
  end if;

  if p_id is null then
    insert into public.fichas_musicais (tipo, membro_id, casa_oracao_id, dados)
    values (p_tipo, p_membro, v_casa, p_dados)
    returning id into v_id;
    perform public.registrar_auditoria('ficha_criada', 'ficha', v_id, jsonb_build_object('tipo', p_tipo));
  else
    select * into v_f from public.fichas_musicais x where x.id = p_id and x.excluido_em is null for update;
    if not found or not public.ficha_visivel(v_f.casa_oracao_id) then
      raise exception 'Ficha não encontrada.';
    end if;
    if v_f.resultado is not null then
      raise exception 'Esta ficha já tem resultado e não pode mais ser alterada.';
    end if;
    update public.fichas_musicais
       set membro_id = p_membro, casa_oracao_id = v_casa, dados = p_dados, atualizado_em = now()
     where id = p_id;
    v_id := p_id;
    perform public.registrar_auditoria('ficha_alterada', 'ficha', v_id, jsonb_build_object('tipo', v_f.tipo));
  end if;
  return v_id;
end
$f$;
