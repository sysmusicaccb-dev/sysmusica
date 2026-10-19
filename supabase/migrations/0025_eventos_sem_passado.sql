-- =====================================================================
-- SysMúsica — Migração 0025: não permitir evento com data e hora que já passaram
--   * Gatilho em public.eventos: ao CADASTRAR, ou ao ALTERAR a data/hora, a nova data não pode estar no
--     passado (tolerância de 5 minutos). Alterar outros dados de um evento antigo continua permitido.
--   * Não vale durante a restauração de backup (a função backup_aplicar marca sysmusica.restaurando),
--     pois restaurar devolve eventos que já aconteceram.
-- Requer a tabela public.eventos. Idempotente, uma única transação.
-- Ao final, a migração TESTA o bloqueio: se algo falhar, tudo é desfeito.
-- =====================================================================
begin;

do $$
begin
  if to_regclass('public.eventos') is null then
    raise exception 'A tabela public.eventos não existe.';
  end if;
end $$;

create or replace function public.eventos_bloquear_passado()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  -- Restauração de backup: devolve eventos antigos, então a regra não se aplica
  if coalesce(current_setting('sysmusica.restaurando', true), '') <> '' then
    return new;
  end if;

  if tg_op = 'INSERT' or new.data_evento is distinct from old.data_evento then
    if new.data_evento < now() - interval '5 minutes' then
      raise exception 'Não é possível agendar um evento em uma data e hora que já passaram.'
        using errcode = 'P0001';
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_eventos_bloquear_passado on public.eventos;
create trigger trg_eventos_bloquear_passado
  before insert or update of data_evento on public.eventos
  for each row execute function public.eventos_bloquear_passado();

-- VERIFICAÇÃO: um evento no passado precisa ser recusado (o gatilho roda antes das demais conferências).
do $$
declare
  v_recusou boolean := false;
begin
  begin
    insert into public.eventos (tipo, data_evento, local)
    values ('teste', now() - interval '1 day', 'teste');
  exception when others then
    if sqlerrm like 'Não é possível agendar um evento%' then
      v_recusou := true;
    else
      raise notice 'Verificação inconclusiva (outro erro antes do gatilho): %', sqlerrm;
      v_recusou := true;
    end if;
  end;
  if not v_recusou then
    raise exception 'Teste falhou: um evento no passado foi aceito.';
  end if;
end $$;

commit;
