-- 0056 — Portarias só aparecem para quem está na região delas.
-- Problema: pode_ver_portaria liberava a portaria para (a) quem a criou e (b) qualquer um com portarias.visualizar,
-- sem olhar a região. Por isso o Jerrivan (Secretaria/Aprovadores) via portarias de Jequié em Registrar Presença.
-- Correção: TODAS as regras passam a exigir que a casa de oração da portaria esteja na abrangência de quem consulta.
-- (Administrador global continua vendo tudo: casa_oracao_na_abrangencia já devolve verdadeiro para ele.)
-- Esta função alimenta listar_portarias, entradas_da_portaria, historico_portaria e outras telas da Portaria.
-- Seguro rodar mais de uma vez. Reverter: supabase/rollback/0056_reverter.sql

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
      -- trava regional: vale para TODAS as regras abaixo, inclusive para quem criou a portaria
      and public.casa_oracao_na_abrangencia(p.casa_oracao_id)
      and (
        p.criada_por = (select auth.uid())
        or public.tem_permissao('portarias.visualizar')
        or public.tem_permissao('portarias.aprovar')
        or (public.tem_permissao('portaria.registrar') and p.status = 'APROVADA')
      )
  )
$function$;

do $$
begin
  if (select prosrc from pg_proc where oid = 'public.pode_ver_portaria(uuid)'::regprocedure) not like '%casa_oracao_na_abrangencia%' then
    raise exception 'Verificação falhou: pode_ver_portaria não foi atualizada.';
  end if;
end $$;

commit;
