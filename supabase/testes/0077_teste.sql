-- TESTE da 0077 (encerramento manual + configuração) — NÃO GRAVA NADA (tudo é desfeito no final). Esperado: nenhuma linha FALHOU.

create or replace function pg_temp.tenta(p_sql text)
returns text language plpgsql as $f$
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

create or replace function pg_temp.teste77()
returns table(ordem int, verificacao text, esperado text, obtido text, resultado text)
language plpgsql as $f$
declare
  v_master uuid; n int := 0; b boolean; v int; t text;
begin
  select u.id into v_master from public.usuarios u where lower(u.email) = 'levialencar@gmail.com';
  begin
    perform set_config('request.jwt.claims', json_build_object('sub', v_master, 'role', 'authenticated')::text, true);
    perform set_config('request.jwt.claim.sub', v_master::text, true);

    -- Configuração padrão: encerra sozinho, 24 h
    update public.config_eventos set encerra_sozinho = true, horas_apos_inicio = 24 where id = 1;
    b := public.portaria_encerrada(now() - interval '23 hours');
    n := n + 1; ordem := n; verificacao := 'Com 24 h: 23 h depois NÃO está encerrada'; esperado := 'false'; obtido := b::text;
    resultado := case when b = false then 'OK' else 'FALHOU' end; return next;
    b := public.portaria_encerrada(now() - interval '25 hours');
    n := n + 1; ordem := n; verificacao := 'Com 24 h: 25 h depois está encerrada'; esperado := 'true'; obtido := b::text;
    resultado := case when b = true then 'OK' else 'FALHOU' end; return next;
    b := public.portaria_janela_aberta(now() - interval '10 hours');
    n := n + 1; ordem := n; verificacao := 'Com 24 h: 10 h depois a portaria ainda está aberta'; esperado := 'true'; obtido := b::text;
    resultado := case when b = true then 'OK' else 'FALHOU' end; return next;
    b := public.portaria_janela_aberta(now() + interval '3 hours');
    n := n + 1; ordem := n; verificacao := 'Abre só 2 h antes: 3 h antes ainda está fechada'; esperado := 'false'; obtido := b::text;
    resultado := case when b = false then 'OK' else 'FALHOU' end; return next;

    -- Sem encerramento automático
    update public.config_eventos set encerra_sozinho = false where id = 1;
    b := public.portaria_encerrada(now() - interval '1000 hours');
    n := n + 1; ordem := n; verificacao := 'Sem encerrar sozinho: nunca encerra pelo relógio'; esperado := 'false'; obtido := b::text;
    resultado := case when b = false then 'OK' else 'FALHOU' end; return next;
    b := public.portaria_janela_aberta(now() - interval '1000 hours');
    n := n + 1; ordem := n; verificacao := 'Sem encerrar sozinho: portaria continua aberta'; esperado := 'true'; obtido := b::text;
    resultado := case when b = true then 'OK' else 'FALHOU' end; return next;

    -- Salvar a configuração
    perform public.salvar_config_eventos(true, 12);
    select c.horas_apos_inicio into v from public.obter_config_eventos() c;
    n := n + 1; ordem := n; verificacao := 'salvar_config_eventos grava 12 h'; esperado := '12'; obtido := coalesce(v::text, 'nulo');
    resultado := case when v = 12 then 'OK' else 'FALHOU' end; return next;
    t := pg_temp.tenta('select public.salvar_config_eventos(true, 0)');
    n := n + 1; ordem := n; verificacao := 'Horas inválidas (0) são recusadas'; esperado := 'BLOQUEADO'; obtido := t;
    resultado := case when t like 'BLOQUEADO%' then 'OK' else 'FALHOU' end; return next;

    -- Permissões e grupos
    n := n + 1; ordem := n; verificacao := 'Administrador tem as 4 permissões novas'; esperado := '4';
    select count(*)::text into obtido from public.grupo_permissoes gp join public.grupos g on g.id = gp.grupo_id
     where g.nome = 'Administrador' and gp.permissao_codigo in ('eventos.encerrar_qualquer', 'eventos.encerrar_regional', 'eventos.encerrar_local', 'eventos.configurar');
    resultado := case when obtido = '4' then 'OK' else 'FALHOU' end; return next;
    n := n + 1; ordem := n; verificacao := 'Administrador Regional encerra qualquer evento'; esperado := '1';
    select count(*)::text into obtido from public.grupo_permissoes gp join public.grupos g on g.id = gp.grupo_id
     where g.nome = 'Administrador Regional' and gp.permissao_codigo = 'eventos.encerrar_qualquer';
    resultado := case when obtido = '1' then 'OK' else 'FALHOU' end; return next;
    n := n + 1; ordem := n; verificacao := 'Secretário da Música encerra o Regional'; esperado := '1';
    select count(*)::text into obtido from public.grupo_permissoes gp join public.grupos g on g.id = gp.grupo_id
     where g.nome = 'Secretário da Música' and gp.permissao_codigo = 'eventos.encerrar_regional';
    resultado := case when obtido = '1' then 'OK' else 'FALHOU' end; return next;
    n := n + 1; ordem := n; verificacao := 'Grupo Instrutor encerra o Local e vê Eventos'; esperado := '2';
    select count(*)::text into obtido from public.grupo_permissoes gp join public.grupos g on g.id = gp.grupo_id
     where g.nome = 'Instrutor' and gp.permissao_codigo in ('eventos.encerrar_local', 'eventos.visualizar');
    resultado := case when obtido = '2' then 'OK' else 'FALHOU' end; return next;
    n := n + 1; ordem := n; verificacao := 'Aprovadores de portarias NÃO encerram mais'; esperado := '0';
    select count(*)::text into obtido from public.grupo_permissoes gp join public.grupos g on g.id = gp.grupo_id
     where g.nome = 'Aprovadores de portarias' and gp.permissao_codigo like 'eventos.encerrar_%';
    resultado := case when obtido = '0' then 'OK' else 'FALHOU' end; return next;

    n := n + 1; ordem := n; verificacao := 'modelos_dos_tipos_evento devolve os tipos'; esperado := '> 0';
    select count(*)::text into obtido from public.modelos_dos_tipos_evento();
    resultado := case when obtido::int > 0 then 'OK' else 'FALHOU' end; return next;

    raise exception using errcode = 'XX999', message = '__reverter__';
  exception when others then
    if sqlerrm <> '__reverter__' then raise; end if;
  end;
end
$f$;

select * from pg_temp.teste77();
