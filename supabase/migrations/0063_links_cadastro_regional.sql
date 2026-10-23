-- ============================================================================
-- 0063 — Links de cadastro por região (cadastro público encaminhado à região certa)
--
-- PROBLEMA: o formulário público lista as casas de TODAS as regiões e, quando a pessoa digita uma casa que não está
-- na lista, o pedido fica sem casa e só o administrador global enxerga.
--
-- SOLUÇÃO: cada administração (RRM, RA ou ADM) gera o próprio link. Quem abre o link:
--   * vê apenas as Casas de Oração daquela região;
--   * se digitar uma casa que não existe, o pedido nasce marcado com a região do link
--     e aparece para os responsáveis daquela região (e de cima dela), não só para o global.
-- O link geral (sem código) continua funcionando como hoje.
--
-- O que muda:
--   1. tabela cadastro_links (código aleatório, nível, alvo, ativo);
--   2. cadastros_pendentes ganha link_id, origem_nivel, origem_id;
--   3. cadastro_pendente_visivel_r (nova) = regra antiga OU "pedido sem casa vindo de uma região na minha abrangência";
--      listar/obter/contar/aprovar/rejeitar passam a usar a nova regra (troca feita por substituição de texto, com conferência);
--   4. registrar_cadastro_publico lê dados.link: valida o link e a casa escolhida pertence à região;
--   5. opcoes_cadastro_link(código): as opções do formulário só com as casas da região;
--   6. listar_links_cadastro / criar_link_cadastro / desativar_link_cadastro (tela de Cadastros).
-- Para desfazer: 0063_reverter.sql
-- ============================================================================

-- 1) Tabela de links ----------------------------------------------------------
create table if not exists public.cadastro_links (
  id            uuid primary key default gen_random_uuid(),
  codigo        text not null unique default replace(gen_random_uuid()::text, '-', ''),
  nivel         text not null check (nivel in ('RRM', 'RA', 'ADM')),
  alvo_id       uuid not null,
  rotulo        text not null,
  ativo         boolean not null default true,
  criado_por    uuid,
  criado_em     timestamptz not null default now(),
  desativado_em timestamptz
);
alter table public.cadastro_links enable row level security;
revoke all on public.cadastro_links from public, anon, authenticated;
-- No máximo um link ATIVO por região (criar de novo devolve o que já existe)
create unique index if not exists cadastro_links_um_ativo
  on public.cadastro_links (nivel, alvo_id) where ativo;

-- 2) Marca de origem nos pedidos ------------------------------------------------
alter table public.cadastros_pendentes
  add column if not exists link_id      uuid references public.cadastro_links (id) on delete set null,
  add column if not exists origem_nivel text,
  add column if not exists origem_id    uuid;

-- 3) Casa pertence à região do link? ---------------------------------------------
create or replace function public.casa_na_regiao_do_link(p_casa uuid, p_nivel text, p_alvo uuid)
returns boolean
language sql stable security definer set search_path = public
as $$
  select exists (select 1 from public.cadeia_organizacao('CASA_ORACAO', p_casa) c
                  where c.r_nivel = p_nivel and c.r_id = p_alvo)
$$;
revoke all on function public.casa_na_regiao_do_link(uuid, text, uuid) from public, anon, authenticated;

-- 4) Nova regra de visibilidade --------------------------------------------------
create or replace function public.cadastro_pendente_visivel_r(p_casa uuid, p_membro uuid, p_origem_nivel text, p_origem_id uuid)
returns boolean
language sql stable security definer set search_path = public
as $$
  select public.cadastro_pendente_visivel(p_casa, p_membro)
      or (p_casa is null and p_origem_id is not null and public.alvo_na_minha_abrangencia(p_origem_nivel, p_origem_id))
$$;
revoke all on function public.cadastro_pendente_visivel_r(uuid, uuid, text, uuid) from public, anon, authenticated;

-- 5) Troca da regra nas funções que já existem (substituição de texto CONFERIDA) ------------------
do $troca$
declare
  r        record;
  v_def    text;
  v_novo   text;
  v_velho  constant text := 'public.cadastro_pendente_visivel(c.casa_oracao_id, c.membro_id)';
  v_nova   constant text := 'public.cadastro_pendente_visivel_r(c.casa_oracao_id, c.membro_id, c.origem_nivel, c.origem_id)';
begin
  for r in
    select p.oid, p.proname
      from pg_proc p
     where p.pronamespace = 'public'::regnamespace
       and p.proname in ('listar_cadastros_pendentes', 'obter_cadastro_pendente', 'contar_cadastros_pendentes',
                         'aprovar_cadastro_pendente', 'rejeitar_cadastro_pendente')
  loop
    v_def := pg_get_functiondef(r.oid);
    if position(v_nova in v_def) > 0 then continue; end if;          -- já trocada
    if position(v_velho in v_def) = 0 then
      raise exception 'Função % não tem o trecho esperado; nada foi alterado.', r.proname;
    end if;
    v_novo := replace(v_def, v_velho, v_nova);
    execute v_novo;
  end loop;
end
$troca$;

-- 6) registrar_cadastro_publico: lê dados.link, valida e marca a origem ---------------------------------
do $troca2$
declare
  v_oid  oid;
  v_def  text;
  v_novo text;
  v_par  text[][] := array[
    -- [trecho antigo, trecho novo]
    [E'  v_comp text; v_uf text; v_cnum text;\nbegin',
     E'  v_comp text; v_uf text; v_cnum text;\n  v_link public.cadastro_links%rowtype; v_link_cod text;\nbegin'],
    [E'  d := p_dados;\n',
     E'  d := p_dados;\n\n  -- Link de cadastro da região (opcional): precisa estar ativo\n  v_link_cod := nullif(btrim(d ->> ''link''), '''');\n  if v_link_cod is not null then\n    select * into v_link from public.cadastro_links l where l.codigo = v_link_cod and l.ativo;\n    if not found then\n      raise exception ''Este link de cadastro não está mais ativo. Peça um link novo à sua administração.'';\n    end if;\n  end if;\n'],
    [E'  -- Cargo, categoria e instrumento\n',
     E'  -- Com link da região: a casa escolhida da lista precisa ser da região do link\n  if v_link.id is not null and v_casa is not null\n     and not public.casa_na_regiao_do_link(v_casa, v_link.nivel, v_link.alvo_id) then\n    raise exception ''A Casa de Oração escolhida não pertence à região deste link.'';\n  end if;\n\n  -- Cargo, categoria e instrumento\n'],
    [E'  update public.cadastro_publico_uploads set usado = true where id = p_envio;',
     E'  -- Marca a região de origem (quem aprova nessa região passa a enxergar o pedido, mesmo sem casa cadastrada)\n  if v_link.id is not null then\n    update public.cadastros_pendentes\n       set link_id = v_link.id, origem_nivel = v_link.nivel, origem_id = v_link.alvo_id\n     where id = p_envio;\n  end if;\n\n  update public.cadastro_publico_uploads set usado = true where id = p_envio;']
  ];
  i int;
begin
  select p.oid into v_oid from pg_proc p
   where p.pronamespace = 'public'::regnamespace and p.proname = 'registrar_cadastro_publico';
  -- A função em produção pode ter quebras de linha do Windows (CR+LF): normaliza para LF antes de procurar os trechos
  v_def := replace(pg_get_functiondef(v_oid), E'\r', '');
  if position('v_link_cod' in v_def) > 0 then return; end if;       -- já trocada
  v_novo := v_def;
  for i in 1 .. array_length(v_par, 1) loop
    if (length(v_novo) - length(replace(v_novo, v_par[i][1], ''))) <> length(v_par[i][1]) then
      raise exception 'registrar_cadastro_publico: o trecho % não foi achado exatamente uma vez; nada foi alterado.', i;
    end if;
    v_novo := replace(v_novo, v_par[i][1], v_par[i][2]);
  end loop;
  execute v_novo;
end
$troca2$;

-- 7) Opções do formulário para um link ---------------------------------------------
create or replace function public.opcoes_cadastro_link(p_codigo text)
returns jsonb
language plpgsql stable security definer set search_path = public
as $$
declare
  l public.cadastro_links%rowtype;
  o jsonb;
begin
  select * into l from public.cadastro_links x where x.codigo = nullif(btrim(p_codigo), '') and x.ativo;
  if not found then return null; end if;
  o := public.opcoes_cadastro_publico();
  return jsonb_set(
           jsonb_set(o, '{casas}',
             coalesce((select jsonb_agg(e order by e ->> 'nome')
                         from jsonb_array_elements(o -> 'casas') e
                        where public.casa_na_regiao_do_link((e ->> 'id')::uuid, l.nivel, l.alvo_id)), '[]'::jsonb)),
           '{regiao}', jsonb_build_object('nivel', l.nivel, 'nome', l.rotulo));
end
$$;
revoke all on function public.opcoes_cadastro_link(text) from public, anon, authenticated;
grant execute on function public.opcoes_cadastro_link(text) to anon, authenticated, service_role;

-- 8) Telas de Cadastros: listar / criar / desativar ----------------------------------
create or replace function public.listar_links_cadastro()
returns table (id uuid, codigo text, nivel text, alvo_id uuid, rotulo text, ativo boolean, criado_em timestamptz,
               criado_por_nome text, pendentes bigint)
language plpgsql stable security definer set search_path = public
as $$
begin
  perform public.exigir_permissao('cadastros.aprovar');
  return query
    select l.id, l.codigo, l.nivel, l.alvo_id, l.rotulo, l.ativo, l.criado_em, u.nome,
           (select count(*) from public.cadastros_pendentes c where c.link_id = l.id and c.status = 'PENDENTE')
      from public.cadastro_links l
      left join public.usuarios u on u.id = l.criado_por
     where public.alvo_na_minha_abrangencia(l.nivel, l.alvo_id)
     order by l.ativo desc, l.criado_em desc;
end
$$;

create or replace function public.criar_link_cadastro(p_nivel text, p_alvo uuid)
returns jsonb
language plpgsql security definer set search_path = public
as $$
declare
  v_nome text;
  l      public.cadastro_links%rowtype;
begin
  perform public.exigir_permissao('cadastros.aprovar');
  if p_nivel not in ('RRM', 'RA', 'ADM') or p_alvo is null then
    raise exception 'Escolha a região do link (RRM, RA ou ADM).' using errcode = '22023';
  end if;
  if p_nivel = 'RRM' then select x.nome into v_nome from public.rrms x where x.id = p_alvo and x.ativo;
  elsif p_nivel = 'RA' then select x.nome into v_nome from public.ras x where x.id = p_alvo and x.ativo;
  else select x.nome into v_nome from public.adms x where x.id = p_alvo and x.ativo; end if;
  if v_nome is null then raise exception 'Região não encontrada.' using errcode = 'P0002'; end if;
  if not public.alvo_na_minha_abrangencia(p_nivel, p_alvo) then
    raise exception 'Esta região está fora da sua abrangência.' using errcode = '42501';
  end if;

  select * into l from public.cadastro_links x where x.nivel = p_nivel and x.alvo_id = p_alvo and x.ativo;
  if not found then
    insert into public.cadastro_links (nivel, alvo_id, rotulo, criado_por)
    values (p_nivel, p_alvo, v_nome, (select auth.uid())) returning * into l;
    perform public.registrar_auditoria('link_cadastro_criado', 'link_cadastro', l.id,
              jsonb_build_object('nivel', p_nivel, 'rotulo', v_nome));
  end if;
  return jsonb_build_object('id', l.id, 'codigo', l.codigo, 'nivel', l.nivel, 'rotulo', l.rotulo);
end
$$;

create or replace function public.desativar_link_cadastro(p_id uuid)
returns void
language plpgsql security definer set search_path = public
as $$
declare l public.cadastro_links%rowtype;
begin
  perform public.exigir_permissao('cadastros.aprovar');
  select * into l from public.cadastro_links x where x.id = p_id for update;
  if not found or not public.alvo_na_minha_abrangencia(l.nivel, l.alvo_id) then
    raise exception 'Link não encontrado.' using errcode = 'P0002';
  end if;
  if not l.ativo then return; end if;
  update public.cadastro_links set ativo = false, desativado_em = now() where id = p_id;
  perform public.registrar_auditoria('link_cadastro_desativado', 'link_cadastro', p_id,
            jsonb_build_object('nivel', l.nivel, 'rotulo', l.rotulo));
end
$$;

revoke all on function public.listar_links_cadastro() from public, anon, authenticated;
revoke all on function public.criar_link_cadastro(text, uuid) from public, anon, authenticated;
revoke all on function public.desativar_link_cadastro(uuid) from public, anon, authenticated;
grant execute on function public.listar_links_cadastro() to authenticated;
grant execute on function public.criar_link_cadastro(text, uuid) to authenticated;
grant execute on function public.desativar_link_cadastro(uuid) to authenticated;
