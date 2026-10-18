-- =====================================================================
-- SysMúsica — Migração 0019: preferências de aparência de cada usuário
--   * Cada usuário guarda o modo (claro, escuro ou automático), a cor principal e o tamanho da letra.
--   * A tabela só é lida e gravada pelas funções abaixo (cada pessoa só enxerga e altera as próprias).
--   * Sem esta migração o sistema funciona do mesmo jeito, mas a aparência fica salva só no aparelho.
-- Requer a migração 0002. Idempotente, uma única transação.
-- Ao final, a migração TESTA a gravação e a recusa de valores inválidos: se algo falhar, tudo é desfeito.
-- =====================================================================
begin;

do $$
begin
  if to_regprocedure('public.tem_acesso()') is null then
    raise exception 'Aplique primeiro as migrações anteriores (falta a função tem_acesso).';
  end if;
end $$;

-- 1) TABELA (sem acesso direto: só pelas funções abaixo)
create table if not exists public.usuario_preferencias (
  usuario_id    uuid primary key references public.usuarios (id) on delete cascade,
  tema          text not null default 'claro'  check (tema  in ('claro', 'escuro', 'sistema')),
  cor           text not null default 'indigo' check (cor   in ('indigo', 'azul', 'verde', 'vinho', 'grafite')),
  fonte         text not null default 'normal' check (fonte in ('normal', 'media', 'grande')),
  atualizado_em timestamptz not null default now()
);

alter table public.usuario_preferencias enable row level security;
revoke all on public.usuario_preferencias from anon, authenticated;

-- 2) LER AS PRÓPRIAS PREFERÊNCIAS (sem linha = ainda não escolheu nada: o sistema usa o padrão)
create or replace function public.minhas_preferencias()
returns table (tema text, cor text, fonte text)
language sql stable security definer set search_path = public as $$
  select p.tema, p.cor, p.fonte
  from public.usuario_preferencias p
  where p.usuario_id = (select auth.uid())
$$;

-- 3) SALVAR AS PRÓPRIAS PREFERÊNCIAS (confere os valores; quem não tem acesso ao sistema não grava)
create or replace function public.salvar_preferencias(p_tema text, p_cor text, p_fonte text)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.tem_acesso() then
    raise exception 'Sem acesso.' using errcode = '42501';
  end if;
  if p_tema is null or p_tema not in ('claro', 'escuro', 'sistema')
     or p_cor is null or p_cor not in ('indigo', 'azul', 'verde', 'vinho', 'grafite')
     or p_fonte is null or p_fonte not in ('normal', 'media', 'grande') then
    raise exception 'Preferência inválida.';
  end if;

  insert into public.usuario_preferencias (usuario_id, tema, cor, fonte)
  values ((select auth.uid()), p_tema, p_cor, p_fonte)
  on conflict (usuario_id) do update
    set tema = excluded.tema, cor = excluded.cor, fonte = excluded.fonte, atualizado_em = now();
end;
$$;

-- 4) PERMISSÕES DE EXECUÇÃO
revoke all on function public.minhas_preferencias(), public.salvar_preferencias(text, text, text)
  from public, anon;
grant execute on function public.minhas_preferencias(), public.salvar_preferencias(text, text, text)
  to authenticated;

-- 5) VERIFICAÇÃO DE SEGURANÇA: testa que um valor inválido é recusado. Se falhar, a migração INTEIRA é desfeita.
do $$
declare
  v_admin uuid;
begin
  select u.id into v_admin
  from public.usuarios u join public.grupos g on g.id = u.grupo_id
  where g.sistema and g.nome = 'Administrador' and u.ativo
  limit 1;

  if v_admin is null then
    return;  -- ainda não há administrador: nada a testar
  end if;

  perform set_config('request.jwt.claims', json_build_object('sub', v_admin, 'role', 'authenticated')::text, true);

  perform count(*) from public.minhas_preferencias();

  begin
    perform public.salvar_preferencias('xyz', 'indigo', 'normal');
    raise exception 'sysmusica_sem_bloqueio';
  exception when others then
    if sqlerrm <> 'Preferência inválida.' then
      raise exception 'Verificação falhou (teste das preferências): %', sqlerrm;
    end if;
  end;

  perform set_config('request.jwt.claims', '', true);
end $$;

commit;
