-- 0059 — Isolamento regional (Etapa 2, final): QR do membro e registro de entrada.
--  * obter_qr_membro e regenerar_qr: só para membros de casas da própria abrangência.
--  * registrar_entrada: só em portaria de casa da própria abrangência.
-- O resto de cada função continua IGUAL ao que está em produção. Seguro rodar mais de uma vez.
-- Reverter: supabase/rollback/0059_reverter.sql

begin;

create or replace function public.obter_qr_membro(p_id uuid)
 returns uuid
 language plpgsql
 security definer
 set search_path to 'public'
as $function$
declare
  v_token uuid;
  v_casa  uuid;
begin
  perform public.exigir_permissao('membros.qr');

  select m.qr_secret, m.casa_oracao_id into v_token, v_casa
    from public.membros m where m.id = p_id and m.excluido_em is null;
  if not found then
    raise exception 'Membro não encontrado.';
  end if;
  if not public.casa_oracao_na_abrangencia(v_casa) then
    raise exception 'Este membro está fora da sua abrangência.' using errcode = '42501';
  end if;

  perform public.registrar_auditoria('qr_visualizado', 'membro', p_id, '{}'::jsonb);
  return v_token;
end;
$function$;

create or replace function public.regenerar_qr(p_id uuid, p_justificativa text)
 returns uuid
 language plpgsql
 security definer
 set search_path to 'public'
as $function$
declare
  v_membro public.membros;
  v_novo   uuid := gen_random_uuid();
  v_just   text := btrim(coalesce(p_justificativa, ''));
begin
  perform public.exigir_permissao('membros.qr_revogar');

  if char_length(v_just) < 10 then
    raise exception 'Informe a justificativa (mínimo de 10 caracteres).';
  end if;
  if char_length(v_just) > 300 then
    raise exception 'A justificativa pode ter no máximo 300 caracteres.';
  end if;

  select * into v_membro from public.membros where id = p_id and excluido_em is null for update;
  if not found then
    raise exception 'Membro não encontrado.';
  end if;
  if not public.casa_oracao_na_abrangencia(v_membro.casa_oracao_id) then
    raise exception 'Este membro está fora da sua abrangência.' using errcode = '42501';
  end if;

  insert into public.qr_historico (membro_id, token_hash, revogado_por, justificativa)
  values (
    p_id,
    encode(sha256(convert_to(v_membro.qr_secret::text, 'UTF8')), 'hex'),
    (select auth.uid()),
    v_just
  );

  update public.membros set qr_secret = v_novo where id = p_id;

  perform public.registrar_auditoria('qr_substituido', 'membro', p_id,
                                     jsonb_build_object('justificativa', v_just));
  return v_novo;
end;
$function$;

create or replace function public.registrar_entrada(p_portaria_id uuid, p_membro_id uuid, p_origem text default 'MANUAL'::text, p_toca boolean default null::boolean, p_instrumento_id uuid default null::uuid)
 returns presencas
 language plpgsql
 security definer
 set search_path to 'public'
as $function$
declare
  v_evento   uuid;
  v_casa     uuid;
  v_presenca public.presencas;
  v_m        record;
  v_ef_inst  uuid;
  v_ef_nome  text;
  v_linha    public.linhas_painel;
  v_toca     boolean;
  v_gravar   uuid;
begin
  if p_origem not in ('MANUAL', 'QR') then
    raise exception 'Origem de registro inválida.';
  end if;
  select p.evento_id, p.casa_oracao_id into v_evento, v_casa
    from public.portarias p where p.id = p_portaria_id and p.excluido_em is null;
  if not found then
    raise exception 'Portaria não encontrada.';
  end if;
  if not public.casa_oracao_na_abrangencia(v_casa) then
    raise exception 'Portaria indisponível para você.' using errcode = '42501';
  end if;

  select cg.nome as cargo, m.categoria, m.instrumento_id into v_m
    from public.membros m left join public.cargos cg on cg.id = m.cargo_id
   where m.id = p_membro_id and m.excluido_em is null;
  if not found then
    raise exception 'Cadastro do membro não encontrado.';
  end if;

  if p_instrumento_id is not null and not exists (select 1 from public.instrumentos i where i.id = p_instrumento_id) then
    raise exception 'Instrumento inválido.';
  end if;

  -- Instrumento: o músico só toca o instrumento do cadastro (liberado pelo ministério). A escolha feita na
  -- entrada só vale para quem ainda NÃO tem instrumento cadastrado.
  v_ef_inst := coalesce(v_m.instrumento_id, p_instrumento_id);
  select i.nome into v_ef_nome from public.instrumentos i where i.id = v_ef_inst;
  select * into v_linha from public.linhas_painel l
   where l.codigo = public.classificar_linha(v_m.cargo, v_m.categoria, v_ef_nome);

  if v_linha.pergunta_toca then
    if p_toca is null then
      raise exception 'Informe se a pessoa vai tocar.';
    end if;
    v_toca := p_toca;
    if v_toca and v_ef_inst is null then
      raise exception 'Informe o instrumento que a pessoa vai tocar.';
    end if;
    v_gravar := case when v_toca and v_m.instrumento_id is null then p_instrumento_id else null end;
  else
    v_toca := null;               -- sem pergunta: vale a regra da linha (Músico conta sempre; Ancião/Diácono não)
    v_gravar := case when v_m.instrumento_id is null then p_instrumento_id else null end;
  end if;

  perform set_config('sysmusica.origem', p_origem, true);
  insert into public.presencas (membro_id, evento_id, status, portaria_id, toca, instrumento_id, linha_codigo)
  values (p_membro_id, v_evento, 'Presente', p_portaria_id, v_toca, v_gravar, v_linha.codigo)
  returning * into v_presenca;
  return v_presenca;
end;
$function$;

do $$
begin
  if (select count(*) from pg_proc where proname in ('obter_qr_membro','regenerar_qr','registrar_entrada')
        and prosrc like '%casa_oracao_na_abrangencia%') <> 3 then
    raise exception 'Verificação falhou: as 3 funções não foram atualizadas.';
  end if;
end $$;

commit;
