-- ============================================================================
-- 0070 — Fichas da Comissão Musical (grupo Administrativo): tabela, permissões e funções
--
-- O QUE FAZ
--   1) Cria a tabela fichas_musicais (guarda cada ficha preenchida: pedidos M01..M07, avaliações etc.).
--   2) Cria as permissões fichas.visualizar / criar / editar / excluir / resultado.
--   3) Cria o grupo "Secretário da Música" (só ele e o Administrador marcam o RESULTADO da ficha).
--   4) Funções: listar_fichas, obter_ficha, salvar_ficha, excluir_ficha, definir_resultado_ficha,
--      buscar_membros_para_ficha. Todas respeitam a região (abrangência) de quem está logado.
--   5) Resultado "Apto" altera o cadastro do músico (categoria ou instrumento), conforme o tipo da ficha.
-- Seguro rodar mais de uma vez. Para desfazer: 0070_reverter.sql
-- ============================================================================

-- 1) Tabela -------------------------------------------------------------------
create table if not exists public.fichas_musicais (
  id             uuid primary key default gen_random_uuid(),
  tipo           text not null check (tipo in (
                   'M01', 'M02', 'M03', 'M05', 'M07',
                   'AVALIACAO_RJM', 'AVALIACAO_CANDIDATO', 'PRE_AVALIACAO_ORGANISTA',
                   'EXAME_ORGANISTA', 'ACOMPANHAMENTO_GEM', 'NECESSIDADE_INSTRUMENTO')),
  membro_id      uuid references public.membros (id),          -- pessoa do cadastro (pode ficar vazio: candidato novo)
  casa_oracao_id uuid not null references public.casas_oracao (id),
  dados          jsonb not null default '{}'::jsonb,           -- campos digitados da ficha
  resultado      text check (resultado in ('APTO', 'NAO_APTO')),
  resultado_por  uuid,
  resultado_em   timestamptz,
  aplicado_em    timestamptz,                                   -- quando o cadastro do músico foi alterado pelo resultado
  criado_por     uuid default auth.uid(),
  criado_em      timestamptz not null default now(),
  atualizado_em  timestamptz not null default now(),
  excluido_em    timestamptz
);
create index if not exists fichas_musicais_tipo_idx   on public.fichas_musicais (tipo) where excluido_em is null;
create index if not exists fichas_musicais_membro_idx on public.fichas_musicais (membro_id) where excluido_em is null;
create index if not exists fichas_musicais_casa_idx   on public.fichas_musicais (casa_oracao_id) where excluido_em is null;
alter table public.fichas_musicais enable row level security;
revoke all on public.fichas_musicais from public, anon, authenticated;   -- só as funções abaixo mexem na tabela

-- 2) Permissões ---------------------------------------------------------------
insert into public.permissoes (codigo, modulo, acao, descricao) values
  ('fichas.visualizar', 'Fichas', 'Visualizar', 'Ver e imprimir as fichas da Comissão Musical da própria região.'),
  ('fichas.criar',      'Fichas', 'Criar',      'Preencher novas fichas.'),
  ('fichas.editar',     'Fichas', 'Editar',     'Alterar fichas que ainda não têm resultado.'),
  ('fichas.excluir',    'Fichas', 'Excluir',    'Excluir fichas que ainda não alteraram o cadastro.'),
  ('fichas.resultado',  'Fichas', 'Resultado',  'Marcar Apto / Não apto (Apto altera o cadastro do músico). Função do Secretário da Música.')
on conflict (codigo) do nothing;

-- 3) Grupos -------------------------------------------------------------------
insert into public.grupos (nome, descricao, ativo, sistema)
select 'Secretário da Música',
       'Preenche as fichas da Comissão Musical e marca o resultado (Apto / Não apto) da própria região.',
       true, false
 where not exists (select 1 from public.grupos where nome = 'Secretário da Música');

insert into public.grupo_permissoes (grupo_id, permissao_codigo)
select g.id, p.codigo
  from public.grupos g
  join public.permissoes p on p.codigo like 'fichas.%'
 where g.nome = 'Administrador' and g.sistema
on conflict do nothing;

insert into public.grupo_permissoes (grupo_id, permissao_codigo)
select g.id, p.codigo
  from public.grupos g
  join public.permissoes p on p.codigo in ('fichas.visualizar', 'fichas.criar', 'fichas.editar', 'fichas.excluir', 'fichas.resultado')
 where g.nome = 'Secretário da Música'
on conflict do nothing;

-- O Administrador Regional vê, preenche e edita, mas NÃO marca o resultado
insert into public.grupo_permissoes (grupo_id, permissao_codigo)
select g.id, p.codigo
  from public.grupos g
  join public.permissoes p on p.codigo in ('fichas.visualizar', 'fichas.criar', 'fichas.editar')
 where g.nome = 'Administrador Regional'
on conflict do nothing;

-- 4) Regra de visibilidade: a ficha é da região da Casa de Oração dela --------------------------------
create or replace function public.ficha_visivel(p_casa uuid)
returns boolean
language sql stable security definer set search_path = public
as $$ select p_casa is not null and public.casa_oracao_na_abrangencia(p_casa) $$;
revoke all on function public.ficha_visivel(uuid) from public, anon;
grant execute on function public.ficha_visivel(uuid) to authenticated;

-- 5) Lista -----------------------------------------------------------------------------------------
create or replace function public.listar_fichas(p_tipo text default null, p_limite integer default 300)
returns table(id uuid, tipo text, membro_id uuid, membro_nome text, casa_oracao_id uuid, casa_nome text,
              resultado text, aplicado_em timestamptz, criado_em timestamptz, criado_por_nome text)
language plpgsql stable security definer set search_path = public
as $f$
begin
  perform public.exigir_permissao('fichas.visualizar');
  return query
    select f.id, f.tipo, f.membro_id,
           coalesce(m.nome, f.dados ->> 'nome'),
           f.casa_oracao_id, c.nome,
           f.resultado, f.aplicado_em, f.criado_em, u.nome
      from public.fichas_musicais f
      left join public.membros m on m.id = f.membro_id
      left join public.casas_oracao c on c.id = f.casa_oracao_id
      left join public.usuarios u on u.id = f.criado_por
     where f.excluido_em is null
       and (p_tipo is null or f.tipo = p_tipo)
       and public.ficha_visivel(f.casa_oracao_id)
     order by f.criado_em desc
     limit greatest(1, least(coalesce(p_limite, 300), 1000));
end
$f$;

-- 6) Uma ficha (com nome do membro e da casa) ------------------------------------------------------
create or replace function public.obter_ficha(p_id uuid)
returns jsonb
language plpgsql stable security definer set search_path = public
as $f$
declare
  v_f public.fichas_musicais;
begin
  perform public.exigir_permissao('fichas.visualizar');
  select * into v_f from public.fichas_musicais x where x.id = p_id and x.excluido_em is null;
  if not found or not public.ficha_visivel(v_f.casa_oracao_id) then
    raise exception 'Ficha não encontrada.';
  end if;
  return to_jsonb(v_f) || jsonb_build_object(
    'membro_nome', (select m.nome from public.membros m where m.id = v_f.membro_id),
    'casa_nome',   (select c.nome from public.casas_oracao c where c.id = v_f.casa_oracao_id),
    'criado_por_nome', (select u.nome from public.usuarios u where u.id = v_f.criado_por),
    'resultado_por_nome', (select u.nome from public.usuarios u where u.id = v_f.resultado_por));
end
$f$;

-- 7) Salvar (nova ou alteração; ficha com resultado não muda mais) -------------------------------------
create or replace function public.salvar_ficha(p_id uuid, p_tipo text, p_membro uuid, p_casa uuid, p_dados jsonb)
returns uuid
language plpgsql security definer set search_path = public
as $f$
declare
  v_casa uuid := p_casa;
  v_f    public.fichas_musicais;
  v_id   uuid;
begin
  if p_id is null then
    perform public.exigir_permissao('fichas.criar');
  else
    perform public.exigir_permissao('fichas.editar');
  end if;
  if p_tipo is null or p_tipo not in ('M01', 'M02', 'M03', 'M05', 'M07', 'AVALIACAO_RJM', 'AVALIACAO_CANDIDATO',
       'PRE_AVALIACAO_ORGANISTA', 'EXAME_ORGANISTA', 'ACOMPANHAMENTO_GEM', 'NECESSIDADE_INSTRUMENTO') then
    raise exception 'Tipo de ficha inválido.';
  end if;
  if p_dados is null or jsonb_typeof(p_dados) <> 'object' or char_length(p_dados::text) > 30000 then
    raise exception 'Dados da ficha inválidos ou grandes demais.';
  end if;

  if p_membro is not null then
    select coalesce(m.casa_oracao_id, p_casa) into v_casa
      from public.membros m where m.id = p_membro and m.excluido_em is null;
    if not found then raise exception 'Membro não encontrado.'; end if;
  end if;
  if v_casa is null then raise exception 'Informe a Casa de Oração.'; end if;
  if not public.ficha_visivel(v_casa) then
    raise exception 'Esta Casa de Oração está fora da sua abrangência.' using errcode = '42501';
  end if;

  if p_id is null then
    insert into public.fichas_musicais (tipo, membro_id, casa_oracao_id, dados)
    values (p_tipo, p_membro, v_casa, p_dados)
    returning id into v_id;
    perform public.registrar_auditoria('ficha_criada', 'ficha', v_id, jsonb_build_object('tipo', p_tipo));
  else
    select * into v_f from public.fichas_musicais x where x.id = p_id and x.excluido_em is null for update;
    if not found or not public.ficha_visivel(v_f.casa_oracao_id) then
      raise exception 'Ficha não encontrada.';
    end if;
    if v_f.resultado is not null then
      raise exception 'Esta ficha já tem resultado e não pode mais ser alterada.';
    end if;
    update public.fichas_musicais
       set membro_id = p_membro, casa_oracao_id = v_casa, dados = p_dados, atualizado_em = now()
     where id = p_id;
    v_id := p_id;
    perform public.registrar_auditoria('ficha_alterada', 'ficha', v_id, jsonb_build_object('tipo', v_f.tipo));
  end if;
  return v_id;
end
$f$;

-- 8) Excluir (só ficha ainda sem alteração no cadastro) ------------------------------------------------
create or replace function public.excluir_ficha(p_id uuid)
returns void
language plpgsql security definer set search_path = public
as $f$
declare
  v_f public.fichas_musicais;
begin
  perform public.exigir_permissao('fichas.excluir');
  select * into v_f from public.fichas_musicais x where x.id = p_id and x.excluido_em is null for update;
  if not found or not public.ficha_visivel(v_f.casa_oracao_id) then
    raise exception 'Ficha não encontrada.';
  end if;
  if v_f.aplicado_em is not null then
    raise exception 'Esta ficha já alterou o cadastro do músico e não pode ser excluída.';
  end if;
  update public.fichas_musicais set excluido_em = now() where id = p_id;
  perform public.registrar_auditoria('ficha_excluida', 'ficha', p_id, jsonb_build_object('tipo', v_f.tipo));
end
$f$;

-- 9) Resultado (Secretário da Música): "Apto" altera o cadastro conforme o tipo -----------------------
--   M02 (Culto Oficial): RJM -> CULTO_OFICIAL      M03 (Oficialização): CULTO_OFICIAL -> OFICIALIZADO
--   M05 (organista): vai para a categoria pedida na ficha (dados.para)
--   M07 (troca de instrumento): instrumento do cadastro vira dados.instrumento_novo_id
--   Demais tipos: só registram o resultado (não alteram o cadastro).
create or replace function public.definir_resultado_ficha(p_id uuid, p_resultado text)
returns jsonb
language plpgsql security definer set search_path = public
as $f$
declare
  v_f      public.fichas_musicais;
  v_m      public.membros;
  v_nova   text;
  v_instr  uuid;
  v_aplic  boolean := false;
  v_msg    text := 'Resultado registrado.';
begin
  perform public.exigir_permissao('fichas.resultado');
  if p_resultado is null or p_resultado not in ('APTO', 'NAO_APTO') then
    raise exception 'Resultado inválido.';
  end if;
  select * into v_f from public.fichas_musicais x where x.id = p_id and x.excluido_em is null for update;
  if not found or not public.ficha_visivel(v_f.casa_oracao_id) then
    raise exception 'Ficha não encontrada.';
  end if;
  if v_f.resultado is not null then
    raise exception 'Esta ficha já tem resultado.';
  end if;

  if p_resultado = 'APTO' and v_f.tipo in ('M02', 'M03', 'M05', 'M07') then
    if v_f.membro_id is null then
      raise exception 'Escolha o membro do cadastro nesta ficha antes de marcar Apto.';
    end if;
    select * into v_m from public.membros m where m.id = v_f.membro_id and m.excluido_em is null for update;
    if not found then raise exception 'Membro não encontrado.'; end if;

    if v_f.tipo = 'M07' then
      begin
        v_instr := nullif(v_f.dados ->> 'instrumento_novo_id', '')::uuid;
      exception when others then
        raise exception 'Instrumento novo inválido na ficha.';
      end;
      if v_instr is null or not exists (select 1 from public.instrumentos i where i.id = v_instr) then
        raise exception 'Escolha o instrumento novo na ficha antes de marcar Apto.';
      end if;
      update public.membros set instrumento_id = v_instr where id = v_m.id;
      v_msg := 'Apto: o instrumento do cadastro foi trocado.';
    else
      v_nova := case v_f.tipo
                  when 'M02' then 'CULTO_OFICIAL'
                  when 'M03' then 'OFICIALIZADO'
                  else upper(coalesce(v_f.dados ->> 'para', '')) end;
      if v_nova not in ('RJM', 'CULTO_OFICIAL', 'OFICIALIZADO') then
        raise exception 'A ficha não informa para qual categoria o pedido foi feito.';
      end if;
      update public.membros set categoria = v_nova where id = v_m.id;
      v_msg := 'Apto: a categoria do cadastro agora é ' || v_nova || '.';
    end if;
    v_aplic := true;
  end if;

  update public.fichas_musicais
     set resultado = p_resultado, resultado_por = (select auth.uid()), resultado_em = now(),
         aplicado_em = case when v_aplic then now() else null end, atualizado_em = now()
   where id = p_id;
  perform public.registrar_auditoria('ficha_resultado', 'ficha', p_id,
            jsonb_build_object('tipo', v_f.tipo, 'resultado', p_resultado, 'cadastro_alterado', v_aplic));
  return jsonb_build_object('aplicado', v_aplic, 'mensagem', v_msg);
end
$f$;

-- 10) Busca de pessoas do cadastro para preencher a ficha (só da região de quem busca) ---------------
create or replace function public.buscar_membros_para_ficha(p_termo text)
returns table(id uuid, nome text, casa_oracao_id uuid, casa_nome text, cargo text,
              instrumento_id uuid, instrumento_nome text, categoria text)
language plpgsql stable security definer set search_path = public
as $f$
declare
  v_t text := regexp_replace(public.normalizar_texto(coalesce(p_termo, '')), '[%_\\]', '', 'g');
begin
  perform public.exigir_permissao('fichas.criar');
  if char_length(v_t) < 2 then return; end if;
  return query
    select m.id, m.nome, m.casa_oracao_id, c.nome, g.nome, m.instrumento_id, i.nome, m.categoria
      from public.membros m
      left join public.casas_oracao c on c.id = m.casa_oracao_id
      left join public.cargos g on g.id = m.cargo_id
      left join public.instrumentos i on i.id = m.instrumento_id
     where m.excluido_em is null
       and public.normalizar_texto(m.nome) like '%' || v_t || '%'
       and public.ficha_visivel(m.casa_oracao_id)
     order by m.nome
     limit 15;
end
$f$;

revoke all on function public.listar_fichas(text, integer), public.obter_ficha(uuid), public.salvar_ficha(uuid, text, uuid, uuid, jsonb),
  public.excluir_ficha(uuid), public.definir_resultado_ficha(uuid, text), public.buscar_membros_para_ficha(text)
  from public, anon;
grant execute on function public.listar_fichas(text, integer), public.obter_ficha(uuid), public.salvar_ficha(uuid, text, uuid, uuid, jsonb),
  public.excluir_ficha(uuid), public.definir_resultado_ficha(uuid, text), public.buscar_membros_para_ficha(text)
  to authenticated;

-- 11) Conferência (se falhar, nada é aplicado) --------------------------------------------------------
do $$
begin
  if (select count(*) from public.permissoes where codigo like 'fichas.%') <> 5 then
    raise exception 'Verificação falhou: as 5 permissões de fichas não foram criadas.';
  end if;
  if not exists (select 1 from public.grupos where nome = 'Secretário da Música') then
    raise exception 'Verificação falhou: grupo Secretário da Música ausente.';
  end if;
  if to_regprocedure('public.definir_resultado_ficha(uuid,text)') is null then
    raise exception 'Verificação falhou: funções de fichas ausentes.';
  end if;
end
$$;
