-- =====================================================================
-- SysMúsica — Migração 0016: instrumento obrigatório para o cargo Músico
--   * Coluna cargos.exige_instrumento (marcada para o cargo Músico; os outros cargos continuam como estavam).
--   * O banco RECUSA cadastrar ou trocar o cargo/instrumento de um membro com cargo que exige instrumento
--     sem informar o instrumento (vale para qualquer tela). Membros antigos sem instrumento não são
--     alterados: a regra vale na hora de cadastrar, ou de trocar o cargo ou o instrumento.
--   * O cadastro de visitante também exige o instrumento nesses cargos.
--   * As opções do visitante passam a trazer a família de cada instrumento (para a "Família automática").
-- Requer as migrações 0014 e 0015. Idempotente, uma única transação.
-- Ao final, a migração TESTA a regra: se algo falhar, tudo é desfeito.
-- =====================================================================
begin;

do $$
begin
  if to_regclass('public.cargos') is null
     or to_regprocedure('public.cadastrar_visitante(uuid,text,uuid,uuid,uuid)') is null
     or to_regprocedure('public.opcoes_visitante()') is null then
    raise exception 'Aplique primeiro as migrações até a 0015.';
  end if;
end $$;

-- 1) CARGOS: quais exigem instrumento
alter table public.cargos add column if not exists exige_instrumento boolean not null default false;
grant select (exige_instrumento) on public.cargos to authenticated;

update public.cargos set exige_instrumento = true
 where public.normalizar_texto(btrim(nome)) = 'musico';

-- 2) MEMBROS: o banco recusa cargo que exige instrumento sem instrumento (ao cadastrar ou ao trocar cargo/instrumento)
create or replace function public.membros_exige_instrumento()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_exige boolean;
  v_nome  text;
begin
  if (select auth.uid()) is null then
    return new;   -- SQL Editor / rotinas internas: sem restrição
  end if;

  -- Alterações que não mexem em cargo nem em instrumento (foto, situação, exclusão...) passam direto
  if tg_op = 'UPDATE'
     and new.cargo_id is not distinct from old.cargo_id
     and new.instrumento_id is not distinct from old.instrumento_id then
    return new;
  end if;

  select c.exige_instrumento, c.nome into v_exige, v_nome from public.cargos c where c.id = new.cargo_id;
  if coalesce(v_exige, false) and new.instrumento_id is null then
    raise exception 'O cargo % exige o instrumento. Escolha o instrumento na lista.', v_nome;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_membros_exige_instrumento on public.membros;
create trigger trg_membros_exige_instrumento
  before insert or update of cargo_id, instrumento_id on public.membros
  for each row execute function public.membros_exige_instrumento();

-- 3) OPÇÕES DO VISITANTE: cargos (com a regra), instrumentos (com a família) e famílias
drop function if exists public.opcoes_visitante();

create function public.opcoes_visitante()
returns table (
  tipo text, id uuid, nome text, permite_instrumento boolean, exige_instrumento boolean, familia_id uuid
)
language plpgsql stable security definer set search_path = public as $$
begin
  perform public.exigir_permissao('portaria.cadastrar_visitante');
  return query
    select 'CARGO'::text, c.id, c.nome, c.permite_instrumento, c.exige_instrumento, null::uuid
      from public.cargos c
    union all
    select 'INSTRUMENTO'::text, i.id, i.nome, false, false, i.familia_id
      from public.instrumentos i
    union all
    select 'FAMILIA'::text, f.id, f.nome, false, false, null::uuid
      from public.familias f
    order by 1, 3;
end;
$$;

-- 4) CADASTRO DO VISITANTE: instrumento obrigatório nos cargos que exigem
create or replace function public.cadastrar_visitante(
  p_portaria_id uuid, p_nome text, p_cargo_id uuid, p_instrumento_id uuid, p_origem_comum_id uuid
)
returns uuid language plpgsql security definer set search_path = public as $$
declare
  v_p          public.portarias;
  v_comum      text;
  v_nome       text := btrim(regexp_replace(coalesce(p_nome, ''), '\s+', ' ', 'g'));
  v_origem     record;
  v_permite    boolean;
  v_exige      boolean;
  v_nome_cargo text;
  v_id         uuid;
begin
  perform public.exigir_permissao('portaria.cadastrar_visitante');
  perform public.exigir_acesso_atendimento(p_portaria_id);   -- aprovada e dentro da abrangência de quem atende

  select * into v_p from public.portarias p where p.id = p_portaria_id;
  select c.nome into v_comum from public.comuns c where c.id = v_p.comum_id;
  if v_comum is null then
    raise exception 'A comum desta portaria não foi encontrada.';
  end if;

  if char_length(v_nome) < 5 or char_length(v_nome) > 120 or position(' ' in v_nome) = 0 then
    raise exception 'Digite o nome completo do visitante (nome e sobrenome).';
  end if;

  select c.permite_instrumento, c.exige_instrumento, c.nome into v_permite, v_exige, v_nome_cargo
  from public.cargos c where c.id = p_cargo_id;
  if not found then
    raise exception 'Escolha o cargo ou ministério do visitante.';
  end if;

  if p_instrumento_id is not null then
    if not v_permite then
      raise exception 'Este cargo não usa instrumento.';
    end if;
    if not exists (select 1 from public.instrumentos i where i.id = p_instrumento_id) then
      raise exception 'Instrumento não encontrado.';
    end if;
  elsif coalesce(v_exige, false) then
    raise exception 'O cargo % exige o instrumento. Escolha o instrumento na lista.', v_nome_cargo;
  end if;

  -- A origem precisa ser uma comum cadastrada, ativa e com setor, região e estado ativos
  select c.nome as comum, c.cidade as cidade, r.nome as regiao into v_origem
  from public.comuns c
  join public.setores s on s.id = c.setor_id
  join public.regioes r on r.id = s.regiao_id
  join public.estados e on e.id = r.estado_id
  where c.id = p_origem_comum_id and c.ativo and s.ativo and r.ativo and e.ativo;
  if not found then
    raise exception 'Escolha a igreja de origem na lista (estado, região, setor e comum). Se ela não aparecer, peça a um administrador para cadastrá-la em Organização.';
  end if;

  if exists (
    select 1 from public.membros m
    where m.comum_id = v_p.comum_id and m.excluido_em is null
      and public.normalizar_texto(m.nome) = public.normalizar_texto(v_nome)
  ) then
    raise exception 'Já existe um membro com este nome nesta comum. Busque pelo nome completo em vez de cadastrar de novo.';
  end if;

  insert into public.membros
    (nome, congregacao, cargo_id, instrumento_id, status, comum_id, cidade, bairro, visitante, origem_comum_id)
  values
    (v_nome, v_comum, p_cargo_id, p_instrumento_id, 'Ativo', v_p.comum_id,
     coalesce(v_origem.cidade, v_origem.regiao), v_origem.comum, true, p_origem_comum_id)
  returning id into v_id;

  perform public.registrar_auditoria('visitante_cadastrado', 'membro', v_id,
            jsonb_build_object('portaria_id', p_portaria_id, 'comum_id', v_p.comum_id,
                               'origem_comum_id', p_origem_comum_id, 'rotulo', v_nome));
  return v_id;
end;
$$;

-- 5) PERMISSÕES DE EXECUÇÃO
revoke all on function public.membros_exige_instrumento() from public, anon, authenticated;
revoke all on function public.opcoes_visitante() from public, anon;
grant execute on function public.opcoes_visitante() to authenticated;

-- 6) VERIFICAÇÃO DE SEGURANÇA: testa a regra de verdade. Se falhar, a migração INTEIRA é desfeita.
do $$
declare
  v_musico   uuid;
  v_admin    uuid;
  v_bloqueou boolean := false;
begin
  select c.id into v_musico from public.cargos c where c.exige_instrumento limit 1;
  if v_musico is null then
    raise exception 'Verificação falhou: nenhum cargo exige instrumento (o cargo Músico não foi encontrado). Nada foi alterado.';
  end if;

  select u.id into v_admin
  from public.usuarios u join public.grupos g on g.id = u.grupo_id
  where g.sistema and g.nome = 'Administrador' and u.ativo
  limit 1;

  if v_admin is null then
    return;  -- ainda não há administrador: nada a testar
  end if;

  perform set_config('request.jwt.claims', json_build_object('sub', v_admin, 'role', 'authenticated')::text, true);

  -- Um cadastro de teste (Músico sem instrumento) precisa ser recusado; nada é gravado
  begin
    insert into public.membros (nome, congregacao, cargo_id) values ('Teste Obrigatorio', 'Teste', v_musico);
    raise exception 'sysmusica_sem_bloqueio';
  exception when others then
    if sqlerrm like '%exige o instrumento%' then
      v_bloqueou := true;
    elsif sqlerrm <> 'sysmusica_sem_bloqueio' then
      raise exception 'Verificação falhou (teste do instrumento obrigatório): %', sqlerrm;
    end if;
  end;

  if not v_bloqueou then
    raise exception 'Verificação falhou: o banco aceitou um Músico sem instrumento. Nada foi alterado.';
  end if;

  perform count(*) from public.opcoes_visitante();
  perform set_config('request.jwt.claims', '', true);
end $$;

commit;
