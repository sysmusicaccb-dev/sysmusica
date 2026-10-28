-- 0081: Perfil do Evento (Entrega 3) — campos extras criados pelo administrador em cada perfil.
-- Cada perfil pode ter até 10 campos extras (texto curto, texto longo, número, sim/não ou lista), na ordem escolhida,
-- obrigatórios ou não. A definição fica em perfis_evento.config -> campos_extras e os valores, em dados_ensaio.extras
-- (jsonb, por id do campo). Campo já preenchido em algum ensaio não pode ser excluído nem mudar de tipo: só desativar.
-- Seguro rodar mais de uma vez. Rodar ANTES do push.

alter table public.dados_ensaio add column if not exists extras jsonb not null default '{}'::jsonb;

-- Limpa a lista de campos extras enviada pela tela: ids únicos, nomes, tipos e opções válidos; no máximo 10 campos
create or replace function public.normalizar_campos_extras(j jsonb)
returns jsonb
language plpgsql immutable set search_path = public
as $f$
declare
  v_out   jsonb := '[]'::jsonb;
  v_e     jsonb;
  v_id    text;
  v_nome  text;
  v_tipo  text;
  v_op    jsonb;
  v_ids   text[] := '{}';
  v_nomes text[] := '{}';
begin
  if jsonb_typeof(j) <> 'array' then
    return '[]'::jsonb;
  end if;
  for v_e in select * from jsonb_array_elements(j) loop
    exit when jsonb_array_length(v_out) >= 10;
    continue when jsonb_typeof(v_e) <> 'object';
    v_id   := lower(coalesce(v_e ->> 'id', ''));
    v_nome := public.cfg_texto(v_e -> 'nome', '');
    v_tipo := coalesce(v_e ->> 'tipo', '');
    continue when v_id !~ '^[a-z0-9_]{1,24}$' or v_id = any (v_ids)
               or v_nome = '' or lower(v_nome) = any (v_nomes)
               or v_tipo not in ('texto_curto', 'texto_longo', 'numero', 'sim_nao', 'lista');
    v_op := '[]'::jsonb;
    if v_tipo = 'lista' then
      select coalesce(jsonb_agg(d.o order by d.ord), '[]'::jsonb) into v_op
        from (select q.o, min(q.ord) as ord
                from (select public.cfg_texto(x.val, '') as o, x.ord
                        from jsonb_array_elements(case when jsonb_typeof(v_e -> 'opcoes') = 'array' then v_e -> 'opcoes' else '[]'::jsonb end)
                             with ordinality x(val, ord)) q
               where q.o <> ''
               group by q.o order by min(q.ord) limit 20) d;
      continue when jsonb_array_length(v_op) < 2;
    end if;
    v_ids   := v_ids || v_id;
    v_nomes := v_nomes || lower(v_nome);
    v_out := v_out || jsonb_build_array(jsonb_build_object(
      'id', v_id, 'nome', v_nome, 'tipo', v_tipo,
      'obrigatorio', public.cfg_bool(v_e -> 'obrigatorio', false),
      'ativo', public.cfg_bool(v_e -> 'ativo', true),
      'opcoes', v_op));
  end loop;
  return v_out;
end
$f$;

-- Normalização do perfil passa a levar os campos extras
create or replace function public.normalizar_config_perfil(p jsonb, p_modelo text)
returns jsonb
language plpgsql immutable set search_path = public
as $f$
declare
  d   jsonb := public.config_padrao_ensaio(p_modelo);
  i   jsonb := case when jsonb_typeof(p) = 'object' then p else '{}'::jsonb end;
  qa  jsonb := case when jsonb_typeof(i -> 'quem_atendeu') = 'object' then i -> 'quem_atendeu' else '{}'::jsonb end;
  ab  jsonb := case when jsonb_typeof(i -> 'hino_abertura') = 'object' then i -> 'hino_abertura' else '{}'::jsonb end;
  pa  jsonb := case when jsonb_typeof(i -> 'palavra') = 'object' then i -> 'palavra' else '{}'::jsonb end;
  en  jsonb := case when jsonb_typeof(i -> 'encarregados') = 'object' then i -> 'encarregados' else '{}'::jsonb end;
  hx  jsonb := case when jsonb_typeof(i -> 'hinos_executados') = 'object' then i -> 'hinos_executados' else '{}'::jsonb end;
  v_max integer := public.cfg_int(en -> 'maximo', 1, 3, 3);
  v_modo text := coalesce(ab ->> 'modo', '');
  ce  jsonb := public.normalizar_campos_extras(i -> 'campos_extras');
begin
  return jsonb_build_object(
    'quem_atendeu', jsonb_build_object(
      'ativo', public.cfg_bool(qa -> 'ativo', true),
      'titulo', public.cfg_texto(qa -> 'titulo', d #>> '{quem_atendeu,titulo}'),
      'rotulo_nome', public.cfg_texto(qa -> 'rotulo_nome', d #>> '{quem_atendeu,rotulo_nome}'),
      'cargos', public.cfg_lista(qa -> 'cargos', array['ANCIAO','DIACONO','COOPERADOR_OFICIO','COOPERADOR_RJM'], d #> '{quem_atendeu,cargos}')),
    'hino_abertura', jsonb_build_object(
      'modo', case when v_modo in ('obrigatorio', 'pergunta', 'nao_usa') then v_modo else d #>> '{hino_abertura,modo}' end),
    'palavra', jsonb_build_object(
      'ativo', public.cfg_bool(pa -> 'ativo', (d #>> '{palavra,ativo}')::boolean),
      'obrigatoria', public.cfg_bool(pa -> 'obrigatoria', true),
      'limite', public.cfg_int(pa -> 'limite', 1, 500, 500)),
    'encarregados', jsonb_build_object(
      'ativo', public.cfg_bool(en -> 'ativo', true),
      'cargos', public.cfg_lista(en -> 'cargos', array['REGIONAL','LOCAL','INSTRUTOR'], d #> '{encarregados,cargos}'),
      'minimo', least(public.cfg_int(en -> 'minimo', 0, 3, 1), v_max),
      'maximo', v_max,
      'cidade_uf', public.cfg_bool(en -> 'cidade_uf', true)),
    'hinos_executados', jsonb_build_object('ativo', public.cfg_bool(hx -> 'ativo', true)),
    'campos_extras', ce);
end
$f$;

-- Dados do ensaio: obter (devolve os valores dos campos extras)
create or replace function public.obter_dados_ensaio(p_evento_id uuid)
returns jsonb
language plpgsql stable security definer set search_path = public
as $f$
declare
  v_e        record;
  v_d        public.dados_ensaio;
  v_admin    boolean;
  v_iniciado boolean;
  v_encerr   boolean;
begin
  if not public.tem_alguma_permissao(array['ensaio.visualizar', 'ensaio.registrar']) then
    raise exception 'Você não tem permissão para esta operação.' using errcode = '42501';
  end if;

  select e.id, e.tipo, e.tipo_evento_id, e.data_evento, e.local, e.cidade, e.cancelado_em, t.modelo_ensaio, c.nome as casa
    into v_e
    from public.eventos e
    left join public.tipos_evento t on t.id = e.tipo_evento_id
    left join public.casas_oracao c on c.id = e.casa_oracao_id
   where e.id = p_evento_id and e.excluido_em is null;
  if not found then
    raise exception 'Evento não encontrado.';
  end if;
  if not public.evento_na_abrangencia(p_evento_id) then
    raise exception 'Este evento está fora da sua abrangência.' using errcode = '42501';
  end if;
  if v_e.modelo_ensaio is null then
    raise exception 'Este evento não é um ensaio Local ou Regional.';
  end if;

  v_admin    := public.tem_permissao('eventos.cancelar');
  v_iniciado := now() >= v_e.data_evento - interval '2 hours';
  v_encerr   := public.portaria_encerrada(v_e.data_evento);
  select * into v_d from public.dados_ensaio d where d.evento_id = p_evento_id;

  return jsonb_build_object(
    'evento', jsonb_build_object(
      'id', v_e.id, 'tipo', v_e.tipo, 'modelo_ensaio', v_e.modelo_ensaio, 'data_evento', v_e.data_evento,
      'local', v_e.local, 'cidade', v_e.cidade, 'casa_oracao', v_e.casa,
      'cancelado', v_e.cancelado_em is not null, 'iniciado', v_iniciado, 'encerrado', v_encerr),
    -- Campos que o perfil do tipo de evento manda mostrar
    'config', public.config_ensaio_do_tipo(v_e.tipo_evento_id),
    -- A tela só deixa editar quando o banco deixaria salvar
    'pode_editar', public.tem_permissao('ensaio.registrar') and v_e.cancelado_em is null
                   and (v_admin or (v_iniciado and not v_encerr)),
    'dados', case when v_d.id is null then null else jsonb_build_object(
      'atende_cargo', v_d.atende_cargo, 'atende_nome', v_d.atende_nome, 'palavra', v_d.palavra,
      'hino_abertura_id', v_d.hino_abertura_id, 'atualizado_em', v_d.atualizado_em, 'extras', coalesce(v_d.extras, '{}'::jsonb),
      'encarregados', (select coalesce(jsonb_agg(jsonb_build_object('ordem', x.ordem, 'nome', x.nome, 'cidade_uf', x.cidade_uf, 'cargo', x.cargo)
                                                 order by x.ordem), '[]'::jsonb)
                         from public.dados_ensaio_encarregados x where x.dados_ensaio_id = v_d.id),
      'hinos', (select coalesce(jsonb_agg(h.hino_id order by h.ordem), '[]'::jsonb)
                  from public.dados_ensaio_hinos h where h.dados_ensaio_id = v_d.id)) end);
end;
$f$;

-- Dados do ensaio: salvar (valida e grava os campos extras)
create or replace function public.salvar_dados_ensaio(p_evento_id uuid, p_dados jsonb)
returns uuid
language plpgsql security definer set search_path = public
as $f$
declare
  v_uid      uuid := (select auth.uid());
  v_e        record;
  v_d        public.dados_ensaio;
  v_admin    boolean;
  v_cfg      jsonb;
  v_cargo    text := nullif(upper(coalesce(p_dados ->> 'atende_cargo', '')), '');
  v_nome     text := public.limpar_espacos(p_dados ->> 'atende_nome');
  v_palavra  text := nullif(btrim(coalesce(p_dados ->> 'palavra', '')), '');
  v_abertura uuid;
  v_enc      jsonb := coalesce(p_dados -> 'encarregados', '[]'::jsonb);
  v_hinos    jsonb := coalesce(p_dados -> 'hinos', '[]'::jsonb);
  v_item     jsonb;
  v_ordem    integer;
  v_n        integer;
  v_min      integer;
  v_max      integer;
  v_nomeenc  text;
  v_cidade   text;
  v_ceg      text;
  v_id       uuid;
  v_antes    jsonb;
  v_depois   jsonb;
  v_mud      jsonb;
  v_extras   jsonb;
  v_in       jsonb;
  v_c        jsonb;
  v_cid      text;
  v_val      jsonb;
  v_tp       text;
  v_nm       text;
  v_vazio    boolean;
  v_ufs      text[] := array['AC','AL','AP','AM','BA','CE','DF','ES','GO','MA','MT','MS','MG','PA','PB','PR','PE','PI','RJ','RN','RS','RO','RR','SC','SP','SE','TO'];
begin
  perform public.exigir_permissao('ensaio.registrar');
  -- Duas pessoas salvando o mesmo ensaio ao mesmo tempo: a segunda espera a primeira
  perform pg_advisory_xact_lock(hashtextextended('ensaio:' || p_evento_id::text, 0));

  select e.id, e.tipo, e.tipo_evento_id, e.local, e.data_evento, e.cancelado_em, t.modelo_ensaio
    into v_e
    from public.eventos e
    left join public.tipos_evento t on t.id = e.tipo_evento_id
   where e.id = p_evento_id and e.excluido_em is null;
  if not found then
    raise exception 'Evento não encontrado.';
  end if;
  if not public.evento_na_abrangencia(p_evento_id) then
    raise exception 'Este evento está fora da sua abrangência.' using errcode = '42501';
  end if;
  if v_e.modelo_ensaio is null then
    raise exception 'Este evento não é um ensaio Local ou Regional.';
  end if;
  if v_e.cancelado_em is not null then
    raise exception 'Este evento foi cancelado.';
  end if;

  -- Preenche-se DURANTE o ensaio (a partir de 2h antes até 3h depois do início). Só o Administrador
  -- (permissão eventos.cancelar) corrige fora dessa janela, como nos demais dados de evento encerrado.
  v_admin := public.tem_permissao('eventos.cancelar');
  if not v_admin then
    if now() < v_e.data_evento - interval '2 hours' then
      raise exception 'O ensaio ainda não começou. Os dados podem ser preenchidos a partir de 2 horas antes do horário.';
    end if;
    if public.portaria_encerrada(v_e.data_evento) then
      raise exception 'Este ensaio já foi encerrado. Só o Administrador pode alterar os dados.' using errcode = '42501';
    end if;
  end if;

  -- Campos que o perfil do tipo manda usar
  v_cfg := public.config_ensaio_do_tipo(v_e.tipo_evento_id);

  -- Quem atendeu
  if (v_cfg #>> '{quem_atendeu,ativo}')::boolean then
    if v_cargo is null or not jsonb_exists(v_cfg #> '{quem_atendeu,cargos}', v_cargo) then
      raise exception 'Escolha o cargo de quem atendeu o ensaio.';
    end if;
    if v_nome is null or char_length(v_nome) < 3 then
      raise exception 'Informe o nome de quem atendeu o ensaio.';
    end if;
    if char_length(v_nome) > 120 then
      raise exception 'O nome de quem atendeu pode ter no máximo 120 caracteres.';
    end if;
  else
    v_cargo := null;
    v_nome  := null;
  end if;

  -- Palavra exortada
  if (v_cfg #>> '{palavra,ativo}')::boolean then
    if v_palavra is null and (v_cfg #>> '{palavra,obrigatoria}')::boolean then
      raise exception 'Informe a palavra que foi exortada.';
    end if;
    if v_palavra is not null and char_length(v_palavra) > (v_cfg #>> '{palavra,limite}')::integer then
      raise exception 'A palavra pode ter no máximo % caracteres.', v_cfg #>> '{palavra,limite}';
    end if;
  else
    v_palavra := null;
  end if;

  -- Hino de abertura: obrigatório, só quando houve (pergunta) ou não usado; fica fora da lista de executados
  begin
    v_abertura := (p_dados ->> 'hino_abertura_id')::uuid;
  exception when others then
    v_abertura := null;
  end;
  if (v_cfg #>> '{hino_abertura,modo}') = 'nao_usa' then
    v_abertura := null;
  elsif v_abertura is null and (v_cfg #>> '{hino_abertura,modo}') = 'obrigatorio' then
    raise exception 'Escolha o hino de abertura.';
  end if;
  if v_abertura is not null and not exists (select 1 from public.hinos h where h.id = v_abertura) then
    raise exception 'Hino de abertura não encontrado.';
  end if;

  select * into v_d from public.dados_ensaio d where d.evento_id = p_evento_id;

  if v_abertura is not null and v_abertura is distinct from v_d.hino_abertura_id
     and exists (select 1 from public.hinos h where h.id = v_abertura and not h.ativo) then
    raise exception 'O hino de abertura escolhido está desativado.';
  end if;

  -- Encarregados: quantidade, nome, cargo e (se o perfil pedir) Cidade/UF
  if (v_cfg #>> '{encarregados,ativo}')::boolean then
    v_min := (v_cfg #>> '{encarregados,minimo}')::integer;
    v_max := (v_cfg #>> '{encarregados,maximo}')::integer;
    if jsonb_typeof(v_enc) <> 'array' then
      raise exception 'Lista de encarregados inválida.';
    end if;
    if jsonb_array_length(v_enc) < v_min then
      raise exception 'Informe pelo menos % encarregado(s).', v_min;
    end if;
    if jsonb_array_length(v_enc) > v_max then
      raise exception 'Informe no máximo % encarregado(s).', v_max;
    end if;
    for v_item in select * from jsonb_array_elements(v_enc) loop
      v_nomeenc := public.limpar_espacos(v_item ->> 'nome');
      v_cidade  := public.limpar_espacos(v_item ->> 'cidade_uf');
      v_ceg     := nullif(upper(coalesce(v_item ->> 'cargo', '')), '');
      if v_nomeenc is null or char_length(v_nomeenc) < 3 or char_length(v_nomeenc) > 120 then
        raise exception 'Informe o nome de cada encarregado (de 3 a 120 caracteres).';
      end if;
      if (v_cfg #>> '{encarregados,cidade_uf}')::boolean
         and (v_cidade is null or v_cidade !~ '^.{2,}-[A-Z]{2}$' or not (right(v_cidade, 2) = any (v_ufs))) then
        raise exception 'Informe a cidade de % no formato Cidade-UF (ex.: São Paulo-SP).', v_nomeenc;
      end if;
      if v_ceg is null then
        if jsonb_array_length(v_cfg #> '{encarregados,cargos}') = 1 then
          v_ceg := (v_cfg #>> '{encarregados,cargos,0}');
        else
          raise exception 'Escolha o cargo de % (Encarregado Regional, Encarregado Local ou Instrutor).', v_nomeenc;
        end if;
      end if;
      if not jsonb_exists(v_cfg #> '{encarregados,cargos}', v_ceg) then
        raise exception 'O cargo de % não é permitido neste tipo de ensaio.', v_nomeenc;
      end if;
    end loop;
    if (select count(distinct public.normalizar_texto(public.limpar_espacos(x ->> 'nome')))
          from jsonb_array_elements(v_enc) x) <> jsonb_array_length(v_enc) then
      raise exception 'Há encarregados com o mesmo nome.';
    end if;
  else
    v_enc := '[]'::jsonb;
  end if;

  -- Hinos executados: sem repetir, sem o hino de abertura
  if not (v_cfg #>> '{hinos_executados,ativo}')::boolean then
    v_hinos := '[]'::jsonb;
  end if;
  if jsonb_typeof(v_hinos) <> 'array' then
    raise exception 'Lista de hinos inválida.';
  end if;
  if jsonb_array_length(v_hinos) > 100 then
    raise exception 'Informe no máximo 100 hinos executados.';
  end if;
  if exists (select 1 from jsonb_array_elements_text(v_hinos) x
              where x !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$') then
    raise exception 'Lista de hinos inválida.';
  end if;
  if (select count(distinct lower(x)) from jsonb_array_elements_text(v_hinos) x) <> jsonb_array_length(v_hinos) then
    raise exception 'O mesmo hino não pode ser executado duas vezes no ensaio.';
  end if;
  if v_abertura is not null and exists (select 1 from jsonb_array_elements_text(v_hinos) x where x::uuid = v_abertura) then
    raise exception 'O hino de abertura não conta entre os hinos executados. Tire-o da lista.';
  end if;
  select count(*) into v_n from jsonb_array_elements_text(v_hinos) x join public.hinos h on h.id = x::uuid;
  if v_n <> jsonb_array_length(v_hinos) then
    raise exception 'Algum hino escolhido não foi encontrado.';
  end if;
  -- Hino desativado só pode ficar se já fazia parte deste ensaio
  if exists (select 1 from jsonb_array_elements_text(v_hinos) x join public.hinos h on h.id = x::uuid
              where not h.ativo
                and not exists (select 1 from public.dados_ensaio_hinos dh where dh.dados_ensaio_id = v_d.id and dh.hino_id = h.id)) then
    raise exception 'Algum hino escolhido está desativado.';
  end if;

  -- Campos extras do perfil: confere cada campo ligado (tipo, obrigatório, lista de opções) e guarda por id.
  -- Valores de campos desativados que já existiam ficam como estão (o histórico não se perde).
  v_extras := coalesce(v_d.extras, '{}'::jsonb);
  v_in := case when jsonb_typeof(p_dados -> 'extras') = 'object' then p_dados -> 'extras' else '{}'::jsonb end;
  for v_c in select * from jsonb_array_elements(coalesce(v_cfg -> 'campos_extras', '[]'::jsonb)) loop
    continue when not (v_c ->> 'ativo')::boolean;
    v_cid := v_c ->> 'id';
    v_tp  := v_c ->> 'tipo';
    v_nm  := v_c ->> 'nome';
    v_val := v_in -> v_cid;
    v_vazio := v_val is null or jsonb_typeof(v_val) = 'null'
               or (jsonb_typeof(v_val) = 'string' and btrim(v_val #>> '{}') = '');
    if v_vazio then
      if (v_c ->> 'obrigatorio')::boolean then
        raise exception 'Preencha o campo "%".', v_nm;
      end if;
      v_extras := v_extras - v_cid;
      continue;
    end if;
    if v_tp = 'texto_curto' then
      if jsonb_typeof(v_val) <> 'string' or char_length(btrim(v_val #>> '{}')) > 200 then
        raise exception 'O campo "%" aceita texto de até 200 caracteres.', v_nm;
      end if;
      v_extras := v_extras || jsonb_build_object(v_cid, to_jsonb(public.limpar_espacos(v_val #>> '{}')));
    elsif v_tp = 'texto_longo' then
      if jsonb_typeof(v_val) <> 'string' or char_length(btrim(v_val #>> '{}')) > 1000 then
        raise exception 'O campo "%" aceita texto de até 1000 caracteres.', v_nm;
      end if;
      v_extras := v_extras || jsonb_build_object(v_cid, to_jsonb(btrim(v_val #>> '{}')));
    elsif v_tp = 'numero' then
      if jsonb_typeof(v_val) <> 'number' then
        raise exception 'O campo "%" aceita só número.', v_nm;
      end if;
      v_extras := v_extras || jsonb_build_object(v_cid, v_val);
    elsif v_tp = 'sim_nao' then
      if jsonb_typeof(v_val) <> 'boolean' then
        raise exception 'Responda Sim ou Não no campo "%".', v_nm;
      end if;
      v_extras := v_extras || jsonb_build_object(v_cid, v_val);
    elsif v_tp = 'lista' then
      if jsonb_typeof(v_val) <> 'string' or not jsonb_exists(v_c -> 'opcoes', v_val #>> '{}') then
        raise exception 'Escolha uma das opções do campo "%".', v_nm;
      end if;
      v_extras := v_extras || jsonb_build_object(v_cid, v_val);
    end if;
  end loop;

  if v_d.id is not null then
    begin
      v_antes := public.ensaio_resumo(v_d.id);
    exception when others then
      v_antes := null;
    end;
  end if;

  if v_d.id is null then
    insert into public.dados_ensaio (evento_id, atende_cargo, atende_nome, palavra, hino_abertura_id, extras, criado_por, atualizado_por)
    values (p_evento_id, v_cargo, v_nome, v_palavra, v_abertura, v_extras, v_uid, v_uid)
    returning id into v_id;
  else
    v_id := v_d.id;
    -- Apaga os itens antes de trocar o hino de abertura (o gatilho confere abertura x executados)
    delete from public.dados_ensaio_encarregados where dados_ensaio_id = v_id;
    delete from public.dados_ensaio_hinos where dados_ensaio_id = v_id;
    update public.dados_ensaio
       set atende_cargo = v_cargo, atende_nome = v_nome, palavra = v_palavra, hino_abertura_id = v_abertura, extras = v_extras,
           atualizado_por = v_uid, atualizado_em = now()
     where id = v_id;
  end if;

  v_ordem := 0;
  for v_item in select * from jsonb_array_elements(v_enc) loop
    v_ordem := v_ordem + 1;
    v_ceg := nullif(upper(coalesce(v_item ->> 'cargo', '')), '');
    if v_ceg is null then v_ceg := (v_cfg #>> '{encarregados,cargos,0}'); end if;
    insert into public.dados_ensaio_encarregados (dados_ensaio_id, ordem, nome, cidade_uf, cargo)
    values (v_id, v_ordem, public.limpar_espacos(v_item ->> 'nome'),
            case when (v_cfg #>> '{encarregados,cidade_uf}')::boolean then public.limpar_espacos(v_item ->> 'cidade_uf') else null end,
            v_ceg);
  end loop;

  v_ordem := 0;
  for v_item in select * from jsonb_array_elements(v_hinos) loop
    v_ordem := v_ordem + 1;
    insert into public.dados_ensaio_hinos (dados_ensaio_id, hino_id, ordem)
    values (v_id, (v_item #>> '{}')::uuid, v_ordem);
  end loop;

  -- Auditoria: uma linha por gravação, com o que mudou (texto simples). Se o resumo falhar, não trava o salvamento.
  begin
    v_depois := public.ensaio_resumo(v_id);
  exception when others then
    v_depois := null;
  end;
  if v_depois is not null then
    if v_antes is null then
      perform public.registrar_auditoria('ensaio_registrado', 'ensaio', p_evento_id,
                jsonb_build_object('rotulo', v_e.tipo || ' · ' || v_e.local, 'depois', v_depois));
    else
      select coalesce(jsonb_object_agg(n.key, jsonb_build_object('de', o.value, 'para', n.value)), '{}'::jsonb)
        into v_mud
        from jsonb_each(v_depois) n
        left join jsonb_each(v_antes) o on o.key = n.key
       where n.value is distinct from o.value;
      if v_mud <> '{}'::jsonb then
        perform public.registrar_auditoria('ensaio_alterado', 'ensaio', p_evento_id,
                  jsonb_build_object('rotulo', v_e.tipo || ' · ' || v_e.local, 'mudancas', v_mud));
      end if;
    end if;
  else
    perform public.registrar_auditoria(case when v_d.id is null then 'ensaio_registrado' else 'ensaio_alterado' end,
              'ensaio', p_evento_id, jsonb_build_object('rotulo', v_e.tipo || ' · ' || v_e.local));
  end if;

  return v_id;
end;
$f$;

-- Perfil: campo extra já preenchido não pode ser excluído nem mudar de tipo
create or replace function public.salvar_perfil_evento(p_id uuid, p_dados jsonb)
returns uuid
language plpgsql security definer set search_path = public
as $f$
declare
  v_nome   text := regexp_replace(btrim(coalesce(p_dados ->> 'nome', '')), '\s+', ' ', 'g');
  v_desc   text := nullif(btrim(coalesce(p_dados ->> 'descricao', '')), '');
  v_modelo text := p_dados ->> 'modelo_base';
  v_ativo  boolean := coalesce((p_dados ->> 'ativo')::boolean, true);
  v_atual  text;
  v_cfg_ant jsonb;
  v_nova   jsonb;
  v_c      jsonb;
  v_c_novo jsonb;
  v_id     uuid := p_id;
begin
  if p_id is null then perform public.exigir_permissao('tipoevento.criar');
  else perform public.exigir_permissao('tipoevento.editar'); end if;
  if not public.tem_acesso_total_organizacao() then
    raise exception 'Só o administrador pode alterar os perfis de evento.' using errcode = '42501';
  end if;
  if char_length(v_nome) < 3 or char_length(v_nome) > 60 then
    raise exception 'O nome do perfil deve ter de 3 a 60 caracteres.';
  end if;
  if v_desc is not null and char_length(v_desc) > 200 then
    raise exception 'A descrição pode ter no máximo 200 caracteres.';
  end if;
  if v_modelo is null or v_modelo not in ('LOCAL', 'REGIONAL') then
    raise exception 'Escolha o modelo do perfil (Local ou Regional).';
  end if;
  if exists (select 1 from public.perfis_evento p where lower(btrim(p.nome)) = lower(v_nome) and p.id is distinct from p_id) then
    raise exception 'Já existe um perfil com este nome.';
  end if;

  if p_id is null then
    insert into public.perfis_evento (nome, descricao, modelo_base, ativo, ordem, config)
    values (v_nome, v_desc, v_modelo, v_ativo, coalesce((select max(ordem) from public.perfis_evento), 0) + 1,
            public.normalizar_config_perfil(p_dados -> 'config', v_modelo))
    returning id into v_id;
    perform public.registrar_auditoria('perfil_evento_criado', 'perfil_evento', v_id, jsonb_build_object('nome', v_nome));
  else
    select modelo_base, public.normalizar_config_perfil(config, modelo_base) into v_atual, v_cfg_ant from public.perfis_evento where id = p_id;
    if not found then raise exception 'Perfil não encontrado.'; end if;
    -- O modelo vale para os tipos já ligados (quem pode encerrar etc.): não muda enquanto o perfil estiver em uso
    if v_atual is distinct from v_modelo and exists (select 1 from public.tipos_evento t where t.perfil_id = p_id) then
      raise exception 'Este perfil está em uso por tipos de evento: não dá para trocar o modelo (Local/Regional).';
    end if;
    -- Campo extra que já foi preenchido em algum ensaio não pode ser excluído nem mudar de tipo (só desativar)
    if jsonb_exists(p_dados, 'config') then
      v_nova := public.normalizar_config_perfil(p_dados -> 'config', v_modelo);
      for v_c in select * from jsonb_array_elements(coalesce(v_cfg_ant -> 'campos_extras', '[]'::jsonb)) loop
        select x into v_c_novo from jsonb_array_elements(coalesce(v_nova -> 'campos_extras', '[]'::jsonb)) x where x ->> 'id' = v_c ->> 'id';
        if (v_c_novo is null or v_c_novo ->> 'tipo' <> v_c ->> 'tipo')
           and exists (select 1 from public.dados_ensaio d
                         join public.eventos e on e.id = d.evento_id
                         join public.tipos_evento t on t.id = e.tipo_evento_id
                        where t.perfil_id = p_id and jsonb_exists(d.extras, v_c ->> 'id')) then
          raise exception 'O campo extra "%" já foi preenchido em ensaios: desative-o em vez de excluir ou mudar o tipo.', v_c ->> 'nome';
        end if;
      end loop;
    end if;
    update public.perfis_evento
       set nome = v_nome, descricao = v_desc, modelo_base = v_modelo, ativo = v_ativo, atualizado_em = now(),
           config = case when jsonb_exists(p_dados, 'config') then public.normalizar_config_perfil(p_dados -> 'config', v_modelo) else config end
     where id = p_id;
    perform public.registrar_auditoria('perfil_evento_alterado', 'perfil_evento', p_id, jsonb_build_object('nome', v_nome));
  end if;
  return v_id;
end
$f$;

-- Conferência (se falhar, nada é aplicado)
do $$
begin
  if jsonb_array_length(public.normalizar_campos_extras('[{"id":"a1","nome":"Obs","tipo":"texto_longo"},{"id":"a1","nome":"Repetido","tipo":"numero"},{"id":"b2","nome":"Lista","tipo":"lista","opcoes":["x"]}]'::jsonb)) <> 1 then
    raise exception '0081: normalização dos campos extras não funcionou.';
  end if;
  if (public.normalizar_config_perfil('{"campos_extras":[{"id":"c1","nome":"Obs","tipo":"sim_nao"}]}'::jsonb, 'LOCAL') #>> '{campos_extras,0,tipo}') <> 'sim_nao' then
    raise exception '0081: o perfil não guardou os campos extras.';
  end if;
end $$;
