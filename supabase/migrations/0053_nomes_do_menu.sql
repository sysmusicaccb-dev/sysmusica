-- 0053 — Nomes do menu editáveis pelo usuário Master (Levi Alencar).
-- O nome personalizado vale para TODOS os usuários. Sem nome personalizado, vale o nome padrão do código.
-- Só o Master grava; qualquer usuário logado lê. Seguro rodar mais de uma vez.
-- Para trocar quem é o Master: altere o e-mail em public.usuario_master() abaixo.

create table if not exists public.menu_rotulos (
  href          text primary key check (char_length(href) between 1 and 120),
  rotulo        text not null check (char_length(btrim(rotulo)) between 1 and 40),
  atualizado_em timestamptz not null default now(),
  atualizado_por uuid
);
alter table public.menu_rotulos enable row level security;
-- Ninguém acessa a tabela direto: leitura e gravação passam pelas funções abaixo.
revoke all on public.menu_rotulos from anon, authenticated;

create or replace function public.usuario_master()
returns boolean
language sql
stable
security definer
set search_path to 'public'
as $function$
  select exists (
    select 1 from auth.users u
     where u.id = (select auth.uid())
       and lower(u.email) = 'levialencar@gmail.com'
  );
$function$;

create or replace function public.listar_rotulos_menu()
returns table(href text, rotulo text)
language plpgsql
stable
security definer
set search_path to 'public'
as $function$
begin
  if (select auth.uid()) is null then
    raise exception 'Faça login para continuar.' using errcode = '42501';
  end if;
  return query select m.href, m.rotulo from public.menu_rotulos m order by m.href;
end;
$function$;

create or replace function public.salvar_rotulo_menu(p_href text, p_rotulo text)
returns void
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_texto text := btrim(regexp_replace(coalesce(p_rotulo, ''), '\s+', ' ', 'g'));
begin
  if not public.usuario_master() then
    raise exception 'Somente o administrador Master pode alterar os nomes do menu.' using errcode = '42501';
  end if;
  if p_href is null or char_length(p_href) not between 1 and 120 or left(p_href, 1) <> '/' then
    raise exception 'Item de menu inválido.';
  end if;
  if char_length(v_texto) not between 1 and 40 then
    raise exception 'O nome do menu deve ter de 1 a 40 caracteres.';
  end if;
  insert into public.menu_rotulos (href, rotulo, atualizado_em, atualizado_por)
  values (p_href, v_texto, now(), (select auth.uid()))
  on conflict (href) do update
    set rotulo = excluded.rotulo, atualizado_em = now(), atualizado_por = (select auth.uid());
end;
$function$;

create or replace function public.restaurar_rotulo_menu(p_href text)
returns void
language plpgsql
security definer
set search_path to 'public'
as $function$
begin
  if not public.usuario_master() then
    raise exception 'Somente o administrador Master pode alterar os nomes do menu.' using errcode = '42501';
  end if;
  delete from public.menu_rotulos where href = p_href;
end;
$function$;

revoke all on function public.usuario_master(), public.listar_rotulos_menu(),
  public.salvar_rotulo_menu(text, text), public.restaurar_rotulo_menu(text) from public, anon;
grant execute on function public.usuario_master(), public.listar_rotulos_menu(),
  public.salvar_rotulo_menu(text, text), public.restaurar_rotulo_menu(text) to authenticated;

do $$
begin
  if to_regclass('public.menu_rotulos') is null
     or to_regprocedure('public.salvar_rotulo_menu(text,text)') is null
     or to_regprocedure('public.listar_rotulos_menu()') is null
     or to_regprocedure('public.usuario_master()') is null then
    raise exception 'Verificação falhou: estrutura dos nomes do menu incompleta.';
  end if;
end $$;
