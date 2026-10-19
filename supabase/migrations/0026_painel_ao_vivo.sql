-- =====================================================================
-- SysMúsica — Migração 0026: Painel ao vivo + Categoria do membro + cargos
--
--   A) PERMISSÃO "painel.visualizar" (Painel ao vivo). O Administrador recebe; os demais grupos
--      são marcados em Administração > Grupos e permissões.
--   B) CATEGORIA do membro (Oficializado, Culto Oficial ou RJM), usada nas linhas de Músicos e Organistas.
--   C) CARGOS: novo cargo "Candidato (a)"; os Cooperadores passam a poder informar instrumento;
--      "Cooperador de Jovens e Menores" passa a se chamar "Cooperador da Reunião de Jovens e Menores".
--   D) LINHAS DO PAINEL (tabela linhas_painel): a regra de contagem fica em UM lugar só do banco.
--      Cada linha pertence a um bloco: Ministério, Músicos ou Organistas.
--   E) PRESENÇAS ganham três colunas (toca, instrumento_id, linha_codigo), preenchidas pela Portaria
--      numa etapa seguinte. Enquanto vazias, a contagem usa o cadastro atual do membro.
--   F) FUNÇÕES: classificar_linha (cargo + categoria + instrumento -> linha), painel_ao_vivo (contagens de
--      um evento, sem devolver linhas de presença) e eventos_do_painel (eventos para escolher).
--      Tudo respeita a abrangência (região e setor) de quem consulta.
--
-- Cada presença conta UMA vez só, em uma única linha. O bloco Instrumentos é só um recorte de quem toca
-- e não soma ao total. O órgão conta apenas em Organistas.
-- Requer as migrações 0012 e 0025. Idempotente, uma única transação.
-- Ao final, a migração TESTA a classificação: se algo falhar, tudo é desfeito.
-- =====================================================================
begin;

do $$
begin
  if to_regprocedure('public.evento_na_abrangencia(uuid)') is null
     or to_regprocedure('public.normalizar_texto(text)') is null
     or to_regprocedure('public.exigir_permissao(text)') is null
     or to_regclass('public.presencas') is null
     or to_regclass('public.permissoes') is null then
    raise exception 'Aplique primeiro as migrações até a 0025.';
  end if;
end $$;

-- A) PERMISSÃO (igual a CATALOGO_PERMISSOES em src/lib/permissoes.ts); só o Administrador recebe
insert into public.permissoes (codigo, modulo, acao, descricao) values
  ('painel.visualizar', 'Painel ao vivo', 'Visualizar',
   'Acompanhar ao vivo as contagens de presença de um evento (ministério, músicos, organistas e instrumentos)')
on conflict (codigo) do update
  set modulo = excluded.modulo, acao = excluded.acao, descricao = excluded.descricao;

insert into public.grupo_permissoes (grupo_id, permissao_codigo)
select g.id, p.codigo
from public.grupos g cross join public.permissoes p
where g.sistema and g.nome = 'Administrador'
on conflict do nothing;

-- B) CATEGORIA DO MEMBRO
alter table public.membros add column if not exists categoria text;
alter table public.membros drop constraint if exists membros_categoria_check;
alter table public.membros add constraint membros_categoria_check
  check (categoria is null or categoria in ('OFICIALIZADO', 'CULTO_OFICIAL', 'RJM'));
-- O acesso às colunas de "membros" é liberado coluna por coluna (o qr_secret e o CPF ficam protegidos)
grant select (categoria), insert (categoria), update (categoria) on public.membros to authenticated;

-- C) CARGOS
update public.cargos set permite_instrumento = true
 where public.normalizar_texto(nome) like 'cooperador%' and not permite_instrumento;

update public.cargos set nome = 'Cooperador da Reunião de Jovens e Menores'
 where public.normalizar_texto(nome) = 'cooperador de jovens e menores'
   and not exists (select 1 from public.cargos c2
                    where public.normalizar_texto(c2.nome) = 'cooperador da reuniao de jovens e menores');

insert into public.cargos (nome, permite_instrumento, exige_instrumento)
select 'Candidato (a)', true, false
 where not exists (select 1 from public.cargos c where public.normalizar_texto(c.nome) like 'candidat%');

-- D) LINHAS DO PAINEL
--   pergunta_toca : a Portaria pergunta "Vai tocar?"
--   toca_sempre   : conta o instrumento sem perguntar (Músico, Secretário da Música)
--   instrumento   : NENHUM (não usa), ORGAO (órgão implícito, sem escolher) ou LIVRE (escolhe o instrumento)
--   selecionavel  : pode ser escolhida na entrada sem cadastro (as linhas "Sem categoria" e "Outros" só aparecem se houver gente)
create table if not exists public.linhas_painel (
  codigo        text primary key,
  bloco         text    not null check (bloco in ('MINISTERIO', 'MUSICOS', 'ORGANISTAS')),
  rotulo        text    not null,
  ordem         integer not null,
  pergunta_toca boolean not null default false,
  toca_sempre   boolean not null default false,
  instrumento   text    not null default 'NENHUM' check (instrumento in ('NENHUM', 'ORGAO', 'LIVRE')),
  selecionavel  boolean not null default true
);
alter table public.linhas_painel enable row level security;
revoke all on public.linhas_painel from public, anon, authenticated;

insert into public.linhas_painel (codigo, bloco, rotulo, ordem, pergunta_toca, toca_sempre, instrumento, selecionavel) values
  ('MIN_ANCIAO',        'MINISTERIO', 'Ancião',                 10, false, false, 'NENHUM', true),
  ('MIN_DIACONO',       'MINISTERIO', 'Diácono',                20, false, false, 'NENHUM', true),
  ('MIN_COOP_OFICIO',   'MINISTERIO', 'Cooperador do Ofício',   30, true,  false, 'LIVRE',  true),
  ('MIN_COOP_RJM',      'MINISTERIO', 'Cooperador RJM',         40, true,  false, 'LIVRE',  true),
  ('OUT_OUTROS',        'MINISTERIO', 'Outros cargos',          50, false, false, 'NENHUM', false),
  ('MUS_ENC_REGIONAL',  'MUSICOS',    'Encarregado Regional',  110, true,  false, 'LIVRE',  true),
  ('MUS_ENC_LOCAL',     'MUSICOS',    'Encarregado Local',     120, true,  false, 'LIVRE',  true),
  ('MUS_INSTRUTOR',     'MUSICOS',    'Instrutor',             130, true,  false, 'LIVRE',  true),
  ('MUS_SECRETARIO',    'MUSICOS',    'Secretário da Música',  140, false, true,  'LIVRE',  true),
  ('MUS_OFICIALIZADO',  'MUSICOS',    'Oficializado',          150, false, true,  'LIVRE',  true),
  ('MUS_CULTO_OFICIAL', 'MUSICOS',    'Culto Oficial',         160, false, true,  'LIVRE',  true),
  ('MUS_RJM',           'MUSICOS',    'RJM',                   170, false, true,  'LIVRE',  true),
  ('MUS_CANDIDATO',     'MUSICOS',    'Candidato',             180, true,  false, 'LIVRE',  true),
  ('MUS_SEM_CATEGORIA', 'MUSICOS',    'Sem categoria',         190, false, true,  'LIVRE',  false),
  ('ORG_EXAMINADORA',   'ORGANISTAS', 'Examinadora',           210, false, false, 'ORGAO',  true),
  ('ORG_INSTRUTORA',    'ORGANISTAS', 'Instrutora',            220, false, false, 'ORGAO',  true),
  ('ORG_OFICIALIZADA',  'ORGANISTAS', 'Oficializada',          230, false, false, 'ORGAO',  true),
  ('ORG_CULTO_OFICIAL', 'ORGANISTAS', 'Culto Oficial',         240, false, false, 'ORGAO',  true),
  ('ORG_RJM',           'ORGANISTAS', 'RJM',                   250, false, false, 'ORGAO',  true),
  ('ORG_CANDIDATA',     'ORGANISTAS', 'Candidata',             260, false, false, 'ORGAO',  true),
  ('ORG_SEM_CATEGORIA', 'ORGANISTAS', 'Sem categoria',         290, false, false, 'ORGAO',  false)
on conflict (codigo) do update
  set bloco = excluded.bloco, rotulo = excluded.rotulo, ordem = excluded.ordem,
      pergunta_toca = excluded.pergunta_toca, toca_sempre = excluded.toca_sempre,
      instrumento = excluded.instrumento, selecionavel = excluded.selecionavel;

-- E) PRESENÇAS: como a pessoa foi contada (preenchido pela Portaria; vazio = vale o cadastro do membro)
alter table public.presencas add column if not exists toca boolean;
alter table public.presencas add column if not exists instrumento_id uuid references public.instrumentos (id);
alter table public.presencas add column if not exists linha_codigo text references public.linhas_painel (codigo);

-- F) FUNÇÕES
-- O instrumento é órgão? (o órgão eletrônico conta em Organistas, nunca em Instrumentos)
create or replace function public.instrumento_e_orgao(p_nome text)
returns boolean language sql immutable set search_path = public as $$
  select coalesce(public.normalizar_texto(p_nome) like '%orgao%', false)
$$;

-- Cargo + categoria + instrumento -> linha do painel (a mesma pessoa cai sempre em UMA linha)
create or replace function public.classificar_linha(p_cargo text, p_categoria text, p_instrumento text)
returns text language sql immutable set search_path = public as $$
  select case
    when t.c like 'anciao%' then 'MIN_ANCIAO'
    when t.c like 'diacono%' then 'MIN_DIACONO'
    when t.c like 'cooperador%' and (t.c like '%jovens%' or t.c like '%rjm%') then 'MIN_COOP_RJM'
    when t.c like 'cooperador%' then 'MIN_COOP_OFICIO'
    when t.c like 'encarregado regional%' then 'MUS_ENC_REGIONAL'
    when t.c like 'encarregado local%' then 'MUS_ENC_LOCAL'
    when t.c like 'examinadora%' then 'ORG_EXAMINADORA'
    when t.c like 'instrutor%' then
      case when public.instrumento_e_orgao(p_instrumento) then 'ORG_INSTRUTORA' else 'MUS_INSTRUTOR' end
    when t.c like 'secretario%' then 'MUS_SECRETARIO'
    when t.c like 'candidat%' then
      case when public.instrumento_e_orgao(p_instrumento) then 'ORG_CANDIDATA' else 'MUS_CANDIDATO' end
    when t.c like 'organista%' then
      case p_categoria when 'OFICIALIZADO' then 'ORG_OFICIALIZADA' when 'CULTO_OFICIAL' then 'ORG_CULTO_OFICIAL'
                       when 'RJM' then 'ORG_RJM' else 'ORG_SEM_CATEGORIA' end
    when t.c like 'musico%' then
      case p_categoria when 'OFICIALIZADO' then 'MUS_OFICIALIZADO' when 'CULTO_OFICIAL' then 'MUS_CULTO_OFICIAL'
                       when 'RJM' then 'MUS_RJM' else 'MUS_SEM_CATEGORIA' end
    else 'OUT_OUTROS'
  end
  from (select public.normalizar_texto(p_cargo) as c) t
$$;

-- Eventos para escolher no painel: de 30 dias atrás a 30 dias à frente, do mais próximo de agora para o mais distante
create or replace function public.eventos_do_painel()
returns table (id uuid, tipo text, local_evento text, data_evento timestamptz, cidade text, comum_nome text)
language plpgsql stable security definer set search_path = public as $$
begin
  perform public.exigir_permissao('painel.visualizar');
  return query
    select e.id, e.tipo, e.local, e.data_evento, e.cidade, c.nome
      from public.eventos e
      left join public.comuns c on c.id = e.comum_id
     where e.excluido_em is null
       and public.evento_na_abrangencia(e.id)
       and e.data_evento between now() - interval '30 days' and now() + interval '30 days'
     order by abs(extract(epoch from (e.data_evento - now())))
     limit 40;
end;
$$;

-- Contagens ao vivo de um evento (só números, nenhuma linha de presença sai do banco)
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
    select pr.toca, pr.linha_codigo, m.categoria, cg.nome as cargo,
           coalesce(pr.instrumento_id, m.instrumento_id) as instrumento_efetivo
      from public.presencas pr
      join public.membros m on m.id = pr.membro_id
      left join public.cargos cg on cg.id = m.cargo_id
     where pr.evento_id = p_evento_id and pr.excluido_em is null and pr.status = 'Presente'
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

-- Permissões de execução (as funções auxiliares só são usadas por dentro das outras)
revoke all on function public.instrumento_e_orgao(text), public.classificar_linha(text, text, text)
  from public, anon, authenticated;
revoke all on function public.eventos_do_painel(), public.painel_ao_vivo(uuid) from public, anon;
grant execute on function public.eventos_do_painel(), public.painel_ao_vivo(uuid) to authenticated;

-- VERIFICAÇÃO: a classificação precisa dar a linha esperada e toda linha precisa existir.
-- Se falhar, a migração INTEIRA é desfeita.
do $$
declare
  t record;
  v text;
begin
  for t in
    select * from (values
      ('Ancião', null, null, 'MIN_ANCIAO'),
      ('Diácono', null, null, 'MIN_DIACONO'),
      ('Cooperador do Ofício Ministerial', null, null, 'MIN_COOP_OFICIO'),
      ('Cooperador de Jovens e Menores', null, null, 'MIN_COOP_RJM'),
      ('Cooperador da Reunião de Jovens e Menores', null, null, 'MIN_COOP_RJM'),
      ('Encarregado Regional', null, null, 'MUS_ENC_REGIONAL'),
      ('Encarregado Local', null, null, 'MUS_ENC_LOCAL'),
      ('Instrutor (a)', null, 'Saxofone Alto', 'MUS_INSTRUTOR'),
      ('Instrutor (a)', null, 'Orgão Eletrônico', 'ORG_INSTRUTORA'),
      ('Secretário da Música', null, 'Trompete', 'MUS_SECRETARIO'),
      ('Músico', 'OFICIALIZADO', 'Trompete', 'MUS_OFICIALIZADO'),
      ('Músico', 'CULTO_OFICIAL', 'Acordeon', 'MUS_CULTO_OFICIAL'),
      ('Músico', 'RJM', 'Clarinete', 'MUS_RJM'),
      ('Músico', null, 'Clarinete', 'MUS_SEM_CATEGORIA'),
      ('Organista', 'OFICIALIZADO', 'Orgão Eletrônico', 'ORG_OFICIALIZADA'),
      ('Organista', 'CULTO_OFICIAL', null, 'ORG_CULTO_OFICIAL'),
      ('Organista', 'RJM', null, 'ORG_RJM'),
      ('Organista', null, null, 'ORG_SEM_CATEGORIA'),
      ('Examinadora', null, null, 'ORG_EXAMINADORA'),
      ('Candidato (a)', null, 'Clarinete', 'MUS_CANDIDATO'),
      ('Candidato (a)', null, 'Orgão Eletrônico', 'ORG_CANDIDATA'),
      ('Sacristão', null, null, 'OUT_OUTROS')
    ) as x(cargo, categoria, instrumento, esperado)
  loop
    v := public.classificar_linha(t.cargo, t.categoria, t.instrumento);
    if v is distinct from t.esperado then
      raise exception 'Teste falhou: % (%, %) deu % e o esperado era %', t.cargo, t.categoria, t.instrumento, v, t.esperado;
    end if;
    if not exists (select 1 from public.linhas_painel l where l.codigo = v) then
      raise exception 'Teste falhou: a linha % não existe em linhas_painel.', v;
    end if;
  end loop;

  if not public.instrumento_e_orgao('Orgão Eletrônico') or public.instrumento_e_orgao('Acordeon') then
    raise exception 'Teste falhou: reconhecimento do órgão.';
  end if;

  if not exists (select 1 from public.permissoes where codigo = 'painel.visualizar') then
    raise exception 'Teste falhou: a permissão painel.visualizar não foi criada.';
  end if;
  if to_regprocedure('public.painel_ao_vivo(uuid)') is null or to_regprocedure('public.eventos_do_painel()') is null then
    raise exception 'Teste falhou: funções do painel ausentes.';
  end if;
end $$;

commit;
