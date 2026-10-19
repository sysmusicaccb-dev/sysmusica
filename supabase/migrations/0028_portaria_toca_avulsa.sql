-- =====================================================================
-- SysMúsica — Migração 0028: Portaria com "Vai tocar?" e entrada SEM cadastro
--
--   A) PRESENÇA com a escolha da Portaria: registrar_entrada passa a receber p_toca (vai tocar?) e
--      p_instrumento_id. O banco confere: cargos que perguntam (Cooperadores, Encarregados, Instrutor,
--      Candidato) EXIGEM a resposta; quem vai tocar precisa de instrumento. Grava toca, instrumento_id e a
--      linha do painel NO MOMENTO da entrada (mudar a categoria depois não altera o histórico).
--   B) ENTRADA SEM CADASTRO (candidato, visitante...): tabela presencas_avulsas. Não cria membro.
--      Guarda só a linha do painel (cargo/categoria), se toca, o instrumento e a localidade de origem
--      (uma casa de oração da lista OU um texto livre; opcional). Respeita a janela da portaria (2h antes a
--      3h depois; controle total fora da janela, com auditoria) e a abrangência de quem atende.
--   C) FUNÇÕES: info_entrada (a pessoa precisa responder "Vai tocar?"), opcoes_entrada (linhas e instrumentos),
--      buscar_localidades (busca pelas primeiras letras), registrar/desfazer/listar entradas sem cadastro.
--   D) painel_ao_vivo passa a somar as entradas sem cadastro (sem duplicar ninguém).
--
-- Requer as migrações 0024, 0026 e 0027. Idempotente, uma única transação.
-- =====================================================================
begin;

do $$
begin
  if to_regclass('public.linhas_painel') is null
     or to_regprocedure('public.classificar_linha(text,text,text)') is null
     or to_regprocedure('public.instrumento_e_orgao(text)') is null
     or to_regprocedure('public.exigir_acesso_atendimento(uuid)') is null
     or to_regprocedure('public.portaria_janela_aberta(timestamptz,timestamptz)') is null
     or (to_regprocedure('public.registrar_entrada(uuid,uuid,text)') is null
         and to_regprocedure('public.registrar_entrada(uuid,uuid,text,boolean,uuid)') is null)
     or to_regprocedure('public.registrar_auditoria(text,text,uuid,jsonb)') is null then
    raise exception 'Aplique primeiro as migrações 0024, 0026 e 0027.';
  end if;
end $$;

-- B) TABELA das entradas sem cadastro (só as funções abaixo mexem nela; ninguém lê direto)
create table if not exists public.presencas_avulsas (
  id              uuid primary key default gen_random_uuid(),
  portaria_id     uuid not null references public.portarias (id),
  evento_id       uuid not null references public.eventos (id),
  linha_codigo    text not null references public.linhas_painel (codigo),
  toca            boolean,
  instrumento_id  uuid references public.instrumentos (id),
  origem_comum_id uuid references public.comuns (id),
  origem_texto    text check (origem_texto is null or char_length(origem_texto) between 2 and 120),
  hora_entrada    timestamptz not null default now(),
  registrado_por  uuid,
  excluido_em     timestamptz,
  excluido_por    uuid,
  check (origem_comum_id is null or origem_texto is null)
);
create index if not exists presencas_avulsas_portaria_idx on public.presencas_avulsas (portaria_id) where excluido_em is null;
create index if not exists presencas_avulsas_evento_idx on public.presencas_avulsas (evento_id) where excluido_em is null;
alter table public.presencas_avulsas enable row level security;
revoke all on public.presencas_avulsas from public, anon, authenticated;

-- A) registrar_entrada com "Vai tocar?" (a assinatura antiga é substituída)
drop function if exists public.registrar_entrada(uuid, uuid, text);
create or replace function public.registrar_entrada(
  p_portaria_id uuid, p_membro_id uuid, p_origem text default 'MANUAL',
  p_toca boolean default null, p_instrumento_id uuid default null
)
returns public.presencas
language plpgsql security definer set search_path = public as $$
declare
  v_evento   uuid;
  v_presenca public.presencas;
  v_m        record;
  v_ef_inst  uuid;
  v_ef_nome  text;
  v_linha    public.linhas_painel;
  v_toca     boolean;
  v_gravar   uuid;
begin
  if p_origem not in ('MANUAL', 'QR') then
    raise exception 'Origem de registro inválida.';
  end if;
  select p.evento_id into v_evento from public.portarias p where p.id = p_portaria_id and p.excluido_em is null;
  if not found then
    raise exception 'Portaria não encontrada.';
  end if;

  select cg.nome as cargo, m.categoria, m.instrumento_id into v_m
    from public.membros m left join public.cargos cg on cg.id = m.cargo_id
   where m.id = p_membro_id and m.excluido_em is null;
  if not found then
    raise exception 'Cadastro do membro não encontrado.';
  end if;

  if p_instrumento_id is not null and not exists (select 1 from public.instrumentos i where i.id = p_instrumento_id) then
    raise exception 'Instrumento inválido.';
  end if;

  -- Instrumento efetivo: o escolhido na entrada ou, se não houver, o do cadastro
  v_ef_inst := coalesce(p_instrumento_id, v_m.instrumento_id);
  select i.nome into v_ef_nome from public.instrumentos i where i.id = v_ef_inst;
  select * into v_linha from public.linhas_painel l
   where l.codigo = public.classificar_linha(v_m.cargo, v_m.categoria, v_ef_nome);

  if v_linha.pergunta_toca then
    if p_toca is null then
      raise exception 'Informe se a pessoa vai tocar.';
    end if;
    v_toca := p_toca;
    if v_toca and v_ef_inst is null then
      raise exception 'Informe o instrumento que a pessoa vai tocar.';
    end if;
    v_gravar := case when v_toca then p_instrumento_id else null end;
  else
    v_toca := null;               -- sem pergunta: vale a regra da linha (Músico conta sempre; Ancião/Diácono não)
    v_gravar := p_instrumento_id;
  end if;

  perform set_config('sysmusica.origem', p_origem, true);
  insert into public.presencas (membro_id, evento_id, status, portaria_id, toca, instrumento_id, linha_codigo)
  values (p_membro_id, v_evento, 'Presente', p_portaria_id, v_toca, v_gravar, v_linha.codigo)
  returning * into v_presenca;
  return v_presenca;
end;
$$;

-- C) A pessoa precisa responder "Vai tocar?"  (usada na conferência, depois do QR ou da busca pelo nome)
create or replace function public.info_entrada(p_portaria_id uuid, p_membro_id uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare
  v record;
  l public.linhas_painel;
begin
  perform public.exigir_acesso_atendimento(p_portaria_id);
  select cg.nome as cargo, m.categoria, m.instrumento_id, i.nome as instrumento into v
    from public.membros m
    left join public.cargos cg on cg.id = m.cargo_id
    left join public.instrumentos i on i.id = m.instrumento_id
   where m.id = p_membro_id and m.excluido_em is null;
  if not found then
    raise exception 'Cadastro do membro não encontrado.';
  end if;
  select * into l from public.linhas_painel x where x.codigo = public.classificar_linha(v.cargo, v.categoria, v.instrumento);
  return jsonb_build_object(
    'linha_codigo', l.codigo, 'linha_rotulo', l.rotulo, 'bloco', l.bloco,
    'pergunta_toca', l.pergunta_toca,
    'instrumento_id', v.instrumento_id, 'instrumento', v.instrumento);
end;
$$;

-- C) Linhas e instrumentos para a entrada (órgão fica de fora: o órgão é contado em Organistas)
create or replace function public.opcoes_entrada()
returns jsonb language plpgsql stable security definer set search_path = public as $$
begin
  perform public.exigir_permissao('portaria.registrar');
  return jsonb_build_object(
    'linhas', coalesce((select jsonb_agg(jsonb_build_object(
                'codigo', l.codigo, 'bloco', l.bloco, 'rotulo', l.rotulo,
                'pergunta_toca', l.pergunta_toca, 'toca_sempre', l.toca_sempre, 'instrumento', l.instrumento)
                order by l.ordem)
              from public.linhas_painel l where l.selecionavel), '[]'::jsonb),
    'instrumentos', coalesce((select jsonb_agg(jsonb_build_object(
                'id', i.id, 'nome', i.nome, 'familia', coalesce(f.nome, 'Outros'))
                order by coalesce(f.nome, 'Outros'), i.nome)
              from public.instrumentos i left join public.familias f on f.id = i.familia_id
             where not public.instrumento_e_orgao(i.nome)), '[]'::jsonb));
end;
$$;

-- C) Busca de localidade pelas primeiras letras (do nome ou de qualquer palavra dele), até 15 resultados
create or replace function public.buscar_localidades(p_termo text)
returns table (comum_id uuid, nome text, caminho text)
language plpgsql stable security definer set search_path = public as $$
declare
  v_t text := regexp_replace(public.normalizar_texto(coalesce(p_termo, '')), '[%_\\]', '', 'g');
begin
  perform public.exigir_permissao('portaria.registrar');
  if char_length(v_t) < 2 then
    return;
  end if;
  return query
    select c.id, c.nome, concat_ws(' › ', e.nome, r.nome, s.nome)
      from public.comuns c
      join public.setores s on s.id = c.setor_id
      join public.regioes r on r.id = s.regiao_id
      join public.estados e on e.id = r.estado_id
     where c.ativo and s.ativo and r.ativo and e.ativo
       and (public.normalizar_texto(c.nome) like v_t || '%' or public.normalizar_texto(c.nome) like '% ' || v_t || '%')
     order by (public.normalizar_texto(c.nome) like v_t || '%') desc, c.nome
     limit 15;
end;
$$;

-- B) Registrar entrada SEM cadastro
create or replace function public.registrar_entrada_avulsa(
  p_portaria_id uuid, p_linha_codigo text, p_toca boolean default null, p_instrumento_id uuid default null,
  p_origem_comum_id uuid default null, p_origem_texto text default null
)
returns uuid language plpgsql security definer set search_path = public as $$
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
  if p_origem_comum_id is not null then
    if not exists (select 1 from public.comuns c where c.id = p_origem_comum_id and c.ativo) then
      raise exception 'Localidade de origem inválida.';
    end if;
    v_texto := null;
  elsif v_texto is not null and (char_length(v_texto) < 2 or char_length(v_texto) > 120) then
    raise exception 'A localidade deve ter de 2 a 120 caracteres.';
  end if;

  insert into public.presencas_avulsas
    (portaria_id, evento_id, linha_codigo, toca, instrumento_id, origem_comum_id, origem_texto, registrado_por)
  values (p_portaria_id, v_p.evento_id, l.codigo, v_toca, v_inst, p_origem_comum_id, v_texto, (select auth.uid()))
  returning id into v_id;

  perform public.registrar_auditoria('entrada_avulsa_registrada', 'portaria', p_portaria_id,
    jsonb_build_object('linha', l.rotulo, 'toca', v_toca, 'localidade',
      coalesce((select c.nome from public.comuns c where c.id = p_origem_comum_id), v_texto)));
  return v_id;
end;
$$;

-- B) Desfazer uma entrada sem cadastro (quem registrou, ou quem pode excluir registros)
create or replace function public.desfazer_entrada_avulsa(p_id uuid)
returns void language plpgsql security definer set search_path = public as $$
declare
  v record;
begin
  select a.portaria_id, a.registrado_por, l.rotulo into v
    from public.presencas_avulsas a join public.linhas_painel l on l.codigo = a.linha_codigo
   where a.id = p_id and a.excluido_em is null;
  if not found then
    raise exception 'Registro não encontrado.';
  end if;
  perform public.exigir_acesso_atendimento(v.portaria_id);
  if v.registrado_por is distinct from (select auth.uid()) and not public.tem_permissao('portaria.excluir') then
    raise exception 'Só quem registrou a entrada (ou quem pode excluir registros) pode desfazê-la.' using errcode = '42501';
  end if;
  update public.presencas_avulsas set excluido_em = now(), excluido_por = (select auth.uid()) where id = p_id;
  perform public.registrar_auditoria('entrada_avulsa_desfeita', 'portaria', v.portaria_id,
    jsonb_build_object('linha', v.rotulo));
end;
$$;

-- B) Últimas entradas sem cadastro da portaria (e o total)
create or replace function public.entradas_avulsas_da_portaria(p_portaria_id uuid)
returns table (id uuid, linha_rotulo text, bloco text, toca boolean, instrumento text, origem text,
               hora_entrada timestamptz, total bigint)
language plpgsql stable security definer set search_path = public as $$
begin
  perform public.exigir_acesso_atendimento(p_portaria_id);
  return query
    select a.id, l.rotulo, l.bloco, a.toca, i.nome,
           coalesce(c.nome, a.origem_texto), a.hora_entrada, count(*) over ()
      from public.presencas_avulsas a
      join public.linhas_painel l on l.codigo = a.linha_codigo
      left join public.instrumentos i on i.id = a.instrumento_id
      left join public.comuns c on c.id = a.origem_comum_id
     where a.portaria_id = p_portaria_id and a.excluido_em is null
     order by a.hora_entrada desc
     limit 20;
end;
$$;

-- Contagens ao vivo de um evento (só números, nenhuma linha de presença sai do banco). Agora soma também as entradas sem cadastro.
create or replace function public.painel_ao_vivo(p_evento_id uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare
  v_evento jsonb;
  v_dados  jsonb;
begin
  perform public.exigir_permissao('painel.visualizar');
  if not public.evento_na_abrangencia(p_evento_id) then
    raise exception 'Evento indisponível para você.' using errcode = '42501';
  end if;

  select jsonb_build_object('id', e.id, 'tipo', e.tipo, 'local', e.local, 'data_evento', e.data_evento,
                            'cidade', e.cidade, 'comum', c.nome)
    into v_evento
    from public.eventos e
    left join public.comuns c on c.id = e.comum_id
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
$$;


-- Permissões de execução
revoke all on function
  public.registrar_entrada(uuid, uuid, text, boolean, uuid), public.info_entrada(uuid, uuid), public.opcoes_entrada(),
  public.buscar_localidades(text), public.registrar_entrada_avulsa(uuid, text, boolean, uuid, uuid, text),
  public.desfazer_entrada_avulsa(uuid), public.entradas_avulsas_da_portaria(uuid), public.painel_ao_vivo(uuid)
  from public, anon;
grant execute on function
  public.registrar_entrada(uuid, uuid, text, boolean, uuid), public.info_entrada(uuid, uuid), public.opcoes_entrada(),
  public.buscar_localidades(text), public.registrar_entrada_avulsa(uuid, text, boolean, uuid, uuid, text),
  public.desfazer_entrada_avulsa(uuid), public.entradas_avulsas_da_portaria(uuid), public.painel_ao_vivo(uuid)
  to authenticated;

-- VERIFICAÇÃO: tudo precisa existir. Se falhar, a migração INTEIRA é desfeita.
do $$
begin
  if to_regclass('public.presencas_avulsas') is null
     or to_regprocedure('public.registrar_entrada(uuid,uuid,text,boolean,uuid)') is null
     or to_regprocedure('public.registrar_entrada(uuid,uuid,text)') is not null
     or to_regprocedure('public.registrar_entrada_avulsa(uuid,text,boolean,uuid,uuid,text)') is null
     or to_regprocedure('public.info_entrada(uuid,uuid)') is null
     or to_regprocedure('public.opcoes_entrada()') is null
     or to_regprocedure('public.buscar_localidades(text)') is null then
    raise exception 'Teste falhou: objetos da migração 0028 ausentes ou assinatura antiga ainda existe.';
  end if;
end $$;

commit;
