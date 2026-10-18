-- =====================================================================
-- SysMúsica — Migração 0020: módulo de Backup (base)
--   * 4 permissões novas (backup.visualizar, criar, configurar e restaurar). Ficam TRAVADAS no banco: só o
--     grupo Administrador pode tê-las (um gatilho recusa qualquer outro grupo).
--   * Tabelas do módulo (sem acesso direto pelo navegador: só o servidor, com a chave secreta, as usa):
--     arquivos de backup, configuração das notificações (segredos criptografados) e destinatários de e-mail.
--   * Armazenamento privado "backups" (nenhum usuário acessa direto).
--   * Função de restauração em UMA transação (só o servidor a executa). Durante a restauração, a auditoria
--     automática linha a linha fica pausada e é gravada uma única entrada resumida.
-- Requer as migrações até a 0015. Idempotente, uma única transação.
-- Ao final, a migração TESTA a trava de administrador, a restauração e a auditoria: se algo falhar, tudo é desfeito.
-- =====================================================================
begin;

do $$
begin
  if to_regprocedure('public.auditar_tabela()') is null
     or to_regprocedure('public.auditoria_limpar(jsonb)') is null
     or to_regclass('public.usuario_grupos') is null
     or to_regclass('public.portarias') is null then
    raise exception 'Aplique primeiro as migrações anteriores (pelo menos até a 0015).';
  end if;
end $$;

-- 1) PERMISSÕES (iguais a CATALOGO_PERMISSOES em src/lib/permissoes.ts); só o Administrador recebe
insert into public.permissoes (codigo, modulo, acao, descricao) values
  ('backup.visualizar', 'Backup', 'Visualizar', 'Ver, baixar e verificar os backups'),
  ('backup.criar',      'Backup', 'Criar',      'Fazer backups'),
  ('backup.configurar', 'Backup', 'Configurar', 'Configurar as notificações e excluir backups'),
  ('backup.restaurar',  'Backup', 'Restaurar',  'Visualizar e restaurar dados a partir de um backup')
on conflict (codigo) do update
  set modulo = excluded.modulo, acao = excluded.acao, descricao = excluded.descricao;

insert into public.grupo_permissoes (grupo_id, permissao_codigo)
select g.id, p.codigo
from public.grupos g cross join public.permissoes p
where g.sistema and g.nome = 'Administrador'
on conflict do nothing;

-- 2) TRAVA: permissões de backup só no grupo Administrador (vale para qualquer tela ou função)
create or replace function public.backup_somente_administrador()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.permissao_codigo like 'backup.%' then
    if not exists (
      select 1 from public.grupos g
      where g.id = new.grupo_id and g.sistema and g.nome = 'Administrador'
    ) then
      raise exception 'As permissões de backup só podem pertencer ao grupo Administrador.';
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_backup_somente_administrador on public.grupo_permissoes;
create trigger trg_backup_somente_administrador
  before insert or update on public.grupo_permissoes
  for each row execute function public.backup_somente_administrador();

-- 3) TABELAS DO MÓDULO (sem acesso direto: só o servidor, com a chave secreta)
create table if not exists public.backup_arquivos (
  id            uuid primary key default gen_random_uuid(),
  criado_em     timestamptz not null default now(),
  tipo          text not null check (tipo in ('manual', 'seguranca', 'diario', 'semanal', 'quinzenal', 'mensal')),
  situacao      text not null check (situacao in ('ok', 'falhou')),
  caminho       text,
  tamanho_bytes bigint,
  sha256        text,
  contagens     jsonb,
  criado_por    uuid,
  observacao    text,
  erro          text,
  destinos      jsonb not null default '{"sistema": true}'::jsonb
);
create index if not exists idx_backup_arquivos_criado on public.backup_arquivos (criado_em desc);

create table if not exists public.backup_configuracao (
  id                     int primary key default 1 check (id = 1),
  notificar_sucesso      boolean not null default true,
  notificar_falha        boolean not null default true,
  notificar_restauracao  boolean not null default true,
  telegram_ativo         boolean not null default false,
  telegram_token_cifrado text,
  telegram_chat_id       text,
  email_ativo            boolean not null default false,
  email_provedor         text check (email_provedor in ('smtp', 'resend')),
  email_config_cifrado   text,
  atualizado_em          timestamptz not null default now(),
  atualizado_por         uuid
);
insert into public.backup_configuracao (id) values (1) on conflict (id) do nothing;

create table if not exists public.backup_destinatarios (
  id        uuid primary key default gen_random_uuid(),
  email     text not null,
  ativo     boolean not null default true,
  criado_em timestamptz not null default now()
);
create unique index if not exists backup_destinatarios_email_unico on public.backup_destinatarios (lower(email));

alter table public.backup_arquivos      enable row level security;
alter table public.backup_configuracao  enable row level security;
alter table public.backup_destinatarios enable row level security;
revoke all on public.backup_arquivos, public.backup_configuracao, public.backup_destinatarios from anon, authenticated;

-- 4) ARMAZENAMENTO PRIVADO (sem políticas: nenhum usuário acessa direto; só o servidor)
insert into storage.buckets (id, name, public, file_size_limit)
values ('backups', 'backups', false, 52428800)
on conflict (id) do update set public = false, file_size_limit = excluded.file_size_limit;

-- 5) AUDITORIA AUTOMÁTICA: pausada durante a restauração (a restauração grava uma entrada resumida)
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
  -- Restauração de backup em andamento: não registra linha a linha
  if current_setting('sysmusica.restaurando', true) = 'sim' then
    if tg_op = 'DELETE' then
      return old;
    end if;
    return new;
  end if;

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

-- 6) RESTAURAÇÃO EM UMA TRANSAÇÃO (só o servidor executa). p_operacoes =
--    [{ "tabela": "membros", "acao": "inserir|atualizar|excluir_logico|excluir", "colunas": [...], "linhas": [...] }]
--    Só as tabelas da lista abaixo são aceitas. As colunas geradas nunca são gravadas, e só as colunas
--    informadas pelo backup são tocadas (colunas criadas depois do backup não são zeradas).
create or replace function public.backup_aplicar(p_usuario uuid, p_operacoes jsonb, p_resumo jsonb)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_op        jsonb;
  v_tabela    text;
  v_acao      text;
  v_linhas    jsonb;
  v_colunas   text[];
  v_def       record;
  v_cols      text;
  v_bcols     text;
  v_set       text;
  v_pk_cond   text;
  v_extra     text;
  v_n         bigint;
  v_ignorados bigint;
  v_resultado jsonb := '[]'::jsonb;
begin
  if p_operacoes is null or jsonb_typeof(p_operacoes) <> 'array' then
    raise exception 'Operações inválidas.';
  end if;

  perform set_config('sysmusica.restaurando', 'sim', true);

  for v_op in select * from jsonb_array_elements(p_operacoes) loop
    v_tabela := v_op ->> 'tabela';
    v_acao   := v_op ->> 'acao';
    v_linhas := coalesce(v_op -> 'linhas', '[]'::jsonb);

    select t.* into v_def
    from (values
      ('estados',             array['id'],                              false, false, ''),
      ('regioes',             array['id'],                              false, false, ''),
      ('setores',             array['id'],                              false, false, ''),
      ('comuns',              array['id'],                              false, false, ''),
      ('familias',            array['id'],                              false, false, ''),
      ('cargos',              array['id'],                              false, false, ''),
      ('finalidades_evento',  array['id'],                              false, false, ''),
      ('instrumentos',        array['id'],                              false, false, ''),
      ('grupos',              array['id'],                              false, false, ''),
      ('grupo_permissoes',    array['grupo_id', 'permissao_codigo'],    false, false, ''),
      ('usuarios',            array['id'],                              false, false, 'login'),
      ('usuario_grupos',      array['usuario_id', 'grupo_id'],          false, false, ''),
      ('usuario_vinculos',    array['usuario_id', 'nivel', 'alvo_id'],  false, false, ''),
      ('membros',             array['id'],                              true,  false, ''),
      ('eventos',             array['id'],                              true,  false, ''),
      ('portarias',           array['id'],                              true,  false, ''),
      ('portarias_historico', array['id'],                              false, true,  ''),
      ('presencas',           array['id'],                              true,  false, '')
    ) as t(tabela, pk, soft, so_inserir, extra)
    where t.tabela = v_tabela;
    if not found then
      raise exception 'Tabela não permitida na restauração: %', coalesce(v_tabela, '(vazia)');
    end if;

    if v_acao is null or v_acao not in ('inserir', 'atualizar', 'excluir_logico', 'excluir') then
      raise exception 'Ação inválida na restauração: %', coalesce(v_acao, '(vazia)');
    end if;
    if v_def.so_inserir and v_acao <> 'inserir' then
      raise exception 'A tabela % só aceita devolver registros apagados.', v_tabela;
    end if;
    if v_acao = 'excluir_logico' and not v_def.soft then
      raise exception 'A tabela % não usa exclusão lógica.', v_tabela;
    end if;
    if v_acao = 'excluir' and v_def.soft then
      raise exception 'Os itens da tabela % são excluídos logicamente.', v_tabela;
    end if;
    if jsonb_typeof(v_linhas) <> 'array' then
      raise exception 'Linhas inválidas em %.', v_tabela;
    end if;
    if jsonb_array_length(v_linhas) = 0 then
      continue;
    end if;

    select coalesce(array_agg(x), '{}'::text[]) into v_colunas
    from jsonb_array_elements_text(coalesce(v_op -> 'colunas', '[]'::jsonb)) as x;

    if not (v_def.pk <@ v_colunas) then
      raise exception 'Faltam as colunas de identificação em %.', v_tabela;
    end if;

    -- Só colunas que existem e podem ser gravadas (as geradas ficam de fora)
    select string_agg(quote_ident(c.column_name), ', ' order by c.ordinal_position),
           string_agg(format('b.%I', c.column_name), ', ' order by c.ordinal_position),
           string_agg(format('%1$I = b.%1$I', c.column_name), ', ' order by c.ordinal_position)
             filter (where c.column_name <> all (v_def.pk))
      into v_cols, v_bcols, v_set
    from information_schema.columns c
    where c.table_schema = 'public' and c.table_name = v_tabela
      and c.is_generated = 'NEVER' and c.column_name = any (v_colunas);

    select string_agg(format('c.%1$I = b.%1$I', k), ' and ') into v_pk_cond from unnest(v_def.pk) as k;

    v_ignorados := 0;

    if v_acao = 'inserir' then
      -- Usuários só voltam se a conta de login ainda existir (a senha não é guardada no backup)
      v_extra := case when v_def.extra = 'login' then 'where exists (select 1 from auth.users a where a.id = b.id)' else '' end;
      execute format(
        'insert into public.%1$I (%2$s) select %3$s from jsonb_populate_recordset(null::public.%1$I, $1) b %4$s',
        v_tabela, v_cols, v_bcols, v_extra) using v_linhas;
      get diagnostics v_n = row_count;
      v_ignorados := jsonb_array_length(v_linhas) - v_n;

    elsif v_acao = 'atualizar' then
      if v_set is null then
        v_n := 0;
      else
        execute format(
          'update public.%1$I c set %2$s from jsonb_populate_recordset(null::public.%1$I, $1) b where %3$s',
          v_tabela, v_set, v_pk_cond) using v_linhas;
        get diagnostics v_n = row_count;
      end if;

    elsif v_acao = 'excluir_logico' then
      execute format(
        'update public.%1$I c set excluido_em = now() from jsonb_populate_recordset(null::public.%1$I, $1) b where %2$s and c.excluido_em is null',
        v_tabela, v_pk_cond) using v_linhas;
      get diagnostics v_n = row_count;

    else
      execute format(
        'delete from public.%1$I c using jsonb_populate_recordset(null::public.%1$I, $1) b where %2$s',
        v_tabela, v_pk_cond) using v_linhas;
      get diagnostics v_n = row_count;
    end if;

    v_resultado := v_resultado || jsonb_build_object(
      'tabela', v_tabela, 'acao', v_acao, 'afetados', v_n, 'ignorados', v_ignorados);
  end loop;

  perform set_config('sysmusica.restaurando', '', true);

  -- Uma única entrada resumida na auditoria (a auditoria linha a linha ficou pausada)
  insert into public.auditoria (usuario_id, acao, entidade, entidade_id, detalhes)
  values (p_usuario, 'backup_restaurado', 'backup', null,
          coalesce(p_resumo, '{}'::jsonb) || jsonb_build_object('operacoes', v_resultado));

  return v_resultado;
end;
$$;

-- 7) PERMISSÕES DE EXECUÇÃO: a restauração só roda pelo servidor (chave secreta)
revoke all on function public.backup_aplicar(uuid, jsonb, jsonb) from public, anon, authenticated;
grant execute on function public.backup_aplicar(uuid, jsonb, jsonb) to service_role;
revoke all on function public.backup_somente_administrador() from public, anon, authenticated;

-- 8) VERIFICAÇÃO DE SEGURANÇA: testa a trava, a restauração e a auditoria. Se algo falhar, a migração INTEIRA é desfeita.
do $$
declare
  v_cargo    public.cargos;
  v_grupo    uuid;
  v_bloqueou boolean := false;
  v_antes    bigint;
  v_depois   bigint;
  v_nome     text;
  v_admin    uuid;
begin
  -- 8.1) Dar permissão de backup a um grupo que NÃO é o Administrador precisa ser recusado
  select g.id into v_grupo
  from public.grupos g
  where not (g.sistema and g.nome = 'Administrador')
  limit 1;

  if v_grupo is not null then
    begin
      insert into public.grupo_permissoes (grupo_id, permissao_codigo) values (v_grupo, 'backup.visualizar');
      raise exception 'sysmusica_sem_bloqueio';
    exception when others then
      if sqlerrm like '%só podem pertencer ao grupo Administrador%' then
        v_bloqueou := true;
      elsif sqlerrm <> 'sysmusica_sem_bloqueio' then
        raise exception 'Verificação falhou (trava do administrador): %', sqlerrm;
      end if;
    end;
    if not v_bloqueou then
      raise exception 'Verificação falhou: o banco aceitou uma permissão de backup em um grupo comum. Nada foi alterado.';
    end if;
  end if;

  -- 8.2) A restauração de teste altera o cargo, não registra auditoria linha a linha, e tudo é desfeito
  select * into v_cargo from public.cargos limit 1;
  if found then
    select count(*) into v_antes from public.auditoria where entidade = 'cargo';
    begin
      perform public.backup_aplicar(
        null,
        jsonb_build_array(jsonb_build_object(
          'tabela', 'cargos', 'acao', 'atualizar', 'colunas', jsonb_build_array('id', 'nome'),
          'linhas', jsonb_build_array(jsonb_build_object('id', v_cargo.id, 'nome', v_cargo.nome || ' (teste)')))),
        '{}'::jsonb);
      select nome into v_nome from public.cargos where id = v_cargo.id;
      select count(*) into v_depois from public.auditoria where entidade = 'cargo';
      if v_nome is distinct from v_cargo.nome || ' (teste)' then
        raise exception 'Verificação falhou: a restauração de teste não alterou o cargo.';
      end if;
      if v_depois <> v_antes then
        raise exception 'Verificação falhou: a auditoria linha a linha não foi pausada na restauração.';
      end if;
      raise exception 'sysmusica_teste_ok';
    exception when others then
      if sqlerrm <> 'sysmusica_teste_ok' then
        raise;
      end if;
    end;

    -- 8.3) Depois de desfeito, a auditoria automática precisa voltar a funcionar
    select count(*) into v_antes from public.auditoria where entidade = 'cargo';
    begin
      update public.cargos set nome = nome || ' (teste)' where id = v_cargo.id;
      select count(*) into v_depois from public.auditoria where entidade = 'cargo';
      if v_depois <= v_antes then
        raise exception 'Verificação falhou: a auditoria automática deixou de registrar as alterações.';
      end if;
      raise exception 'sysmusica_teste_ok';
    exception when others then
      if sqlerrm <> 'sysmusica_teste_ok' then
        raise;
      end if;
    end;
  end if;

  -- 8.4) O Administrador precisa ter recebido as permissões
  select u.id into v_admin
  from public.usuarios u join public.grupos g on g.id = u.grupo_id
  where g.sistema and g.nome = 'Administrador' and u.ativo
  limit 1;

  if v_admin is not null then
    perform set_config('request.jwt.claims', json_build_object('sub', v_admin, 'role', 'authenticated')::text, true);
    if not public.tem_permissao('backup.restaurar') or not public.tem_permissao('backup.visualizar') then
      raise exception 'Verificação falhou: o Administrador não recebeu as permissões de backup. Nada foi alterado.';
    end if;
    perform set_config('request.jwt.claims', '', true);
  end if;

  if not exists (select 1 from public.backup_configuracao where id = 1) then
    raise exception 'Verificação falhou: a configuração do backup não foi criada. Nada foi alterado.';
  end if;
end $$;

commit;
