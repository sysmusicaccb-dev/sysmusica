cd /workspaces/sysmusica/sysmusica || { echo "Pasta do projeto não encontrada"; exit 1; }
(
set -u
BKP="/tmp/bkp-painel-ao-vivo-$(date +%H%M%S)"; mkdir -p "$BKP/a"
ALT=("src/lib/permissoes.ts" "src/components/layout/navegacao.ts" "src/types/database.ts" "src/modules/membros/services/membros.ts" "src/components/FormularioMembro.tsx")
NOV=("supabase/migrations/0026_painel_ao_vivo.sql" "src/modules/painel/tipos.ts" "src/modules/painel/regras.ts" "src/modules/painel/regras.test.ts" "src/modules/painel/services/painel.ts" "src/modules/painel/components/PainelAoVivo.tsx" "src/modules/painel/components/ResumoTempoReal.tsx" "src/app/(painel)/painel-ao-vivo/layout.tsx" "src/app/(painel)/painel-ao-vivo/page.tsx")
for f in "${ALT[@]}"; do mkdir -p "$BKP/a/$(dirname "$f")"; cp "$f" "$BKP/a/$f"; done

reverter() {
  echo ">>> REVERTENDO tudo (nada do que foi tentado fica no projeto)"
  for f in "${ALT[@]}"; do cp "$BKP/a/$f" "$f"; done
  for f in "${NOV[@]}"; do rm -f "$f"; done
  rmdir "src/app/(painel)/painel-ao-vivo" "src/app/(painel)" src/modules/painel/components src/modules/painel/services src/modules/painel 2>/dev/null
  echo ">>> REVERTIDO. Me mande o log: /tmp/painel-ao-vivo-instalar.log"
}

echo "=== 0) Conferência prévia (só leitura) ==="
for f in "${ALT[@]}"; do [ -f "$f" ] || { echo "ERRO: arquivo esperado não existe: $f"; exit 1; }; done
[ -e src/modules/painel ] && { echo "ERRO: o painel já parece instalado."; exit 1; }
[ -d supabase/migrations ] || { echo "ERRO: pasta supabase/migrations não existe"; exit 1; }
ls supabase/migrations | tail -3

echo; echo "=== 1) Gravando os arquivos ==="
python3 - <<'PYSCRIPT'
import os, sys
NOVOS = {
  'supabase/migrations/0026_painel_ao_vivo.sql': r"""-- =====================================================================
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
""",
  'src/modules/painel/tipos.ts': r"""/** SysMúsica — Tipos do painel ao vivo (campos = o que as funções do banco devolvem, migração 0026). */

export type BlocoPainel = "MINISTERIO" | "MUSICOS" | "ORGANISTAS";

/** Uma linha do painel (por exemplo, "Encarregado Local") com a quantidade de presentes. */
export interface LinhaPainel {
  codigo: string;
  bloco: BlocoPainel;
  rotulo: string;
  ordem: number;
  qtd: number;
  selecionavel: boolean;
}

/** Quantidade de quem toca instrumentos de uma família (o órgão não entra aqui: conta em Organistas). */
export interface ContagemFamilia {
  familia: string;
  qtd: number;
}

export interface EventoDoPainel {
  id: string;
  tipo: string;
  local: string | null;
  data_evento: string;
  cidade: string | null;
  comum: string | null;
}

/** Resposta de painel_ao_vivo: só números, nenhuma linha de presença. */
export interface DadosPainel {
  evento: EventoDoPainel;
  total: number;
  linhas: LinhaPainel[];
  instrumentos: ContagemFamilia[];
  atualizado_em: string;
}

/** Um evento da lista para escolher (eventos_do_painel). */
export interface EventoParaEscolher {
  id: string;
  tipo: string;
  local_evento: string | null;
  data_evento: string;
  cidade: string | null;
  comum_nome: string | null;
}

/** Um bloco pronto para mostrar: Ministério, Músicos ou Organistas. */
export interface BlocoResumo {
  bloco: BlocoPainel;
  rotulo: string;
  total: number;
  linhas: LinhaPainel[];
}

export interface FamiliaResumo {
  nome: string;
  qtd: number;
  percentual: string; // "27,7%"
}

export type TipoCategoria = "musico" | "organista";
""",
  'src/modules/painel/regras.ts': r"""/**
 * SysMúsica — Regras puras do painel ao vivo (sem banco). Testadas em regras.test.ts.
 * A contagem de verdade é feita no banco (função painel_ao_vivo); aqui ficam a montagem dos blocos para a tela,
 * os percentuais, os formatos de data e hora e a regra do campo Categoria do membro.
 */
import type {
  BlocoPainel,
  BlocoResumo,
  ContagemFamilia,
  FamiliaResumo,
  LinhaPainel,
  TipoCategoria,
} from "./tipos";

// ---------- Atualização automática ----------

/** Intervalos que o usuário pode escolher, em segundos. */
export const INTERVALOS_SEGUNDOS = [5, 10, 15, 30, 60] as const;
export const INTERVALO_PADRAO = 10;

/** Devolve o intervalo se for um dos permitidos; senão, o padrão (10 s). */
export function intervaloValido(valor: unknown): number {
  const numero = typeof valor === "number" ? valor : Number(valor);
  return (INTERVALOS_SEGUNDOS as readonly number[]).includes(numero) ? numero : INTERVALO_PADRAO;
}

// ---------- Percentuais e formatos ----------

/** "27,7%": a parte sobre o total, com uma casa decimal e vírgula. Total zero dá "0,0%". */
export function formatarPercentual(parte: number, total: number): string {
  const valor = total > 0 ? (parte / total) * 100 : 0;
  return `${valor.toLocaleString("pt-BR", { minimumFractionDigits: 1, maximumFractionDigits: 1 })}%`;
}

const FUSO = "America/Sao_Paulo";

/** Dia do evento no formato dd/mm/aaaa (fuso de Salvador). */
export function formatarDiaDoEvento(iso: string): string {
  return new Intl.DateTimeFormat("pt-BR", {
    timeZone: FUSO,
    day: "2-digit",
    month: "2-digit",
    year: "numeric",
  }).format(new Date(iso));
}

/** Hora do evento: "09h" quando é em ponto, "09h30" nos demais casos (fuso de Salvador). */
export function formatarHoraDoEvento(iso: string): string {
  const [hora, minuto] = new Intl.DateTimeFormat("pt-BR", {
    timeZone: FUSO,
    hour: "2-digit",
    minute: "2-digit",
    hour12: false,
  })
    .format(new Date(iso))
    .split(":");
  return minuto === "00" ? `${hora}h` : `${hora}h${minuto}`;
}

/** "Atualizado às 10:46:12" (fuso de Salvador). */
export function formatarHoraDaAtualizacao(data: Date): string {
  return new Intl.DateTimeFormat("pt-BR", {
    timeZone: FUSO,
    hour: "2-digit",
    minute: "2-digit",
    second: "2-digit",
    hour12: false,
  }).format(data);
}

// ---------- Montagem dos blocos ----------

export const ROTULO_BLOCO: Record<BlocoPainel, string> = {
  MINISTERIO: "Ministério",
  MUSICOS: "Músicos",
  ORGANISTAS: "Organistas",
};

const ORDEM_BLOCOS: BlocoPainel[] = ["MINISTERIO", "MUSICOS", "ORGANISTAS"];

/**
 * Agrupa as linhas em Ministério, Músicos e Organistas, com o total de cada bloco.
 * Linhas que não podem ser escolhidas na entrada (ex.: "Sem categoria") só aparecem se tiverem gente.
 */
export function agruparBlocos(linhas: LinhaPainel[]): BlocoResumo[] {
  return ORDEM_BLOCOS.map((bloco) => {
    const doBloco = linhas
      .filter((linha) => linha.bloco === bloco && (linha.selecionavel || linha.qtd > 0))
      .sort((a, b) => a.ordem - b.ordem);
    return {
      bloco,
      rotulo: ROTULO_BLOCO[bloco],
      total: doBloco.reduce((soma, linha) => soma + linha.qtd, 0),
      linhas: doBloco,
    };
  });
}

const FAMILIAS_FIXAS = ["Cordas", "Madeiras", "Metais"];

/**
 * Famílias do bloco Instrumentos: Cordas, Madeiras e Metais sempre aparecem (mesmo com zero);
 * outras (como Teclas, para o acordeom) só quando houver alguém. O percentual é sobre o total do bloco.
 */
export function montarFamilias(itens: ContagemFamilia[]): { total: number; familias: FamiliaResumo[] } {
  const total = itens.reduce((soma, item) => soma + item.qtd, 0);
  const quantidade = (nome: string) => itens.find((item) => item.familia === nome)?.qtd ?? 0;

  const extras = itens
    .filter((item) => !FAMILIAS_FIXAS.includes(item.familia) && item.qtd > 0)
    .map((item) => item.familia)
    .sort((a, b) => a.localeCompare(b, "pt-BR"));

  const familias = [...FAMILIAS_FIXAS, ...extras].map((nome) => ({
    nome,
    qtd: quantidade(nome),
    percentual: formatarPercentual(quantidade(nome), total),
  }));
  return { total, familias };
}

// ---------- Categoria do membro (Músico e Organista) ----------

export const CATEGORIAS = [
  { valor: "OFICIALIZADO", musico: "Oficializado", organista: "Oficializada" },
  { valor: "CULTO_OFICIAL", musico: "Culto Oficial", organista: "Culto Oficial" },
  { valor: "RJM", musico: "RJM", organista: "RJM" },
] as const;

function semAcento(texto: string): string {
  return texto
    .normalize("NFD")
    .replace(/[̀-ͯ]/g, "")
    .toLowerCase()
    .trim();
}

/** O cargo usa Categoria? Só Músico e Organista (as demais pessoas contam pelo cargo). */
export function cargoUsaCategoria(nomeCargo: string | undefined | null): TipoCategoria | null {
  if (!nomeCargo) return null;
  const nome = semAcento(nomeCargo);
  if (nome.startsWith("musico")) return "musico";
  if (nome.startsWith("organista")) return "organista";
  return null;
}

/** Texto da categoria para o tipo de cargo (a organista é "Oficializada", no feminino). */
export function rotuloDaCategoria(valor: string | null | undefined, tipo: TipoCategoria): string {
  const encontrada = CATEGORIAS.find((categoria) => categoria.valor === valor);
  return encontrada ? encontrada[tipo] : "Sem categoria";
}

/** Músico e Organista precisam de categoria; devolve a mensagem de erro ou null. O banco só aceita os valores da lista. */
export function validarCategoria(nomeCargo: string | undefined | null, categoria: string): string | null {
  const tipo = cargoUsaCategoria(nomeCargo);
  if (!tipo) return null;
  if (!CATEGORIAS.some((item) => item.valor === categoria)) {
    return `Escolha a categoria (${CATEGORIAS.map((item) => item[tipo]).join(", ")}).`;
  }
  return null;
}
""",
  'src/modules/painel/regras.test.ts': r"""import { describe, expect, it } from "vitest";
import {
  agruparBlocos,
  cargoUsaCategoria,
  formatarHoraDoEvento,
  formatarPercentual,
  intervaloValido,
  montarFamilias,
  rotuloDaCategoria,
  validarCategoria,
} from "./regras";
import type { LinhaPainel } from "./tipos";

const linha = (parcial: Partial<LinhaPainel> & Pick<LinhaPainel, "codigo" | "bloco">): LinhaPainel => ({
  rotulo: parcial.codigo,
  ordem: 0,
  qtd: 0,
  selecionavel: true,
  ...parcial,
});

describe("intervaloValido", () => {
  it("aceita os intervalos permitidos", () => {
    expect(intervaloValido(5)).toBe(5);
    expect(intervaloValido("30")).toBe(30);
    expect(intervaloValido(60)).toBe(60);
  });
  it("qualquer outro valor volta para 10 segundos", () => {
    expect(intervaloValido(7)).toBe(10);
    expect(intervaloValido(null)).toBe(10);
    expect(intervaloValido("abc")).toBe(10);
    expect(intervaloValido(0)).toBe(10);
  });
});

describe("formatarPercentual", () => {
  it("usa vírgula e uma casa decimal", () => {
    expect(formatarPercentual(13, 47)).toBe("27,7%");
    expect(formatarPercentual(18, 47)).toBe("38,3%");
    expect(formatarPercentual(16, 47)).toBe("34,0%");
  });
  it("total zero não divide por zero", () => {
    expect(formatarPercentual(0, 0)).toBe("0,0%");
  });
});

describe("formatarHoraDoEvento", () => {
  it("em ponto mostra só a hora; senão, hora e minutos (fuso de Salvador)", () => {
    expect(formatarHoraDoEvento("2026-10-11T12:00:00Z")).toBe("09h");
    expect(formatarHoraDoEvento("2026-10-11T12:30:00Z")).toBe("09h30");
    expect(formatarHoraDoEvento("2026-10-11T22:05:00Z")).toBe("19h05");
  });
});

describe("agruparBlocos", () => {
  const linhas = [
    linha({ codigo: "MUS_B", bloco: "MUSICOS", ordem: 2, qtd: 3 }),
    linha({ codigo: "MUS_A", bloco: "MUSICOS", ordem: 1, qtd: 2 }),
    linha({ codigo: "MUS_SEM", bloco: "MUSICOS", ordem: 9, qtd: 0, selecionavel: false }),
    linha({ codigo: "MIN_A", bloco: "MINISTERIO", ordem: 1, qtd: 4 }),
    linha({ codigo: "ORG_SEM", bloco: "ORGANISTAS", ordem: 9, qtd: 1, selecionavel: false }),
  ];

  it("separa em Ministério, Músicos e Organistas, nessa ordem, com o total de cada um", () => {
    const blocos = agruparBlocos(linhas);
    expect(blocos.map((b) => b.rotulo)).toEqual(["Ministério", "Músicos", "Organistas"]);
    expect(blocos.map((b) => b.total)).toEqual([4, 5, 1]);
  });

  it("ordena as linhas e esconde 'Sem categoria' quando está zerada, mas mostra quando há gente", () => {
    const [, musicos, organistas] = agruparBlocos(linhas);
    expect(musicos.linhas.map((l) => l.codigo)).toEqual(["MUS_A", "MUS_B"]);
    expect(organistas.linhas.map((l) => l.codigo)).toEqual(["ORG_SEM"]);
  });

  it("não altera a lista original", () => {
    const copia = JSON.stringify(linhas);
    agruparBlocos(linhas);
    expect(JSON.stringify(linhas)).toBe(copia);
  });
});

describe("montarFamilias", () => {
  it("Cordas, Madeiras e Metais sempre aparecem; percentual sobre o total do bloco", () => {
    const { total, familias } = montarFamilias([
      { familia: "Cordas", qtd: 13 },
      { familia: "Madeiras", qtd: 18 },
      { familia: "Metais", qtd: 16 },
    ]);
    expect(total).toBe(47);
    expect(familias.map((f) => [f.nome, f.qtd, f.percentual])).toEqual([
      ["Cordas", 13, "27,7%"],
      ["Madeiras", 18, "38,3%"],
      ["Metais", 16, "34,0%"],
    ]);
  });

  it("sem ninguém, mostra as três com zero", () => {
    const { total, familias } = montarFamilias([]);
    expect(total).toBe(0);
    expect(familias.map((f) => f.qtd)).toEqual([0, 0, 0]);
    expect(familias[0].percentual).toBe("0,0%");
  });

  it("Teclas (acordeom) só aparece quando há alguém e entra no total", () => {
    const { total, familias } = montarFamilias([
      { familia: "Cordas", qtd: 1 },
      { familia: "Teclas", qtd: 1 },
      { familia: "Sem família", qtd: 0 },
    ]);
    expect(total).toBe(2);
    expect(familias.map((f) => f.nome)).toEqual(["Cordas", "Madeiras", "Metais", "Teclas"]);
  });
});

describe("categoria do membro", () => {
  it("só Músico e Organista usam categoria", () => {
    expect(cargoUsaCategoria("Músico")).toBe("musico");
    expect(cargoUsaCategoria("Organista")).toBe("organista");
    expect(cargoUsaCategoria("Encarregado Local")).toBeNull();
    expect(cargoUsaCategoria("Examinadora")).toBeNull();
    expect(cargoUsaCategoria(undefined)).toBeNull();
  });

  it("a organista é Oficializada (feminino) e sem valor vira 'Sem categoria'", () => {
    expect(rotuloDaCategoria("OFICIALIZADO", "musico")).toBe("Oficializado");
    expect(rotuloDaCategoria("OFICIALIZADO", "organista")).toBe("Oficializada");
    expect(rotuloDaCategoria("RJM", "musico")).toBe("RJM");
    expect(rotuloDaCategoria(null, "musico")).toBe("Sem categoria");
  });

  it("exige a categoria só para Músico e Organista", () => {
    expect(validarCategoria("Músico", "")).toMatch(/Escolha a categoria/);
    expect(validarCategoria("Organista", "")).toMatch(/Oficializada/);
    expect(validarCategoria("Músico", "RJM")).toBeNull();
    expect(validarCategoria("Ancião", "")).toBeNull();
  });
});
""",
  'src/modules/painel/services/painel.ts': r"""/**
 * SysMúsica — Serviço de dados do painel ao vivo.
 * As contagens são feitas no banco (funções painel_ao_vivo e eventos_do_painel): a tela recebe só números,
 * nunca as linhas de presença. O banco confere a permissão "Painel ao vivo" e a abrangência (região e setor)
 * de quem consulta.
 */
import { supabase } from "@/lib/supabase";
import { mensagemDoErro } from "@/lib/erros";
import type { DadosPainel, EventoParaEscolher } from "../tipos";

/** Eventos para escolher: de 30 dias atrás a 30 dias à frente, do mais próximo de agora para o mais distante. */
export async function listarEventosDoPainel(): Promise<EventoParaEscolher[]> {
  const { data, error } = await supabase.rpc("eventos_do_painel");
  if (error) throw new Error(mensagemDoErro(error, "Não foi possível carregar os eventos."));
  return (data ?? []) as EventoParaEscolher[];
}

/** Contagens ao vivo do evento (total, linhas dos blocos e instrumentos por família). */
export async function buscarPainel(eventoId: string): Promise<DadosPainel> {
  const { data, error } = await supabase.rpc("painel_ao_vivo", { p_evento_id: eventoId });
  if (error || !data) {
    throw new Error(error ? mensagemDoErro(error, "Não foi possível atualizar o painel.") : "Não foi possível atualizar o painel.");
  }
  return data as unknown as DadosPainel;
}
""",
  'src/modules/painel/components/PainelAoVivo.tsx': r""""use client";

/**
 * SysMúsica — Painel ao vivo: acompanha, em tempo real, quantos já entraram no evento e a contagem por
 * Ministério, Músicos, Organistas e Instrumentos, enquanto a Portaria registra as entradas.
 *
 * Atualização automática: a tela pergunta ao banco de tempos em tempos (padrão 10 s; o usuário escolhe
 * 5, 10, 15, 30 ou 60 s ou pausa). A escolha do intervalo fica guardada neste navegador. Com a aba em segundo
 * plano a tela não consulta, e ao voltar atualiza na hora. Se a internet cair, mostra os últimos números e
 * tenta de novo no próximo ciclo. O banco entrega só contagens e respeita a abrangência de cada usuário.
 */
import { useEffect, useState } from "react";
import { CalendarDays, Clock, Pause, Play, RefreshCw } from "lucide-react";
import EmptyState from "@/components/ui/EmptyState";
import ErrorState from "@/components/ui/ErrorState";
import Skeleton from "@/components/ui/Skeleton";
import {
  INTERVALOS_SEGUNDOS,
  INTERVALO_PADRAO,
  formatarDiaDoEvento,
  formatarHoraDaAtualizacao,
  formatarHoraDoEvento,
  intervaloValido,
} from "../regras";
import { buscarPainel, listarEventosDoPainel } from "../services/painel";
import type { DadosPainel, EventoParaEscolher } from "../tipos";
import ResumoTempoReal from "./ResumoTempoReal";

// Guarda o intervalo escolhido só neste navegador (se o armazenamento não estiver disponível, apenas não lembra)
const CHAVE_INTERVALO = "sysmusica.painel.intervalo";

function lerIntervaloGuardado(): number {
  try {
    return intervaloValido(window.localStorage.getItem(CHAVE_INTERVALO));
  } catch {
    return INTERVALO_PADRAO;
  }
}

function guardarIntervalo(segundos: number) {
  try {
    window.localStorage.setItem(CHAVE_INTERVALO, String(segundos));
  } catch {
    // sem armazenamento disponível: apenas não lembra a escolha
  }
}

const classeCampo =
  "w-full rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 shadow-sm " +
  "focus:border-brand-500 focus:outline-none focus:ring-2 focus:ring-brand-200 [color-scheme:light]";

const classeBotao =
  "inline-flex items-center gap-2 rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm font-medium " +
  "text-slate-700 transition hover:bg-slate-50 disabled:cursor-not-allowed disabled:opacity-60";

function rotuloDoEvento(evento: EventoParaEscolher): string {
  const quando = `${formatarDiaDoEvento(evento.data_evento)} ${formatarHoraDoEvento(evento.data_evento)}`;
  return [quando, evento.tipo, evento.local_evento].filter(Boolean).join(" · ");
}

export default function PainelAoVivo() {
  const [eventos, setEventos] = useState<EventoParaEscolher[] | null>(null); // nulo = carregando a lista
  const [erroEventos, setErroEventos] = useState<string | null>(null);
  const [eventoId, setEventoId] = useState("");
  const [dados, setDados] = useState<DadosPainel | null>(null);
  const [erro, setErro] = useState<string | null>(null);
  const [intervalo, setIntervalo] = useState(INTERVALO_PADRAO);
  const [pausado, setPausado] = useState(false);
  const [atualizadoEm, setAtualizadoEm] = useState<Date | null>(null);
  const [atualizando, setAtualizando] = useState(false);
  const [rodada, setRodada] = useState(0); // muda quando o usuário pede "Atualizar agora"

  /* eslint-disable react-hooks/set-state-in-effect */
  // Intervalo guardado neste navegador
  useEffect(() => {
    setIntervalo(lerIntervaloGuardado());
  }, []);

  // Lista de eventos: já abre no mais próximo de agora
  useEffect(() => {
    let cancelado = false;
    void listarEventosDoPainel()
      .then((lista) => {
        if (cancelado) return;
        setEventos(lista);
        setEventoId(lista[0]?.id ?? "");
      })
      .catch((e: unknown) => {
        if (cancelado) return;
        setEventos([]);
        setErroEventos(e instanceof Error ? e.message : "Não foi possível carregar os eventos.");
      });
    return () => {
      cancelado = true;
    };
  }, []);

  // Atualização automática do evento escolhido
  useEffect(() => {
    if (!eventoId) return;
    let ativo = true;

    const buscar = async () => {
      if (document.hidden) return; // aba em segundo plano: não consulta
      setAtualizando(true);
      try {
        const resposta = await buscarPainel(eventoId);
        if (!ativo) return;
        setDados(resposta);
        setErro(null);
        setAtualizadoEm(new Date());
      } catch (e) {
        if (!ativo) return;
        setErro(e instanceof Error ? e.message : "Não foi possível atualizar o painel.");
      } finally {
        if (ativo) setAtualizando(false);
      }
    };

    void buscar();
    const temporizador = pausado ? null : setInterval(() => void buscar(), intervalo * 1000);
    const aoVoltarParaAAba = () => {
      if (!document.hidden) void buscar();
    };
    document.addEventListener("visibilitychange", aoVoltarParaAAba);

    return () => {
      ativo = false;
      if (temporizador) clearInterval(temporizador);
      document.removeEventListener("visibilitychange", aoVoltarParaAAba);
    };
  }, [eventoId, intervalo, pausado, rodada]);
  /* eslint-enable react-hooks/set-state-in-effect */

  function trocarEvento(id: string) {
    setDados(null);
    setErro(null);
    setAtualizadoEm(null);
    setPausado(false);
    setEventoId(id);
  }

  function trocarIntervalo(valor: string) {
    const segundos = intervaloValido(valor);
    setIntervalo(segundos);
    guardarIntervalo(segundos);
  }

  // ---------- Estados da tela ----------

  if (eventos === null) {
    return (
      <div role="status" aria-live="polite" className="space-y-3">
        <span className="sr-only">Carregando o painel...</span>
        <Skeleton className="h-20 rounded-2xl" />
        <Skeleton className="h-96 rounded-2xl" />
      </div>
    );
  }

  if (erroEventos) {
    return (
      <ErrorState
        titulo="Não foi possível carregar o painel."
        mensagem={erroEventos}
        onTentarNovamente={() => window.location.reload()}
      />
    );
  }

  if (eventos.length === 0) {
    return (
      <EmptyState
        titulo="Nenhum evento por perto"
        descricao="O painel mostra os eventos dos últimos e dos próximos 30 dias dentro da sua abrangência. Cadastre o evento e a portaria para acompanhar a entrada."
      />
    );
  }

  const evento = dados?.evento;

  return (
    <div className="space-y-4">
      {/* Controles: evento, intervalo, pausar e atualizar */}
      <section className="rounded-2xl border border-slate-200 bg-white p-4 shadow-sm">
        <div className="flex flex-wrap items-end gap-3">
          {eventos.length > 1 && (
            <div className="min-w-0 flex-1 basis-64 space-y-1.5">
              <label htmlFor="painel-evento" className="text-xs font-medium text-slate-600">
                Evento
              </label>
              <select
                id="painel-evento"
                value={eventoId}
                onChange={(e) => trocarEvento(e.target.value)}
                className={classeCampo}
              >
                {eventos.map((item) => (
                  <option key={item.id} value={item.id}>
                    {rotuloDoEvento(item)}
                  </option>
                ))}
              </select>
            </div>
          )}

          <div className="space-y-1.5">
            <label htmlFor="painel-intervalo" className="text-xs font-medium text-slate-600">
              Atualizar a cada
            </label>
            <select
              id="painel-intervalo"
              value={intervalo}
              onChange={(e) => trocarIntervalo(e.target.value)}
              className={classeCampo}
            >
              {INTERVALOS_SEGUNDOS.map((segundos) => (
                <option key={segundos} value={segundos}>
                  {segundos} segundos
                </option>
              ))}
            </select>
          </div>

          <button type="button" className={classeBotao} onClick={() => setPausado((valor) => !valor)}>
            {pausado ? (
              <Play className="h-4 w-4" aria-hidden="true" />
            ) : (
              <Pause className="h-4 w-4" aria-hidden="true" />
            )}
            {pausado ? "Retomar" : "Pausar"}
          </button>

          <button
            type="button"
            className={classeBotao}
            onClick={() => setRodada((valor) => valor + 1)}
            disabled={atualizando}
          >
            <RefreshCw className={"h-4 w-4" + (atualizando ? " animate-spin" : "")} aria-hidden="true" />
            Atualizar agora
          </button>
        </div>

        <p className="mt-3 flex flex-wrap items-center gap-x-3 gap-y-1 text-xs text-slate-500" role="status">
          <span className="inline-flex items-center gap-1.5 font-medium text-slate-700">
            <span
              className={
                "h-2 w-2 rounded-full " + (pausado || erro ? "bg-slate-400" : "animate-pulse bg-emerald-500")
              }
              aria-hidden="true"
            />
            {pausado ? "Atualização pausada" : erro ? "Sem atualização" : `Ao vivo · a cada ${intervalo} s`}
          </span>
          {atualizadoEm && <span>Atualizado às {formatarHoraDaAtualizacao(atualizadoEm)}</span>}
        </p>
      </section>

      {erro && dados && (
        <p role="alert" className="rounded-lg bg-amber-50 px-3 py-2 text-sm text-amber-800">
          Não foi possível atualizar agora ({erro}). Estes são os últimos números recebidos; a tela tenta de novo sozinha.
        </p>
      )}

      {!dados ? (
        erro ? (
          <ErrorState
            titulo="Não foi possível carregar o painel."
            mensagem={erro}
            onTentarNovamente={() => setRodada((valor) => valor + 1)}
          />
        ) : (
          <div role="status" aria-live="polite" className="space-y-3">
            <span className="sr-only">Carregando o painel...</span>
            <Skeleton className="h-20 rounded-2xl" />
            <Skeleton className="h-96 rounded-2xl" />
          </div>
        )
      ) : (
        <>
          {/* Cabeçalho do evento */}
          {evento && (
            <section className="flex flex-wrap items-center justify-between gap-4 rounded-2xl bg-brand-700 px-5 py-4 text-white shadow-sm">
              <div className="flex min-w-0 items-center gap-3">
                <CalendarDays className="h-8 w-8 shrink-0" aria-hidden="true" />
                <div className="min-w-0">
                  <h2 className="truncate text-lg font-semibold">{evento.tipo}</h2>
                  <p className="truncate text-sm uppercase tracking-wide text-white/80">
                    {[evento.local, evento.comum].filter(Boolean).join(" · ")}
                  </p>
                </div>
              </div>
              <div className="flex items-center gap-4 text-sm font-medium">
                <span className="inline-flex items-center gap-1.5">
                  <CalendarDays className="h-4 w-4" aria-hidden="true" />
                  {formatarDiaDoEvento(evento.data_evento)}
                </span>
                <span className="inline-flex items-center gap-1.5">
                  <Clock className="h-4 w-4" aria-hidden="true" />
                  {formatarHoraDoEvento(evento.data_evento)}
                </span>
              </div>
            </section>
          )}

          <ResumoTempoReal dados={dados} />
        </>
      )}
    </div>
  );
}
""",
  'src/modules/painel/components/ResumoTempoReal.tsx': r"""/**
 * SysMúsica — "Resumo em tempo real" do painel ao vivo (componente de apresentação).
 * Total de participantes, os blocos Ministério, Músicos e Organistas (com as linhas de cada um) e o bloco
 * Instrumentos por família, com a quantidade e o percentual. Cada pessoa conta uma vez só no total; o bloco
 * Instrumentos é um recorte de quem toca e não soma de novo.
 */
import { Guitar, Keyboard, Music, Users, type LucideIcon } from "lucide-react";
import { agruparBlocos, montarFamilias } from "../regras";
import type { BlocoPainel, DadosPainel } from "../tipos";

const VISUAL_BLOCO: Record<BlocoPainel, { icone: LucideIcon; fundo: string; texto: string }> = {
  MINISTERIO: { icone: Users, fundo: "bg-blue-100", texto: "text-blue-700" },
  MUSICOS: { icone: Music, fundo: "bg-blue-100", texto: "text-blue-700" },
  ORGANISTAS: { icone: Keyboard, fundo: "bg-orange-100", texto: "text-orange-600" },
};

// Cor da bolinha de cada família no bloco Instrumentos
const COR_FAMILIA: Record<string, string> = {
  Cordas: "bg-amber-700",
  Madeiras: "bg-stone-700",
  Metais: "bg-yellow-500",
  Teclas: "bg-violet-500",
};

function CabecalhoDoBloco({
  icone: Icone,
  fundo,
  texto,
  titulo,
  total,
}: {
  icone: LucideIcon;
  fundo: string;
  texto: string;
  titulo: string;
  total: number;
}) {
  return (
    <div className="flex items-center justify-between px-4 py-3">
      <div className="flex items-center gap-2">
        <span className={`flex h-7 w-7 items-center justify-center rounded-full ${fundo} ${texto}`}>
          <Icone className="h-4 w-4" aria-hidden="true" />
        </span>
        <h3 className="text-sm font-semibold text-slate-900">{titulo}</h3>
      </div>
      <span className="text-xl font-bold tabular-nums text-slate-900">{total}</span>
    </div>
  );
}

export default function ResumoTempoReal({ dados }: { dados: DadosPainel }) {
  const blocos = agruparBlocos(dados.linhas);
  const { total: totalInstrumentos, familias } = montarFamilias(dados.instrumentos);

  return (
    <div className="mx-auto w-full max-w-md space-y-3">
      <h2 className="text-lg font-bold text-slate-900">Resumo em tempo real</h2>

      {/* Total de participantes (cada pessoa conta uma vez só) */}
      <section
        aria-label="Total de participantes"
        className="flex items-center gap-4 rounded-xl border border-slate-200 bg-white px-4 py-4 shadow-sm"
      >
        <span className="flex h-14 w-14 shrink-0 items-center justify-center rounded-xl bg-blue-50 text-blue-600">
          <Users className="h-8 w-8" aria-hidden="true" />
        </span>
        <div>
          <p className="text-sm font-medium text-slate-700">Total de participantes</p>
          <p className="text-4xl font-bold leading-tight tabular-nums text-slate-900">{dados.total}</p>
        </div>
      </section>

      {/* Ministério, Músicos e Organistas */}
      {blocos.map((bloco) => {
        const visual = VISUAL_BLOCO[bloco.bloco];
        return (
          <section
            key={bloco.bloco}
            aria-label={bloco.rotulo}
            className="rounded-xl border border-slate-200 bg-white shadow-sm"
          >
            <CabecalhoDoBloco {...visual} titulo={bloco.rotulo} total={bloco.total} />
            <ul className="divide-y divide-slate-100 border-t border-slate-100 px-4">
              {bloco.linhas.map((linha) => (
                <li key={linha.codigo} className="flex items-center justify-between py-1.5 text-sm">
                  <span className="text-slate-600">{linha.rotulo}</span>
                  <span className="font-medium tabular-nums text-slate-900">{linha.qtd}</span>
                </li>
              ))}
            </ul>
          </section>
        );
      })}

      {/* Instrumentos por família (recorte de quem toca; não soma ao total) */}
      <section aria-label="Instrumentos" className="rounded-xl border border-slate-200 bg-white shadow-sm">
        <CabecalhoDoBloco
          icone={Guitar}
          fundo="bg-emerald-100"
          texto="text-emerald-700"
          titulo="Instrumentos"
          total={totalInstrumentos}
        />
        <ul className="divide-y divide-slate-100 border-t border-slate-100 px-4">
          {familias.map((familia) => (
            <li key={familia.nome} className="flex items-center justify-between py-2 text-sm">
              <span className="flex items-center gap-2 text-slate-700">
                <span
                  className={`h-3 w-3 rounded-full ${COR_FAMILIA[familia.nome] ?? "bg-slate-400"}`}
                  aria-hidden="true"
                />
                {familia.nome}
              </span>
              <span className="tabular-nums text-slate-900">
                <span className="font-medium">{familia.qtd}</span>{" "}
                <span className="text-slate-500">({familia.percentual})</span>
              </span>
            </li>
          ))}
        </ul>
      </section>
    </div>
  );
}
""",
  'src/app/(painel)/painel-ao-vivo/layout.tsx': r"""import type { ReactNode } from "react";
import RequerPermissao from "@/modules/autenticacao/components/RequerPermissao";

/** Protege a tela do Painel ao vivo: só entra quem tem a permissão de visualizar o painel. */
export default function PainelAoVivoLayout({ children }: { children: ReactNode }) {
  return <RequerPermissao permissao="painel.visualizar">{children}</RequerPermissao>;
}
""",
  'src/app/(painel)/painel-ao-vivo/page.tsx': r""""use client";

/**
 * SysMúsica — Página /painel-ao-vivo: contagens do evento em tempo real (ministério, músicos, organistas e
 * instrumentos), atualizadas sozinhas enquanto a Portaria registra as entradas.
 * Só entra quem tem a permissão painel.visualizar (o banco também confere).
 */
import PageHeader from "@/components/ui/PageHeader";
import PainelAoVivo from "@/modules/painel/components/PainelAoVivo";

export default function PainelAoVivoPage() {
  return (
    <main className="text-slate-900">
      <div className="mx-auto max-w-4xl px-4 py-8 sm:px-6 lg:px-8">
        <PageHeader
          titulo="Painel ao vivo"
          descricao="Acompanhe a presença do evento em tempo real, enquanto a Portaria registra as entradas."
        />
        <PainelAoVivo />
      </div>
    </main>
  );
}
""",
}

def abrir(c):
    return open(c, encoding="utf-8").read()

def trocar(texto, antigo, novo, onde):
    if texto.count(antigo) != 1:
        print("ERRO: trecho não encontrado exatamente uma vez em", onde, "->", antigo[:80].replace("\n", "\\n")); sys.exit(1)
    return texto.replace(antigo, novo)

# Nada existente pode ser sobrescrito
for caminho in NOVOS:
    if os.path.exists(caminho):
        print("ERRO: já existe", caminho); sys.exit(1)

edicoes = {}

# ---------- Permissão nova no catálogo (igual ao banco, migração 0026) ----------
a = "src/lib/permissoes.ts"
edicoes[a] = trocar(abrir(a),
  '  { codigo: "relatorios.visualizar", modulo: "Relatórios", acao: "Visualizar" },\n',
  '  { codigo: "relatorios.visualizar", modulo: "Relatórios", acao: "Visualizar" },\n'
  '  { codigo: "painel.visualizar", modulo: "Painel ao vivo", acao: "Visualizar" },\n', a)

# ---------- Menu: "Painel ao vivo" em Operações (só aparece para quem tem a permissão) ----------
a = "src/components/layout/navegacao.ts"
t = abrir(a)
t = trocar(t, 'import {\n  CalendarDays,\n', 'import {\n  Activity,\n  CalendarDays,\n', a)
t = trocar(t,
  '      { href: "/portaria", rotulo: "Portaria", icone: DoorOpen, permissao: "portaria.visualizar" },\n',
  '      { href: "/portaria", rotulo: "Portaria", icone: DoorOpen, permissao: "portaria.visualizar" },\n'
  '      { href: "/painel-ao-vivo", rotulo: "Painel ao vivo", icone: Activity, permissao: "painel.visualizar" },\n', a)
edicoes[a] = t

# ---------- Tipos do banco: categoria do membro ----------
a = "src/types/database.ts"
t = abrir(a)
t = trocar(t,
  '  foto_path?: string | null; // caminho da fotografia no armazenamento privado (exibida por URL temporária)\n}',
  '  foto_path?: string | null; // caminho da fotografia no armazenamento privado (exibida por URL temporária)\n'
  '  categoria?: string | null; // OFICIALIZADO, CULTO_OFICIAL ou RJM (só Músico e Organista; define a linha do painel ao vivo)\n}', a)
t = trocar(t, 'comum_id, foto_path" as const;', 'comum_id, foto_path, categoria" as const;', a)
t = trocar(t, '"cpf" | "comum_id" | "foto_path"\n', '"cpf" | "comum_id" | "foto_path" | "categoria"\n', a)
edicoes[a] = t

# ---------- Serviço de membros: a categoria pode ser alterada na edição ----------
a = "src/modules/membros/services/membros.ts"
edicoes[a] = trocar(abrir(a),
  '  comum_id?: string | null; // a comum escolhida (o banco ajusta o nome da congregação)\n',
  '  comum_id?: string | null; // a comum escolhida (o banco ajusta o nome da congregação)\n'
  '  categoria?: string | null; // Oficializado, Culto Oficial ou RJM (Músico e Organista)\n', a)

# ---------- Formulário de membro: campo Categoria (só para Músico e Organista) ----------
a = "src/components/FormularioMembro.tsx"
f = abrir(a)
f = trocar(f,
  'import { atualizarMembro, criarMembro } from "@/modules/membros/services/membros";\n',
  'import { atualizarMembro, criarMembro } from "@/modules/membros/services/membros";\n'
  'import { CATEGORIAS, cargoUsaCategoria, validarCategoria } from "@/modules/painel/regras";\n', a)
f = trocar(f,
  '  const [instrumentoId, setInstrumentoId] = useState(membro?.instrumento_id ?? "");\n',
  '  const [instrumentoId, setInstrumentoId] = useState(membro?.instrumento_id ?? "");\n'
  '  const [categoria, setCategoria] = useState(membro?.categoria ?? ""); // Oficializado, Culto Oficial ou RJM\n', a)
f = trocar(f,
  '    (cargoSelecionado as (Cargo & { exige_instrumento?: boolean }) | undefined)?.exige_instrumento === true;\n',
  '    (cargoSelecionado as (Cargo & { exige_instrumento?: boolean }) | undefined)?.exige_instrumento === true;\n'
  '  // Só Músico e Organista têm categoria (as demais pessoas contam no painel pelo próprio cargo)\n'
  '  const tipoCategoria = cargoUsaCategoria(cargoSelecionado?.nome);\n', a)
f = trocar(f,
  '    if (!novoCargo?.permite_instrumento) setInstrumentoId("");\n',
  '    if (!novoCargo?.permite_instrumento) setInstrumentoId("");\n'
  '    if (!cargoUsaCategoria(novoCargo?.nome)) setCategoria("");\n', a)
f = trocar(f,
  '    if (erroInstrumento) return setErroForm(erroInstrumento);\n',
  '    if (erroInstrumento) return setErroForm(erroInstrumento);\n\n'
  '    // Categoria: obrigatória para Músico e Organista (define em qual linha do painel ao vivo ele conta)\n'
  '    const erroCategoria = validarCategoria(cargoSelecionado?.nome, categoria);\n'
  '    if (erroCategoria) return setErroForm(erroCategoria);\n', a)
f = trocar(f,
  '        instrumento_id: permiteInstrumento && instrumentoId ? instrumentoId : null,\n',
  '        instrumento_id: permiteInstrumento && instrumentoId ? instrumentoId : null,\n'
  '        categoria: tipoCategoria && categoria ? categoria : null,\n', a)
f = trocar(f,
  '      {/* Localidade: comum (lista do banco), cidade e bairro (com sugestões dos já cadastrados) */}\n',
  '      {/* Categoria: só para Músico e Organista (define em qual linha do painel ao vivo a pessoa conta) */}\n'
  '      {tipoCategoria && (\n'
  '        <div className="space-y-1.5">\n'
  '          <label htmlFor="categoria" className="text-sm font-medium text-slate-700">\n'
  '            Categoria <span className="font-normal text-red-600">(obrigatória)</span>\n'
  '          </label>\n'
  '          <select\n'
  '            id="categoria"\n'
  '            required\n'
  '            value={categoria}\n'
  '            onChange={(e) => setCategoria(e.target.value)}\n'
  '            disabled={salvando}\n'
  '            className={classeInput}\n'
  '          >\n'
  '            <option value="">Selecione a categoria</option>\n'
  '            {CATEGORIAS.map((item) => (\n'
  '              <option key={item.valor} value={item.valor}>\n'
  '                {item[tipoCategoria]}\n'
  '              </option>\n'
  '            ))}\n'
  '          </select>\n'
  '        </div>\n'
  '      )}\n\n'
  '      {/* Localidade: comum (lista do banco), cidade e bairro (com sugestões dos já cadastrados) */}\n', a)
edicoes[a] = f

# Só grava depois de TODAS as trocas terem dado certo
for caminho, conteudo in edicoes.items():
    open(caminho, "w", encoding="utf-8").write(conteudo)
for caminho, conteudo in NOVOS.items():
    os.makedirs(os.path.dirname(caminho) or ".", exist_ok=True)
    open(caminho, "w", encoding="utf-8").write(conteudo)
print("Arquivos gravados:", len(NOVOS), "novos,", len(edicoes), "alterados.")

PYSCRIPT
[ $? -eq 0 ] || { reverter; exit 1; }

echo; echo "=== 2) Parando o servidor de teste e limpando o cache ==="
pkill -f "next dev" 2>/dev/null; pkill -f next-server 2>/dev/null; pkill -f "next/dist" 2>/dev/null; sleep 2
for i in 1 2 3 4 5; do rm -rf .next 2>/dev/null; [ -d .next ] || break; sleep 1; done

echo; echo "=== 3) Conferência de tipos ==="
npx tsc --noEmit || { reverter; exit 1; }
echo; echo "=== 4) Testes automáticos ==="
npx vitest run || { reverter; exit 1; }
echo; echo "=== 5) Lint ==="
npx eslint "${ALT[@]}" src/modules/painel "src/app/(painel)" || { reverter; exit 1; }
echo; echo "=== 6) Build de produção (pode demorar alguns minutos) ==="
npm run build || { reverter; exit 1; }

echo; echo "=== TUDO CERTO: arquivos gravados e conferidos ==="
git status --short
echo
echo "PRÓXIMO PASSO: rodar a migração 0026 no Supabase ANTES de publicar (git push)."
) 2>&1 | tee /tmp/painel-ao-vivo-instalar.log
