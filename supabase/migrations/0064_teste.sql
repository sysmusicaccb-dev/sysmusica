-- TESTE da 0064 — NÃO GRAVA NADA. Esperado: nenhuma linha FALHOU.
create or replace function pg_temp.teste64()
returns table(ordem int, verificacao text, esperado text, obtido text, resultado text)
language plpgsql as $f$
declare v_jer uuid; v_lev uuid; v_g uuid; v_tot int; v_fora int;
begin
  select u.id into v_jer from public.usuarios u where lower(u.email) = 'jerrivan@congregacao.org.br';
  select u.id into v_lev from public.usuarios u where lower(u.email) = 'levialencar@gmail.com';
  begin
    insert into public.grupo_permissoes (grupo_id, permissao_codigo)
    select g.gid, 'cadastros.aprovar'
      from (select ug.grupo_id as gid from public.usuario_grupos ug where ug.usuario_id = v_jer
            union select u.grupo_id from public.usuarios u where u.id = v_jer) g where g.gid is not null
    on conflict do nothing;
    perform set_config('request.jwt.claims', json_build_object('sub', v_jer, 'role', 'authenticated')::text, true);
    perform set_config('request.jwt.claim.sub', v_jer::text, true);
    ordem := 1; verificacao := 'Jerrivan recebe pelo menos uma região'; esperado := '>0';
    select count(*) into v_tot from public.regioes_para_link_cadastro(); obtido := v_tot::text;
    resultado := case when v_tot > 0 then 'OK' else 'FALHOU' end; return next;
    ordem := 2; verificacao := 'Nenhuma região fora da abrangência dele'; esperado := '0';
    select count(*) into v_fora from public.regioes_para_link_cadastro() r where not public.alvo_na_minha_abrangencia(r.nivel, r.alvo_id);
    obtido := v_fora::text; resultado := case when v_fora = 0 then 'OK' else 'FALHOU' end; return next;
    perform set_config('request.jwt.claims', json_build_object('sub', v_lev, 'role', 'authenticated')::text, true);
    perform set_config('request.jwt.claim.sub', v_lev::text, true);
    ordem := 3; verificacao := 'Administrador global vê mais regiões que o Jerrivan'; esperado := '>' || v_tot;
    select count(*)::text into obtido from public.regioes_para_link_cadastro();
    resultado := case when obtido::int > v_tot then 'OK' else 'FALHOU' end; return next;
    raise exception using errcode = 'XX999', message = '__reverter__';
  exception when others then
    if sqlerrm <> '__reverter__' then raise; end if;
  end;
end $f$;
select * from pg_temp.teste64();
