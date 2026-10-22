-- =============================================================================
-- SysMúsica — Migração 0048: relatórios com filtro por RRM e por ADM (e as colunas RRM e ADM)
--
--  Os relatórios "Presença por evento", "Membros" e "Eventos" passam a aceitar:
--   * p_rrm — só dados das casas de oração da RRM escolhida;
--   * p_adm — só dados das casas de oração da ADM escolhida;
--  e devolvem também as colunas rrm e adm. Os filtros antigos (RA, setor, casa de oração) continuam iguais.
--  As três funções são recriadas (o conjunto de parâmetros muda), então a versão antiga é apagada antes.
--  A abrangência do usuário continua sendo conferida pelo banco (casa_oracao_na_abrangencia).
-- Rode UMA vez no SQL Editor do Supabase, ANTES do git push. Pode rodar de novo sem problema.
-- Se der erro, rode:  rollback;
-- =============================================================================
begin;
set local check_function_bodies = off;

do $$
begin
  if to_regclass('public.rrms') is null or to_regclass('public.cadastro_publico_config') is null
     or to_regprocedure('public.casa_oracao_na_abrangencia(uuid)') is null
     or to_regprocedure('public.exigir_permissao(text)') is null then
    raise exception 'Aplique primeiro as migrações até a 0047. Nada foi alterado.';
  end if;
end $$;

-- Versões anteriores (a nova tem outros parâmetros e outras colunas de retorno)
drop function if exists public.relatorio_presencas(timestamptz, timestamptz, uuid, uuid, uuid, uuid, text, integer);
drop function if exists public.relatorio_membros(uuid, uuid, uuid, uuid, uuid, text, text, integer);
drop function if exists public.relatorio_eventos(timestamptz, timestamptz, uuid, uuid, uuid, integer);
-- (caso já exista a versão nova, de uma execução anterior)
drop function if exists public.relatorio_presencas(timestamptz, timestamptz, uuid, uuid, uuid, uuid, text, integer, uuid, uuid);
drop function if exists public.relatorio_membros(uuid, uuid, uuid, uuid, uuid, text, text, integer, uuid, uuid);
drop function if exists public.relatorio_eventos(timestamptz, timestamptz, uuid, uuid, uuid, integer, uuid, uuid);

-- ---------------------------------------------------------------------------
-- Presença por evento
-- ---------------------------------------------------------------------------
create function public.relatorio_presencas(
  p_inicio timestamptz, p_fim timestamptz, p_evento uuid, p_regiao uuid, p_setor uuid, p_casa_oracao uuid,
  p_status text, p_limite integer, p_rrm uuid default null, p_adm uuid default null)
returns table (evento_tipo text, evento_data timestamptz, evento_local text, evento_finalidade text, rrm text,
               regiao text, adm text, setor text, casa_oracao text, membro_nome text, membro_casa_oracao text,
               cargo text, instrumento text, familia text, cidade text, bairro text, visitante boolean, status text,
               hora_entrada timestamptz, hora_saida timestamptz, origem text, registrado_por text, total bigint)
language plpgsql stable security definer set search_path to 'public'
as $$
declare
  v_lim int := least(greatest(coalesce(p_limite, 5000), 1), 20000);
begin
  perform public.exigir_permissao('portaria.visualizar');

  return query
    select ev.tipo, ev.data_evento, ev.local, fi.nome,
           rr.nome, r.nome, a.nome, s.nome, c.nome,
           m.nome, m.congregacao, ca.nome, i.nome, f.nome,
           m.cidade, m.bairro, m.visitante,
           pr.status, pr.hora_entrada, pr.hora_saida,
           case when pr.portaria_id is null then 'ANTIGO' else pr.origem end,
           u.nome,
           count(*) over ()
    from public.presencas pr
    join public.eventos ev on ev.id = pr.evento_id and ev.excluido_em is null
    join public.membros m on m.id = pr.membro_id
    left join public.finalidades_evento fi on fi.id = ev.finalidade_id
    left join public.casas_oracao c on c.id = ev.casa_oracao_id
    left join public.setores s on s.id = c.setor_id
    left join public.adms a on a.id = c.adm_id
    left join public.ras r on r.id = a.ra_id
    left join public.rrms rr on rr.id = r.rrm_id
    left join public.cargos ca on ca.id = m.cargo_id
    left join public.instrumentos i on i.id = m.instrumento_id
    left join public.familias f on f.id = i.familia_id
    left join public.usuarios u on u.id = pr.registrado_por
    where pr.excluido_em is null
      and public.casa_oracao_na_abrangencia(ev.casa_oracao_id)
      and (p_inicio is null or ev.data_evento >= p_inicio)
      and (p_fim is null or ev.data_evento < p_fim)
      and (p_evento is null or pr.evento_id = p_evento)
      and (p_rrm is null or rr.id = p_rrm)
      and (p_regiao is null or r.id = p_regiao)
      and (p_adm is null or a.id = p_adm)
      and (p_setor is null or s.id = p_setor)
      and (p_casa_oracao is null or c.id = p_casa_oracao)
      and (nullif(p_status, '') is null or pr.status = p_status)
    order by ev.data_evento desc, ev.id, m.nome
    limit v_lim;
end;
$$;

-- ---------------------------------------------------------------------------
-- Membros
-- ---------------------------------------------------------------------------
create function public.relatorio_membros(
  p_regiao uuid, p_setor uuid, p_casa_oracao uuid, p_cargo uuid, p_instrumento uuid,
  p_status text, p_visitante text, p_limite integer, p_rrm uuid default null, p_adm uuid default null)
returns table (nome text, cargo text, instrumento text, familia text, rrm text, regiao text, adm text, setor text,
               casa_oracao text, cidade text, bairro text, status text, visitante boolean, data_nascimento date,
               cadastrado_em timestamptz, cpf_parcial text, total bigint)
language plpgsql stable security definer set search_path to 'public'
as $$
declare
  v_lim int := least(greatest(coalesce(p_limite, 5000), 1), 20000);
  v_cpf boolean;
begin
  perform public.exigir_permissao('membros.visualizar');
  v_cpf := public.tem_permissao('membros.cpf');

  return query
    select m.nome, ca.nome, i.nome, f.nome, rr.nome, r.nome, a.nome, s.nome, c.nome,
           m.cidade, m.bairro, m.status, m.visitante, m.data_nascimento,
           m.data_cadastro,
           case when v_cpf then m.cpf_mascarado end,
           count(*) over ()
    from public.membros m
    left join public.casas_oracao c on c.id = m.casa_oracao_id
    left join public.setores s on s.id = c.setor_id
    left join public.adms a on a.id = c.adm_id
    left join public.ras r on r.id = a.ra_id
    left join public.rrms rr on rr.id = r.rrm_id
    left join public.cargos ca on ca.id = m.cargo_id
    left join public.instrumentos i on i.id = m.instrumento_id
    left join public.familias f on f.id = i.familia_id
    where m.excluido_em is null
      and public.casa_oracao_na_abrangencia(m.casa_oracao_id)
      and (p_rrm is null or rr.id = p_rrm)
      and (p_regiao is null or r.id = p_regiao)
      and (p_adm is null or a.id = p_adm)
      and (p_setor is null or s.id = p_setor)
      and (p_casa_oracao is null or c.id = p_casa_oracao)
      and (p_cargo is null or m.cargo_id = p_cargo)
      and (p_instrumento is null or m.instrumento_id = p_instrumento)
      and (nullif(p_status, '') is null or m.status = p_status)
      and (nullif(p_visitante, '') is null
           or (p_visitante = 'sim' and m.visitante)
           or (p_visitante = 'nao' and not m.visitante))
    order by m.nome
    limit v_lim;
end;
$$;

-- ---------------------------------------------------------------------------
-- Eventos
-- ---------------------------------------------------------------------------
create function public.relatorio_eventos(
  p_inicio timestamptz, p_fim timestamptz, p_regiao uuid, p_setor uuid, p_casa_oracao uuid, p_limite integer,
  p_rrm uuid default null, p_adm uuid default null)
returns table (tipo text, data_evento timestamptz, local_evento text, finalidade text, cidade text, rrm text,
               regiao text, adm text, setor text, casa_oracao text, registros bigint, presentes bigint, portaria text,
               total bigint)
language plpgsql stable security definer set search_path to 'public'
as $$
declare
  v_lim int := least(greatest(coalesce(p_limite, 5000), 1), 20000);
begin
  perform public.exigir_permissao('eventos.visualizar');

  return query
    select ev.tipo, ev.data_evento, ev.local, fi.nome, ev.cidade,
           rr.nome, r.nome, a.nome, s.nome, c.nome,
           (select count(*) from public.presencas pr
             where pr.evento_id = ev.id and pr.excluido_em is null),
           (select count(*) from public.presencas pr
             where pr.evento_id = ev.id and pr.excluido_em is null and pr.status = 'Presente'),
           (select case po.status when 'APROVADA' then 'Aprovada' when 'PENDENTE_APROVACAO' then 'Pendente'
                                  when 'REJEITADA' then 'Rejeitada' end
              from public.portarias po
             where po.evento_id = ev.id and po.excluido_em is null
             order by po.criada_em desc limit 1),
           count(*) over ()
    from public.eventos ev
    left join public.finalidades_evento fi on fi.id = ev.finalidade_id
    left join public.casas_oracao c on c.id = ev.casa_oracao_id
    left join public.setores s on s.id = c.setor_id
    left join public.adms a on a.id = c.adm_id
    left join public.ras r on r.id = a.ra_id
    left join public.rrms rr on rr.id = r.rrm_id
    where ev.excluido_em is null
      and public.casa_oracao_na_abrangencia(ev.casa_oracao_id)
      and (p_inicio is null or ev.data_evento >= p_inicio)
      and (p_fim is null or ev.data_evento < p_fim)
      and (p_rrm is null or rr.id = p_rrm)
      and (p_regiao is null or r.id = p_regiao)
      and (p_adm is null or a.id = p_adm)
      and (p_setor is null or s.id = p_setor)
      and (p_casa_oracao is null or c.id = p_casa_oracao)
    order by ev.data_evento desc, ev.id
    limit v_lim;
end;
$$;

-- Acesso: só usuários logados (e o servidor); o visitante sem login não executa relatórios
revoke execute on function public.relatorio_presencas(timestamptz, timestamptz, uuid, uuid, uuid, uuid, text, integer, uuid, uuid) from public, anon;
revoke execute on function public.relatorio_membros(uuid, uuid, uuid, uuid, uuid, text, text, integer, uuid, uuid) from public, anon;
revoke execute on function public.relatorio_eventos(timestamptz, timestamptz, uuid, uuid, uuid, integer, uuid, uuid) from public, anon;
grant execute on function public.relatorio_presencas(timestamptz, timestamptz, uuid, uuid, uuid, uuid, text, integer, uuid, uuid) to authenticated, service_role;
grant execute on function public.relatorio_membros(uuid, uuid, uuid, uuid, uuid, text, text, integer, uuid, uuid) to authenticated, service_role;
grant execute on function public.relatorio_eventos(timestamptz, timestamptz, uuid, uuid, uuid, integer, uuid, uuid) to authenticated, service_role;

commit;
select set_config('sysmusica.migracao_0048', 'ok', false);
