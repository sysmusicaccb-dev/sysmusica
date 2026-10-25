-- TESTE da 0057 — NÃO GRAVA NADA. Simula o Jerrivan (Administrador Regional) com PODERES EXTRAS (pior caso)
-- e tenta mexer em registros de OUTRA região. Tudo é desfeito no final.
-- Esperado: nenhuma linha FALHOU.

create or replace function pg_temp.tenta(p_sql text)
returns text
language plpgsql
as $f$
begin
  begin
    execute p_sql;
    raise exception using errcode = 'XX999', message = '__reverter__';
  exception when others then
    if sqlerrm = '__reverter__' then return 'PERMITIDO'; end if;
    return 'BLOQUEADO: ' || sqlerrm;
  end;
end
$f$;

create or replace function pg_temp.teste2()
returns table(ordem int, verificacao text, esperado text, obtido text, resultado text)
language plpgsql
as $f$
declare
  v_jer uuid; v_reg uuid;
  v_ev uuid; v_po uuid; v_pr uuid; v_av uuid; v_me uuid;
  v_evd uuid; v_pod uuid;
  v_o text;
  n int := 0;
begin
  select u.id into v_jer from public.usuarios u where lower(u.email) = 'jerrivan@congregacao.org.br';
  select g.id into v_reg from public.grupos g where g.nome = 'Administrador Regional';
  begin
    -- pior caso: o Regional recebe também as permissões de excluir/cancelar/CPF (só nesta simulação)
    insert into public.usuario_grupos (usuario_id, grupo_id) values (v_jer, v_reg) on conflict do nothing;
    insert into public.grupo_permissoes (grupo_id, permissao_codigo)
      select v_reg, p.codigo from public.permissoes p
       where p.codigo in ('eventos.excluir', 'eventos.cancelar', 'portarias.excluir', 'portaria.excluir', 'membros.excluir', 'membros.cpf', 'eventos.editar', 'portaria.editar')
      on conflict do nothing;
    perform set_config('request.jwt.claims', json_build_object('sub', v_jer, 'role', 'authenticated')::text, true);
    perform set_config('request.jwt.claim.sub', v_jer::text, true);

    select e.id into v_ev from public.eventos e where e.excluido_em is null and not public.evento_na_abrangencia(e.id) limit 1;
    select p.id into v_po from public.portarias p where p.excluido_em is null and not public.casa_oracao_na_abrangencia(p.casa_oracao_id) limit 1;
    select x.id into v_pr from public.presencas x where x.excluido_em is null and not public.evento_na_abrangencia(x.evento_id) limit 1;
    select x.id into v_av from public.presencas_avulsas x where x.excluido_em is null and not public.evento_na_abrangencia(x.evento_id) limit 1;
    select m.id into v_me from public.membros m where m.excluido_em is null and not public.casa_oracao_na_abrangencia(m.casa_oracao_id) limit 1;
    select e.id into v_evd from public.eventos e where e.excluido_em is null and public.evento_na_abrangencia(e.id) limit 1;
    select p.id into v_pod from public.portarias p where p.excluido_em is null and public.casa_oracao_na_abrangencia(p.casa_oracao_id) limit 1;

    -- Gatilhos (alteração direta, fora da região): esperado bloqueio com a mensagem de região
    n := n + 1; ordem := n; verificacao := 'Alterar EVENTO de outra região';
    esperado := 'BLOQUEADO'; obtido := case when v_ev is null then 'n/a (sem evento fora da região)' else pg_temp.tenta(format('update public.eventos set excluido_em = excluido_em where id = %L', v_ev)) end;
    resultado := case when v_ev is null then 'INFO' when obtido like 'BLOQUEADO%abrang%' then 'OK' else 'FALHOU' end; return next;

    n := n + 1; ordem := n; verificacao := 'Alterar PORTARIA de outra região';
    esperado := 'BLOQUEADO'; obtido := case when v_po is null then 'n/a (sem portaria fora da região)' else pg_temp.tenta(format('update public.portarias set excluido_em = excluido_em where id = %L', v_po)) end;
    resultado := case when v_po is null then 'INFO' when obtido like 'BLOQUEADO%abrang%' then 'OK' else 'FALHOU' end; return next;

    n := n + 1; ordem := n; verificacao := 'Alterar PRESENÇA de outra região';
    esperado := 'BLOQUEADO'; obtido := case when v_pr is null then 'n/a (sem presença fora da região)' else pg_temp.tenta(format('update public.presencas set excluido_em = excluido_em where id = %L', v_pr)) end;
    resultado := case when v_pr is null then 'INFO' when obtido like 'BLOQUEADO%abrang%' then 'OK' else 'FALHOU' end; return next;

    n := n + 1; ordem := n; verificacao := 'Alterar ENTRADA SEM CADASTRO de outra região';
    esperado := 'BLOQUEADO'; obtido := case when v_av is null then 'n/a (sem entrada avulsa fora da região)' else pg_temp.tenta(format('update public.presencas_avulsas set excluido_em = excluido_em where id = %L', v_av)) end;
    resultado := case when v_av is null then 'INFO' when obtido like 'BLOQUEADO%abrang%' then 'OK' else 'FALHOU' end; return next;

    -- Funções por ID
    n := n + 1; ordem := n; verificacao := 'excluir_evento de outra região';
    esperado := 'BLOQUEADO'; obtido := case when v_ev is null then 'n/a' else pg_temp.tenta(format('select public.excluir_evento(%L)', v_ev)) end;
    resultado := case when v_ev is null then 'INFO' when obtido like 'BLOQUEADO%' then 'OK' else 'FALHOU' end; return next;

    n := n + 1; ordem := n; verificacao := 'cancelar_evento de outra região';
    esperado := 'BLOQUEADO'; obtido := case when v_ev is null then 'n/a' else pg_temp.tenta(format('select public.cancelar_evento(%L, %L)', v_ev, 'teste de isolamento')) end;
    resultado := case when v_ev is null then 'INFO' when obtido like 'BLOQUEADO%' then 'OK' else 'FALHOU' end; return next;

    n := n + 1; ordem := n; verificacao := 'excluir_portaria de outra região';
    esperado := 'BLOQUEADO'; obtido := case when v_po is null then 'n/a' else pg_temp.tenta(format('select public.excluir_portaria(%L)', v_po)) end;
    resultado := case when v_po is null then 'INFO' when obtido like 'BLOQUEADO%' then 'OK' else 'FALHOU' end; return next;

    n := n + 1; ordem := n; verificacao := 'excluir_presenca de outra região';
    esperado := 'BLOQUEADO'; obtido := case when v_pr is null then 'n/a' else pg_temp.tenta(format('select public.excluir_presenca(%L)', v_pr)) end;
    resultado := case when v_pr is null then 'INFO' when obtido like 'BLOQUEADO%' then 'OK' else 'FALHOU' end; return next;

    n := n + 1; ordem := n; verificacao := 'desfazer_entrada_avulsa de outra região';
    esperado := 'BLOQUEADO'; obtido := case when v_av is null then 'n/a' else pg_temp.tenta(format('select public.desfazer_entrada_avulsa(%L)', v_av)) end;
    resultado := case when v_av is null then 'INFO' when obtido like 'BLOQUEADO%' then 'OK' else 'FALHOU' end; return next;

    n := n + 1; ordem := n; verificacao := 'excluir_membro de outra região';
    esperado := 'BLOQUEADO'; obtido := case when v_me is null then 'n/a (sem membro fora da região)' else pg_temp.tenta(format('select public.excluir_membro(%L)', v_me)) end;
    resultado := case when v_me is null then 'INFO' when obtido like 'BLOQUEADO%abrang%' then 'OK' else 'FALHOU' end; return next;

    n := n + 1; ordem := n; verificacao := 'obter_cpf_membro de outra região';
    esperado := 'BLOQUEADO'; obtido := case when v_me is null then 'n/a (sem membro fora da região)' else pg_temp.tenta(format('select public.obter_cpf_membro(%L)', v_me)) end;
    resultado := case when v_me is null then 'INFO' when obtido like 'BLOQUEADO%abrang%' then 'OK' else 'FALHOU' end; return next;

    -- Controles positivos: dentro da própria região continua funcionando
    n := n + 1; ordem := n; verificacao := 'Alterar evento da PRÓPRIA região (deve continuar permitido)';
    esperado := 'PERMITIDO'; obtido := case when v_evd is null then 'n/a (sem evento na região)' else pg_temp.tenta(format('update public.eventos set excluido_em = excluido_em where id = %L', v_evd)) end;
    resultado := case when v_evd is null then 'INFO' when obtido = 'PERMITIDO' then 'OK' else 'FALHOU' end; return next;

    n := n + 1; ordem := n; verificacao := 'Alterar portaria da PRÓPRIA região (deve continuar permitido)';
    esperado := 'PERMITIDO'; obtido := case when v_pod is null then 'n/a (sem portaria na região)' else pg_temp.tenta(format('update public.portarias set excluido_em = excluido_em where id = %L', v_pod)) end;
    resultado := case when v_pod is null then 'INFO' when obtido = 'PERMITIDO' then 'OK' else 'FALHOU' end; return next;

    raise exception using errcode = 'XX999', message = '__reverter__';
  exception when others then
    if sqlerrm <> '__reverter__' then raise; end if;
  end;
end
$f$;

select * from pg_temp.teste2();
