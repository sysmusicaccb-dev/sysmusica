-- ============================================================================
-- Sysmusica — 0073: TRAVA DE ETAPA nas fichas da Comissão Musical
-- Regra da casa: a pessoa só pode ser colocada numa ficha da etapa SEGUINTE à que ela já cumpriu.
--   Etapas (de baixo para cima):  sem etapa  ->  RJM  ->  Culto Oficial  ->  Oficializado
--   Quem tem cargo de ministério/encarregado (Ancião, Diácono, Cooperador, Encarregado, Examinadora, Instrutor,
--   Secretário) já é Oficializado. Oficializado é o último nível: não faz GEM, RJM, Culto Oficial nem teste algum.
--
-- Quem pode em cada ficha:
--   M01 (ingresso no GEM), Ficha do GEM, Avaliação de candidato, Avaliação RJM ... só quem está SEM etapa
--   M02 (Culto Oficial) ............ só quem está em RJM
--   M03 (Oficialização) ............ só quem está em Culto Oficial
--   M05 (organista) ................ só organista (Órgão / cargo só-Órgão); RJM<-sem etapa, Culto Oficial<-RJM, Oficialização<-Culto Oficial
--   Pré-avaliação / Testes e exames de organistas ... só organista que ainda não é Oficializada
--   M07 (troca de instrumento) ..... só Oficializado que toca (tem instrumento) e cujo cargo não seja só-Órgão
--   Necessidade de instrumentos .... sem restrição
-- Pessoa sem cadastro: se já existir alguém com o MESMO NOME na região, a ficha exige escolher a pessoa no cadastro.
--
-- O que este script faz:
--   1) nivel_musical_do_membro(membro)           -> 'NENHUM' | 'RJM' | 'CULTO_OFICIAL' | 'OFICIALIZADO'
--   2) avaliar_elegibilidade_ficha(tipo, membro, dados) -> texto do motivo, ou nulo se pode
--   3) salvar_ficha e definir_resultado_ficha passam a conferir a regra (Apto não rebaixa ninguém)
--   4) buscar_membros_para_ficha(termo, tipo, para) devolve também nivel, organista e motivo (a tela mostra quem NÃO pode)
-- Seguro rodar mais de uma vez. Para desfazer: 0073_reverter.sql
-- ============================================================================

-- 1) Etapa musical da pessoa ----------------------------------------------------------------------------
create or replace function public.nivel_musical_do_membro(p_membro uuid)
returns text
language plpgsql stable security definer set search_path = public
as $f$
declare
  v_cargo text;
  v_cat   text;
begin
  select public.normalizar_texto(coalesce(g.nome, '')), upper(coalesce(m.categoria, ''))
    into v_cargo, v_cat
    from public.membros m
    left join public.cargos g on g.id = m.cargo_id
   where m.id = p_membro and m.excluido_em is null;
  if not found then
    return 'NENHUM';
  end if;
  -- Ministério e encarregados já passaram por todas as etapas
  if v_cargo like 'anciao%' or v_cargo like 'diacono%' or v_cargo like 'cooperador%' or v_cargo like 'encarregado%'
     or v_cargo like 'examinadora%' or v_cargo like 'instrutor%' or v_cargo like 'secretario%' then
    return 'OFICIALIZADO';
  end if;
  if v_cat in ('RJM', 'CULTO_OFICIAL', 'OFICIALIZADO') then
    return v_cat;
  end if;
  return 'NENHUM';
end
$f$;

-- 2) A regra (um lugar só) ------------------------------------------------------------------------------
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
      return format('%s já está na etapa %s e não pode entrar numa ficha de etapa inicial (GEM, candidato ou RJM).', v_nome, v_rot);
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

revoke all on function public.nivel_musical_do_membro(uuid), public.avaliar_elegibilidade_ficha(text, uuid, jsonb)
  from public, anon, authenticated;

-- 3) salvar_ficha e definir_resultado_ficha com a trava ------------------------------------------------
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
  if p_resultado = 'APTO' and v_f.tipo in ('M02', 'M03', 'M05', 'M07') then
    v_motivo := public.avaliar_elegibilidade_ficha(v_f.tipo, v_f.membro_id, v_f.dados);
    if v_motivo is not null then
      raise exception '%', v_motivo using errcode = '22023';
    end if;
  end if;

  if p_resultado = 'APTO' and v_f.tipo in ('M02', 'M03', 'M05', 'M07') then
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
                  else upper(coalesce(v_f.dados ->> 'para', '')) end;
      if v_nova not in ('RJM', 'CULTO_OFICIAL', 'OFICIALIZADO') then
        raise exception 'A ficha não informa para qual categoria o pedido foi feito.';
      end if;
      update public.membros set categoria = v_nova where id = v_m.id;
      v_msg := 'Apto: a categoria do cadastro agora é ' || v_nova || '.';
    end if;
    v_aplic := true;
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

-- 4) Busca no cadastro: devolve a etapa e o motivo (quem NÃO pode aparece, mas não pode ser escolhido) ----
drop function if exists public.buscar_membros_para_ficha(text);
create or replace function public.buscar_membros_para_ficha(p_termo text, p_tipo text default null, p_para text default null)
returns table(id uuid, nome text, casa_oracao_id uuid, casa_nome text, cargo text,
              instrumento_id uuid, instrumento_nome text, categoria text,
              nivel text, organista boolean, motivo text)
language plpgsql stable security definer set search_path = public
as $f$
declare
  v_t text := regexp_replace(public.normalizar_texto(coalesce(p_termo, '')), '[%_\\]', '', 'g');
begin
  perform public.exigir_permissao('fichas.criar');
  if char_length(v_t) < 2 then return; end if;
  return query
    select m.id, m.nome, m.casa_oracao_id, c.nome, g.nome, m.instrumento_id, i.nome, m.categoria,
           public.nivel_musical_do_membro(m.id),
           coalesce(public.normalizar_texto(i.nome) like '%orgao%', false)
             or coalesce(public.normalizar_texto(g.nome) like 'organista%', false)
             or coalesce((to_jsonb(g) ->> 'somente_orgao')::boolean, false),
           public.avaliar_elegibilidade_ficha(p_tipo, m.id, jsonb_build_object('para', coalesce(p_para, '')))
      from public.membros m
      left join public.casas_oracao c on c.id = m.casa_oracao_id
      left join public.cargos g on g.id = m.cargo_id
      left join public.instrumentos i on i.id = m.instrumento_id
     where m.excluido_em is null
       and public.normalizar_texto(m.nome) like '%' || v_t || '%'
       and public.ficha_visivel(m.casa_oracao_id)
     order by m.nome
     limit 15;
end
$f$;
revoke all on function public.buscar_membros_para_ficha(text, text, text) from public, anon;
grant execute on function public.buscar_membros_para_ficha(text, text, text) to authenticated;

do $$
begin
  if to_regprocedure('public.avaliar_elegibilidade_ficha(text,uuid,jsonb)') is null
     or to_regprocedure('public.nivel_musical_do_membro(uuid)') is null
     or to_regprocedure('public.buscar_membros_para_ficha(text,text,text)') is null then
    raise exception 'Verificação falhou: funções da trava de etapa ausentes.';
  end if;
end
$$;
