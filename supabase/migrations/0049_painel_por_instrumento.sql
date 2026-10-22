-- =====================================================================
-- Sysmusica — Migração 0049: Painel de Totais com a contagem POR INSTRUMENTO
--
-- A função painel_ao_vivo passa a devolver, além do que já devolvia (total, linhas, instrumentos por família),
-- o campo novo "instrumentos_detalhe": uma lista com família, instrumento e quantidade (ex.: Cordas / Violino / 6).
-- É só um ACRÉSCIMO: a assinatura e os campos antigos continuam iguais, então a tela atual e a impressão
-- não são afetadas. Regra de quem entra na contagem = a mesma do bloco Instrumentos (quem toca; órgão fora).
-- Requer a migração 0031 (casas de oração). Idempotente, uma única transação.
-- Se algo falhar, tudo é desfeito.
-- =====================================================================
begin;

do $$
begin
  if to_regclass('public.casas_oracao') is null
     or to_regclass('public.presencas_avulsas') is null
     or to_regclass('public.linhas_painel') is null
     or to_regprocedure('public.painel_ao_vivo(uuid)') is null then
    raise exception 'Aplique primeiro as migrações até a 0048.';
  end if;
end $$;

create or replace function public.painel_ao_vivo(p_evento_id uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare
  v_evento jsonb;
  v_dados  jsonb;
begin
  perform public.exigir_permissao('painel.visualizar');
  if not public.evento_na_abrangencia(p_evento_id) then
    raise exception 'Evento indisponível para você.' using errcode = '42501';
  end if;

  select jsonb_build_object('id', e.id, 'tipo', e.tipo, 'local', e.local, 'data_evento', e.data_evento,
                            'cidade', e.cidade, 'casa_oracao', c.nome)
    into v_evento
    from public.eventos e
    left join public.casas_oracao c on c.id = e.casa_oracao_id
   where e.id = p_evento_id and e.excluido_em is null;
  if v_evento is null then
    raise exception 'Evento não encontrado.';
  end if;

  with base as (
    -- presenças de membros cadastrados
    select pr.toca, pr.linha_codigo, m.categoria, cg.nome as cargo,
           coalesce(pr.instrumento_id, m.instrumento_id) as instrumento_efetivo
      from public.presencas pr
      join public.membros m on m.id = pr.membro_id
      left join public.cargos cg on cg.id = m.cargo_id
     where pr.evento_id = p_evento_id and pr.excluido_em is null and pr.status = 'Presente'
    union all
    -- entradas SEM cadastro (a linha e o instrumento já vêm escolhidos na Portaria)
    select a.toca, a.linha_codigo, null::text, null::text, a.instrumento_id
      from public.presencas_avulsas a
     where a.evento_id = p_evento_id and a.excluido_em is null
  ), calc as (
    select b.toca, i.nome as instrumento_nome, i.familia_id,
           coalesce(b.linha_codigo, public.classificar_linha(b.cargo, b.categoria, i.nome)) as linha,
           b.instrumento_efetivo
      from base b
      left join public.instrumentos i on i.id = b.instrumento_efetivo
  ), por_linha as (
    select l.codigo, l.bloco, l.rotulo, l.ordem, l.selecionavel, count(c.linha) as qtd
      from public.linhas_painel l
      left join calc c on c.linha = l.codigo
     group by l.codigo, l.bloco, l.rotulo, l.ordem, l.selecionavel
  ), toca as (
    -- quem conta como "tocando" (a mesma regra para família e instrumento)
    select c.instrumento_nome, c.familia_id
      from calc c
      join public.linhas_painel l on l.codigo = c.linha
     where c.instrumento_efetivo is not null
       and not public.instrumento_e_orgao(c.instrumento_nome)
       and (c.toca is true or (c.toca is null and l.toca_sempre))
  ), por_familia as (
    select coalesce(f.nome, 'Sem família') as familia, count(*) as qtd
      from toca t
      left join public.familias f on f.id = t.familia_id
     group by 1
  ), por_instrumento as (
    select coalesce(f.nome, 'Sem família') as familia, t.instrumento_nome as instrumento, count(*) as qtd
      from toca t
      left join public.familias f on f.id = t.familia_id
     group by 1, 2
  )
  select jsonb_build_object(
           'total', (select count(*) from calc),
           'linhas', coalesce((select jsonb_agg(jsonb_build_object('codigo', p.codigo, 'bloco', p.bloco,
                                    'rotulo', p.rotulo, 'ordem', p.ordem, 'qtd', p.qtd, 'selecionavel', p.selecionavel)
                                    order by p.ordem)
                                 from por_linha p where p.selecionavel or p.qtd > 0), '[]'::jsonb),
           'instrumentos', coalesce((select jsonb_agg(jsonb_build_object('familia', f.familia, 'qtd', f.qtd)
                                    order by f.familia) from por_familia f), '[]'::jsonb),
           -- NOVO (0049): contagem por instrumento
           'instrumentos_detalhe', coalesce((select jsonb_agg(jsonb_build_object('familia', i.familia,
                                    'instrumento', i.instrumento, 'qtd', i.qtd)
                                    order by i.familia, i.qtd desc, i.instrumento) from por_instrumento i), '[]'::jsonb))
    into v_dados;

  return v_dados || jsonb_build_object('evento', v_evento, 'atualizado_em', now());
end;
$$;

-- Permissões de execução (iguais às de antes)
revoke all on function public.painel_ao_vivo(uuid) from public, anon;
grant execute on function public.painel_ao_vivo(uuid) to authenticated;

-- VERIFICAÇÃO: a função existe e já contém o campo novo. Se falhar, a migração INTEIRA é desfeita.
do $$
begin
  if to_regprocedure('public.painel_ao_vivo(uuid)') is null
     or (select p.prosrc from pg_proc p where p.oid = 'public.painel_ao_vivo(uuid)'::regprocedure)
        not like '%instrumentos_detalhe%' then
    raise exception 'Teste falhou: painel_ao_vivo não foi atualizada.';
  end if;
end $$;

commit;
