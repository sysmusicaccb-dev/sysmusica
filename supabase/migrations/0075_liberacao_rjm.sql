-- 0075: LIBERAÇÃO PARA TOCAR. Quando o candidato (músico) ou a candidata (organista) é aprovado(a), o cadastro já passa para RJM.
--   Apto em: Ficha de avaliação de candidato, Avaliação de músico para RJM, Pré-avaliação de candidatas a organistas -> categoria = RJM.
--   Escada: candidato (GEM) -> RJM -> Culto Oficial (M02) -> Oficialização (M03) -> Oficializado.
--   O GEM (M01 e Acompanhamento) passa a dizer que é só para candidatos. Só substitui duas funções.

create or replace function public.avaliar_elegibilidade_ficha(p_tipo text, p_membro uuid, p_dados jsonb)
returns text
language plpgsql stable security definer set search_path = public
as $f$
declare
  v_nome    text;
  v_nivel   text;
  v_rot     text;
  v_org     boolean;
  v_somente boolean;
  v_instr   boolean;
  v_para    text := upper(coalesce(p_dados ->> 'para', ''));
  v_nome_n  text;
begin
  -- Tipos sem trava de etapa
  if p_tipo is null or p_tipo not in ('M01', 'M02', 'M03', 'M05', 'M07', 'AVALIACAO_RJM', 'AVALIACAO_CANDIDATO',
       'PRE_AVALIACAO_ORGANISTA', 'EXAME_ORGANISTA', 'ACOMPANHAMENTO_GEM') then
    return null;
  end if;

  -- Sem pessoa do cadastro: se o mesmo nome já existe na região, exige escolher a pessoa (para conferirmos a etapa)
  if p_membro is null then
    v_nome_n := public.normalizar_texto(coalesce(p_dados ->> 'nome', ''));
    if v_nome_n <> '' and exists (
         select 1 from public.membros m
          where m.excluido_em is null
            and public.normalizar_texto(m.nome) = v_nome_n
            and public.ficha_visivel(m.casa_oracao_id)) then
      return 'Já existe uma pessoa com este nome no cadastro. Use "Buscar no cadastro" e escolha-a, para o sistema conferir a etapa em que ela está.';
    end if;
    return null;
  end if;

  select m.nome,
         (m.instrumento_id is not null),
         coalesce(public.normalizar_texto(i.nome) like '%orgao%', false)
           or coalesce(public.normalizar_texto(g.nome) like 'organista%', false)
           or coalesce((to_jsonb(g) ->> 'somente_orgao')::boolean, false),
         coalesce((to_jsonb(g) ->> 'somente_orgao')::boolean, false)
    into v_nome, v_instr, v_org, v_somente
    from public.membros m
    left join public.cargos g on g.id = m.cargo_id
    left join public.instrumentos i on i.id = m.instrumento_id
   where m.id = p_membro and m.excluido_em is null;
  if not found then
    return 'Membro não encontrado.';
  end if;

  v_nivel := public.nivel_musical_do_membro(p_membro);
  v_rot := case v_nivel when 'RJM' then 'RJM' when 'CULTO_OFICIAL' then 'Culto Oficial' when 'OFICIALIZADO' then 'Oficializado' else 'sem etapa musical' end;

  -- Etapa inicial: só quem ainda não tem etapa
  if p_tipo in ('M01', 'ACOMPANHAMENTO_GEM', 'AVALIACAO_CANDIDATO', 'AVALIACAO_RJM') then
    if v_nivel <> 'NENHUM' then
      -- GEM é só para candidato (quem ainda não toca); a avaliação de liberação também só vale para quem ainda não foi liberado
      if p_tipo in ('M01', 'ACOMPANHAMENTO_GEM') then
        return format('O GEM é só para candidatos (quem ainda não toca). %s já toca: etapa %s.', v_nome, v_rot);
      end if;
      return format('%s já foi liberado(a) para tocar (etapa %s) e não faz mais esta avaliação.', v_nome, v_rot);
    end if;
    return null;
  end if;

  if p_tipo = 'M02' then
    if v_nivel <> 'RJM' then
      return format('A ficha M02 (Culto Oficial) é só para quem está em RJM. %s está em: %s.', v_nome, v_rot);
    end if;
    return null;
  end if;

  if p_tipo = 'M03' then
    if v_nivel <> 'CULTO_OFICIAL' then
      return format('A ficha M03 (Oficialização) é só para quem está em Culto Oficial. %s está em: %s.', v_nome, v_rot);
    end if;
    return null;
  end if;

  if p_tipo in ('M05', 'PRE_AVALIACAO_ORGANISTA', 'EXAME_ORGANISTA') then
    if not v_org then
      return format('Esta ficha é só para organista (Órgão). %s não é organista no cadastro.', v_nome);
    end if;
    if v_nivel = 'OFICIALIZADO' then
      return format('%s já é Oficializada: não faz mais pedido de avaliação, teste ou exame.', v_nome);
    end if;
    if p_tipo = 'M05' and v_para <> '' then
      if (v_para = 'RJM' and v_nivel <> 'NENHUM')
         or (v_para = 'CULTO_OFICIAL' and v_nivel <> 'RJM')
         or (v_para = 'OFICIALIZADO' and v_nivel <> 'CULTO_OFICIAL') then
        return format('Pedido para %s não confere com a etapa de %s (%s). Cada pedido é para a etapa seguinte.',
                      case v_para when 'RJM' then 'RJM' when 'CULTO_OFICIAL' then 'Culto Oficial' else 'Oficialização' end, v_nome, v_rot);
      end if;
    end if;
    return null;
  end if;

  if p_tipo = 'M07' then
    if v_nivel <> 'OFICIALIZADO' then
      return format('A troca de instrumento (M07) é só para Oficializado. %s está em: %s.', v_nome, v_rot);
    end if;
    if not v_instr then
      return format('%s não tem instrumento no cadastro, então não há o que trocar.', v_nome);
    end if;
    if v_somente then
      return format('O cargo de %s só toca Órgão: não há troca de instrumento.', v_nome);
    end if;
    return null;
  end if;

  return null;
end
$f$;

create or replace function public.definir_resultado_ficha(p_id uuid, p_resultado text)
returns jsonb
language plpgsql security definer set search_path = public
as $f$
declare
  v_f      public.fichas_musicais;
  v_m      public.membros;
  v_nova   text;
  v_instr  uuid;
  v_aplic  boolean := false;
  v_msg    text := 'Resultado registrado.';
  v_motivo text;
  v_pular  boolean := false; -- Apto da pré-avaliação de quem já está em RJM ou acima: não mexe no cadastro
begin
  perform public.exigir_permissao('fichas.resultado');
  if p_resultado is null or p_resultado not in ('APTO', 'NAO_APTO') then
    raise exception 'Resultado inválido.';
  end if;
  select * into v_f from public.fichas_musicais x where x.id = p_id and x.excluido_em is null for update;
  if not found or not public.ficha_visivel(v_f.casa_oracao_id) then
    raise exception 'Ficha não encontrada.';
  end if;
  if v_f.resultado is not null then
    raise exception 'Esta ficha já tem resultado.';
  end if;

  -- Apto muda o cadastro: reconfere a etapa atual da pessoa (impede, por exemplo, rebaixar um Oficializado)
  if p_resultado = 'APTO' and v_f.tipo in ('M02', 'M03', 'M05', 'M07', 'AVALIACAO_CANDIDATO', 'AVALIACAO_RJM', 'PRE_AVALIACAO_ORGANISTA') then
    v_motivo := public.avaliar_elegibilidade_ficha(v_f.tipo, v_f.membro_id, v_f.dados);
    if v_motivo is not null then
      raise exception '%', v_motivo using errcode = '22023';
    end if;
  end if;

  if p_resultado = 'APTO' and v_f.tipo in ('M02', 'M03', 'M05', 'M07', 'AVALIACAO_CANDIDATO', 'AVALIACAO_RJM', 'PRE_AVALIACAO_ORGANISTA') then
    if v_f.membro_id is null then
      raise exception 'Escolha o membro do cadastro nesta ficha antes de marcar Apto.';
    end if;
    select * into v_m from public.membros m where m.id = v_f.membro_id and m.excluido_em is null for update;
    if not found then raise exception 'Membro não encontrado.'; end if;

    if v_f.tipo = 'M07' then
      begin
        v_instr := nullif(v_f.dados ->> 'instrumento_novo_id', '')::uuid;
      exception when others then
        raise exception 'Instrumento novo inválido na ficha.';
      end;
      if v_instr is null or not exists (select 1 from public.instrumentos i where i.id = v_instr) then
        raise exception 'Escolha o instrumento novo na ficha antes de marcar Apto.';
      end if;
      update public.membros set instrumento_id = v_instr where id = v_m.id;
      v_msg := 'Apto: o instrumento do cadastro foi trocado.';
    else
      v_nova := case v_f.tipo
                  when 'M02' then 'CULTO_OFICIAL'
                  when 'M03' then 'OFICIALIZADO'
                  -- Liberação: candidato/candidata aprovado(a) já entra na Reunião de Jovens e Menores
                  when 'AVALIACAO_CANDIDATO' then 'RJM'
                  when 'AVALIACAO_RJM' then 'RJM'
                  when 'PRE_AVALIACAO_ORGANISTA' then 'RJM'
                  else upper(coalesce(v_f.dados ->> 'para', '')) end;
      if v_nova not in ('RJM', 'CULTO_OFICIAL', 'OFICIALIZADO') then
        raise exception 'A ficha não informa para qual categoria o pedido foi feito.';
      end if;
      if v_f.tipo = 'PRE_AVALIACAO_ORGANISTA' and public.nivel_musical_do_membro(v_m.id) <> 'NENHUM' then
        v_pular := true;
        v_msg := 'Apto registrado. O cadastro já estava em RJM ou acima e não foi alterado.';
      else
        update public.membros set categoria = v_nova where id = v_m.id;
        v_msg := 'Apto: a categoria do cadastro agora é ' || v_nova || '.';
        if v_nova = 'RJM' then
          v_msg := v_msg || ' Já pode tocar nas Reuniões de Jovens e Menores.';
        end if;
      end if;
    end if;
    v_aplic := not v_pular;
  end if;

  update public.fichas_musicais
     set resultado = p_resultado, resultado_por = (select auth.uid()), resultado_em = now(),
         aplicado_em = case when v_aplic then now() else null end, atualizado_em = now()
   where id = p_id;
  perform public.registrar_auditoria('ficha_resultado', 'ficha', p_id,
            jsonb_build_object('tipo', v_f.tipo, 'resultado', p_resultado, 'cadastro_alterado', v_aplic));
  return jsonb_build_object('aplicado', v_aplic, 'mensagem', v_msg);
end
$f$;
