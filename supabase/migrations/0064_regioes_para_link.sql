-- ============================================================================
-- 0064 — Regiões que a pessoa pode usar para gerar o link de cadastro (RRM, RA, ADM da abrangência dela)
-- Alimenta a lista "Gerar link para" da tela Cadastros Pendentes. Só leitura. Para desfazer: 0064_reverter.sql
-- ============================================================================
create or replace function public.regioes_para_link_cadastro()
returns table (nivel text, alvo_id uuid, nome text, caminho text)
language plpgsql stable security definer set search_path = public
as $$
begin
  perform public.exigir_permissao('cadastros.aprovar');
  return query
    select x.nivel, x.alvo_id, x.nome, x.caminho
      from (
        select 'RRM'::text as nivel, r.id as alvo_id, r.nome, ''::text as caminho, 1 as ordem
          from public.rrms r where r.ativo
        union all
        select 'RA', a.id, a.nome, coalesce(r.nome, ''), 2
          from public.ras a left join public.rrms r on r.id = a.rrm_id where a.ativo
        union all
        select 'ADM', d.id, d.nome, concat_ws(' › ', r.nome, a.nome), 3
          from public.adms d left join public.ras a on a.id = d.ra_id left join public.rrms r on r.id = a.rrm_id where d.ativo
      ) x
     where public.alvo_na_minha_abrangencia(x.nivel, x.alvo_id)
     order by x.ordem, x.nome;
end
$$;
revoke all on function public.regioes_para_link_cadastro() from public, anon, authenticated;
grant execute on function public.regioes_para_link_cadastro() to authenticated;
