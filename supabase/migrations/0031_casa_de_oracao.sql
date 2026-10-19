-- 0031 — Renomeia "Comum" para "Casa de Oração" em todo o banco
-- Tabela comuns -> casas_oracao; coluna comum_id -> casa_oracao_id; nível COMUM -> CASA_ORACAO;
-- funções, gatilhos, políticas, mensagens e descrições de permissões. Roda tudo ou nada.
-- Backups gerados ANTES desta migração não restauram depois dela (os nomes das tabelas mudaram).
set local check_function_bodies = off;

do $$
begin
  if to_regclass('public.comuns') is null then
    raise exception 'A tabela comuns não existe (migração já aplicada?). Nada foi alterado.';
  end if;
end $$;

-- 1) Guarda quem pode executar cada função que será recriada
create temp table _acl_fn on commit drop as
select p.proname::text as velho,
       case when a.grantee = 0 then 'public' else a.grantee::regrole::text end as quem
from pg_proc p
cross join lateral aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) a
where p.pronamespace = 'public'::regnamespace
  and a.privilege_type = 'EXECUTE'
  and p.proname in ('cadastrar_visitante', 'comum_na_abrangencia', 'comum_na_minha_abrangencia', 'comuns_propaga_nome', 'eventos_do_painel', 'eventos_valida_comum', 'listar_eventos_para_portaria', 'membros_sincroniza_comum', 'registrar_entrada_avulsa', 'relatorio_eventos', 'relatorio_membros', 'relatorio_presencas', 'rotulo_setor', 'transferir_comum');

-- 2) Guarda e remove os gatilhos que usam essas funções; remove políticas e funções que mudam
create temp table _trg_fn on commit drop as
select pg_get_triggerdef(t.oid) as def, t.tgname::text as nome, c.relname::text as tabela
from pg_trigger t
join pg_class c on c.oid = t.tgrelid
join pg_proc p on p.oid = t.tgfoid
where not t.tgisinternal and p.pronamespace = 'public'::regnamespace
  and p.proname in ('cadastrar_visitante', 'comum_na_abrangencia', 'comum_na_minha_abrangencia', 'comuns_propaga_nome', 'eventos_do_painel', 'eventos_valida_comum', 'listar_eventos_para_portaria', 'membros_sincroniza_comum', 'registrar_entrada_avulsa', 'relatorio_eventos', 'relatorio_membros', 'relatorio_presencas', 'rotulo_setor', 'transferir_comum');
do $$
declare r record;
begin
  for r in select * from _trg_fn loop
    execute format('drop trigger %I on public.%I', r.nome, r.tabela);
  end loop;
end $$;
drop policy if exists regiao_eventos on public.eventos;
drop policy if exists regiao_membros on public.membros;

drop function if exists public.cadastrar_visitante(p_portaria_id uuid, p_nome text, p_cargo_id uuid, p_instrumento_id uuid, p_origem_comum_id uuid, p_membro_id uuid, p_foto_path text);
drop function if exists public.comum_na_abrangencia(p_comum uuid);
drop function if exists public.comum_na_minha_abrangencia(p_comum uuid);
drop function if exists public.comuns_propaga_nome();
drop function if exists public.eventos_do_painel();
drop function if exists public.eventos_valida_comum();
drop function if exists public.listar_eventos_para_portaria();
drop function if exists public.membros_sincroniza_comum();
drop function if exists public.registrar_entrada_avulsa(p_portaria_id uuid, p_linha_codigo text, p_toca boolean, p_instrumento_id uuid, p_origem_comum_id uuid, p_origem_texto text);
drop function if exists public.relatorio_eventos(p_inicio timestamp with time zone, p_fim timestamp with time zone, p_regiao uuid, p_setor uuid, p_comum uuid, p_limite integer);
drop function if exists public.relatorio_membros(p_regiao uuid, p_setor uuid, p_comum uuid, p_cargo uuid, p_instrumento uuid, p_status text, p_visitante text, p_limite integer);
drop function if exists public.relatorio_presencas(p_inicio timestamp with time zone, p_fim timestamp with time zone, p_evento uuid, p_regiao uuid, p_setor uuid, p_comum uuid, p_status text, p_limite integer);
drop function if exists public.rotulo_setor(p_comum uuid);
drop function if exists public.transferir_comum(p_comum uuid, p_setor uuid, p_justificativa text);

-- 3) Tabelas, colunas, restrições e índices
alter table public.comuns rename to casas_oracao;
alter table public.comuns_historico rename to casas_oracao_historico;
alter table public.casas_oracao_historico rename column comum_id to casa_oracao_id;
alter table public.eventos rename column comum_id to casa_oracao_id;
alter table public.membros rename column comum_id to casa_oracao_id;
alter table public.membros rename column origem_comum_id to origem_casa_oracao_id;
alter table public.portarias rename column comum_id to casa_oracao_id;
alter table public.presencas_avulsas rename column origem_comum_id to origem_casa_oracao_id;

alter table public.casas_oracao rename constraint comuns_pkey to casas_oracao_pkey;
alter table public.casas_oracao rename constraint comuns_setor_id_fkey to casas_oracao_setor_id_fkey;
alter table public.casas_oracao_historico rename constraint comuns_historico_pkey to casas_oracao_historico_pkey;
alter table public.eventos rename constraint eventos_comum_id_fkey to eventos_casa_oracao_id_fkey;
alter table public.membros rename constraint membros_comum_id_fkey to membros_casa_oracao_id_fkey;
alter table public.membros rename constraint membros_origem_comum_id_fkey to membros_origem_casa_oracao_id_fkey;
alter table public.portarias rename constraint portarias_comum_id_fkey to portarias_casa_oracao_id_fkey;
alter table public.presencas_avulsas rename constraint presencas_avulsas_origem_comum_id_fkey to presencas_avulsas_origem_casa_oracao_id_fkey;
alter index public.comuns_nome_unico rename to casas_oracao_nome_unico;
alter index public.idx_comuns_setor rename to idx_casas_oracao_setor;
alter index public.idx_eventos_comum rename to idx_eventos_casa_oracao;
alter index public.idx_membros_comum rename to idx_membros_casa_oracao;
alter index public.idx_portarias_comum rename to idx_portarias_casa_oracao;

-- 4) Nível dos vínculos de usuário: COMUM -> CASA_ORACAO
alter table public.usuario_vinculos drop constraint usuario_vinculos_nivel_check;
update public.usuario_vinculos set nivel = 'CASA_ORACAO' where nivel = 'COMUM';
alter table public.usuario_vinculos add constraint usuario_vinculos_nivel_check
  check (nivel = any (array['ESTADO'::text, 'REGIAO'::text, 'SETOR'::text, 'CASA_ORACAO'::text]));

-- 5) Funções com os nomes e mensagens novos

CREATE OR REPLACE FUNCTION public.auditar_tabela()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
    when 'casas_oracao' then 'casa_oracao'
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
$function$;

CREATE OR REPLACE FUNCTION public.cadastrar_visitante(p_portaria_id uuid, p_nome text, p_cargo_id uuid, p_instrumento_id uuid, p_origem_casa_oracao_id uuid, p_membro_id uuid, p_foto_path text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_p          public.portarias;
  v_casa_oracao      text;
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
  select c.nome into v_casa_oracao from public.casas_oracao c where c.id = v_p.casa_oracao_id;
  if v_casa_oracao is null then
    raise exception 'A casa de oração desta portaria não foi encontrada.';
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

  -- A origem precisa ser uma casa de oração cadastrada, ativa e com setor, região e estado ativos
  select c.nome as casa_oracao, c.cidade as cidade, r.nome as regiao into v_origem
  from public.casas_oracao c
  join public.setores s on s.id = c.setor_id
  join public.regioes r on r.id = s.regiao_id
  join public.estados e on e.id = r.estado_id
  where c.id = p_origem_casa_oracao_id and c.ativo and s.ativo and r.ativo and e.ativo;
  if not found then
    raise exception 'Escolha a igreja de origem na lista (estado, região, setor e casa de oração). Se ela não aparecer, peça a um administrador para cadastrá-la em Organização.';
  end if;

  if exists (
    select 1 from public.membros m
    where m.casa_oracao_id = v_p.casa_oracao_id and m.excluido_em is null
      and public.normalizar_texto(m.nome) = public.normalizar_texto(v_nome)
  ) then
    raise exception 'Já existe um membro com este nome nesta casa de oração. Busque pelo nome completo em vez de cadastrar de novo.';
  end if;

  insert into public.membros
    (id, nome, congregacao, cargo_id, instrumento_id, status, casa_oracao_id, cidade, bairro, visitante,
     origem_casa_oracao_id, foto_path)
  values
    (p_membro_id, v_nome, v_casa_oracao, p_cargo_id, p_instrumento_id, 'Ativo', v_p.casa_oracao_id,
     coalesce(v_origem.cidade, v_origem.regiao), v_origem.casa_oracao, true, p_origem_casa_oracao_id, p_foto_path)
  returning id into v_id;

  perform public.registrar_auditoria('visitante_cadastrado', 'membro', v_id,
            jsonb_build_object('portaria_id', p_portaria_id, 'casa_oracao_id', v_p.casa_oracao_id,
                               'origem_casa_oracao_id', p_origem_casa_oracao_id, 'rotulo', v_nome));
  return v_id;
end;
$function$;

CREATE OR REPLACE FUNCTION public.cartao_membro(p_portaria_id uuid, p_membro_id uuid)
 RETURNS TABLE(membro_id uuid, nome text, congregacao text, cargo text, instrumento text, cidade text, bairro text, status text, foto_path text, ja_registrado_em timestamp with time zone)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select m.id, m.nome, m.congregacao, c.nome, i.nome, m.cidade, m.bairro, m.status, m.foto_path,
         (select min(pr.hora_entrada)
            from public.presencas pr
            join public.portarias po on po.id = p_portaria_id
           where pr.membro_id = m.id
             and pr.excluido_em is null
             and (pr.portaria_id = po.id or pr.evento_id = po.evento_id))
  from public.membros m
  left join public.cargos c on c.id = m.cargo_id
  left join public.instrumentos i on i.id = m.instrumento_id
  where m.id = p_membro_id and m.excluido_em is null
    and public.casa_oracao_na_abrangencia(m.casa_oracao_id)
$function$;

CREATE OR REPLACE FUNCTION public.casa_oracao_na_abrangencia(p_casa_oracao uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select public.tem_acesso_total_organizacao() or public.casa_oracao_na_minha_abrangencia(p_casa_oracao)
$function$;

CREATE OR REPLACE FUNCTION public.casa_oracao_na_minha_abrangencia(p_casa_oracao uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select p_casa_oracao is not null and exists (
    select 1
    from public.casas_oracao c
    join public.setores s on s.id = c.setor_id
    join public.regioes r on r.id = s.regiao_id
    join public.estados e on e.id = r.estado_id
    join public.usuario_vinculos v
      on v.usuario_id = (select auth.uid())
     and ((v.nivel = 'CASA_ORACAO'  and v.alvo_id = c.id)
       or (v.nivel = 'SETOR'  and v.alvo_id = s.id)
       or (v.nivel = 'REGIAO' and v.alvo_id = r.id)
       or (v.nivel = 'ESTADO' and v.alvo_id = e.id))
    where c.id = p_casa_oracao and c.ativo and s.ativo and r.ativo and e.ativo
  )
$function$;

CREATE OR REPLACE FUNCTION public.casas_oracao_propaga_nome()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if new.nome is distinct from old.nome then
    update public.membros set congregacao = new.nome where casa_oracao_id = new.id;
  end if;
  return new;
end;
$function$;

CREATE OR REPLACE FUNCTION public.contagem_membros_por()
 RETURNS TABLE(tipo text, id uuid, qtd bigint)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  perform public.exigir_permissao('membros.visualizar');

  return query
    select 'INSTRUMENTO'::text, m.instrumento_id, count(*)
      from public.membros m
     where m.excluido_em is null and m.instrumento_id is not null
       and public.casa_oracao_na_abrangencia(m.casa_oracao_id)
     group by m.instrumento_id
    union all
    select 'CARGO'::text, m.cargo_id, count(*)
      from public.membros m
     where m.excluido_em is null and public.casa_oracao_na_abrangencia(m.casa_oracao_id)
     group by m.cargo_id;
end;
$function$;

CREATE OR REPLACE FUNCTION public.criar_portaria(p_evento_id uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_uid    uuid := (select auth.uid());
  v_dia    date := (now() at time zone 'America/Sao_Paulo')::date;
  v_evento public.eventos;
  v_usadas int;
  v_total  boolean;
  v_setor  uuid;
  v_id     uuid;
begin
  perform public.exigir_permissao('portarias.criar');
  v_total := public.tem_permissao('portarias.controle_total');

  -- Serializa as criações do MESMO usuário no MESMO dia (a 2ª requisição espera e recota)
  perform pg_advisory_xact_lock(hashtextextended('portarias:' || v_uid::text || ':' || v_dia::text, 0));

  select count(*)::int into v_usadas
  from public.portarias p
  where p.criada_por = v_uid and p.dia_criacao = v_dia;   -- inclui rejeitadas e excluídas

  if not v_total and v_usadas >= public.limite_diario_portarias() then
    raise exception 'Você atingiu o limite máximo de % portarias criadas hoje. Novas criações estarão disponíveis no próximo dia.',
      public.limite_diario_portarias();
  end if;

  select * into v_evento from public.eventos e where e.id = p_evento_id and e.excluido_em is null;
  if not found then
    raise exception 'Evento não encontrado.';
  end if;
  if v_evento.casa_oracao_id is null then
    raise exception 'Escolha a casa de oração do evento (Eventos > Editar) antes de criar a portaria.';
  end if;

  select c.setor_id into v_setor from public.casas_oracao c where c.id = v_evento.casa_oracao_id;
  if v_setor is null then
    raise exception 'A casa de oração deste evento ainda não tem setor. Peça a um administrador para vinculá-la a um setor (Administração > Organização).';
  end if;
  if not public.casa_oracao_na_abrangencia(v_evento.casa_oracao_id) then
    raise exception 'Este evento está fora da sua abrangência (casa de oração de outro setor).' using errcode = '42501';
  end if;

  if exists (select 1 from public.portarias p
             where p.evento_id = p_evento_id and p.excluido_em is null
               and p.status in ('PENDENTE_APROVACAO', 'APROVADA')) then
    raise exception 'Já existe uma portaria pendente ou aprovada para este evento.';
  end if;

  insert into public.portarias (evento_id, casa_oracao_id, cidade, criada_por, dia_criacao)
  values (p_evento_id, v_evento.casa_oracao_id, public.rotulo_setor(v_evento.casa_oracao_id), v_uid, v_dia)
  returning id into v_id;

  insert into public.portarias_historico (portaria_id, acao, status_novo, usuario_id)
  values (v_id, 'CRIADA', 'PENDENTE_APROVACAO', v_uid);

  perform public.registrar_auditoria('portaria_criada', 'portaria', v_id,
            jsonb_build_object('evento_id', p_evento_id,
                               'acima_do_limite', v_usadas >= public.limite_diario_portarias()));
  return v_id;
end;
$function$;

CREATE OR REPLACE FUNCTION public.decidir_portaria(p_id uuid, p_aprovar boolean, p_motivo text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_uid     uuid := (select auth.uid());
  v_p       public.portarias;
  v_motivo  text := nullif(btrim(coalesce(p_motivo, '')), '');
  v_novo    text;
  v_propria boolean;
  v_fora    boolean;
begin
  perform public.exigir_permissao('portarias.aprovar');

  select * into v_p from public.portarias p where p.id = p_id and p.excluido_em is null for update;
  if not found then
    raise exception 'Portaria não encontrada.';
  end if;
  if v_p.status <> 'PENDENTE_APROVACAO' then
    raise exception 'Esta portaria já foi decidida e não pode mais ser alterada.';
  end if;

  v_propria := v_p.criada_por = v_uid;
  v_fora    := not public.casa_oracao_na_minha_abrangencia(v_p.casa_oracao_id);

  if v_propria and not public.tem_permissao('portarias.controle_total') then
    raise exception 'Você não pode aprovar ou rejeitar uma portaria criada por você.' using errcode = '42501';
  end if;
  if v_fora and not public.tem_acesso_total_organizacao() then
    raise exception 'Esta portaria está fora da sua abrangência de atuação (setor).' using errcode = '42501';
  end if;

  if not p_aprovar and (v_motivo is null or char_length(v_motivo) < 5) then
    raise exception 'Informe o motivo da rejeição (mínimo de 5 caracteres).';
  end if;
  if v_motivo is not null and char_length(v_motivo) > 300 then
    raise exception 'O motivo pode ter no máximo 300 caracteres.';
  end if;

  v_novo := case when p_aprovar then 'APROVADA' else 'REJEITADA' end;

  update public.portarias
     set status = v_novo, decidida_por = v_uid, decidida_em = now(),
         motivo_rejeicao = case when p_aprovar then null else v_motivo end,
         decisao_controle_total = (v_propria or v_fora)
   where id = p_id;

  insert into public.portarias_historico (portaria_id, acao, status_anterior, status_novo, usuario_id, motivo)
  values (p_id, v_novo, v_p.status, v_novo, v_uid,
          case when v_propria or v_fora then concat_ws(' · ', 'Decisão por controle total', v_motivo) else v_motivo end);

  perform public.registrar_auditoria('portaria_' || lower(v_novo), 'portaria', p_id,
            jsonb_build_object('status_anterior', v_p.status, 'motivo', v_motivo,
                               'controle_total', (v_propria or v_fora)));
end;
$function$;

CREATE OR REPLACE FUNCTION public.definir_foto_membro(p_membro_id uuid, p_path text)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_antigo text;
  v_casa_oracao  uuid;
begin
  perform public.exigir_permissao('membros.foto');
  perform public.validar_foto_membro(p_membro_id, p_path);

  select m.foto_path, m.casa_oracao_id into v_antigo, v_casa_oracao
  from public.membros m where m.id = p_membro_id and m.excluido_em is null for update;
  if not found or not public.casa_oracao_na_abrangencia(v_casa_oracao) then
    raise exception 'Membro não encontrado.';
  end if;

  update public.membros set foto_path = p_path where id = p_membro_id;

  perform public.registrar_auditoria('foto_definida', 'membro', p_membro_id,
            jsonb_build_object('caminho', p_path));
  return v_antigo;
end;
$function$;

CREATE OR REPLACE FUNCTION public.definir_vinculos(p_usuario uuid, p_vinculos jsonb)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_item  jsonb;
  v_nivel text;
  v_alvo  uuid;
  v_lista jsonb := coalesce(p_vinculos, '[]'::jsonb);
  v_ok    boolean;
begin
  perform public.exigir_permissao('usuarios.vinculos');

  if not exists (select 1 from public.usuarios u where u.id = p_usuario) then
    raise exception 'Usuário não encontrado.';
  end if;
  if jsonb_typeof(v_lista) <> 'array' then
    raise exception 'Vínculos inválidos.';
  end if;

  delete from public.usuario_vinculos where usuario_id = p_usuario;

  for v_item in select * from jsonb_array_elements(v_lista) loop
    v_nivel := v_item ->> 'nivel';
    v_alvo  := (v_item ->> 'alvo_id')::uuid;
    v_ok := case v_nivel
      when 'ESTADO' then exists (select 1 from public.estados x where x.id = v_alvo)
      when 'REGIAO' then exists (select 1 from public.regioes x where x.id = v_alvo)
      when 'SETOR'  then exists (select 1 from public.setores x where x.id = v_alvo)
      when 'CASA_ORACAO'  then exists (select 1 from public.casas_oracao x where x.id = v_alvo)
      else false
    end;
    if not v_ok then
      raise exception 'Vínculo inválido: o cadastro escolhido não existe mais.';
    end if;
    insert into public.usuario_vinculos (usuario_id, nivel, alvo_id) values (p_usuario, v_nivel, v_alvo)
    on conflict do nothing;
  end loop;

  perform public.registrar_auditoria('vinculos_definidos', 'usuario', p_usuario,
            jsonb_build_object('vinculos', v_lista));
end;
$function$;

CREATE OR REPLACE FUNCTION public.entradas_avulsas_da_portaria(p_portaria_id uuid)
 RETURNS TABLE(id uuid, linha_rotulo text, bloco text, toca boolean, instrumento text, origem text, hora_entrada timestamp with time zone, total bigint)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  perform public.exigir_acesso_atendimento(p_portaria_id);
  return query
    select a.id, l.rotulo, l.bloco, a.toca, i.nome,
           coalesce(c.nome, a.origem_texto), a.hora_entrada, count(*) over ()
      from public.presencas_avulsas a
      join public.linhas_painel l on l.codigo = a.linha_codigo
      left join public.instrumentos i on i.id = a.instrumento_id
      left join public.casas_oracao c on c.id = a.origem_casa_oracao_id
     where a.portaria_id = p_portaria_id and a.excluido_em is null
     order by a.hora_entrada desc
     limit 20;
end;
$function$;

CREATE OR REPLACE FUNCTION public.evento_na_abrangencia(p_evento uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select exists (
    select 1 from public.eventos e
    where e.id = p_evento and public.casa_oracao_na_abrangencia(e.casa_oracao_id)
  )
$function$;

CREATE OR REPLACE FUNCTION public.eventos_do_painel()
 RETURNS TABLE(id uuid, tipo text, local_evento text, data_evento timestamp with time zone, cidade text, casa_oracao_nome text)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  perform public.exigir_permissao('painel.visualizar');
  return query
    select e.id, e.tipo, e.local, e.data_evento, e.cidade, c.nome
      from public.eventos e
      left join public.casas_oracao c on c.id = e.casa_oracao_id
     where e.excluido_em is null
       and public.evento_na_abrangencia(e.id)
       and e.data_evento between now() - interval '30 days' and now() + interval '30 days'
     order by abs(extract(epoch from (e.data_evento - now())))
     limit 40;
end;
$function$;

CREATE OR REPLACE FUNCTION public.eventos_valida_casa_oracao()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if current_setting('sysmusica.org_excluindo', true) = 'sim' then
    return new;
  end if;

  if (select auth.uid()) is null then
    return new;   -- SQL Editor / rotinas internas: sem restrição
  end if;

  -- Quem tem acesso por região precisa escolher a casa de oração (senão o evento sumiria da própria lista)
  if new.casa_oracao_id is null and not public.tem_acesso_total_organizacao()
     and (tg_op = 'INSERT' or old.casa_oracao_id is not null) then
    raise exception 'Escolha a casa de oração do evento.';
  end if;

  if tg_op = 'INSERT' then
    if new.casa_oracao_id is not null and not public.casa_oracao_na_abrangencia(new.casa_oracao_id) then
      raise exception 'Esta casa de oração está fora da sua abrangência.' using errcode = '42501';
    end if;
  elsif new.casa_oracao_id is distinct from old.casa_oracao_id then
    if (new.casa_oracao_id is not null and not public.casa_oracao_na_abrangencia(new.casa_oracao_id))
       or (old.casa_oracao_id is not null and not public.casa_oracao_na_abrangencia(old.casa_oracao_id)) then
      raise exception 'Você não pode mudar a casa de oração deste evento: ela está fora da sua abrangência.'
        using errcode = '42501';
    end if;
    update public.portarias
       set casa_oracao_id = new.casa_oracao_id, cidade = public.rotulo_setor(new.casa_oracao_id)
     where evento_id = new.id and excluido_em is null;
    perform public.registrar_auditoria('evento_casa_oracao_alterada', 'evento', new.id,
              jsonb_build_object('de', old.casa_oracao_id, 'para', new.casa_oracao_id));
  end if;
  return new;
end;
$function$;

CREATE OR REPLACE FUNCTION public.excluir_organizacao(p_nivel text, p_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_nome text;
  v_qtd  bigint;
begin
  perform public.exigir_permissao('organizacao.excluir');

  if p_nivel is null or p_nivel not in ('ESTADO', 'REGIAO', 'SETOR', 'CASA_ORACAO') then
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
    select c.nome into v_nome from public.casas_oracao c where c.id = p_id for update;
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
    select count(*) into v_qtd from public.casas_oracao x where x.setor_id = p_id;
    if v_qtd > 0 then
      raise exception 'O setor "%" ainda tem % casa(s) de oração. Transfira as casas de oração para outro setor antes de excluir.', v_nome, v_qtd;
    end if;
    delete from public.setores where id = p_id;

  else  -- CASA_ORACAO
    select count(*) into v_qtd from public.membros x where x.casa_oracao_id = p_id and x.excluido_em is null;
    if v_qtd > 0 then
      raise exception 'A casa de oração "%" ainda tem % membro(s). Mude os membros para outra casa de oração (ou exclua-os) antes.', v_nome, v_qtd;
    end if;
    select count(*) into v_qtd from public.eventos x where x.casa_oracao_id = p_id and x.excluido_em is null;
    if v_qtd > 0 then
      raise exception 'A casa de oração "%" ainda tem % evento(s). Mude a casa de oração dos eventos (ou exclua-os) antes.', v_nome, v_qtd;
    end if;
    select count(*) into v_qtd from public.portarias x where x.casa_oracao_id = p_id;
    if v_qtd > 0 then
      raise exception 'A casa de oração "%" tem % portaria(s) no histórico e não pode ser excluída. Use Inativar.', v_nome, v_qtd;
    end if;

    -- Membros e eventos já excluídos (exclusão lógica) deixam de apontar para a casa de oração
    perform set_config('sysmusica.org_excluindo', 'sim', true);
    update public.membros set casa_oracao_id = null where casa_oracao_id = p_id;
    update public.eventos set casa_oracao_id = null where casa_oracao_id = p_id;
    perform set_config('sysmusica.org_excluindo', '', true);

    delete from public.casas_oracao where id = p_id;
  end if;

  perform public.registrar_auditoria('organizacao_excluida', 'organizacao', p_id,
            jsonb_build_object('nivel', p_nivel, 'nome', v_nome));
end;
$function$;

CREATE OR REPLACE FUNCTION public.exigir_acesso_atendimento(p_portaria_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_p    public.portarias;
  v_data timestamptz;
begin
  perform public.exigir_permissao('portaria.registrar');
  select * into v_p from public.portarias p where p.id = p_portaria_id and p.excluido_em is null;
  if not found or v_p.status <> 'APROVADA' or not public.casa_oracao_na_abrangencia(v_p.casa_oracao_id) then
    raise exception 'Portaria indisponível para você.' using errcode = '42501';
  end if;
  select e.data_evento into v_data from public.eventos e where e.id = v_p.evento_id;
  if public.portaria_encerrada(v_data) then
    raise exception 'Esta portaria foi encerrada e não aceita mais nada. Só o Administrador pode corrigir registros.'
      using errcode = '42501';
  end if;
end;
$function$;

CREATE OR REPLACE FUNCTION public.exigir_acesso_portaria_sem_prazo(p_portaria_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_p public.portarias;
begin
  perform public.exigir_permissao('portaria.registrar');
  select * into v_p from public.portarias p where p.id = p_portaria_id and p.excluido_em is null;
  if not found or v_p.status <> 'APROVADA' or not public.casa_oracao_na_abrangencia(v_p.casa_oracao_id) then
    raise exception 'Portaria indisponível para você.' using errcode = '42501';
  end if;
end;
$function$;

CREATE OR REPLACE FUNCTION public.listar_eventos_para_portaria()
 RETURNS TABLE(id uuid, tipo text, data_evento timestamp with time zone, local text, cidade text, casa_oracao_id uuid)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  perform public.exigir_permissao('portarias.criar');
  return query
    select e.id, e.tipo, e.data_evento, e.local,
           case when c.setor_id is not null then public.rotulo_setor(e.casa_oracao_id) end,
           e.casa_oracao_id
    from public.eventos e
    join public.casas_oracao c on c.id = e.casa_oracao_id
    where e.excluido_em is null
      and public.casa_oracao_na_abrangencia(e.casa_oracao_id)
    order by e.data_evento desc
    limit 300;
end;
$function$;

CREATE OR REPLACE FUNCTION public.listar_membros_para_foto()
 RETURNS TABLE(id uuid, nome text, congregacao text, foto_path text)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  perform public.exigir_permissao('membros.foto');
  return query
    select m.id, m.nome, m.congregacao, m.foto_path
    from public.membros m
    where m.excluido_em is null and public.casa_oracao_na_abrangencia(m.casa_oracao_id)
    order by m.nome;
end;
$function$;

CREATE OR REPLACE FUNCTION public.listar_organizacao()
 RETURNS TABLE(nivel text, id uuid, parent_id uuid, nome text, descricao text, ativo boolean, cidade text, bairro text, qtd_filhos bigint, qtd_membros bigint)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  perform public.exigir_alguma_permissao(array['organizacao.visualizar', 'usuarios.vinculos', 'usuarios.editar']);
  return query
    select 'ESTADO'::text, e.id, null::uuid, e.nome, null::text, e.ativo, null::text, null::text,
           (select count(*) from public.regioes r where r.estado_id = e.id), 0::bigint
    from public.estados e
    union all
    select 'REGIAO'::text, r.id, r.estado_id, r.nome, r.descricao, r.ativo, null::text, null::text,
           (select count(*) from public.setores s where s.regiao_id = r.id), 0::bigint
    from public.regioes r
    union all
    select 'SETOR'::text, s.id, s.regiao_id, s.nome, s.descricao, s.ativo, null::text, null::text,
           (select count(*) from public.casas_oracao c where c.setor_id = s.id), 0::bigint
    from public.setores s
    union all
    select 'CASA_ORACAO'::text, c.id, c.setor_id, c.nome, null::text, c.ativo, c.cidade, c.bairro, 0::bigint,
           (select count(*) from public.membros m where m.casa_oracao_id = c.id and m.excluido_em is null)
    from public.casas_oracao c;
end;
$function$;

CREATE OR REPLACE FUNCTION public.listar_organizacao_para_selecao()
 RETURNS TABLE(nivel text, id uuid, parent_id uuid, nome text)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_total boolean;
begin
  if not public.tem_acesso() then
    raise exception 'Sem acesso.' using errcode = '42501';
  end if;
  v_total := public.tem_acesso_total_organizacao();

  return query
    with ok as (
      select c.id as casa_oracao_id, c.nome as casa_oracao_nome, c.setor_id as setor_id
      from public.casas_oracao c
      where c.ativo and (v_total or public.casa_oracao_na_minha_abrangencia(c.id))
    ),
    sset as (
      select s.id as setor_id, s.regiao_id as regiao_id, s.nome as setor_nome
      from public.setores s
      where s.ativo and (v_total or s.id in (select ok.setor_id from ok))
    ),
    rset as (
      select r.id as regiao_id, r.estado_id as estado_id, r.nome as regiao_nome
      from public.regioes r
      where r.ativo and (v_total or r.id in (select sset.regiao_id from sset))
    ),
    eset as (
      select e.id as estado_id, e.nome as estado_nome
      from public.estados e
      where e.ativo and (v_total or e.id in (select rset.estado_id from rset))
    )
    select 'ESTADO'::text, eset.estado_id, null::uuid, eset.estado_nome from eset
    union all
    select 'REGIAO'::text, rset.regiao_id, rset.estado_id, rset.regiao_nome from rset
    union all
    select 'SETOR'::text, sset.setor_id, sset.regiao_id, sset.setor_nome from sset
    union all
    select 'CASA_ORACAO'::text, ok.casa_oracao_id, ok.setor_id, ok.casa_oracao_nome from ok;
end;
$function$;

CREATE OR REPLACE FUNCTION public.listar_origens_visitante()
 RETURNS TABLE(nivel text, id uuid, parent_id uuid, nome text)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
    select 'CASA_ORACAO'::text, c.id, c.setor_id, c.nome
      from public.casas_oracao c
      join public.setores s on s.id = c.setor_id
      join public.regioes r on r.id = s.regiao_id
      join public.estados e on e.id = r.estado_id
     where c.ativo and s.ativo and r.ativo and e.ativo;
end;
$function$;

CREATE OR REPLACE FUNCTION public.listar_portarias()
 RETURNS TABLE(id uuid, evento_id uuid, status text, cidade text, criada_em timestamp with time zone, criada_por uuid, criador_nome text, decidida_em timestamp with time zone, decisor_nome text, motivo_rejeicao text, evento_tipo text, evento_data timestamp with time zone, evento_local text, evento_finalidade text, pode_decidir boolean, pode_excluir boolean)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_uid    uuid := (select auth.uid());
  v_aprova boolean;
  v_exclui boolean;
  v_ctotal boolean;
begin
  perform public.exigir_alguma_permissao(array[
    'portarias.visualizar', 'portarias.criar', 'portarias.aprovar', 'portaria.registrar'
  ]);
  v_aprova := public.tem_permissao('portarias.aprovar');
  v_exclui := public.tem_permissao('portarias.excluir');
  v_ctotal := public.tem_permissao('portarias.controle_total');

  return query
    select p.id, p.evento_id, p.status, coalesce(public.rotulo_setor(p.casa_oracao_id), p.cidade),
           p.criada_em, p.criada_por, cr.nome,
           p.decidida_em, de.nome, p.motivo_rejeicao,
           ev.tipo, ev.data_evento, ev.local, fi.nome,
           (v_aprova and p.status = 'PENDENTE_APROVACAO'
              and (p.criada_por <> v_uid or v_ctotal)
              and public.casa_oracao_na_abrangencia(p.casa_oracao_id)),
           ((v_exclui or (p.criada_por = v_uid and p.status = 'PENDENTE_APROVACAO'))
              and not exists (select 1 from public.presencas pr
                              where pr.portaria_id = p.id and pr.excluido_em is null))
    from public.portarias p
    left join public.usuarios cr on cr.id = p.criada_por
    left join public.usuarios de on de.id = p.decidida_por
    left join public.eventos ev on ev.id = p.evento_id
    left join public.finalidades_evento fi on fi.id = ev.finalidade_id
    where public.pode_ver_portaria(p.id)
    order by p.criada_em desc;
end;
$function$;

CREATE OR REPLACE FUNCTION public.membros_sincroniza_casa_oracao()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_id  uuid;
  v_qtd int;
begin
  if current_setting('sysmusica.org_excluindo', true) = 'sim' then
    return new;
  end if;

  if new.casa_oracao_id is not null and (tg_op = 'INSERT' or new.casa_oracao_id is distinct from old.casa_oracao_id) then
    select c.nome into new.congregacao from public.casas_oracao c where c.id = new.casa_oracao_id;
    if not found then
      raise exception 'Casa de Oração não encontrada.';
    end if;
  elsif tg_op = 'INSERT' or new.congregacao is distinct from old.congregacao then
    select (array_agg(c.id))[1], count(*) into v_id, v_qtd
    from public.casas_oracao c
    where public.normalizar_texto(c.nome) = public.normalizar_texto(btrim(coalesce(new.congregacao, '')));
    new.casa_oracao_id := case when v_qtd = 1 then v_id else null end;
  end if;

  -- Quem tem acesso por região precisa ligar o membro a uma casa de oração (senão ele sumiria da própria lista)
  if new.casa_oracao_id is null and (select auth.uid()) is not null and not public.tem_acesso_total_organizacao() then
    raise exception 'Não encontrei a casa de oração "%". Use o nome exato de uma casa de oração cadastrada em Administração > Organização.',
      coalesce(new.congregacao, '');
  end if;
  return new;
end;
$function$;

CREATE OR REPLACE FUNCTION public.painel_ao_vivo(p_evento_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_evento jsonb;
  v_dados  jsonb;
begin
  perform public.exigir_permissao('painel.visualizar');
  if not public.evento_na_abrangencia(p_evento_id) then
    raise exception 'Evento indisponível para você.' using errcode = '42501';
  end if;

  select jsonb_build_object('id', e.id, 'tipo', e.tipo, 'local', e.local, 'data_evento', e.data_evento,
                            'cidade', e.cidade, 'casa_oracao', c.nome)
    into v_evento
    from public.eventos e
    left join public.casas_oracao c on c.id = e.casa_oracao_id
   where e.id = p_evento_id and e.excluido_em is null;
  if v_evento is null then
    raise exception 'Evento não encontrado.';
  end if;

  with base as (
    -- presenças de membros cadastrados
    select pr.toca, pr.linha_codigo, m.categoria, cg.nome as cargo,
           coalesce(pr.instrumento_id, m.instrumento_id) as instrumento_efetivo
      from public.presencas pr
      join public.membros m on m.id = pr.membro_id
      left join public.cargos cg on cg.id = m.cargo_id
     where pr.evento_id = p_evento_id and pr.excluido_em is null and pr.status = 'Presente'
    union all
    -- entradas SEM cadastro (a linha e o instrumento já vêm escolhidos na Portaria)
    select a.toca, a.linha_codigo, null::text, null::text, a.instrumento_id
      from public.presencas_avulsas a
     where a.evento_id = p_evento_id and a.excluido_em is null
  ), calc as (
    select b.toca, i.nome as instrumento_nome, i.familia_id,
           coalesce(b.linha_codigo, public.classificar_linha(b.cargo, b.categoria, i.nome)) as linha,
           b.instrumento_efetivo
      from base b
      left join public.instrumentos i on i.id = b.instrumento_efetivo
  ), por_linha as (
    select l.codigo, l.bloco, l.rotulo, l.ordem, l.selecionavel, count(c.linha) as qtd
      from public.linhas_painel l
      left join calc c on c.linha = l.codigo
     group by l.codigo, l.bloco, l.rotulo, l.ordem, l.selecionavel
  ), por_familia as (
    select coalesce(f.nome, 'Sem família') as familia, count(*) as qtd
      from calc c
      join public.linhas_painel l on l.codigo = c.linha
      left join public.familias f on f.id = c.familia_id
     where c.instrumento_efetivo is not null
       and not public.instrumento_e_orgao(c.instrumento_nome)
       and (c.toca is true or (c.toca is null and l.toca_sempre))
     group by 1
  )
  select jsonb_build_object(
           'total', (select count(*) from calc),
           'linhas', coalesce((select jsonb_agg(jsonb_build_object('codigo', p.codigo, 'bloco', p.bloco,
                                    'rotulo', p.rotulo, 'ordem', p.ordem, 'qtd', p.qtd, 'selecionavel', p.selecionavel)
                                    order by p.ordem)
                                 from por_linha p where p.selecionavel or p.qtd > 0), '[]'::jsonb),
           'instrumentos', coalesce((select jsonb_agg(jsonb_build_object('familia', f.familia, 'qtd', f.qtd)
                                    order by f.familia) from por_familia f), '[]'::jsonb))
    into v_dados;

  return v_dados || jsonb_build_object('evento', v_evento, 'atualizado_em', now());
end;
$function$;

CREATE OR REPLACE FUNCTION public.pode_ver_portaria(p_id uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select exists (
    select 1 from public.portarias p
    where p.id = p_id and p.excluido_em is null
      and (
        p.criada_por = (select auth.uid())
        or public.tem_permissao('portarias.visualizar')
        or (public.tem_permissao('portarias.aprovar') and public.casa_oracao_na_abrangencia(p.casa_oracao_id))
        or (public.tem_permissao('portaria.registrar') and p.status = 'APROVADA'
            and public.casa_oracao_na_abrangencia(p.casa_oracao_id))
      )
  )
$function$;

CREATE OR REPLACE FUNCTION public.registrar_entrada_avulsa(p_portaria_id uuid, p_linha_codigo text, p_toca boolean DEFAULT NULL::boolean, p_instrumento_id uuid DEFAULT NULL::uuid, p_origem_casa_oracao_id uuid DEFAULT NULL::uuid, p_origem_texto text DEFAULT NULL::text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_p     public.portarias;
  v_data  timestamptz;
  l       public.linhas_painel;
  v_toca  boolean;
  v_inst  uuid;
  v_texto text := nullif(btrim(regexp_replace(coalesce(p_origem_texto, ''), '\s+', ' ', 'g')), '');
  v_id    uuid;
begin
  perform public.exigir_acesso_atendimento(p_portaria_id);   -- permissão, portaria aprovada e abrangência
  select * into v_p from public.portarias p where p.id = p_portaria_id and p.excluido_em is null;

  -- Janela da portaria (a mesma regra da entrada de membros)
  select e.data_evento into v_data from public.eventos e where e.id = v_p.evento_id and e.excluido_em is null;
  if v_data is null then
    raise exception 'O evento desta portaria não foi encontrado.';
  end if;
  if not public.portaria_janela_aberta(v_data) then
    if public.tem_permissao('portarias.controle_total') then
      perform public.registrar_auditoria('presenca_fora_da_janela', 'portaria', p_portaria_id,
        jsonb_build_object('evento_id', v_p.evento_id, 'inicio_do_evento', v_data, 'registrado_em', now(),
          'sem_cadastro', true,
          'situacao', case when now() < v_data then 'antes da abertura' else 'depois do encerramento' end));
    else
      raise exception 'Fora do horário da portaria. Ela abre em % e encerra em % (2 horas antes e 3 horas depois do início do evento, horário de Salvador).',
        to_char((v_data - interval '2 hours') at time zone 'America/Sao_Paulo', 'DD/MM "às" HH24"h"MI'),
        to_char((v_data + interval '3 hours') at time zone 'America/Sao_Paulo', 'DD/MM "às" HH24"h"MI');
    end if;
  end if;

  select * into l from public.linhas_painel x where x.codigo = p_linha_codigo and x.selecionavel;
  if not found then
    raise exception 'Escolha o cargo ou a categoria da pessoa.';
  end if;

  if l.pergunta_toca then
    if p_toca is null then
      raise exception 'Informe se a pessoa vai tocar.';
    end if;
    v_toca := p_toca;
  elsif l.toca_sempre then
    v_toca := true;
  else
    v_toca := null;
  end if;

  if l.instrumento = 'LIVRE' and v_toca is true then
    if p_instrumento_id is null then
      raise exception 'Informe o instrumento que a pessoa vai tocar.';
    end if;
    if not exists (select 1 from public.instrumentos i where i.id = p_instrumento_id) then
      raise exception 'Instrumento inválido.';
    end if;
    if public.instrumento_e_orgao((select i.nome from public.instrumentos i where i.id = p_instrumento_id)) then
      raise exception 'O órgão é contado em Organistas: escolha a categoria de organista.';
    end if;
    v_inst := p_instrumento_id;
  else
    v_inst := null;
  end if;

  -- Localidade de origem (opcional): uma casa de oração da lista OU um texto livre
  if p_origem_casa_oracao_id is not null then
    if not exists (select 1 from public.casas_oracao c where c.id = p_origem_casa_oracao_id and c.ativo) then
      raise exception 'Localidade de origem inválida.';
    end if;
    v_texto := null;
  elsif v_texto is not null and (char_length(v_texto) < 2 or char_length(v_texto) > 120) then
    raise exception 'A localidade deve ter de 2 a 120 caracteres.';
  end if;

  insert into public.presencas_avulsas
    (portaria_id, evento_id, linha_codigo, toca, instrumento_id, origem_casa_oracao_id, origem_texto, registrado_por)
  values (p_portaria_id, v_p.evento_id, l.codigo, v_toca, v_inst, p_origem_casa_oracao_id, v_texto, (select auth.uid()))
  returning id into v_id;

  perform public.registrar_auditoria('entrada_avulsa_registrada', 'portaria', p_portaria_id,
    jsonb_build_object('linha', l.rotulo, 'toca', v_toca, 'localidade',
      coalesce((select c.nome from public.casas_oracao c where c.id = p_origem_casa_oracao_id), v_texto)));
  return v_id;
end;
$function$;

CREATE OR REPLACE FUNCTION public.relatorio_eventos(p_inicio timestamp with time zone, p_fim timestamp with time zone, p_regiao uuid, p_setor uuid, p_casa_oracao uuid, p_limite integer)
 RETURNS TABLE(tipo text, data_evento timestamp with time zone, local_evento text, finalidade text, cidade text, regiao text, setor text, casa_oracao text, registros bigint, presentes bigint, portaria text, total bigint)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
    left join public.casas_oracao c on c.id = ev.casa_oracao_id
    left join public.setores s on s.id = c.setor_id
    left join public.regioes r on r.id = s.regiao_id
    where ev.excluido_em is null
      and public.casa_oracao_na_abrangencia(ev.casa_oracao_id)
      and (p_inicio is null or ev.data_evento >= p_inicio)
      and (p_fim is null or ev.data_evento < p_fim)
      and (p_regiao is null or r.id = p_regiao)
      and (p_setor is null or s.id = p_setor)
      and (p_casa_oracao is null or c.id = p_casa_oracao)
    order by ev.data_evento desc, ev.id
    limit v_lim;
end;
$function$;

CREATE OR REPLACE FUNCTION public.relatorio_membros(p_regiao uuid, p_setor uuid, p_casa_oracao uuid, p_cargo uuid, p_instrumento uuid, p_status text, p_visitante text, p_limite integer)
 RETURNS TABLE(nome text, cargo text, instrumento text, familia text, regiao text, setor text, casa_oracao text, cidade text, bairro text, status text, visitante boolean, data_nascimento date, cadastrado_em timestamp with time zone, cpf_parcial text, total bigint)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
    left join public.casas_oracao c on c.id = m.casa_oracao_id
    left join public.setores s on s.id = c.setor_id
    left join public.regioes r on r.id = s.regiao_id
    left join public.cargos ca on ca.id = m.cargo_id
    left join public.instrumentos i on i.id = m.instrumento_id
    left join public.familias f on f.id = i.familia_id
    where m.excluido_em is null
      and public.casa_oracao_na_abrangencia(m.casa_oracao_id)
      and (p_regiao is null or r.id = p_regiao)
      and (p_setor is null or s.id = p_setor)
      and (p_casa_oracao is null or c.id = p_casa_oracao)
      and (p_cargo is null or m.cargo_id = p_cargo)
      and (p_instrumento is null or m.instrumento_id = p_instrumento)
      and (nullif(p_status, '') is null or m.status = p_status)
      and (nullif(p_visitante, '') is null
           or (p_visitante = 'sim' and m.visitante)
           or (p_visitante = 'nao' and not m.visitante))
    order by m.nome
    limit v_lim;
end;
$function$;

CREATE OR REPLACE FUNCTION public.relatorio_presencas(p_inicio timestamp with time zone, p_fim timestamp with time zone, p_evento uuid, p_regiao uuid, p_setor uuid, p_casa_oracao uuid, p_status text, p_limite integer)
 RETURNS TABLE(evento_tipo text, evento_data timestamp with time zone, evento_local text, evento_finalidade text, regiao text, setor text, casa_oracao text, membro_nome text, membro_casa_oracao text, cargo text, instrumento text, familia text, cidade text, bairro text, visitante boolean, status text, hora_entrada timestamp with time zone, hora_saida timestamp with time zone, origem text, registrado_por text, total bigint)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
    left join public.casas_oracao c on c.id = ev.casa_oracao_id
    left join public.setores s on s.id = c.setor_id
    left join public.regioes r on r.id = s.regiao_id
    left join public.cargos ca on ca.id = m.cargo_id
    left join public.instrumentos i on i.id = m.instrumento_id
    left join public.familias f on f.id = i.familia_id
    left join public.usuarios u on u.id = pr.registrado_por
    where pr.excluido_em is null
      and public.casa_oracao_na_abrangencia(ev.casa_oracao_id)
      and (p_inicio is null or ev.data_evento >= p_inicio)
      and (p_fim is null or ev.data_evento < p_fim)
      and (p_evento is null or pr.evento_id = p_evento)
      and (p_regiao is null or r.id = p_regiao)
      and (p_setor is null or s.id = p_setor)
      and (p_casa_oracao is null or c.id = p_casa_oracao)
      and (nullif(p_status, '') is null or pr.status = p_status)
    order by ev.data_evento desc, ev.id, m.nome
    limit v_lim;
end;
$function$;

CREATE OR REPLACE FUNCTION public.remover_foto_membro(p_membro_id uuid)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_antigo text;
  v_casa_oracao  uuid;
begin
  perform public.exigir_permissao('membros.foto');

  select m.foto_path, m.casa_oracao_id into v_antigo, v_casa_oracao
  from public.membros m where m.id = p_membro_id and m.excluido_em is null for update;
  if not found or not public.casa_oracao_na_abrangencia(v_casa_oracao) then
    raise exception 'Membro não encontrado.';
  end if;

  update public.membros set foto_path = null where id = p_membro_id;

  perform public.registrar_auditoria('foto_removida', 'membro', p_membro_id, '{}'::jsonb);
  return v_antigo;
end;
$function$;

CREATE OR REPLACE FUNCTION public.rotulo_setor(p_casa_oracao uuid)
 RETURNS text
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select r.nome || ' › ' || s.nome
  from public.casas_oracao c
  join public.setores s on s.id = c.setor_id
  join public.regioes r on r.id = s.regiao_id
  where c.id = p_casa_oracao
$function$;

CREATE OR REPLACE FUNCTION public.rotulo_vinculo(p_nivel text, p_alvo uuid)
 RETURNS text
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select case p_nivel
    when 'ESTADO' then (select e.nome from public.estados e where e.id = p_alvo)
    when 'REGIAO' then (select e.nome || ' › ' || r.nome
                          from public.regioes r join public.estados e on e.id = r.estado_id where r.id = p_alvo)
    when 'SETOR'  then (select r.nome || ' › ' || s.nome
                          from public.setores s join public.regioes r on r.id = s.regiao_id where s.id = p_alvo)
    when 'CASA_ORACAO'  then (select coalesce(r.nome || ' › ' || s.nome || ' › ', '') || c.nome
                          from public.casas_oracao c
                          left join public.setores s on s.id = c.setor_id
                          left join public.regioes r on r.id = s.regiao_id
                         where c.id = p_alvo)
  end
$function$;

CREATE OR REPLACE FUNCTION public.salvar_organizacao(p_nivel text, p_id uuid, p_parent uuid, p_nome text, p_descricao text, p_ativo boolean, p_cidade text, p_bairro text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_novo   boolean := p_id is null;
  v_nome   text    := btrim(regexp_replace(coalesce(p_nome, ''), '\s+', ' ', 'g'));
  v_desc   text    := nullif(btrim(coalesce(p_descricao, '')), '');
  v_cidade text    := nullif(btrim(coalesce(p_cidade, '')), '');
  v_bairro text    := nullif(btrim(coalesce(p_bairro, '')), '');
  v_id     uuid;
  v_pai    uuid;
begin
  if p_nivel is null or p_nivel not in ('ESTADO', 'REGIAO', 'SETOR', 'CASA_ORACAO') then
    raise exception 'Nível inválido.';
  end if;
  if v_novo then
    perform public.exigir_permissao('organizacao.criar');
  else
    perform public.exigir_permissao('organizacao.editar');
  end if;

  if char_length(v_nome) < 2 or char_length(v_nome) > 80 then
    raise exception 'O nome deve ter entre 2 e 80 caracteres.';
  end if;
  if v_desc is not null and char_length(v_desc) > 200 then
    raise exception 'A descrição pode ter no máximo 200 caracteres.';
  end if;
  if (v_cidade is not null and char_length(v_cidade) > 80) or (v_bairro is not null and char_length(v_bairro) > 80) then
    raise exception 'Cidade e bairro podem ter no máximo 80 caracteres.';
  end if;

  if p_nivel = 'ESTADO' then
    if exists (select 1 from public.estados x
                where x.id is distinct from p_id
                  and public.normalizar_texto(x.nome) = public.normalizar_texto(v_nome)) then
      raise exception 'Já existe um estado com este nome.';
    end if;
    if v_novo then
      insert into public.estados (nome) values (v_nome) returning id into v_id;
    else
      update public.estados set nome = v_nome, ativo = coalesce(p_ativo, ativo) where id = p_id returning id into v_id;
    end if;

  elsif p_nivel = 'REGIAO' then
    v_pai := case when v_novo then p_parent else (select x.estado_id from public.regioes x where x.id = p_id) end;
    if v_pai is null or not exists (select 1 from public.estados e where e.id = v_pai) then
      raise exception 'Escolha o estado da região.';
    end if;
    if exists (select 1 from public.regioes x
                where x.estado_id = v_pai and x.id is distinct from p_id
                  and public.normalizar_texto(x.nome) = public.normalizar_texto(v_nome)) then
      raise exception 'Já existe uma região com este nome neste estado.';
    end if;
    if v_novo then
      insert into public.regioes (estado_id, nome, descricao) values (v_pai, v_nome, v_desc) returning id into v_id;
    else
      update public.regioes set nome = v_nome, descricao = v_desc, ativo = coalesce(p_ativo, ativo)
       where id = p_id returning id into v_id;
    end if;

  elsif p_nivel = 'SETOR' then
    v_pai := case when v_novo then p_parent else (select x.regiao_id from public.setores x where x.id = p_id) end;
    if v_pai is null or not exists (select 1 from public.regioes r where r.id = v_pai) then
      raise exception 'Escolha a região do setor.';
    end if;
    if exists (select 1 from public.setores x
                where x.regiao_id = v_pai and x.id is distinct from p_id
                  and public.normalizar_texto(x.nome) = public.normalizar_texto(v_nome)) then
      raise exception 'Já existe um setor com este nome nesta região.';
    end if;
    if v_novo then
      insert into public.setores (regiao_id, nome, descricao) values (v_pai, v_nome, v_desc) returning id into v_id;
    else
      update public.setores set nome = v_nome, descricao = v_desc, ativo = coalesce(p_ativo, ativo)
       where id = p_id returning id into v_id;
    end if;

  else  -- CASA_ORACAO
    v_pai := case when v_novo then p_parent else (select x.setor_id from public.casas_oracao x where x.id = p_id) end;
    if v_novo and (v_pai is null or not exists (select 1 from public.setores s where s.id = v_pai)) then
      raise exception 'Escolha o setor da casa de oração.';
    end if;
    if exists (select 1 from public.casas_oracao x
                where x.setor_id is not distinct from v_pai and x.id is distinct from p_id
                  and public.normalizar_texto(x.nome) = public.normalizar_texto(v_nome)) then
      raise exception 'Já existe uma casa de oração com este nome neste setor.';
    end if;
    if v_novo then
      insert into public.casas_oracao (setor_id, nome, cidade, bairro) values (v_pai, v_nome, v_cidade, v_bairro)
      returning id into v_id;
    else
      update public.casas_oracao set nome = v_nome, cidade = v_cidade, bairro = v_bairro, ativo = coalesce(p_ativo, ativo)
       where id = p_id returning id into v_id;
    end if;
  end if;

  if v_id is null then
    raise exception 'Cadastro não encontrado.';
  end if;

  perform public.registrar_auditoria(
    case when v_novo then 'organizacao_criada' else 'organizacao_alterada' end,
    'organizacao', v_id,
    jsonb_build_object('nivel', p_nivel, 'nome', v_nome, 'ativo', p_ativo));
  return v_id;
end;
$function$;

CREATE OR REPLACE FUNCTION public.transferir_casa_oracao(p_casa_oracao uuid, p_setor uuid, p_justificativa text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_c    public.casas_oracao;
  v_just text := nullif(btrim(coalesce(p_justificativa, '')), '');
begin
  perform public.exigir_permissao('organizacao.transferir');

  select * into v_c from public.casas_oracao c where c.id = p_casa_oracao for update;
  if not found then
    raise exception 'Casa de Oração não encontrada.';
  end if;
  if not exists (select 1 from public.setores s where s.id = p_setor and s.ativo) then
    raise exception 'Escolha um setor ativo de destino.';
  end if;
  if v_c.setor_id is not distinct from p_setor then
    raise exception 'A casa de oração já pertence a este setor.';
  end if;
  if v_just is not null and char_length(v_just) > 300 then
    raise exception 'A justificativa pode ter no máximo 300 caracteres.';
  end if;
  if exists (select 1 from public.casas_oracao x
              where x.setor_id = p_setor and x.id <> p_casa_oracao
                and public.normalizar_texto(x.nome) = public.normalizar_texto(v_c.nome)) then
    raise exception 'O setor de destino já tem uma casa de oração com este nome.';
  end if;

  update public.casas_oracao set setor_id = p_setor where id = p_casa_oracao;
  -- As portarias seguem a casa de oração do evento: só o rótulo precisa ser atualizado
  update public.portarias p set cidade = public.rotulo_setor(p.casa_oracao_id)
   where p.casa_oracao_id = p_casa_oracao and p.excluido_em is null;

  insert into public.casas_oracao_historico (casa_oracao_id, setor_anterior, setor_novo, usuario_id, justificativa)
  values (p_casa_oracao, v_c.setor_id, p_setor, (select auth.uid()), v_just);

  perform public.registrar_auditoria('casa_oracao_transferida', 'casa_oracao', p_casa_oracao,
            jsonb_build_object('setor_anterior', v_c.setor_id, 'setor_novo', p_setor, 'justificativa', v_just));
end;
$function$;

CREATE OR REPLACE FUNCTION public.validar_registro_presenca(p_portaria_id uuid, p_evento_id uuid, p_membro_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_p         public.portarias;
  v_m         record;
  v_existente record;
  v_data      timestamptz;
begin
  perform public.exigir_permissao('portaria.registrar');

  select * into v_p from public.portarias p where p.id = p_portaria_id and p.excluido_em is null;
  if not found then
    raise exception 'Portaria não encontrada.';
  end if;
  if v_p.status <> 'APROVADA' then
    raise exception 'Esta portaria não está aprovada (situação: %). Só portarias aprovadas registram presenças.',
      case v_p.status when 'PENDENTE_APROVACAO' then 'pendente de aprovação'
                      when 'REJEITADA' then 'rejeitada' else v_p.status end;
  end if;
  if v_p.evento_id <> p_evento_id then
    raise exception 'A portaria não corresponde ao evento informado.';
  end if;
  if not public.casa_oracao_na_abrangencia(v_p.casa_oracao_id) then
    raise exception 'Você não tem acesso a esta portaria (fora da sua abrangência).' using errcode = '42501';
  end if;

  -- JANELA: de 2 horas antes a 3 horas depois do início do evento (horário de Salvador); depois disso, encerrada
  select e.data_evento into v_data from public.eventos e where e.id = v_p.evento_id;
  if v_data is null then
    raise exception 'O evento desta portaria não foi encontrado.';
  end if;
  -- Portaria ENCERRADA (passou de 3 horas depois do início): ninguém registra, nem o Administrador.
  -- O Administrador só corrige registros já existentes (editar/excluir), nunca cria entrada nova por aqui.
  if public.portaria_encerrada(v_data) then
    raise exception 'Esta portaria foi encerrada em % e não aceita mais entradas. Só o Administrador pode corrigir registros.',
      to_char((v_data + interval '3 hours') at time zone 'America/Sao_Paulo', 'DD/MM "às" HH24"h"MI');
  end if;
  -- Antes da abertura: só o controle total (Administrador), com registro na Auditoria
  if not public.portaria_janela_aberta(v_data) then
    if public.tem_permissao('portarias.controle_total') then
      -- Administrador: permitido, mas fica registrado na Auditoria
      perform public.registrar_auditoria('presenca_fora_da_janela', 'portaria', p_portaria_id,
        jsonb_build_object(
          'evento_id', p_evento_id,
          'membro_id', p_membro_id,
          'inicio_do_evento', v_data,
          'registrado_em', now(),
          'situacao', case when now() < v_data then 'antes da abertura' else 'depois do encerramento' end));
    else
      raise exception 'Fora do horário da portaria. Ela abre em % e encerra em % (2 horas antes e 3 horas depois do início do evento, horário de Salvador).',
        to_char((v_data - interval '2 hours') at time zone 'America/Sao_Paulo', 'DD/MM "às" HH24"h"MI'),
        to_char((v_data + interval '3 hours') at time zone 'America/Sao_Paulo', 'DD/MM "às" HH24"h"MI');
    end if;
  end if;

  select m.status, m.excluido_em into v_m from public.membros m where m.id = p_membro_id;
  if not found then
    raise exception 'Cadastro do membro não encontrado.';
  end if;
  if v_m.excluido_em is not null then
    raise exception 'Cadastro do membro não encontrado.';
  end if;
  if v_m.status <> 'Ativo' then
    raise exception 'O cadastro do membro está inativo.';
  end if;

  -- Duplicidade por EVENTO (inclui registros antigos, sem portaria)
  select pr.hora_entrada, pr.status, pr.portaria_id into v_existente
  from public.presencas pr
  where pr.membro_id = p_membro_id
    and pr.evento_id = p_evento_id
    and pr.excluido_em is null
    and (pr.hora_saida is null or pr.portaria_id = p_portaria_id)
  order by pr.hora_entrada
  limit 1;
  if found then
    raise exception 'Este músico já possui uma entrada registrada neste evento às % (situação: %)%.',
      to_char(v_existente.hora_entrada at time zone 'America/Sao_Paulo', 'HH24"h"MI'),
      v_existente.status,
      case when v_existente.portaria_id is null then ', registro antigo feito antes das portarias' else '' end;
  end if;
end;
$function$;


-- 6) Devolve a permissão de execução das funções recriadas
do $$
declare r record; q record; v_oid regprocedure;
begin
  for r in select * from (values ('cadastrar_visitante','cadastrar_visitante'), ('comum_na_abrangencia','casa_oracao_na_abrangencia'), ('comum_na_minha_abrangencia','casa_oracao_na_minha_abrangencia'), ('comuns_propaga_nome','casas_oracao_propaga_nome'), ('eventos_do_painel','eventos_do_painel'), ('eventos_valida_comum','eventos_valida_casa_oracao'), ('listar_eventos_para_portaria','listar_eventos_para_portaria'), ('membros_sincroniza_comum','membros_sincroniza_casa_oracao'), ('registrar_entrada_avulsa','registrar_entrada_avulsa'), ('relatorio_eventos','relatorio_eventos'), ('relatorio_membros','relatorio_membros'), ('relatorio_presencas','relatorio_presencas'), ('rotulo_setor','rotulo_setor'), ('transferir_comum','transferir_casa_oracao')) as t(velho, novo) loop
    for v_oid in select p.oid::regprocedure from pg_proc p
                 where p.pronamespace = 'public'::regnamespace and p.proname = r.novo loop
      execute format('revoke all on function %s from public, anon, authenticated, service_role', v_oid);
      for q in select distinct quem from _acl_fn where velho = r.velho loop
        execute format('grant execute on function %s to %s', v_oid, case when q.quem = 'public' then 'public' else q.quem end);
      end loop;
    end loop;
  end loop;
end $$;

-- 7) Gatilhos e políticas
do $$
declare r record; v text;
begin
  for r in select * from _trg_fn loop
    v := r.def;
    v := replace(v, 'listar_eventos_para_portaria', 'listar_eventos_para_portaria');
    v := replace(v, 'comum_na_minha_abrangencia', 'casa_oracao_na_minha_abrangencia');
    v := replace(v, 'membros_sincroniza_comum', 'membros_sincroniza_casa_oracao');
    v := replace(v, 'registrar_entrada_avulsa', 'registrar_entrada_avulsa');
    v := replace(v, 'comum_na_abrangencia', 'casa_oracao_na_abrangencia');
    v := replace(v, 'eventos_valida_comum', 'eventos_valida_casa_oracao');
    v := replace(v, 'cadastrar_visitante', 'cadastrar_visitante');
    v := replace(v, 'comuns_propaga_nome', 'casas_oracao_propaga_nome');
    v := replace(v, 'relatorio_presencas', 'relatorio_presencas');
    v := replace(v, 'eventos_do_painel', 'eventos_do_painel');
    v := replace(v, 'relatorio_eventos', 'relatorio_eventos');
    v := replace(v, 'relatorio_membros', 'relatorio_membros');
    v := replace(v, 'transferir_comum', 'transferir_casa_oracao');
    v := replace(v, 'rotulo_setor', 'rotulo_setor');
    v := replace(replace(replace(v, 'comuns', 'casas_oracao'), 'comum_id', 'casa_oracao_id'), 'Comum', 'Casa de Oração');
    execute v;
  end loop;
end $$;
create policy regiao_eventos on public.eventos for all
  using (public.casa_oracao_na_abrangencia(casa_oracao_id)) with check (public.casa_oracao_na_abrangencia(casa_oracao_id));
create policy regiao_membros on public.membros for all
  using (public.casa_oracao_na_abrangencia(casa_oracao_id)) with check (public.casa_oracao_na_abrangencia(casa_oracao_id));

-- 8) Demais funções que citam a tabela antiga pelo nome (ex.: backup_aplicar): trocam comuns -> casas_oracao
do $$
declare r record; v_def text; v_lista text := '';
begin
  for r in select p.oid, p.proname from pg_proc p
           where p.pronamespace = 'public'::regnamespace and p.prokind = 'f' and p.prosrc ~* '\mcomuns\M' loop
    v_def := pg_get_functiondef(r.oid);
    v_def := replace(replace(v_def, 'comuns_historico', 'casas_oracao_historico'), 'comuns', 'casas_oracao');
    execute v_def;
    v_lista := v_lista || r.proname || ' ';
  end loop;
  if v_lista <> '' then raise notice 'Funções ajustadas automaticamente (nome da tabela): %', v_lista; end if;
end $$;

-- 9) Descrições das permissões
update public.permissoes set descricao = regexp_replace(regexp_replace(regexp_replace(descricao,
    'comum\(ns\)', 'casa(s) de oração', 'g'), 'comuns', 'casas de oração', 'g'), 'comum', 'casa de oração', 'g')
 where descricao ilike '%comum%';

-- 10) Conferência final: nada pode ter ficado com o nome antigo
do $$
declare v_sobra text;
begin
  select string_agg(p.proname, ', ') into v_sobra from pg_proc p
   where p.pronamespace = 'public'::regnamespace and (p.proname ilike '%comum%' or p.prosrc ~* 'comum|\mcomuns\M');
  if v_sobra is not null then
    raise exception 'Ainda há funções com o nome antigo: %. Nada foi alterado.', v_sobra;
  end if;
  if exists (select 1 from information_schema.columns where table_schema = 'public' and column_name ilike '%comum%') then
    raise exception 'Ainda há colunas com o nome antigo. Nada foi alterado.';
  end if;
  if exists (select 1 from usuario_vinculos where nivel = 'COMUM') then
    raise exception 'Ainda há vínculos com o nível antigo. Nada foi alterado.';
  end if;
  raise notice 'OK: Comum renomeada para Casa de Oração em todo o banco.';
end $$;
