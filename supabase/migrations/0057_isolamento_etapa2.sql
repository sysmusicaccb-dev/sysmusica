-- 0057 — Isolamento regional, ETAPA 2: alterações "por ID" só dentro da região.
-- O que muda:
--  * Trava no banco (gatilho) em eventos, portarias, presenças e entradas sem cadastro: qualquer UPDATE/DELETE
--    só passa se o evento/casa estiver na abrangência de quem executa. Cobre excluir_evento, cancelar_evento,
--    reabrir_evento, excluir_portaria, excluir_presenca, desfazer_entrada_avulsa e as que forem criadas depois.
--  * excluir_membro e obter_cpf_membro passam a conferir a região do membro.
--  Quem não tem usuário logado (restauração de backup, rotinas do sistema) e o administrador global não são afetados.
-- Seguro rodar mais de uma vez. Reverter: supabase/rollback/0057_reverter.sql
-- Pendente para a 0058 (precisa do código atual): obter_qr_membro e regenerar_qr.

begin;

-- ============================================================ A) Trava por gatilho
-- (o gatilho se chama a0_... para rodar ANTES dos demais e dar a mensagem de região primeiro)
create or replace function public.regiao_exigir_escopo()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_ok boolean;
begin
  -- Rotinas do sistema (sem usuário), restauração de backup e exclusão de estrutura já autorizada não passam por esta trava
  if (select auth.uid()) is null
     or coalesce(current_setting('sysmusica.restaurando', true), '') <> ''
     or coalesce(current_setting('sysmusica.org_excluindo', true), '') = 'sim' then
    return coalesce(new, old);
  end if;

  if tg_table_name in ('eventos', 'portarias') then
    v_ok := public.casa_oracao_na_abrangencia(old.casa_oracao_id);
  else  -- presencas, presencas_avulsas: herdam a região do evento
    v_ok := public.evento_na_abrangencia(old.evento_id);
  end if;

  if not coalesce(v_ok, false) then
    raise exception 'Este registro está fora da sua abrangência.' using errcode = '42501';
  end if;
  return coalesce(new, old);
end;
$function$;

drop trigger if exists a0_regiao_escopo on public.eventos;
create trigger a0_regiao_escopo before update or delete on public.eventos
  for each row execute function public.regiao_exigir_escopo();
drop trigger if exists a0_regiao_escopo on public.portarias;
create trigger a0_regiao_escopo before update or delete on public.portarias
  for each row execute function public.regiao_exigir_escopo();
drop trigger if exists a0_regiao_escopo on public.presencas;
create trigger a0_regiao_escopo before update or delete on public.presencas
  for each row execute function public.regiao_exigir_escopo();
drop trigger if exists a0_regiao_escopo on public.presencas_avulsas;
create trigger a0_regiao_escopo before update or delete on public.presencas_avulsas
  for each row execute function public.regiao_exigir_escopo();

-- ============================================================ B) Membros por ID
create or replace function public.excluir_membro(p_id uuid)
 returns void
 language plpgsql
 security definer
 set search_path to 'public'
as $function$
begin
  perform public.exigir_permissao('membros.excluir');

  -- Região: só exclui membro de uma casa da própria abrangência
  if not exists (select 1 from public.membros m
                  where m.id = p_id and m.excluido_em is null
                    and public.casa_oracao_na_abrangencia(m.casa_oracao_id)) then
    if exists (select 1 from public.membros m where m.id = p_id and m.excluido_em is null) then
      raise exception 'Este membro está fora da sua abrangência.' using errcode = '42501';
    end if;
    raise exception 'Membro não encontrado.';
  end if;

  update public.membros set excluido_em = now() where id = p_id and excluido_em is null;
  if not found then
    raise exception 'Membro não encontrado.';
  end if;
end;
$function$;

create or replace function public.obter_cpf_membro(p_id uuid)
 returns text
 language plpgsql
 security definer
 set search_path to 'public'
as $function$
declare
  v_cpf text;
begin
  perform public.exigir_permissao('membros.cpf');

  -- Região: só mostra o CPF de membro de uma casa da própria abrangência
  if exists (select 1 from public.membros m where m.id = p_id and m.excluido_em is null)
     and not exists (select 1 from public.membros m
                      where m.id = p_id and m.excluido_em is null
                        and public.casa_oracao_na_abrangencia(m.casa_oracao_id)) then
    raise exception 'Este membro está fora da sua abrangência.' using errcode = '42501';
  end if;

  select m.cpf into v_cpf from public.membros m where m.id = p_id and m.excluido_em is null;
  if not found then
    raise exception 'Membro não encontrado.';
  end if;

  perform public.registrar_auditoria('cpf_visualizado', 'membro', p_id, '{}'::jsonb);
  return v_cpf;
end;
$function$;

-- ============================================================ C) Verificação
do $$
begin
  if (select count(*) from pg_trigger where tgname = 'a0_regiao_escopo' and not tgisinternal) <> 4 then
    raise exception 'Verificação falhou: gatilhos de região incompletos.';
  end if;
  if (select prosrc from pg_proc where oid = 'public.obter_cpf_membro(uuid)'::regprocedure) not like '%casa_oracao_na_abrangencia%'
     or (select prosrc from pg_proc where oid = 'public.excluir_membro(uuid)'::regprocedure) not like '%casa_oracao_na_abrangencia%' then
    raise exception 'Verificação falhou: funções de membro não foram atualizadas.';
  end if;
end $$;

commit;
