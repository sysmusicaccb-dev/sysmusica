-- 0069 — Etapa 5: aposenta a tabela antiga usuario_cidades (abrangência por cidade).
-- Hoje a abrangência vem dos vínculos (usuario_vinculos: Estado, RRM, RA, ADM, Setor ou Casa de Oração).
-- Os 2 usuários que ainda tinham cidades (Master e portaria) já têm vínculos novos: nenhum acesso se perde.
-- O QUE FAZ:
--   1) confere se algo mais ainda usa as funções antigas (se usar, ABORTA sem mudar nada);
--   2) tira a tabela da restauração de backup (backup_aplicar) e da lista de cidades (listar_cidades_conhecidas);
--   3) apaga as 3 funções antigas (cidade_na_minha_abrangencia, definir_abrangencia, listar_abrangencias);
--   4) RENOMEIA a tabela para usuario_cidades_aposentada (os dados ficam; dá para desfazer com 0069_reverter.sql).
-- IMPORTANTE: publique antes o instalador do site que tira usuario_cidades da lista do Backup.

do $$
declare
  v_uso text;
begin
  select string_agg(distinct p.proname, ', ') into v_uso
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public'
     and p.proname not in ('cidade_na_minha_abrangencia', 'definir_abrangencia', 'listar_abrangencias')
     and (p.prosrc ilike '%cidade_na_minha_abrangencia%' or p.prosrc ilike '%definir_abrangencia%'
          or p.prosrc ilike '%listar_abrangencias%');
  if v_uso is not null then
    raise exception 'Abortado: ainda há funções que usam as antigas: %', v_uso;
  end if;

  select string_agg(distinct c.relname, ', ') into v_uso
    from pg_policy pol join pg_class c on c.oid = pol.polrelid
   where pg_get_expr(pol.polqual, pol.polrelid) ilike '%cidade_na_minha_abrangencia%'
      or pg_get_expr(pol.polwithcheck, pol.polrelid) ilike '%cidade_na_minha_abrangencia%';
  if v_uso is not null then
    raise exception 'Abortado: ainda há políticas (RLS) que usam cidade_na_minha_abrangencia em: %', v_uso;
  end if;

  select string_agg(distinct v.viewname, ', ') into v_uso
    from pg_views v where v.schemaname = 'public' and v.definition ilike '%cidade_na_minha_abrangencia%';
  if v_uso is not null then
    raise exception 'Abortado: ainda há visões que usam cidade_na_minha_abrangencia: %', v_uso;
  end if;
end
$$;

-- 2) Restauração de backup sem a tabela antiga
CREATE OR REPLACE FUNCTION public.backup_aplicar(p_usuario uuid, p_operacoes jsonb, p_resumo jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
      ('rrms',                array['id'],                              false, false, ''),
      ('ras',                 array['id'],                              false, false, ''),
      ('adms',                array['id'],                              false, false, ''),
      ('setores',             array['id'],                              false, false, ''),
      ('casas_oracao',        array['id'],                              false, false, ''),
      ('familias',            array['id'],                              false, false, ''),
      ('cargos',              array['id'],                              false, false, ''),
      ('finalidades_evento',  array['id'],                              false, false, ''),
      ('instrumentos',        array['id'],                              false, false, ''),
      ('tipos_evento',        array['id'],                              false, false, ''),
      ('hinos',               array['id'],                              false, false, ''),
      ('cadastros_pendentes', array['id'],                              false, false, ''),
      ('membros_cadastro',    array['membro_id'],                       false, false, ''),
      ('dados_ensaio',        array['id'],                              false, false, ''),
      ('dados_ensaio_encarregados', array['id'],                        false, false, ''),
      ('dados_ensaio_hinos',  array['id'],                              false, false, ''),
      ('grupos',              array['id'],                              false, false, ''),
      ('grupo_permissoes',    array['grupo_id', 'permissao_codigo'],    false, false, ''),
      ('usuarios',            array['id'],                              false, false, 'login'),
      ('usuario_grupos',      array['usuario_id', 'grupo_id'],          false, false, ''),
      ('usuario_vinculos',    array['usuario_id', 'nivel', 'alvo_id'],  false, false, ''),
      ('usuario_preferencias', array['usuario_id'],                      false, false, ''),
      ('casas_oracao_historico', array['id'],                           false, true,  ''),
      ('qr_historico',        array['id'],                              false, true,  ''),
      ('cadastro_publico_config', array['id'],                          false, false, ''),
      ('membros',             array['id'],                              true,  false, ''),
      ('eventos',             array['id'],                              true,  false, ''),
      ('portarias',           array['id'],                              true,  false, ''),
      ('portarias_historico', array['id'],                              false, true,  ''),
      ('presencas',           array['id'],                              true,  false, ''),
      ('presencas_avulsas',   array['id'],                              true,  false, '')
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
$function$;

-- Lista de cidades sem a parte legada (só eventos e membros da própria abrangência)
create or replace function public.listar_cidades_conhecidas()
 returns table(cidade text)
 language plpgsql
 stable security definer
 set search_path to 'public'
as $function$
declare
  v_global boolean := public.tem_acesso_total_organizacao();
begin
  perform public.exigir_permissao('usuarios.editar');
  return query
    select distinct on (public.normalizar_texto(t.nome)) t.nome
    from (
      select btrim(e.cidade) as nome from public.eventos e
       where e.cidade is not null and e.excluido_em is null
         and (v_global or public.casa_oracao_na_abrangencia(e.casa_oracao_id))
      union all
      select btrim(m.cidade) from public.membros m
       where m.cidade is not null and m.excluido_em is null
         and (v_global or public.casa_oracao_na_abrangencia(m.casa_oracao_id))
    ) t
    where t.nome <> ''
    order by public.normalizar_texto(t.nome), t.nome;
end;
$function$;

-- 3) Funções antigas
drop function if exists public.cidade_na_minha_abrangencia(text);
drop function if exists public.definir_abrangencia(uuid, text[]);
drop function if exists public.listar_abrangencias();

-- 4) Tabela aposentada (os dados continuam lá)
do $$
begin
  if to_regclass('public.usuario_cidades') is not null and to_regclass('public.usuario_cidades_aposentada') is null then
    alter table public.usuario_cidades rename to usuario_cidades_aposentada;
  end if;
end
$$;
