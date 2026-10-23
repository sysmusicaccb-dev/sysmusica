-- TESTE do isolamento regional (Etapa 1) — NÃO GRAVA NADA.
-- Simula o Jerrivan como "Administrador Regional" e confere o que ele enxerga e o que o banco bloqueia.
-- Tudo roda dentro de uma simulação que é desfeita no final (mesmo as tentativas que forem "permitidas").
-- Rode DEPOIS do 0054. Resultado esperado: nenhuma linha com FALHOU.

create or replace function pg_temp.tenta(p_sql text)
returns text
language plpgsql
as $f$
begin
  begin
    execute p_sql;
    raise exception using errcode = 'XX999', message = '__reverter__';
  exception when others then
    if sqlerrm = '__reverter__' then
      return 'PERMITIDO';
    end if;
    return 'BLOQUEADO: ' || sqlerrm;
  end;
end
$f$;

create or replace function pg_temp.ck(p_res jsonb, p_ordem int, p_nome text, p_esperado text, p_obtido text)
returns jsonb
language sql
as $f$
  select p_res || jsonb_build_array(jsonb_build_object(
    'ordem', p_ordem, 'verificacao', p_nome, 'esperado', p_esperado, 'obtido', p_obtido,
    'resultado', case when p_esperado = 'INFO' then 'INFO'
                      when left(p_obtido, length(p_esperado)) = p_esperado then 'OK' else 'FALHOU' end))
$f$;

create or replace function pg_temp.teste_isolamento()
returns table(ordem int, verificacao text, esperado text, obtido text, resultado text)
language plpgsql
as $f$
declare
  v_res     jsonb := '[]'::jsonb;
  v_jer     uuid;
  v_adm     uuid;
  v_regional uuid;
  v_grupo_admin uuid;
  v_fora    uuid;
  v_dentro  uuid;
  v_n       text;
begin
  select u.id into v_jer from public.usuarios u where lower(u.email) = 'jerrivan@congregacao.org.br';
  select u.id into v_adm from public.usuarios u where lower(u.email) = 'levialencar@gmail.com';
  select g.id into v_regional from public.grupos g where g.nome = 'Administrador Regional';
  select g.id into v_grupo_admin from public.grupos g where g.sistema and g.nome = 'Administrador';
  if v_jer is null or v_adm is null or v_regional is null then
    raise exception 'Faltam dados para o teste (Jerrivan, Levi ou o grupo Administrador Regional). Rode o 0054 antes.';
  end if;

  begin
    -- Simulação: o Jerrivan com o grupo Administrador Regional (desfeita no fim)
    insert into public.usuario_grupos (usuario_id, grupo_id) values (v_jer, v_regional) on conflict do nothing;
    perform set_config('request.jwt.claims', json_build_object('sub', v_jer, 'role', 'authenticated')::text, true);
    perform set_config('request.jwt.claim.sub', v_jer::text, true);

    v_res := pg_temp.ck(v_res, 1, 'Jerrivan NÃO tem acesso global', 'false', public.tem_acesso_total_organizacao()::text);

    select count(*)::text into v_n from public.listar_usuarios() l where public.usuario_e_global(l.id);
    v_res := pg_temp.ck(v_res, 2, 'Administradores globais visíveis na lista de usuários', '0', v_n);

    select coalesce(string_agg(l.nome, ', ' order by l.nome), '(nenhum)') into v_n from public.listar_usuarios() l;
    v_res := pg_temp.ck(v_res, 3, 'Usuários que ele enxerga (conferir os nomes)', 'INFO', v_n);

    select count(*)::text into v_n from public.listar_grupos() g where g.nome = 'Administrador';
    v_res := pg_temp.ck(v_res, 4, 'Grupo Administrador visível na lista de grupos', '0', v_n);

    select coalesce(string_agg(g.nome, ', ' order by g.nome), '(nenhum)') into v_n from public.listar_grupos() g;
    v_res := pg_temp.ck(v_res, 5, 'Grupos que ele pode conceder (conferir)', 'INFO', v_n);

    select count(*)::text into v_n from public.listar_organizacao() o
     where o.nivel = 'CASA_ORACAO' and not public.alvo_na_minha_abrangencia(o.nivel, o.id);
    v_res := pg_temp.ck(v_res, 6, 'Casas de Oração visíveis FORA da abrangência', '0', v_n);

    select coalesce(string_agg(t.nivel || '=' || t.qtd, ', ' order by t.nivel), '(nada)') into v_n
      from (select o.nivel, count(*) as qtd from public.listar_organizacao() o group by o.nivel) t;
    v_res := pg_temp.ck(v_res, 7, 'Itens da organização que ele enxerga, por nível (conferir)', 'INFO', v_n);

    v_res := pg_temp.ck(v_res, 8, 'Pode conceder o grupo Administrador?', 'false', public.grupo_concedivel(v_grupo_admin)::text);
    v_res := pg_temp.ck(v_res, 9, 'Pode conceder o grupo Administrador Regional?', 'true', public.grupo_concedivel(v_regional)::text);

    v_res := pg_temp.ck(v_res, 10, 'Alterar grupos do administrador global (Levi)', 'BLOQUEADO',
      pg_temp.tenta(format('select public.atualizar_usuario_grupos(%L, %L, %L::uuid[], true)',
                           v_adm, 'Levi', array[v_grupo_admin])));
    v_res := pg_temp.ck(v_res, 11, 'Alterar os vínculos do administrador global (Levi)', 'BLOQUEADO',
      pg_temp.tenta(format('select public.definir_vinculos(%L, %L::jsonb)', v_adm, '[]')));
    v_res := pg_temp.ck(v_res, 12, 'Alterar os próprios vínculos', 'BLOQUEADO',
      pg_temp.tenta(format('select public.definir_vinculos(%L, %L::jsonb)', v_jer, '[]')));
    v_res := pg_temp.ck(v_res, 13, 'Alterar os próprios grupos (ficar só com o Regional)', 'BLOQUEADO',
      pg_temp.tenta(format('select public.atualizar_usuario_grupos(%L, %L, %L::uuid[], true)',
                           v_jer, 'Jerrivan', array[v_regional])));
    v_res := pg_temp.ck(v_res, 14, 'Criar grupo', 'BLOQUEADO',
      pg_temp.tenta($q$select public.criar_grupo('zz teste', '', array[]::text[])$q$));
    v_res := pg_temp.ck(v_res, 15, 'Criar estado', 'BLOQUEADO',
      pg_temp.tenta($q$insert into public.estados (nome) values ('zz teste')$q$));

    select r.id into v_fora from public.rrms r where not public.alvo_na_minha_abrangencia('RRM', r.id) limit 1;
    if v_fora is null then
      v_res := pg_temp.ck(v_res, 16, 'Alterar RRM de OUTRA região', 'INFO', 'n/a (só existe a região dele)');
    else
      v_res := pg_temp.ck(v_res, 16, 'Alterar RRM de OUTRA região', 'BLOQUEADO',
        pg_temp.tenta(format('update public.rrms set nome = nome where id = %L', v_fora)));
    end if;

    select o.id into v_dentro from public.listar_organizacao() o
     where o.nivel = 'CASA_ORACAO' and public.alvo_na_minha_abrangencia(o.nivel, o.id) limit 1;
    if v_dentro is null then
      v_res := pg_temp.ck(v_res, 17, 'Alterar Casa de Oração da própria região', 'INFO', 'n/a (sem casas na região)');
    else
      v_res := pg_temp.ck(v_res, 17, 'Alterar Casa de Oração da própria região', 'PERMITIDO',
        pg_temp.tenta(format('update public.casas_oracao set nome = nome where id = %L', v_dentro)));
    end if;

    raise exception using errcode = 'XX999', message = '__reverter__';
  exception when others then
    if sqlerrm <> '__reverter__' then
      raise;
    end if;
  end;

  return query
    select (x ->> 'ordem')::int, x ->> 'verificacao', x ->> 'esperado', x ->> 'obtido', x ->> 'resultado'
      from jsonb_array_elements(v_res) x
     order by 1;
end
$f$;

select * from pg_temp.teste_isolamento();
