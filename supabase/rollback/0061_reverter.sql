-- Reverte a 0061: remove as travas de catálogo e volta o grupo_concedivel ao da 0054.
-- (As permissões de catálogo retiradas do Administrador Regional voltam rodando de novo a 0055.)
begin;
do $$
declare t text;
begin
  foreach t in array array['instrumentos', 'familias', 'hinos', 'tipos_evento'] loop
    if to_regclass('public.' || t) is not null then
      execute format('drop trigger if exists a0_catalogo_global on public.%I', t);
    end if;
  end loop;
end $$;
create or replace function public.grupo_concedivel(p_grupo uuid)
returns boolean language sql stable security definer set search_path to 'public' as $function$
  select public.tem_acesso_total_organizacao()
      or (
        exists (select 1 from public.grupos g where g.id = p_grupo and g.ativo)
        and not exists (select 1 from public.grupo_permissoes gp
                         where gp.grupo_id = p_grupo
                           and not public.tem_permissao(gp.permissao_codigo))
      )
$function$;
drop function if exists public.catalogo_exigir_global();
drop function if exists public.permissao_de_catalogo(text);
commit;
