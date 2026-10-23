-- Reverte a 0057: remove as travas por gatilho e devolve excluir_membro e obter_cpf_membro ao código anterior.
begin;

drop trigger if exists a0_regiao_escopo on public.eventos;
drop trigger if exists a0_regiao_escopo on public.portarias;
drop trigger if exists a0_regiao_escopo on public.presencas;
drop trigger if exists a0_regiao_escopo on public.presencas_avulsas;
drop function if exists public.regiao_exigir_escopo();

create or replace function public.excluir_membro(p_id uuid)
 returns void
 language plpgsql
 security definer
 set search_path to 'public'
as $function$
begin
  perform public.exigir_permissao('membros.excluir');

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

  select m.cpf into v_cpf from public.membros m where m.id = p_id and m.excluido_em is null;
  if not found then
    raise exception 'Membro não encontrado.';
  end if;

  perform public.registrar_auditoria('cpf_visualizado', 'membro', p_id, '{}'::jsonb);
  return v_cpf;
end;
$function$;

commit;
