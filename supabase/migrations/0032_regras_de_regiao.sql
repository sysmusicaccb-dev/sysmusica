-- 0032 — Corrige as regras de acesso por região de eventos e membros
-- A migração 0031 recriou regiao_eventos e regiao_membros como regras comuns (permissivas, para todos os papéis).
-- O correto é o mesmo de regiao_presencas: RESTRITIVAS e só para usuários logados (authenticated).
-- Sem isso, eventos e membros já excluídos reapareciam nas telas e quem tinha abrangência passava por cima
-- das permissões de editar/excluir.
drop policy if exists regiao_eventos on public.eventos;
drop policy if exists regiao_membros on public.membros;

create policy regiao_eventos on public.eventos
  as restrictive for all to authenticated
  using (public.casa_oracao_na_abrangencia(casa_oracao_id))
  with check (public.casa_oracao_na_abrangencia(casa_oracao_id));

create policy regiao_membros on public.membros
  as restrictive for all to authenticated
  using (public.casa_oracao_na_abrangencia(casa_oracao_id))
  with check (public.casa_oracao_na_abrangencia(casa_oracao_id));

do $$
begin
  if (select count(*) from pg_policies
       where schemaname = 'public' and policyname in ('regiao_eventos', 'regiao_membros')
         and permissive = 'RESTRICTIVE' and roles = '{authenticated}') <> 2 then
    raise exception 'As regras de região não ficaram restritivas. Nada foi alterado.';
  end if;
  raise notice 'OK: regras de região de eventos e membros agora são restritivas (só autenticados).';
end $$;
