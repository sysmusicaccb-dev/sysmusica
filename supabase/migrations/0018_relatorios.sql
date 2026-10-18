-- =====================================================================
-- SysMúsica — Migração 0018: módulo Relatórios
--   * Permissão nova "relatorios.visualizar" (o Administrador recebe): abre a tela de Relatórios.
--   * Consultas dos relatórios que juntam várias tabelas (presença por evento, membros, eventos e
--     contagens por instrumento/cargo). Todas conferem a permissão de ver aquele dado e respeitam a
--     REGIÃO do usuário: quem é de Salvador não recebe nada de Jequié (acesso total vê tudo).
--   * Nada de CPF completo: só o CPF parcial, e só para quem tem a permissão de CPF.
-- Requer as migrações 0012, 0014 e 0017. Idempotente, uma única transação.
-- Ao final, a migração TESTA as consultas como Administrador: se algo falhar, tudo é desfeito.
-- =====================================================================
begin;

do $$
begin
  if to_regprocedure('public.comum_na_abrangencia(uuid)') is null
     or not exists (select 1 from information_schema.columns
                    where table_schema = 'public' and table_name = 'membros' and column_name = 'visitante')
     or not exists (select 1 from information_schema.columns
                    where table_schema = 'public' and table_name = 'presencas' and column_name = 'registrado_por') then
    raise exception 'Aplique primeiro as migrações até a 0017.';
  end if;
end $$;

-- 1) PERMISSÃO (igual a CATALOGO_PERMISSOES em src/lib/permissoes.ts); só o Administrador recebe
insert into public.permissoes (codigo, modulo, acao, descricao) values
  ('relatorios.visualizar', 'Relatórios', 'Visualizar',
   'Montar, visualizar, imprimir e exportar relatórios (cada tipo exige também a permissão de ver aquele dado)')
on conflict (codigo) do update
  set modulo = excluded.modulo, acao = excluded.acao, descricao = excluded.descricao;

insert into public.grupo_permissoes (grupo_id, permissao_codigo)
select g.id, p.codigo
from public.grupos g cross join public.permissoes p
where g.sistema and g.nome = 'Administrador'
on conflict do nothing;

-- 2) PRESENÇA POR EVENTO (exige portaria.visualizar; só eventos da abrangência do usuário)
create or replace function public.relatorio_presencas(
  p_inicio timestamptz, p_fim timestamptz, p_evento uuid,
  p_regiao uuid, p_setor uuid, p_comum uuid, p_status text, p_limite int
)
returns table (
  evento_tipo text, evento_data timestamptz, evento_local text, evento_finalidade text,
  regiao text, setor text, comum text,
  membro_nome text, membro_comum text, cargo text, instrumento text, familia text,
  cidade text, bairro text, visitante boolean,
  status text, hora_entrada timestamptz, hora_saida timestamptz, origem text, registrado_por text,
  total bigint
)
language plpgsql stable security definer set search_path = public as $$
declare
  v_lim int := least(greatest(coalesce(p_limite, 5000), 1), 20000);
begin
  perform public.exigir_permissao('portaria.visualizar');

  return query
    select ev.tipo, ev.data_evento, ev.local, fi.nome,
           r.nome, s.nome, c.nome,
           m.nome, m.congregacao, ca.nome, i.nome, f.nome,
           m.cidade, m.bairro, m.visitante,
           pr.status, pr.hora_entrada, pr.hora_saida,
           case when pr.portaria_id is null then 'ANTIGO' else pr.origem end,
           u.nome,
           count(*) over ()
    from public.presencas pr
    join public.eventos ev on ev.id = pr.evento_id and ev.excluido_em is null
    join public.membros m on m.id = pr.membro_id
    left join public.finalidades_evento fi on fi.id = ev.finalidade_id
    left join public.comuns c on c.id = ev.comum_id
    left join public.setores s on s.id = c.setor_id
    left join public.regioes r on r.id = s.regiao_id
    left join public.cargos ca on ca.id = m.cargo_id
    left join public.instrumentos i on i.id = m.instrumento_id
    left join public.familias f on f.id = i.familia_id
    left join public.usuarios u on u.id = pr.registrado_por
    where pr.excluido_em is null
      and public.comum_na_abrangencia(ev.comum_id)
      and (p_inicio is null or ev.data_evento >= p_inicio)
      and (p_fim is null or ev.data_evento < p_fim)
      and (p_evento is null or pr.evento_id = p_evento)
      and (p_regiao is null or r.id = p_regiao)
      and (p_setor is null or s.id = p_setor)
      and (p_comum is null or c.id = p_comum)
      and (nullif(p_status, '') is null or pr.status = p_status)
    order by ev.data_evento desc, ev.id, m.nome
    limit v_lim;
end;
$$;

-- 3) MEMBROS (exige membros.visualizar; só a abrangência do usuário; CPF só parcial e só com a permissão de CPF)
create or replace function public.relatorio_membros(
  p_regiao uuid, p_setor uuid, p_comum uuid, p_cargo uuid, p_instrumento uuid,
  p_status text, p_visitante text, p_limite int
)
returns table (
  nome text, cargo text, instrumento text, familia text, regiao text, setor text, comum text,
  cidade text, bairro text, status text, visitante boolean, data_nascimento date,
  cadastrado_em timestamptz, cpf_parcial text, total bigint
)
language plpgsql stable security definer set search_path = public as $$
declare
  v_lim int := least(greatest(coalesce(p_limite, 5000), 1), 20000);
  v_cpf boolean;
begin
  perform public.exigir_permissao('membros.visualizar');
  v_cpf := public.tem_permissao('membros.cpf');

  return query
    select m.nome, ca.nome, i.nome, f.nome, r.nome, s.nome, c.nome,
           m.cidade, m.bairro, m.status, m.visitante, m.data_nascimento,
           m.data_cadastro,
           case when v_cpf then m.cpf_mascarado end,
           count(*) over ()
    from public.membros m
    left join public.comuns c on c.id = m.comum_id
    left join public.setores s on s.id = c.setor_id
    left join public.regioes r on r.id = s.regiao_id
    left join public.cargos ca on ca.id = m.cargo_id
    left join public.instrumentos i on i.id = m.instrumento_id
    left join public.familias f on f.id = i.familia_id
    where m.excluido_em is null
      and public.comum_na_abrangencia(m.comum_id)
      and (p_regiao is null or r.id = p_regiao)
      and (p_setor is null or s.id = p_setor)
      and (p_comum is null or c.id = p_comum)
      and (p_cargo is null or m.cargo_id = p_cargo)
      and (p_instrumento is null or m.instrumento_id = p_instrumento)
      and (nullif(p_status, '') is null or m.status = p_status)
      and (nullif(p_visitante, '') is null
           or (p_visitante = 'sim' and m.visitante)
           or (p_visitante = 'nao' and not m.visitante))
    order by m.nome
    limit v_lim;
end;
$$;

-- 4) EVENTOS (exige eventos.visualizar; só os da abrangência do usuário), com presenças e situação da portaria
create or replace function public.relatorio_eventos(
  p_inicio timestamptz, p_fim timestamptz, p_regiao uuid, p_setor uuid, p_comum uuid, p_limite int
)
returns table (
  tipo text, data_evento timestamptz, local_evento text, finalidade text, cidade text,
  regiao text, setor text, comum text, registros bigint, presentes bigint, portaria text, total bigint
)
language plpgsql stable security definer set search_path = public as $$
declare
  v_lim int := least(greatest(coalesce(p_limite, 5000), 1), 20000);
begin
  perform public.exigir_permissao('eventos.visualizar');

  return query
    select ev.tipo, ev.data_evento, ev.local, fi.nome, ev.cidade,
           r.nome, s.nome, c.nome,
           (select count(*) from public.presencas pr
             where pr.evento_id = ev.id and pr.excluido_em is null),
           (select count(*) from public.presencas pr
             where pr.evento_id = ev.id and pr.excluido_em is null and pr.status = 'Presente'),
           (select case po.status when 'APROVADA' then 'Aprovada' when 'PENDENTE_APROVACAO' then 'Pendente'
                                  when 'REJEITADA' then 'Rejeitada' end
              from public.portarias po
             where po.evento_id = ev.id and po.excluido_em is null
             order by po.criada_em desc limit 1),
           count(*) over ()
    from public.eventos ev
    left join public.finalidades_evento fi on fi.id = ev.finalidade_id
    left join public.comuns c on c.id = ev.comum_id
    left join public.setores s on s.id = c.setor_id
    left join public.regioes r on r.id = s.regiao_id
    where ev.excluido_em is null
      and public.comum_na_abrangencia(ev.comum_id)
      and (p_inicio is null or ev.data_evento >= p_inicio)
      and (p_fim is null or ev.data_evento < p_fim)
      and (p_regiao is null or r.id = p_regiao)
      and (p_setor is null or s.id = p_setor)
      and (p_comum is null or c.id = p_comum)
    order by ev.data_evento desc, ev.id
    limit v_lim;
end;
$$;

-- 5) CONTAGEM DE MEMBROS por instrumento e por cargo (só a abrangência do usuário)
create or replace function public.contagem_membros_por()
returns table (tipo text, id uuid, qtd bigint)
language plpgsql stable security definer set search_path = public as $$
begin
  perform public.exigir_permissao('membros.visualizar');

  return query
    select 'INSTRUMENTO'::text, m.instrumento_id, count(*)
      from public.membros m
     where m.excluido_em is null and m.instrumento_id is not null
       and public.comum_na_abrangencia(m.comum_id)
     group by m.instrumento_id
    union all
    select 'CARGO'::text, m.cargo_id, count(*)
      from public.membros m
     where m.excluido_em is null and public.comum_na_abrangencia(m.comum_id)
     group by m.cargo_id;
end;
$$;

-- 6) PERMISSÕES DE EXECUÇÃO
revoke all on function
  public.relatorio_presencas(timestamptz, timestamptz, uuid, uuid, uuid, uuid, text, int),
  public.relatorio_membros(uuid, uuid, uuid, uuid, uuid, text, text, int),
  public.relatorio_eventos(timestamptz, timestamptz, uuid, uuid, uuid, int),
  public.contagem_membros_por()
  from public, anon;
grant execute on function
  public.relatorio_presencas(timestamptz, timestamptz, uuid, uuid, uuid, uuid, text, int),
  public.relatorio_membros(uuid, uuid, uuid, uuid, uuid, text, text, int),
  public.relatorio_eventos(timestamptz, timestamptz, uuid, uuid, uuid, int),
  public.contagem_membros_por()
  to authenticated;

-- 7) VERIFICAÇÃO DE SEGURANÇA: roda as consultas como Administrador. Se alguma falhar, a migração
--    INTEIRA é desfeita (nada fica alterado).
do $$
declare
  v_admin uuid;
begin
  select u.id into v_admin
  from public.usuarios u join public.grupos g on g.id = u.grupo_id
  where g.sistema and g.nome = 'Administrador' and u.ativo
  limit 1;

  if v_admin is null then
    return;  -- ainda não há administrador: nada a verificar
  end if;

  perform set_config('request.jwt.claims', json_build_object('sub', v_admin, 'role', 'authenticated')::text, true);

  if not public.tem_permissao('relatorios.visualizar') then
    raise exception 'Verificação falhou: o Administrador não recebeu a permissão de relatórios. Nada foi alterado.';
  end if;

  perform count(*) from public.relatorio_presencas(null, null, null, null, null, null, null, 5);
  perform count(*) from public.relatorio_membros(null, null, null, null, null, null, null, 5);
  perform count(*) from public.relatorio_eventos(null, null, null, null, null, 5);
  perform count(*) from public.contagem_membros_por();

  perform set_config('request.jwt.claims', '', true);
end $$;

commit;
