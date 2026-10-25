-- TESTE da 0068 — NÃO GRAVA NADA (tudo é desfeito no final). Esperado: nenhuma linha FALHOU.
-- Simula o Jerrivan (Administrador Regional) com a permissão "usuarios.editar" (pior caso) e confere que a lista
-- de cidades traz só cidades da região dele; depois confere que o Master continua vendo pelo menos tanto quanto ele.

create or replace function pg_temp.teste68()
returns table(ordem int, verificacao text, esperado text, obtido text, resultado text)
language plpgsql
as $f$
declare
  v_jer uuid; v_reg uuid; v_master uuid;
  v_fora int; v_jer_total int; v_master_total int;
begin
  select u.id into v_jer from public.usuarios u where lower(u.email) = 'jerrivan@congregacao.org.br';
  select u.id into v_master from public.usuarios u where lower(u.email) = 'levialencar@gmail.com';
  select g.id into v_reg from public.grupos g where g.nome = 'Administrador Regional';
  begin
    insert into public.usuario_grupos (usuario_id, grupo_id) values (v_jer, v_reg) on conflict do nothing;
    insert into public.grupo_permissoes (grupo_id, permissao_codigo)
      select v_reg, p.codigo from public.permissoes p where p.codigo = 'usuarios.editar' on conflict do nothing;

    -- Jerrivan
    perform set_config('request.jwt.claims', json_build_object('sub', v_jer, 'role', 'authenticated')::text, true);
    perform set_config('request.jwt.claim.sub', v_jer::text, true);
    select count(*) into v_jer_total from public.listar_cidades_conhecidas();
    select count(*) into v_fora
      from public.listar_cidades_conhecidas() c
     where not exists (select 1 from public.eventos e
                        where e.excluido_em is null and public.normalizar_texto(btrim(e.cidade)) = public.normalizar_texto(c.cidade)
                          and public.casa_oracao_na_abrangencia(e.casa_oracao_id))
       and not exists (select 1 from public.membros m
                        where m.excluido_em is null and public.normalizar_texto(btrim(m.cidade)) = public.normalizar_texto(c.cidade)
                          and public.casa_oracao_na_abrangencia(m.casa_oracao_id));
    ordem := 1; verificacao := 'Regional: cidades de fora da região na lista'; esperado := '0';
    obtido := v_fora::text; resultado := case when v_fora = 0 then 'OK' else 'FALHOU' end; return next;

    -- Master
    perform set_config('request.jwt.claims', json_build_object('sub', v_master, 'role', 'authenticated')::text, true);
    perform set_config('request.jwt.claim.sub', v_master::text, true);
    select count(*) into v_master_total from public.listar_cidades_conhecidas();
    ordem := 2; verificacao := 'Master vê pelo menos tantas cidades quanto o regional';
    esperado := '>= ' || v_jer_total; obtido := v_master_total::text;
    resultado := case when v_master_total >= v_jer_total then 'OK' else 'FALHOU' end; return next;

    raise exception using errcode = 'XX999', message = '__reverter__';
  exception when others then
    if sqlerrm <> '__reverter__' then raise; end if;
  end;
end
$f$;

select * from pg_temp.teste68();
