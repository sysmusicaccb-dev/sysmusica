-- Reverte a 0056: devolve pode_ver_portaria à definição anterior (sem trava regional nas regras 1 e 2).
begin;

create or replace function public.pode_ver_portaria(p_id uuid)
 returns boolean
 language sql
 stable security definer
 set search_path to 'public'
as $function$
  select exists (
    select 1 from public.portarias p
    where p.id = p_id and p.excluido_em is null
      and (
        p.criada_por = (select auth.uid())
        or public.tem_permissao('portarias.visualizar')
        or (public.tem_permissao('portarias.aprovar') and public.casa_oracao_na_abrangencia(p.casa_oracao_id))
        or (public.tem_permissao('portaria.registrar') and p.status = 'APROVADA'
            and public.casa_oracao_na_abrangencia(p.casa_oracao_id))
      )
  )
$function$;

commit;
