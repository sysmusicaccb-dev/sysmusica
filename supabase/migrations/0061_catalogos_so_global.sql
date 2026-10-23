-- 0061 — Catálogos compartilhados (instrumentos, famílias, hinos, tipos de evento): só o Administrador global altera.
--  * Gatilho a0_catalogo_global nas 4 tabelas: criar/alterar/excluir exige acesso global (quem não tem recebe aviso claro).
--    Ver e usar os itens continua liberado para todas as regiões. Rotinas do sistema e restauração de backup não são afetadas.
--  * O Administrador Regional perde as permissões de criar/editar/excluir desses catálogos (os botões somem para ele).
--  * grupo_concedivel passa a IGNORAR essas permissões: o Regional continua podendo conceder Secretaria etc. aos usuários dele.
-- Seguro rodar mais de uma vez. Reverter: supabase/rollback/0061_reverter.sql
-- ATENÇÃO: se rodar a 0055 de novo depois desta, ela devolve as permissões ao Regional; rode esta 0061 em seguida.

begin;

-- A) Quais permissões são "escrita em catálogo compartilhado"
create or replace function public.permissao_de_catalogo(p_codigo text)
returns boolean
language sql
immutable
set search_path to 'public'
as $function$
  select p_codigo ~ '^(instrumentos|familias|hinos|tipoevento|tipos_evento)\.'
     and p_codigo not like '%.visualizar';
$function$;

-- B) Trava no banco: vale para qualquer caminho de escrita
create or replace function public.catalogo_exigir_global()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $function$
begin
  if (select auth.uid()) is null
     or coalesce(current_setting('sysmusica.restaurando', true), '') <> ''
     or public.tem_acesso_total_organizacao() then
    return coalesce(new, old);
  end if;
  raise exception 'Este cadastro é compartilhado por todas as regiões. Somente o Administrador pode alterá-lo. Peça a ele a inclusão ou a mudança.'
    using errcode = '42501';
end;
$function$;

do $$
declare t text;
begin
  foreach t in array array['instrumentos', 'familias', 'hinos', 'tipos_evento'] loop
    if to_regclass('public.' || t) is not null then
      execute format('drop trigger if exists a0_catalogo_global on public.%I', t);
      execute format('create trigger a0_catalogo_global before insert or update or delete on public.%I for each row execute function public.catalogo_exigir_global()', t);
    end if;
  end loop;
end $$;

-- C) O Administrador Regional deixa de ter as permissões de escrita nos catálogos
delete from public.grupo_permissoes gp
 using public.grupos g
 where g.id = gp.grupo_id and g.nome = 'Administrador Regional'
   and public.permissao_de_catalogo(gp.permissao_codigo);

-- D) Conceder grupo: não exige que o concedente tenha as permissões de catálogo (a trava do banco já vale para todos)
create or replace function public.grupo_concedivel(p_grupo uuid)
returns boolean
language sql
stable
security definer
set search_path to 'public'
as $function$
  select public.tem_acesso_total_organizacao()
      or (
        exists (select 1 from public.grupos g where g.id = p_grupo and g.ativo)
        and not exists (select 1 from public.grupo_permissoes gp
                         where gp.grupo_id = p_grupo
                           and not public.permissao_de_catalogo(gp.permissao_codigo)
                           and not public.tem_permissao(gp.permissao_codigo))
      )
$function$;

revoke all on function public.permissao_de_catalogo(text), public.catalogo_exigir_global() from public, anon;
grant execute on function public.permissao_de_catalogo(text) to authenticated;

do $$
begin
  if (select count(*) from pg_trigger where tgname = 'a0_catalogo_global' and not tgisinternal) < 1 then
    raise exception 'Verificação falhou: nenhuma trava de catálogo foi criada.';
  end if;
  if exists (select 1 from public.grupo_permissoes gp join public.grupos g on g.id = gp.grupo_id
              where g.nome = 'Administrador Regional' and public.permissao_de_catalogo(gp.permissao_codigo)) then
    raise exception 'Verificação falhou: o Regional ainda tem permissões de catálogo.';
  end if;
end $$;

commit;
