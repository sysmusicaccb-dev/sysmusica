-- =====================================================================
-- SysMúsica — Migração 0017: fotografia obrigatória no cadastro novo (membro e visitante)
--   * Todo cadastro NOVO de membro precisa de fotografia: o banco recusa sem ela (vale para qualquer tela).
--   * Cadastro de visitante: a foto é obrigatória e vem junto com o cadastro.
--   * Quem cadastra (membros.criar ou portaria.cadastrar_visitante) pode ENVIAR a foto do cadastro novo;
--     trocar ou remover a foto de um membro existente continua só para quem tem a permissão Fotografia
--     (e agora respeitando a região do usuário, que antes não era conferida).
--   * Membros antigos sem foto não são alterados.
-- Requer as migrações 0008, 0012, 0015 e 0016. Idempotente, uma única transação.
-- Ao final, a migração TESTA a regra: se algo falhar, tudo é desfeito.
-- =====================================================================
begin;

do $$
begin
  if to_regprocedure('public.cadastrar_visitante(uuid,text,uuid,uuid,uuid)') is null
     or to_regprocedure('public.definir_foto_membro(uuid,text)') is null
     or to_regprocedure('public.remover_foto_membro(uuid)') is null
     or to_regprocedure('public.comum_na_abrangencia(uuid)') is null
     or not exists (select 1 from information_schema.columns
                    where table_schema = 'public' and table_name = 'cargos' and column_name = 'exige_instrumento') then
    raise exception 'Aplique primeiro as migrações até a 0016.';
  end if;
end $$;

-- 1) CONFERE UMA FOTO: caminho na pasta do próprio membro e arquivo existente no armazenamento
create or replace function public.validar_foto_membro(p_membro_id uuid, p_path text)
returns void language plpgsql security definer set search_path = public as $$
begin
  if p_path is null or btrim(p_path) = '' then
    raise exception 'A fotografia é obrigatória. Tire a foto ou escolha uma imagem.';
  end if;
  if p_membro_id is null or p_path not like (p_membro_id::text || '/%') or position('..' in p_path) > 0 then
    raise exception 'Caminho de fotografia inválido.';
  end if;
  if not exists (select 1 from storage.objects o where o.bucket_id = 'fotos-membros' and o.name = p_path) then
    raise exception 'A fotografia enviada não foi encontrada. Tente enviar novamente.';
  end if;
end;
$$;

-- 2) MEMBROS: leitura do caminho da foto e envio dela junto com o cadastro novo
grant select (foto_path) on public.membros to authenticated;
grant insert (id, foto_path) on public.membros to authenticated;

-- Todo cadastro novo feito por um usuário precisa de foto (o SQL Editor e rotinas internas ficam de fora)
create or replace function public.membros_exige_foto()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if (select auth.uid()) is null then
    return new;
  end if;
  perform public.validar_foto_membro(new.id, new.foto_path);
  return new;
end;
$$;

drop trigger if exists trg_membros_exige_foto on public.membros;
create trigger trg_membros_exige_foto
  before insert on public.membros
  for each row execute function public.membros_exige_foto();

-- 3) ARMAZENAMENTO: quem cadastra membro ou visitante pode ENVIAR a foto do cadastro (a troca e a remoção
--    de fotos continuam só para quem tem Fotografia)
drop policy if exists "fotos_membros_envio" on storage.objects;
create policy "fotos_membros_envio" on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'fotos-membros'
    and public.tem_alguma_permissao(array['membros.foto', 'membros.criar', 'portaria.cadastrar_visitante'])
  );

-- 4) TROCAR E REMOVER FOTO: agora respeitam a região do usuário
create or replace function public.definir_foto_membro(p_membro_id uuid, p_path text)
returns text language plpgsql security definer set search_path = public as $$
declare
  v_antigo text;
  v_comum  uuid;
begin
  perform public.exigir_permissao('membros.foto');
  perform public.validar_foto_membro(p_membro_id, p_path);

  select m.foto_path, m.comum_id into v_antigo, v_comum
  from public.membros m where m.id = p_membro_id and m.excluido_em is null for update;
  if not found or not public.comum_na_abrangencia(v_comum) then
    raise exception 'Membro não encontrado.';
  end if;

  update public.membros set foto_path = p_path where id = p_membro_id;

  perform public.registrar_auditoria('foto_definida', 'membro', p_membro_id,
            jsonb_build_object('caminho', p_path));
  return v_antigo;
end;
$$;

create or replace function public.remover_foto_membro(p_membro_id uuid)
returns text language plpgsql security definer set search_path = public as $$
declare
  v_antigo text;
  v_comum  uuid;
begin
  perform public.exigir_permissao('membros.foto');

  select m.foto_path, m.comum_id into v_antigo, v_comum
  from public.membros m where m.id = p_membro_id and m.excluido_em is null for update;
  if not found or not public.comum_na_abrangencia(v_comum) then
    raise exception 'Membro não encontrado.';
  end if;

  update public.membros set foto_path = null where id = p_membro_id;

  perform public.registrar_auditoria('foto_removida', 'membro', p_membro_id, '{}'::jsonb);
  return v_antigo;
end;
$$;

-- 5) CADASTRO DE VISITANTE: o identificador e a foto vêm junto (a foto sobe antes, na pasta do futuro membro)
drop function if exists public.cadastrar_visitante(uuid, text, uuid, uuid, uuid);

create or replace function public.cadastrar_visitante(
  p_portaria_id uuid, p_nome text, p_cargo_id uuid, p_instrumento_id uuid, p_origem_comum_id uuid,
  p_membro_id uuid, p_foto_path text
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

  if p_membro_id is null or exists (select 1 from public.membros m where m.id = p_membro_id) then
    raise exception 'Não foi possível cadastrar: identificador inválido. Tente novamente.';
  end if;
  perform public.validar_foto_membro(p_membro_id, p_foto_path);   -- foto obrigatória

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
    (id, nome, congregacao, cargo_id, instrumento_id, status, comum_id, cidade, bairro, visitante,
     origem_comum_id, foto_path)
  values
    (p_membro_id, v_nome, v_comum, p_cargo_id, p_instrumento_id, 'Ativo', v_p.comum_id,
     coalesce(v_origem.cidade, v_origem.regiao), v_origem.comum, true, p_origem_comum_id, p_foto_path)
  returning id into v_id;

  perform public.registrar_auditoria('visitante_cadastrado', 'membro', v_id,
            jsonb_build_object('portaria_id', p_portaria_id, 'comum_id', v_p.comum_id,
                               'origem_comum_id', p_origem_comum_id, 'rotulo', v_nome));
  return v_id;
end;
$$;

-- 6) PERMISSÕES DE EXECUÇÃO
revoke all on function public.validar_foto_membro(uuid, text), public.membros_exige_foto()
  from public, anon, authenticated;
revoke all on function public.cadastrar_visitante(uuid, text, uuid, uuid, uuid, uuid, text) from public, anon;
grant execute on function public.cadastrar_visitante(uuid, text, uuid, uuid, uuid, uuid, text) to authenticated;

-- 7) VERIFICAÇÃO DE SEGURANÇA: testa de verdade que um cadastro sem foto é recusado.
--    Se falhar, a migração INTEIRA é desfeita (nada fica alterado).
do $$
declare
  v_admin    uuid;
  v_cargo    uuid;
  v_bloqueou boolean := false;
begin
  select u.id into v_admin
  from public.usuarios u join public.grupos g on g.id = u.grupo_id
  where g.sistema and g.nome = 'Administrador' and u.ativo
  limit 1;

  if v_admin is null then
    return;  -- ainda não há administrador: nada a testar
  end if;

  perform set_config('request.jwt.claims', json_build_object('sub', v_admin, 'role', 'authenticated')::text, true);

  select c.id into v_cargo from public.cargos c where not c.exige_instrumento limit 1;
  if v_cargo is null then
    select c.id into v_cargo from public.cargos c limit 1;
  end if;

  begin
    insert into public.membros (nome, congregacao, cargo_id) values ('Teste Foto', 'Teste', v_cargo);
    raise exception 'sysmusica_sem_bloqueio';
  exception when others then
    if sqlerrm like '%fotografia é obrigatória%' then
      v_bloqueou := true;
    elsif sqlerrm <> 'sysmusica_sem_bloqueio' then
      raise exception 'Verificação falhou (teste da foto obrigatória): %', sqlerrm;
    end if;
  end;

  if not v_bloqueou then
    raise exception 'Verificação falhou: o banco aceitou um membro sem foto. Nada foi alterado.';
  end if;

  perform count(*) from public.opcoes_visitante();
  perform set_config('request.jwt.claims', '', true);
end $$;

commit;
