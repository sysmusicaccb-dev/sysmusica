-- =====================================================================
-- SysMúsica — Migração 0013: excluir itens da organização (lixeira na tela de Organização)
--   * Permissão nova "organizacao.excluir" (o Administrador recebe).
--   * Só exclui item VAZIO: estado sem regiões, região sem setores, setor sem comuns, comum sem membros
--     ativos, sem eventos ativos e sem portarias; e nenhum usuário pode estar vinculado ao item.
--     Caso contrário a função explica o motivo e a saída é INATIVAR.
--   * Fica na auditoria (quem excluiu e o nome do item). O histórico de transferências das comuns é
--     mantido mesmo depois de a comum ser excluída.
--   * Membros e eventos JÁ EXCLUÍDOS (exclusão lógica) que ainda apontavam para a comum passam a não ter comum.
-- Requer a migração 0012. Idempotente, uma única transação.
-- =====================================================================
begin;

do $$
begin
  if to_regprocedure('public.tem_acesso_total_organizacao()') is null
     or to_regprocedure('public.salvar_organizacao(text,uuid,uuid,text,text,boolean,text,text)') is null then
    raise exception 'Aplique primeiro a migração 0012_hierarquia_organizacional.sql.';
  end if;
end $$;

-- 1) PERMISSÃO (igual a CATALOGO_PERMISSOES em src/lib/permissoes.ts); só o Administrador recebe
insert into public.permissoes (codigo, modulo, acao, descricao) values
  ('organizacao.excluir', 'Organização', 'Excluir', 'Excluir estados, regiões, setores e comuns vazios (fica registrado)')
on conflict (codigo) do update
  set modulo = excluded.modulo, acao = excluded.acao, descricao = excluded.descricao;

insert into public.grupo_permissoes (grupo_id, permissao_codigo)
select g.id, p.codigo
from public.grupos g cross join public.permissoes p
where g.sistema and g.nome = 'Administrador'
on conflict do nothing;

-- 2) O histórico de transferências sobrevive à exclusão da comum: remove só a ligação (chave estrangeira)
do $$
declare
  r record;
begin
  for r in
    select conname from pg_constraint
    where conrelid = 'public.comuns_historico'::regclass and contype = 'f'
  loop
    execute format('alter table public.comuns_historico drop constraint %I', r.conname);
  end loop;
end $$;

-- 3) Os gatilhos de membros e eventos ficam quietos enquanto uma comum vazia é excluída
--    (a marca vale só dentro da transação da exclusão e não pode ser enviada pela tela)
create or replace function public.membros_sincroniza_comum()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_id  uuid;
  v_qtd int;
begin
  if current_setting('sysmusica.org_excluindo', true) = 'sim' then
    return new;
  end if;

  if new.comum_id is not null and (tg_op = 'INSERT' or new.comum_id is distinct from old.comum_id) then
    select c.nome into new.congregacao from public.comuns c where c.id = new.comum_id;
    if not found then
      raise exception 'Comum não encontrada.';
    end if;
  elsif tg_op = 'INSERT' or new.congregacao is distinct from old.congregacao then
    select (array_agg(c.id))[1], count(*) into v_id, v_qtd
    from public.comuns c
    where public.normalizar_texto(c.nome) = public.normalizar_texto(btrim(coalesce(new.congregacao, '')));
    new.comum_id := case when v_qtd = 1 then v_id else null end;
  end if;

  -- Quem tem acesso por região precisa ligar o membro a uma comum (senão ele sumiria da própria lista)
  if new.comum_id is null and (select auth.uid()) is not null and not public.tem_acesso_total_organizacao() then
    raise exception 'Não encontrei a comum "%". Use o nome exato de uma comum cadastrada em Administração > Organização.',
      coalesce(new.congregacao, '');
  end if;
  return new;
end;
$$;

create or replace function public.eventos_valida_comum()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if current_setting('sysmusica.org_excluindo', true) = 'sim' then
    return new;
  end if;

  if (select auth.uid()) is null then
    return new;   -- SQL Editor / rotinas internas: sem restrição
  end if;

  -- Quem tem acesso por região precisa escolher a comum (senão o evento sumiria da própria lista)
  if new.comum_id is null and not public.tem_acesso_total_organizacao()
     and (tg_op = 'INSERT' or old.comum_id is not null) then
    raise exception 'Escolha a comum do evento.';
  end if;

  if tg_op = 'INSERT' then
    if new.comum_id is not null and not public.comum_na_abrangencia(new.comum_id) then
      raise exception 'Esta comum está fora da sua abrangência.' using errcode = '42501';
    end if;
  elsif new.comum_id is distinct from old.comum_id then
    if (new.comum_id is not null and not public.comum_na_abrangencia(new.comum_id))
       or (old.comum_id is not null and not public.comum_na_abrangencia(old.comum_id)) then
      raise exception 'Você não pode mudar a comum deste evento: ela está fora da sua abrangência.'
        using errcode = '42501';
    end if;
    update public.portarias
       set comum_id = new.comum_id, cidade = public.rotulo_setor(new.comum_id)
     where evento_id = new.id and excluido_em is null;
    perform public.registrar_auditoria('evento_comum_alterada', 'evento', new.id,
              jsonb_build_object('de', old.comum_id, 'para', new.comum_id));
  end if;
  return new;
end;
$$;

-- 4) EXCLUIR UM ITEM VAZIO DA ORGANIZAÇÃO
create or replace function public.excluir_organizacao(p_nivel text, p_id uuid)
returns void language plpgsql security definer set search_path = public as $$
declare
  v_nome text;
  v_qtd  bigint;
begin
  perform public.exigir_permissao('organizacao.excluir');

  if p_nivel is null or p_nivel not in ('ESTADO', 'REGIAO', 'SETOR', 'COMUM') then
    raise exception 'Nível inválido.';
  end if;

  -- Trava o item e lê o nome (para as mensagens e a auditoria)
  if p_nivel = 'ESTADO' then
    select e.nome into v_nome from public.estados e where e.id = p_id for update;
  elsif p_nivel = 'REGIAO' then
    select r.nome into v_nome from public.regioes r where r.id = p_id for update;
  elsif p_nivel = 'SETOR' then
    select s.nome into v_nome from public.setores s where s.id = p_id for update;
  else
    select c.nome into v_nome from public.comuns c where c.id = p_id for update;
  end if;
  if v_nome is null then
    raise exception 'Cadastro não encontrado.';
  end if;

  -- Usuários vinculados a este item perderiam o acesso sem aviso: a exclusão é bloqueada
  select count(*) into v_qtd from public.usuario_vinculos v where v.nivel = p_nivel and v.alvo_id = p_id;
  if v_qtd > 0 then
    raise exception '"%" ainda tem % usuário(s) vinculado(s). Retire o vínculo em Administração > Usuários antes de excluir.',
      v_nome, v_qtd;
  end if;

  if p_nivel = 'ESTADO' then
    select count(*) into v_qtd from public.regioes x where x.estado_id = p_id;
    if v_qtd > 0 then
      raise exception 'O estado "%" ainda tem % região(ões). Exclua as regiões antes.', v_nome, v_qtd;
    end if;
    delete from public.estados where id = p_id;

  elsif p_nivel = 'REGIAO' then
    select count(*) into v_qtd from public.setores x where x.regiao_id = p_id;
    if v_qtd > 0 then
      raise exception 'A região "%" ainda tem % setor(es). Exclua os setores antes.', v_nome, v_qtd;
    end if;
    delete from public.regioes where id = p_id;

  elsif p_nivel = 'SETOR' then
    select count(*) into v_qtd from public.comuns x where x.setor_id = p_id;
    if v_qtd > 0 then
      raise exception 'O setor "%" ainda tem % comum(ns). Transfira as comuns para outro setor antes de excluir.', v_nome, v_qtd;
    end if;
    delete from public.setores where id = p_id;

  else  -- COMUM
    select count(*) into v_qtd from public.membros x where x.comum_id = p_id and x.excluido_em is null;
    if v_qtd > 0 then
      raise exception 'A comum "%" ainda tem % membro(s). Mude os membros para outra comum (ou exclua-os) antes.', v_nome, v_qtd;
    end if;
    select count(*) into v_qtd from public.eventos x where x.comum_id = p_id and x.excluido_em is null;
    if v_qtd > 0 then
      raise exception 'A comum "%" ainda tem % evento(s). Mude a comum dos eventos (ou exclua-os) antes.', v_nome, v_qtd;
    end if;
    select count(*) into v_qtd from public.portarias x where x.comum_id = p_id;
    if v_qtd > 0 then
      raise exception 'A comum "%" tem % portaria(s) no histórico e não pode ser excluída. Use Inativar.', v_nome, v_qtd;
    end if;

    -- Membros e eventos já excluídos (exclusão lógica) deixam de apontar para a comum
    perform set_config('sysmusica.org_excluindo', 'sim', true);
    update public.membros set comum_id = null where comum_id = p_id;
    update public.eventos set comum_id = null where comum_id = p_id;
    perform set_config('sysmusica.org_excluindo', '', true);

    delete from public.comuns where id = p_id;
  end if;

  perform public.registrar_auditoria('organizacao_excluida', 'organizacao', p_id,
            jsonb_build_object('nivel', p_nivel, 'nome', v_nome));
end;
$$;

-- 5) PERMISSÕES DE EXECUÇÃO
revoke all on function public.excluir_organizacao(text, uuid) from public, anon;
grant execute on function public.excluir_organizacao(text, uuid) to authenticated;

-- 6) VERIFICAÇÃO DE SEGURANÇA: o Administrador precisa ter recebido a permissão nova.
--    Se falhar, a migração INTEIRA é desfeita (nada fica alterado).
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
  if not public.tem_permissao('organizacao.excluir') then
    raise exception 'Verificação falhou: o Administrador não recebeu a permissão de excluir. Nada foi alterado.';
  end if;
  perform set_config('request.jwt.claims', '', true);
end $$;

commit;
