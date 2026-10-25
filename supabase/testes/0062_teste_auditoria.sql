-- TESTE da 0062 — NÃO GRAVA NADA. Esperado: nenhuma linha FALHOU.
create or replace function pg_temp.teste5()
returns table(ordem int, verificacao text, esperado text, obtido text, resultado text)
language plpgsql as $f$
declare
  v_jer uuid; v_adm uuid; v_reg uuid; v_n text; v_tot bigint; v_vis bigint; v_p int := 0;
begin
  select u.id into v_jer from public.usuarios u where lower(u.email) = 'jerrivan@congregacao.org.br';
  select u.id into v_adm from public.usuarios u where lower(u.email) = 'levialencar@gmail.com';
  select g.id into v_reg from public.grupos g where g.nome = 'Administrador Regional';
  begin
    insert into public.usuario_grupos (usuario_id, grupo_id) values (v_jer, v_reg) on conflict do nothing;
    insert into public.grupo_permissoes (grupo_id, permissao_codigo) values (v_reg, 'auditoria.visualizar') on conflict do nothing;
    select count(*) into v_tot from public.auditoria;

    -- Como o Jerrivan (regional)
    perform set_config('request.jwt.claims', json_build_object('sub', v_jer, 'role', 'authenticated')::text, true);
    perform set_config('request.jwt.claim.sub', v_jer::text, true);
    select count(*) into v_vis from public.listar_auditoria(null, null, null, null, null, null, 2000, 0);

    v_p := v_p + 1; ordem := v_p; verificacao := 'Registros sobre eventos/membros/portarias de OUTRA região visíveis (feitos por outros)'; esperado := '0';
    select count(*)::text into obtido from public.listar_auditoria(null, null, null, null, null, null, 2000, 0) l
     where l.usuario_id is distinct from v_jer and not public.usuario_na_minha_abrangencia(coalesce(l.usuario_id, v_jer))
       and ((l.entidade = 'evento'   and not public.evento_na_abrangencia(l.entidade_id))
         or (l.entidade = 'membro'   and exists (select 1 from public.membros m where m.id = l.entidade_id and not public.casa_oracao_na_abrangencia(m.casa_oracao_id)))
         or (l.entidade = 'portaria' and exists (select 1 from public.portarias p where p.id = l.entidade_id and not public.casa_oracao_na_abrangencia(p.casa_oracao_id))));
    resultado := case when obtido = '0' then 'OK' else 'FALHOU' end; return next;

    v_p := v_p + 1; ordem := v_p; verificacao := 'Ações do administrador global sobre catálogos/grupos visíveis'; esperado := '0';
    select count(*)::text into obtido from public.listar_auditoria(null, null, null, null, null, null, 2000, 0) l
     where l.usuario_id = v_adm and l.entidade in ('instrumento', 'familia', 'grupo', 'grupo_permissao', 'cargo', 'finalidade');
    resultado := case when obtido = '0' then 'OK' else 'FALHOU' end; return next;

    v_p := v_p + 1; ordem := v_p; verificacao := 'Administrador global aparece no filtro de usuários'; esperado := '0';
    select count(*)::text into obtido from public.opcoes_auditoria() o where o.tipo = 'USUARIO' and o.valor = v_adm::text;
    resultado := case when obtido = '0' then 'OK' else 'FALHOU' end; return next;

    v_p := v_p + 1; ordem := v_p; verificacao := 'Registros que o Jerrivan enxerga (de um total de ' || v_tot || ')'; esperado := 'INFO';
    obtido := v_vis::text; resultado := 'INFO'; return next;

    -- Como o Levi (global)
    perform set_config('request.jwt.claims', json_build_object('sub', v_adm, 'role', 'authenticated')::text, true);
    perform set_config('request.jwt.claim.sub', v_adm::text, true);
    v_p := v_p + 1; ordem := v_p; verificacao := 'Administrador global continua vendo tudo (limite 2000)'; esperado := least(v_tot, 2000)::text;
    select count(*)::text into obtido from public.listar_auditoria(null, null, null, null, null, null, 2000, 0);
    resultado := case when obtido = esperado then 'OK' else 'FALHOU' end; return next;

    raise exception using errcode = 'XX999', message = '__reverter__';
  exception when others then
    if sqlerrm <> '__reverter__' then raise; end if;
  end;
end $f$;

select * from pg_temp.teste5();
