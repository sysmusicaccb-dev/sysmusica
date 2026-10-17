-- =====================================================================
-- SysMúsica — Migração 0010: duplicidade de presença considerada por EVENTO
-- Problema: o membro já tinha uma entrada em aberto no evento, feita ANTES das portarias (sem portaria
-- vinculada). O banco barrava o novo registro (regra única membro + evento), mas a tela de conferência
-- só olhava a portaria atual e a mensagem era genérica.
-- Correção:
--   * a validação do registro passa a olhar o evento inteiro (inclui registros antigos) e diz a hora,
--     a situação e se o registro é antigo;
--   * o cartão de conferência marca "já registrado" considerando o evento;
--   * as "Últimas entradas" mostram também os registros antigos do evento (origem ANTIGO).
-- Requer as migrações 0007 e 0008. Idempotente, uma única transação.
-- =====================================================================
begin;

do $$
begin
  if to_regprocedure('public.exigir_acesso_atendimento(uuid)') is null then
    raise exception 'Aplique primeiro a migração 0008_atendimento_portaria.sql.';
  end if;
end $$;

-- 1) Validação do registro: duplicidade por evento (mensagem clara)
create or replace function public.validar_registro_presenca(
  p_portaria_id uuid, p_evento_id uuid, p_membro_id uuid
)
returns void language plpgsql security definer set search_path = public as $$
declare
  v_p         public.portarias;
  v_m         record;
  v_existente record;
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
  if not public.cidade_na_abrangencia(v_p.cidade) then
    raise exception 'Você não tem acesso a esta portaria (fora da sua abrangência).' using errcode = '42501';
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

  -- Duplicidade: já há presença do membro NESTE EVENTO (de qualquer portaria ou registro antigo, sem
  -- portaria) ainda em aberto, ou já registrada nesta mesma portaria
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

-- 2) Cartão de conferência: "já registrado" considera o evento da portaria (inclui registros antigos)
create or replace function public.cartao_membro(p_portaria_id uuid, p_membro_id uuid)
returns table (
  membro_id uuid, nome text, congregacao text, cargo text, instrumento text,
  cidade text, bairro text, status text, foto_path text, ja_registrado_em timestamptz
)
language sql stable security definer set search_path = public as $$
  select m.id, m.nome, m.congregacao, c.nome, i.nome, m.cidade, m.bairro, m.status, m.foto_path,
         (select min(pr.hora_entrada)
            from public.presencas pr
            join public.portarias po on po.id = p_portaria_id
           where pr.membro_id = m.id
             and pr.excluido_em is null
             and (pr.portaria_id = po.id or pr.evento_id = po.evento_id))
  from public.membros m
  left join public.cargos c on c.id = m.cargo_id
  left join public.instrumentos i on i.id = m.instrumento_id
  where m.id = p_membro_id and m.excluido_em is null
$$;

-- 3) Últimas entradas: inclui os registros antigos do mesmo evento (origem "ANTIGO")
create or replace function public.entradas_da_portaria(p_portaria_id uuid)
returns table (
  presenca_id uuid, membro_nome text, status text, hora_entrada timestamptz, origem text, total bigint
)
language plpgsql stable security definer set search_path = public as $$
declare
  v_evento uuid;
begin
  perform public.exigir_acesso_atendimento(p_portaria_id);
  select po.evento_id into v_evento from public.portarias po where po.id = p_portaria_id;

  return query
    select pr.id, m.nome, pr.status, pr.hora_entrada,
           case when pr.portaria_id is null then 'ANTIGO' else pr.origem end,
           count(*) over ()
    from public.presencas pr
    join public.membros m on m.id = pr.membro_id
    where pr.excluido_em is null
      and (pr.portaria_id = p_portaria_id or (pr.portaria_id is null and pr.evento_id = v_evento))
    order by pr.hora_entrada desc
    limit 30;
end;
$$;

commit;
