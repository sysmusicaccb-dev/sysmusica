-- Sysmusica — Migração 0050: regras automáticas por cargo nos cadastros enviados pelo formulário PÚBLICO.
-- Ancião, Diácono, Cooperadores, Encarregados, Instrutor(a), Secretário da Música e Examinadora são batizados;
-- Encarregado Regional e Examinadora são casados; Músico/Organista de Oficializado e Culto Oficial são batizados.
-- A tela já preenche e trava esses campos; aqui o banco recusa um envio feito fora da tela que contrarie o cargo.
-- Vale só para NOVOS pedidos (insert em cadastros_pendentes): cadastros e membros antigos não são tocados.
-- Para mudar as regras: edite regra_cargo_cadastro abaixo e src/modules/membros/regrasCargo.ts (mesma lista).

create or replace function public.regra_cargo_cadastro(p_nome text, p_categoria text)
returns table (batizado boolean, casado boolean)
language plpgsql immutable set search_path to 'public'
as $$
declare
  v text := public.normalizar_texto(coalesce(p_nome, ''));
begin
  batizado := false; casado := false;
  if v ~ '^(anciao|diacono|cooperador|encarregado regional|examinadora)' then
    batizado := true; casado := true;
  elsif v ~ '^(encarregado local|instrutor|secretario)' then
    batizado := true;
  elsif v ~ '^(musico|organista)' then
    batizado := coalesce(p_categoria, '') in ('OFICIALIZADO', 'CULTO_OFICIAL');
  end if;
  return next;
end;
$$;

create or replace function public.cadastro_pendente_confere_regras()
returns trigger
language plpgsql set search_path to 'public'
as $$
declare
  v_nome   text;
  v_regra  record;
begin
  if new.cargo_id is null then return new; end if;
  select c.nome into v_nome from public.cargos c where c.id = new.cargo_id;
  if v_nome is null then return new; end if;
  select * into v_regra from public.regra_cargo_cadastro(v_nome, new.categoria);

  if v_regra.batizado and coalesce(new.dados ->> 'batizado', '') <> 'true' then
    raise exception 'Para o cargo %, a pessoa precisa ser batizada. Atualize a página e tente de novo.', v_nome;
  end if;
  if v_regra.casado and coalesce(new.dados ->> 'estado_civil', '') <> 'Casado (a)' then
    raise exception 'Para o cargo %, o estado civil precisa ser Casado (a). Atualize a página e tente de novo.', v_nome;
  end if;
  return new;
end;
$$;

drop trigger if exists cadastro_pendente_regras_cargo on public.cadastros_pendentes;
create trigger cadastro_pendente_regras_cargo
  before insert on public.cadastros_pendentes
  for each row execute function public.cadastro_pendente_confere_regras();

revoke all on function public.regra_cargo_cadastro(text, text) from public, anon, authenticated;
revoke all on function public.cadastro_pendente_confere_regras() from public, anon, authenticated;

-- Verificação: confere as regras e o gatilho; se algo estiver errado, a migração inteira é desfeita.
do $$
begin
  if not (select batizado and casado from public.regra_cargo_cadastro('Encarregado Regional', '')) then
    raise exception 'Verificação falhou: Encarregado Regional deveria ser batizado e casado.';
  end if;
  if (select casado from public.regra_cargo_cadastro('Encarregado Local', '')) then
    raise exception 'Verificação falhou: Encarregado Local não deveria exigir casado.';
  end if;
  if not (select batizado from public.regra_cargo_cadastro('Músico', 'CULTO_OFICIAL'))
     or (select batizado from public.regra_cargo_cadastro('Músico', 'RJM')) then
    raise exception 'Verificação falhou: regra de Músico por categoria.';
  end if;
  if not exists (select 1 from pg_trigger where tgname = 'cadastro_pendente_regras_cargo' and not tgisinternal) then
    raise exception 'Verificação falhou: o gatilho não foi criado.';
  end if;
end $$;
