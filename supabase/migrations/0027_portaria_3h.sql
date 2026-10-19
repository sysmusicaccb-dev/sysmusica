-- =====================================================================
-- SysMúsica — Migração 0027: portaria encerra 3 HORAS DEPOIS do início do evento
--   Antes: de 2h antes a 2h depois. Agora: de 2 HORAS ANTES até 3 HORAS DEPOIS (horário de Salvador).
--   Ex.: ensaio às 14h -> portaria aberta das 12h às 17h.
--   A regra fica em um só lugar (portaria_janela_aberta); a validação do registro e a mensagem de erro seguem ela.
-- Requer a migração 0024. Idempotente, uma única transação. Ao final testa os limites (se falhar, desfaz tudo).
-- =====================================================================
begin;

do $$
begin
  if to_regprocedure('public.portaria_janela_aberta(timestamptz,timestamptz)') is null then
    raise exception 'Aplique primeiro a migração 0024.';
  end if;
end $$;

-- 1) A regra da janela em um só lugar (limites inclusivos): de 2h antes a 3h depois do início
create or replace function public.portaria_janela_aberta(p_data timestamptz, p_agora timestamptz default now())
returns boolean
language sql
immutable
set search_path = public
as $$
  select p_data is not null
     and p_agora >= p_data - interval '2 hours'
     and p_agora <= p_data + interval '3 hours'
$$;

-- 2) A validação do registro (a de 0012) ganha a conferência da janela, logo após a abrangência
create or replace function public.validar_registro_presenca(
  p_portaria_id uuid, p_evento_id uuid, p_membro_id uuid
)
returns void language plpgsql security definer set search_path = public as $$
declare
  v_p         public.portarias;
  v_m         record;
  v_existente record;
  v_data      timestamptz;
begin
  perform public.exigir_permissao('portaria.registrar');

  select * into v_p from public.portarias p where p.id = p_portaria_id and p.excluido_em is null;
  if not found then
    raise exception 'Portaria não encontrada.';
  end if;
  if v_p.status <> 'APROVADA' then
    raise exception 'Esta portaria não está aprovada (situação: %). Só portarias aprovadas registram presenças.',
      case v_p.status when 'PENDENTE_APROVACAO' then 'pendente de aprovação'
                      when 'REJEITADA' then 'rejeitada' else v_p.status end;
  end if;
  if v_p.evento_id <> p_evento_id then
    raise exception 'A portaria não corresponde ao evento informado.';
  end if;
  if not public.comum_na_abrangencia(v_p.comum_id) then
    raise exception 'Você não tem acesso a esta portaria (fora da sua abrangência).' using errcode = '42501';
  end if;

  -- JANELA: de 2 horas antes a 3 horas depois do início do evento (horário de Salvador)
  select e.data_evento into v_data from public.eventos e where e.id = v_p.evento_id;
  if v_data is null then
    raise exception 'O evento desta portaria não foi encontrado.';
  end if;
  if not public.portaria_janela_aberta(v_data) then
    if public.tem_permissao('portarias.controle_total') then
      -- Administrador: permitido, mas fica registrado na Auditoria
      perform public.registrar_auditoria('presenca_fora_da_janela', 'portaria', p_portaria_id,
        jsonb_build_object(
          'evento_id', p_evento_id,
          'membro_id', p_membro_id,
          'inicio_do_evento', v_data,
          'registrado_em', now(),
          'situacao', case when now() < v_data then 'antes da abertura' else 'depois do encerramento' end));
    else
      raise exception 'Fora do horário da portaria. Ela abre em % e encerra em % (2 horas antes e 3 horas depois do início do evento, horário de Salvador).',
        to_char((v_data - interval '2 hours') at time zone 'America/Sao_Paulo', 'DD/MM "às" HH24"h"MI'),
        to_char((v_data + interval '3 hours') at time zone 'America/Sao_Paulo', 'DD/MM "às" HH24"h"MI');
    end if;
  end if;

  select m.status, m.excluido_em into v_m from public.membros m where m.id = p_membro_id;
  if not found then
    raise exception 'Cadastro do membro não encontrado.';
  end if;
  if v_m.excluido_em is not null then
    raise exception 'Cadastro do membro não encontrado.';
  end if;
  if v_m.status <> 'Ativo' then
    raise exception 'O cadastro do membro está inativo.';
  end if;

  -- Duplicidade por EVENTO (inclui registros antigos, sem portaria)
  select pr.hora_entrada, pr.status, pr.portaria_id into v_existente
  from public.presencas pr
  where pr.membro_id = p_membro_id
    and pr.evento_id = p_evento_id
    and pr.excluido_em is null
    and (pr.hora_saida is null or pr.portaria_id = p_portaria_id)
  order by pr.hora_entrada
  limit 1;
  if found then
    raise exception 'Este músico já possui uma entrada registrada neste evento às % (situação: %)%.',
      to_char(v_existente.hora_entrada at time zone 'America/Sao_Paulo', 'HH24"h"MI'),
      v_existente.status,
      case when v_existente.portaria_id is null then ', registro antigo feito antes das portarias' else '' end;
  end if;
end;
$$;

-- 3) VERIFICAÇÃO: os limites da janela (evento às 14h de Salvador = 17h UTC). Se falhar, tudo é desfeito.
do $$
declare
  v_ev constant timestamptz := '2026-10-19T17:00:00Z';
begin
  if public.portaria_janela_aberta(v_ev, '2026-10-19T14:59:59Z') then
    raise exception 'Teste falhou: abriu antes das 12h.';
  end if;
  if not public.portaria_janela_aberta(v_ev, '2026-10-19T15:00:00Z') then
    raise exception 'Teste falhou: não abriu às 12h.';
  end if;
  if not public.portaria_janela_aberta(v_ev, '2026-10-19T20:00:00Z') then
    raise exception 'Teste falhou: fechou antes das 17h.';
  end if;
  if public.portaria_janela_aberta(v_ev, '2026-10-19T20:00:01Z') then
    raise exception 'Teste falhou: não encerrou depois das 17h.';
  end if;
  if public.portaria_janela_aberta(null, now()) then
    raise exception 'Teste falhou: evento sem data não pode estar aberto.';
  end if;
end $$;

commit;
