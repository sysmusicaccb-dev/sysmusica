-- =====================================================================
-- SysMúsica — Migração 0015: origem do visitante vinda do banco + módulo de Auditoria
--
-- A) ORIGEM DO VISITANTE: o atendente escolhe Estado > Região > Setor > Comum (cadastrados em
--    Organização) em vez de digitar. Cidade e igreja de origem do visitante saem dessa escolha.
-- B) AUDITORIA:
--    * Registro AUTOMÁTICO (gatilho no banco) de toda inclusão, alteração e exclusão nas tabelas
--      principais: quem fez, quando, o que mudou (antes e depois) e um rótulo legível.
--      CPF e código do QR Code nunca são gravados (aparece só "(alterado)" ou "(protegido)").
--    * Registro de cada login (gatilho em auth.users; se o Supabase não permitir, o resto continua).
--    * Registro de impressões e exportações (função registrar_uso).
--    * Consulta com filtros, só para quem tem "auditoria.visualizar". A tabela continua só de acréscimo.
-- Requer as migrações 0006 a 0014. Idempotente, uma única transação.
-- Ao final, a migração TESTA a auditoria e as consultas: se algo falhar, tudo é desfeito.
-- =====================================================================
begin;

do $$
begin
  if to_regprocedure('public.exigir_acesso_atendimento(uuid)') is null
     or to_regprocedure('public.registrar_auditoria(text,text,uuid,jsonb)') is null
     or to_regclass('public.comuns') is null
     or to_regclass('public.auditoria') is null then
    raise exception 'Aplique primeiro as migrações até a 0014.';
  end if;
end $$;

-- 1) PERMISSÃO (igual a CATALOGO_PERMISSOES em src/lib/permissoes.ts); só o Administrador recebe
insert into public.permissoes (codigo, modulo, acao, descricao) values
  ('auditoria.visualizar', 'Auditoria', 'Visualizar', 'Consultar, imprimir e exportar a auditoria do sistema')
on conflict (codigo) do update
  set modulo = excluded.modulo, acao = excluded.acao, descricao = excluded.descricao;

insert into public.grupo_permissoes (grupo_id, permissao_codigo)
select g.id, p.codigo
from public.grupos g cross join public.permissoes p
where g.sistema and g.nome = 'Administrador'
on conflict do nothing;

-- 2) TABELA DE AUDITORIA: ações do sistema (sem usuário) e registros sem identificador também são aceitos
alter table public.auditoria alter column entidade_id drop not null;
alter table public.auditoria alter column usuario_id drop not null;
create index if not exists idx_auditoria_ocorrido on public.auditoria (ocorrido_em desc);

-- 3) GATILHO GENÉRICO: grava o que mudou em qualquer tabela auditada
-- Remove campos de ruído e protege os dados sensíveis de uma linha
create or replace function public.auditoria_limpar(p_linha jsonb)
returns jsonb language sql immutable as $$
  select coalesce(jsonb_object_agg(t.k,
           case when t.k = any (array['cpf', 'qr_secret', 'cpf_mascarado', 'token_hash'])
                then to_jsonb('(protegido)'::text) else t.v end), '{}'::jsonb)
  from jsonb_each(p_linha) as t(k, v)
  where t.k <> all (array['atualizado_em'])
    and not (t.k = any (array['cpf', 'qr_secret', 'cpf_mascarado', 'token_hash']) and t.v = 'null'::jsonb)
$$;

create or replace function public.auditar_tabela()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_sens   text[] := array['cpf', 'qr_secret', 'cpf_mascarado', 'token_hash'];
  v_ruido  text[] := array['atualizado_em'];
  v_ref    jsonb;
  v_mud    jsonb;
  v_det    jsonb;
  v_acao   text;
  v_id     uuid;
  v_ent    text;
  v_rotulo text;
begin
  -- Nome da entidade no singular (igual ao das ações já registradas por funções do sistema)
  v_ent := case tg_table_name
    when 'membros' then 'membro'
    when 'eventos' then 'evento'
    when 'presencas' then 'presenca'
    when 'instrumentos' then 'instrumento'
    when 'cargos' then 'cargo'
    when 'familias' then 'familia'
    when 'finalidades_evento' then 'finalidade'
    when 'usuarios' then 'usuario'
    when 'grupos' then 'grupo'
    when 'grupo_permissoes' then 'grupo_permissao'
    when 'usuario_vinculos' then 'vinculo'
    when 'estados' then 'estado'
    when 'regioes' then 'regiao'
    when 'setores' then 'setor'
    when 'comuns' then 'comum'
    else tg_table_name
  end;

  v_ref := case when tg_op = 'DELETE' then to_jsonb(old) else to_jsonb(new) end;
  begin
    v_id := (v_ref ->> 'id')::uuid;
  exception when others then
    v_id := null;
  end;

  if tg_op = 'INSERT' then
    v_acao := 'registro_criado';
    v_det := jsonb_build_object('depois', public.auditoria_limpar(to_jsonb(new)));
  elsif tg_op = 'DELETE' then
    v_acao := 'registro_excluido';
    v_det := jsonb_build_object('antes', public.auditoria_limpar(to_jsonb(old)));
  else
    select coalesce(jsonb_object_agg(n.key,
             case when n.key = any (v_sens) then to_jsonb('(alterado)'::text)
                  else jsonb_build_object('de', o.value, 'para', n.value) end), '{}'::jsonb)
      into v_mud
    from jsonb_each(to_jsonb(new)) as n
    left join jsonb_each(to_jsonb(old)) as o on o.key = n.key
    where n.value is distinct from o.value and n.key <> all (v_ruido);

    if v_mud = '{}'::jsonb then
      return new;   -- nada relevante mudou (por exemplo, só a data de atualização)
    end if;

    -- Exclusão lógica: a linha ganhou a data de exclusão
    v_acao := case when (to_jsonb(old) ->> 'excluido_em') is null and (to_jsonb(new) ->> 'excluido_em') is not null
                   then 'registro_excluido' else 'registro_alterado' end;
    v_det := jsonb_build_object('mudancas', v_mud)
             || case when v_acao = 'registro_excluido' then jsonb_build_object('logica', true) else '{}'::jsonb end;
  end if;

  -- Rótulo legível: nome, tipo, e-mail ou local; presenças e vínculos usam o nome do membro/usuário
  v_rotulo := coalesce(v_ref ->> 'nome', v_ref ->> 'tipo', v_ref ->> 'email', v_ref ->> 'local');
  if v_rotulo is null then
    begin
      if v_ref ? 'membro_id' then
        select m.nome into v_rotulo from public.membros m where m.id = (v_ref ->> 'membro_id')::uuid;
      elsif v_ref ? 'usuario_id' then
        select u.nome into v_rotulo from public.usuarios u where u.id = (v_ref ->> 'usuario_id')::uuid;
      end if;
    exception when others then
      v_rotulo := null;
    end;
  end if;
  if v_rotulo is not null then
    v_det := v_det || jsonb_build_object('rotulo', v_rotulo);
  end if;

  insert into public.auditoria (usuario_id, acao, entidade, entidade_id, detalhes)
  values ((select auth.uid()), v_acao, v_ent, v_id, v_det);

  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end;
$$;

-- Liga o gatilho nas tabelas que existirem
do $$
declare
  t text;
begin
  foreach t in array array[
    'membros', 'eventos', 'presencas', 'instrumentos', 'cargos', 'familias', 'finalidades_evento',
    'usuarios', 'grupos', 'grupo_permissoes', 'usuario_grupos', 'usuario_vinculos',
    'estados', 'regioes', 'setores', 'comuns'
  ] loop
    if to_regclass('public.' || t) is not null then
      execute format('drop trigger if exists trg_auditar on public.%I', t);
      execute format(
        'create trigger trg_auditar after insert or update or delete on public.%I for each row execute function public.auditar_tabela()', t);
    end if;
  end loop;
end $$;

-- 4) LOGIN: grava a entrada no sistema (o login NUNCA pode falhar por causa da auditoria)
create or replace function public.auditar_login()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  begin
    if new.last_sign_in_at is distinct from old.last_sign_in_at then
      insert into public.auditoria (usuario_id, acao, entidade, entidade_id, detalhes)
      select u.id, 'login', 'usuario', u.id, jsonb_build_object('rotulo', u.nome)
      from public.usuarios u where u.id = new.id;
    end if;
  exception when others then
    null;
  end;
  return new;
end;
$$;

do $$
begin
  drop trigger if exists trg_auditar_login on auth.users;
  create trigger trg_auditar_login
    after update of last_sign_in_at on auth.users
    for each row execute function public.auditar_login();
exception when others then
  raise notice 'Não foi possível ligar o registro de logins (auth.users): %', sqlerrm;
end $$;

-- 5) IMPRESSÕES E EXPORTAÇÕES (usado pela Auditoria agora e pelos Relatórios depois)
create or replace function public.registrar_uso(p_acao text, p_detalhes jsonb)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.tem_acesso() then
    raise exception 'Sem acesso.' using errcode = '42501';
  end if;
  if p_acao is null or p_acao not in
     ('relatorio_impresso', 'relatorio_exportado', 'auditoria_impressa', 'auditoria_exportada') then
    raise exception 'Ação de uso inválida.';
  end if;

  insert into public.auditoria (usuario_id, acao, entidade, entidade_id, detalhes)
  values ((select auth.uid()), p_acao, 'relatorio', null, coalesce(p_detalhes, '{}'::jsonb));
end;
$$;

-- 6) CONSULTA DA AUDITORIA (exige auditoria.visualizar; até 2000 linhas por consulta)
create or replace function public.listar_auditoria(
  p_inicio timestamptz, p_fim timestamptz, p_usuario uuid, p_entidade text, p_acao text,
  p_busca text, p_limite int, p_deslocamento int
)
returns table (
  id text, ocorrido_em timestamptz, usuario_id uuid, usuario_nome text, acao text,
  entidade text, entidade_id uuid, detalhes jsonb, total bigint
)
language plpgsql stable security definer set search_path = public as $$
declare
  v_lim   int  := least(greatest(coalesce(p_limite, 50), 1), 2000);
  v_off   int  := greatest(coalesce(p_deslocamento, 0), 0);
  v_busca text := nullif(btrim(coalesce(p_busca, '')), '');
  v_like  text;
begin
  perform public.exigir_permissao('auditoria.visualizar');
  -- A busca é texto simples (os símbolos de coringa são tratados como letras comuns)
  v_like := case when v_busca is null then null
                 else '%' || replace(replace(replace(v_busca, '\', '\\'), '%', '\%'), '_', '\_') || '%' end;

  return query
    select a.id::text, a.ocorrido_em, a.usuario_id, u.nome, a.acao, a.entidade, a.entidade_id, a.detalhes,
           count(*) over ()
    from public.auditoria a
    left join public.usuarios u on u.id = a.usuario_id
    where (p_inicio is null or a.ocorrido_em >= p_inicio)
      and (p_fim is null or a.ocorrido_em < p_fim)
      and (p_usuario is null or a.usuario_id = p_usuario)
      and (nullif(p_entidade, '') is null or a.entidade = p_entidade)
      and (nullif(p_acao, '') is null or a.acao = p_acao)
      and (v_like is null or a.detalhes::text ilike v_like or coalesce(u.nome, '') ilike v_like)
    order by a.ocorrido_em desc, a.id desc
    limit v_lim offset v_off;
end;
$$;

-- Opções dos filtros (usuários, tipos de item e ações já registrados)
create or replace function public.opcoes_auditoria()
returns table (tipo text, valor text, rotulo text)
language plpgsql stable security definer set search_path = public as $$
begin
  perform public.exigir_permissao('auditoria.visualizar');
  return query
    select 'USUARIO'::text, u.id::text, u.nome from public.usuarios u
    union all
    select 'ENTIDADE'::text, x.entidade, x.entidade
      from (select distinct a.entidade from public.auditoria a) x
    union all
    select 'ACAO'::text, y.acao, y.acao
      from (select distinct a.acao from public.auditoria a) y;
end;
$$;

-- 7) ORIGEM DO VISITANTE VINDA DO BANCO
alter table public.membros
  add column if not exists origem_comum_id uuid references public.comuns (id) on delete set null;

-- Toda a estrutura ativa (só nomes), para o atendente escolher a origem do visitante
create or replace function public.listar_origens_visitante()
returns table (nivel text, id uuid, parent_id uuid, nome text)
language plpgsql stable security definer set search_path = public as $$
begin
  perform public.exigir_permissao('portaria.cadastrar_visitante');
  return query
    select 'ESTADO'::text, e.id, null::uuid, e.nome
      from public.estados e where e.ativo
    union all
    select 'REGIAO'::text, r.id, r.estado_id, r.nome
      from public.regioes r join public.estados e on e.id = r.estado_id
     where r.ativo and e.ativo
    union all
    select 'SETOR'::text, s.id, s.regiao_id, s.nome
      from public.setores s
      join public.regioes r on r.id = s.regiao_id
      join public.estados e on e.id = r.estado_id
     where s.ativo and r.ativo and e.ativo
    union all
    select 'COMUM'::text, c.id, c.setor_id, c.nome
      from public.comuns c
      join public.setores s on s.id = c.setor_id
      join public.regioes r on r.id = s.regiao_id
      join public.estados e on e.id = r.estado_id
     where c.ativo and s.ativo and r.ativo and e.ativo;
end;
$$;

-- Nova versão do cadastro: a origem é uma comum cadastrada (escolhida na lista), sem texto livre
drop function if exists public.cadastrar_visitante(uuid, text, uuid, uuid, text, text);

create or replace function public.cadastrar_visitante(
  p_portaria_id uuid, p_nome text, p_cargo_id uuid, p_instrumento_id uuid, p_origem_comum_id uuid
)
returns uuid language plpgsql security definer set search_path = public as $$
declare
  v_p       public.portarias;
  v_comum   text;
  v_nome    text := btrim(regexp_replace(coalesce(p_nome, ''), '\s+', ' ', 'g'));
  v_origem  record;
  v_permite boolean;
  v_id      uuid;
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

  select c.permite_instrumento into v_permite from public.cargos c where c.id = p_cargo_id;
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

-- 8) PERMISSÕES DE EXECUÇÃO
revoke all on function public.auditoria_limpar(jsonb), public.auditar_tabela(), public.auditar_login()
  from public, anon, authenticated;

revoke all on function
  public.registrar_uso(text, jsonb),
  public.listar_auditoria(timestamptz, timestamptz, uuid, text, text, text, int, int),
  public.opcoes_auditoria(),
  public.listar_origens_visitante(),
  public.cadastrar_visitante(uuid, text, uuid, uuid, uuid)
  from public, anon;
grant execute on function
  public.registrar_uso(text, jsonb),
  public.listar_auditoria(timestamptz, timestamptz, uuid, text, text, text, int, int),
  public.opcoes_auditoria(),
  public.listar_origens_visitante(),
  public.cadastrar_visitante(uuid, text, uuid, uuid, uuid)
  to authenticated;

-- 9) VERIFICAÇÃO DE SEGURANÇA: testa a auditoria automática e as consultas.
--    Se alguma falhar, a migração INTEIRA é desfeita (nada fica alterado).
do $$
declare
  v_cargo  uuid;
  v_antes  bigint;
  v_depois bigint := 0;
  v_admin  uuid;
begin
  -- Uma alteração de teste (desfeita na hora) precisa gerar um registro de auditoria
  select c.id into v_cargo from public.cargos c limit 1;
  if v_cargo is not null then
    select count(*) into v_antes from public.auditoria where entidade = 'cargo';
    begin
      update public.cargos set nome = nome || ' (teste)' where id = v_cargo;
      select count(*) into v_depois from public.auditoria where entidade = 'cargo';
      raise exception 'sysmusica_teste_ok';
    exception when others then
      if sqlerrm <> 'sysmusica_teste_ok' then
        raise;
      end if;
    end;
    if v_depois <= v_antes then
      raise exception 'Verificação falhou: a auditoria automática não registrou a alteração de teste. Nada foi alterado.';
    end if;
  end if;

  -- O Administrador precisa conseguir consultar a auditoria e listar as origens
  select u.id into v_admin
  from public.usuarios u join public.grupos g on g.id = u.grupo_id
  where g.sistema and g.nome = 'Administrador' and u.ativo
  limit 1;

  if v_admin is not null then
    perform set_config('request.jwt.claims', json_build_object('sub', v_admin, 'role', 'authenticated')::text, true);
    perform count(*) from public.listar_auditoria(null, null, null, null, null, null, 10, 0);
    perform count(*) from public.opcoes_auditoria();
    perform count(*) from public.listar_origens_visitante();
    perform set_config('request.jwt.claims', '', true);
  end if;
end $$;

commit;
