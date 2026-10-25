-- Desfaz o 0073: volta salvar_ficha, definir_resultado_ficha e buscar_membros_para_ficha ao que eram no 0070
-- e remove as funções da trava de etapa.
drop function if exists public.buscar_membros_para_ficha(text, text, text);

create or replace function public.salvar_ficha(p_id uuid, p_tipo text, p_membro uuid, p_casa uuid, p_dados jsonb)
returns uuid
language plpgsql security definer set search_path = public
as $f$
declare
  v_casa uuid := p_casa;
  v_f    public.fichas_musicais;
  v_id   uuid;
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

create or replace function public.buscar_membros_para_ficha(p_termo text)
returns table(id uuid, nome text, casa_oracao_id uuid, casa_nome text, cargo text,
              instrumento_id uuid, instrumento_nome text, categoria text)
language plpgsql stable security definer set search_path = public
as $f$
declare
  v_t text := regexp_replace(public.normalizar_texto(coalesce(p_termo, '')), '[%_\\]', '', 'g');
begin
  perform public.exigir_permissao('fichas.criar');
  if char_length(v_t) < 2 then return; end if;
  return query
    select m.id, m.nome, m.casa_oracao_id, c.nome, g.nome, m.instrumento_id, i.nome, m.categoria
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

revoke all on function public.buscar_membros_para_ficha(text) from public, anon;
grant execute on function public.buscar_membros_para_ficha(text) to authenticated;

drop function if exists public.avaliar_elegibilidade_ficha(text, uuid, jsonb);
drop function if exists public.nivel_musical_do_membro(uuid);
