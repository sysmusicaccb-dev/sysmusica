-- 0058 — Organização: as contagens (ex.: "3 RRMs") passam a contar só o que o usuário enxerga.
-- Antes, o Jerrivan via "Bahia 3 RRMs" mesmo enxergando só a RRM Itabuna: o número somava todas as regiões.
-- Agora cada "qtd_filhos" é o número de itens VISÍVEIS para quem consulta. O administrador global continua vendo tudo.
-- Seguro rodar mais de uma vez. Reverter: supabase/rollback/0058_reverter.sql

begin;

create or replace function public.listar_organizacao()
 returns table(nivel text, id uuid, parent_id uuid, nome text, descricao text, ativo boolean, cidade text, bairro text, qtd_filhos bigint, qtd_membros bigint)
 language plpgsql
 stable security definer
 set search_path to 'public'
as $function$
declare
  v_global boolean := public.tem_acesso_total_organizacao();
begin
  perform public.exigir_alguma_permissao(array['organizacao.visualizar', 'usuarios.vinculos', 'usuarios.editar']);
  return query
    with todos(tn, ti, tp, tnome, tdesc, tativo, tcid, tbai, tmem) as (
      select 'ESTADO'::text, e.id, null::uuid, e.nome, null::text, e.ativo, null::text, null::text, 0::bigint
      from public.estados e
      union all
      select 'RRM'::text, rr.id, rr.estado_id, rr.nome, rr.descricao, rr.ativo, null::text, null::text, 0::bigint
      from public.rrms rr
      union all
      select 'RA'::text, ra.id, ra.rrm_id, ra.nome, ra.descricao, ra.ativo, null::text, null::text, 0::bigint
      from public.ras ra
      union all
      select 'ADM'::text, a.id, a.ra_id, a.nome, a.descricao, a.ativo, null::text, null::text, 0::bigint
      from public.adms a
      union all
      select 'SETOR'::text, s.id, s.adm_id, s.nome, s.descricao, s.ativo, null::text, null::text, 0::bigint
      from public.setores s
      union all
      select 'CASA_ORACAO'::text, c.id, coalesce(c.setor_id, c.adm_id), c.nome, null::text, c.ativo, c.cidade, c.bairro,
             (select count(*) from public.membros m where m.casa_oracao_id = c.id and m.excluido_em is null)
      from public.casas_oracao c
    ),
    -- Os vínculos de quem chama e os níveis acima deles (para a árvore poder ser desenhada até o item)
    meus_nos(mn, mi) as (
      select c.r_nivel, c.r_id
        from public.usuario_vinculos v
        cross join lateral public.cadeia_organizacao(v.nivel, v.alvo_id) c
       where v.usuario_id = (select auth.uid())
    ),
    visiveis as (
      select t.*
        from todos t
       where v_global
          or public.alvo_na_minha_abrangencia(t.tn, t.ti)
          or exists (select 1 from meus_nos m where m.mn = t.tn and m.mi = t.ti)
    )
    select t.tn, t.ti, t.tp, t.tnome, t.tdesc, t.tativo, t.tcid, t.tbai,
           -- filhos VISÍVEIS (uma casa de oração não tem filhos)
           (select count(*) from visiveis f where f.tp = t.ti and t.tn <> 'CASA_ORACAO'),
           t.tmem
      from visiveis t;
end;
$function$;

do $$
begin
  if (select prosrc from pg_proc where oid = 'public.listar_organizacao()'::regprocedure) not like '%visiveis%' then
    raise exception 'Verificação falhou: listar_organizacao não foi atualizada.';
  end if;
end $$;

commit;
