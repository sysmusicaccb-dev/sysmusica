cd /workspaces/sysmusica/sysmusica || { echo "Pasta do projeto não encontrada"; exit 1; }
(
set -u
BKP="/tmp/bkp-portaria-toca-$(date +%H%M%S)"; mkdir -p "$BKP/a"
ALT=("src/modules/atendimento/services/atendimento.ts" "src/modules/atendimento/components/CartaoConferencia.tsx" "src/modules/atendimento/components/EntradasRecentes.tsx" "src/modules/atendimento/components/AtendimentoPortaria.tsx" "src/modules/auditoria/regras.ts")
NOV=("supabase/migrations/0028_portaria_toca_avulsa.sql" "src/modules/atendimento/tiposEntrada.ts" "src/modules/atendimento/regrasEntrada.ts" "src/modules/atendimento/regrasEntrada.test.ts" "src/modules/atendimento/services/entrada.ts" "src/modules/atendimento/components/PerguntaToca.tsx" "src/modules/atendimento/components/BuscaLocalidade.tsx" "src/modules/atendimento/components/EntradaSemCadastro.tsx")
for f in "${ALT[@]}"; do mkdir -p "$BKP/a/$(dirname "$f")"; cp "$f" "$BKP/a/$f"; done

reverter() {
  echo ">>> REVERTENDO tudo (nada do que foi tentado fica no projeto)"
  for f in "${ALT[@]}"; do cp "$BKP/a/$f" "$f"; done
  for f in "${NOV[@]}"; do rm -f "$f"; done
  echo ">>> REVERTIDO. Me mande o log: /tmp/portaria-toca-instalar.log"
}

echo "=== 0) Conferência prévia (só leitura) ==="
for f in "${ALT[@]}" supabase/migrations/0026_painel_ao_vivo.sql supabase/migrations/0027_portaria_3h.sql src/modules/painel/regras.ts; do
  [ -f "$f" ] || { echo "ERRO: arquivo esperado não existe: $f (as etapas anteriores foram instaladas?)"; exit 1; }
done
[ -e src/modules/atendimento/regrasEntrada.ts ] && { echo "ERRO: esta etapa já parece instalada."; exit 1; }

echo; echo "=== 1) Gravando os arquivos ==="
python3 - <<'PYSCRIPT'
import os, sys
NOVOS = {
  'supabase/migrations/0028_portaria_toca_avulsa.sql': r"""-- =====================================================================
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
""",
  'src/modules/atendimento/tiposEntrada.ts': r"""/**
 * SysMúsica — Tipos da entrada na Portaria com "Vai tocar?" e da entrada SEM cadastro (migração 0028).
 * Os campos são os devolvidos pelas funções do banco (info_entrada, opcoes_entrada, buscar_localidades ...).
 */

/** Blocos do painel ao vivo (mesmos da tabela linhas_painel). */
export type BlocoEntrada = "MINISTERIO" | "MUSICOS" | "ORGANISTAS";

/** Como a pessoa é contada e se a Portaria precisa perguntar "Vai tocar?" (resposta de info_entrada). */
export interface InfoEntrada {
  linha_codigo: string;
  linha_rotulo: string;
  bloco: BlocoEntrada;
  pergunta_toca: boolean;
  instrumento_id: string | null; // instrumento do cadastro
  instrumento: string | null;
}

/** Uma linha do painel que pode ser escolhida na entrada sem cadastro. */
export interface LinhaEntrada {
  codigo: string;
  bloco: BlocoEntrada;
  rotulo: string;
  pergunta_toca: boolean;
  toca_sempre: boolean;
  instrumento: "NENHUM" | "ORGAO" | "LIVRE";
}

export interface InstrumentoEntrada {
  id: string;
  nome: string;
  familia: string;
}

export interface OpcoesEntrada {
  linhas: LinhaEntrada[];
  instrumentos: InstrumentoEntrada[];
}

/** Resultado da busca de localidade (casa de oração + caminho na organização). */
export interface LocalidadeBusca {
  comum_id: string;
  nome: string;
  caminho: string;
}

/** Entrada sem cadastro já registrada na portaria. */
export interface EntradaAvulsa {
  id: string;
  linha_rotulo: string;
  bloco: BlocoEntrada;
  toca: boolean | null;
  instrumento: string | null;
  origem: string | null;
  hora_entrada: string;
  total: number;
}

/** O que a Portaria respondeu na conferência de um membro. */
export interface EscolhaToca {
  toca: boolean | null; // null = ainda não respondeu
  instrumentoId: string; // "" = usar o instrumento do cadastro
}
""",
  'src/modules/atendimento/regrasEntrada.ts': r"""/**
 * SysMúsica — Regras puras da entrada na Portaria (sem banco). Testadas em regrasEntrada.test.ts.
 * Quem decide de verdade é o banco (registrar_entrada e registrar_entrada_avulsa conferem tudo de novo);
 * aqui ficam as conferências rápidas para a tela responder na hora.
 */
import type {
  BlocoEntrada,
  EscolhaToca,
  InfoEntrada,
  InstrumentoEntrada,
  LinhaEntrada,
} from "./tiposEntrada";

export const ROTULO_BLOCO_ENTRADA: Record<BlocoEntrada, string> = {
  MINISTERIO: "Ministério",
  MUSICOS: "Músicos",
  ORGANISTAS: "Organistas",
};

const ORDEM_BLOCOS: BlocoEntrada[] = ["MINISTERIO", "MUSICOS", "ORGANISTAS"];

// ---------- Membro cadastrado: "Vai tocar?" ----------

/** Confere a resposta da conferência; devolve a mensagem de erro ou null. */
export function validarEscolhaMembro(info: InfoEntrada | null, escolha: EscolhaToca): string | null {
  if (!info || !info.pergunta_toca) return null;
  if (escolha.toca === null) return "Informe se a pessoa vai tocar.";
  if (escolha.toca && !escolha.instrumentoId && !info.instrumento_id) {
    return "Escolha o instrumento que a pessoa vai tocar.";
  }
  return null;
}

/** Valores a enviar ao banco na entrada de um membro (sem pergunta: nada é enviado). */
export function valoresDaEntrada(
  info: InfoEntrada | null,
  escolha: EscolhaToca
): { toca: boolean | null; instrumentoId: string | null } {
  if (!info || !info.pergunta_toca) return { toca: null, instrumentoId: null };
  return {
    toca: escolha.toca,
    instrumentoId: escolha.toca && escolha.instrumentoId ? escolha.instrumentoId : null,
  };
}

// ---------- Entrada sem cadastro ----------

/** A linha escolhida pede o instrumento? (Músicos sempre; os demais só se a pessoa for tocar) */
export function precisaInstrumento(linha: LinhaEntrada | null, toca: boolean | null): boolean {
  if (!linha || linha.instrumento !== "LIVRE") return false;
  return linha.toca_sempre || (linha.pergunta_toca && toca === true);
}

/** A tela deve perguntar "Vai tocar?" para esta linha? */
export function precisaPerguntar(linha: LinhaEntrada | null): boolean {
  return linha?.pergunta_toca === true;
}

/** Confere a entrada sem cadastro; devolve a mensagem de erro ou null. */
export function validarEntradaAvulsa(dados: {
  linha: LinhaEntrada | null;
  toca: boolean | null;
  instrumentoId: string;
  outraLocalidade: boolean;
  localidadeTexto: string;
}): string | null {
  if (!dados.linha) return "Escolha o cargo ou a categoria da pessoa.";
  if (precisaPerguntar(dados.linha) && dados.toca === null) return "Informe se a pessoa vai tocar.";
  if (precisaInstrumento(dados.linha, dados.toca) && !dados.instrumentoId) {
    return "Escolha o instrumento que a pessoa vai tocar.";
  }
  if (dados.outraLocalidade) {
    const tamanho = dados.localidadeTexto.trim().replace(/\s+/g, " ").length;
    if (tamanho < 2 || tamanho > 120) return "Escreva a localidade (de 2 a 120 letras) ou desmarque a opção.";
  }
  return null;
}

/** Texto da localidade a enviar: nulo quando "Outra" não está marcada ou o campo está vazio. */
export function textoDaLocalidade(outra: boolean, texto: string): string | null {
  if (!outra) return null;
  const limpo = texto.trim().replace(/\s+/g, " ");
  return limpo === "" ? null : limpo;
}

// ---------- Listas para os campos ----------

/** Linhas agrupadas por bloco, na ordem Ministério, Músicos, Organistas. */
export function agruparLinhas(linhas: LinhaEntrada[]): { bloco: BlocoEntrada; rotulo: string; linhas: LinhaEntrada[] }[] {
  return ORDEM_BLOCOS.map((bloco) => ({
    bloco,
    rotulo: ROTULO_BLOCO_ENTRADA[bloco],
    linhas: linhas.filter((linha) => linha.bloco === bloco),
  })).filter((grupo) => grupo.linhas.length > 0);
}

/** Instrumentos agrupados por família (a ordem de chegada do banco é mantida). */
export function agruparInstrumentos(
  instrumentos: InstrumentoEntrada[]
): { familia: string; itens: InstrumentoEntrada[] }[] {
  const grupos = new Map<string, InstrumentoEntrada[]>();
  for (const item of instrumentos) {
    const lista = grupos.get(item.familia) ?? [];
    lista.push(item);
    grupos.set(item.familia, lista);
  }
  return [...grupos.entries()].map(([familia, itens]) => ({ familia, itens }));
}

/** Como a entrada sem cadastro aparece na lista: "Candidato · tocando Clarinete". */
export function descreverAvulsa(entrada: {
  linha_rotulo: string;
  toca: boolean | null;
  instrumento: string | null;
}): string {
  if (entrada.toca === false) return `${entrada.linha_rotulo} · não vai tocar`;
  if (entrada.instrumento) return `${entrada.linha_rotulo} · ${entrada.instrumento}`;
  return entrada.linha_rotulo;
}
""",
  'src/modules/atendimento/regrasEntrada.test.ts': r"""import { describe, expect, it } from "vitest";
import {
  agruparInstrumentos,
  agruparLinhas,
  descreverAvulsa,
  precisaInstrumento,
  textoDaLocalidade,
  validarEntradaAvulsa,
  validarEscolhaMembro,
  valoresDaEntrada,
} from "./regrasEntrada";
import type { InfoEntrada, LinhaEntrada } from "./tiposEntrada";

const info = (extra: Partial<InfoEntrada> = {}): InfoEntrada => ({
  linha_codigo: "MUS_ENC_LOCAL",
  linha_rotulo: "Encarregado Local",
  bloco: "MUSICOS",
  pergunta_toca: true,
  instrumento_id: null,
  instrumento: null,
  ...extra,
});
const linha = (extra: Partial<LinhaEntrada> = {}): LinhaEntrada => ({
  codigo: "MUS_CANDIDATO",
  bloco: "MUSICOS",
  rotulo: "Candidato",
  pergunta_toca: true,
  toca_sempre: false,
  instrumento: "LIVRE",
  ...extra,
});

describe("validarEscolhaMembro", () => {
  it("sem pergunta não exige nada", () => {
    expect(validarEscolhaMembro(info({ pergunta_toca: false }), { toca: null, instrumentoId: "" })).toBeNull();
    expect(validarEscolhaMembro(null, { toca: null, instrumentoId: "" })).toBeNull();
  });
  it("com pergunta exige a resposta", () => {
    expect(validarEscolhaMembro(info(), { toca: null, instrumentoId: "" })).toMatch(/vai tocar/);
  });
  it("quem vai tocar precisa de instrumento (do cadastro ou escolhido)", () => {
    expect(validarEscolhaMembro(info(), { toca: true, instrumentoId: "" })).toMatch(/instrumento/);
    expect(validarEscolhaMembro(info(), { toca: true, instrumentoId: "i1" })).toBeNull();
    expect(validarEscolhaMembro(info({ instrumento_id: "i9" }), { toca: true, instrumentoId: "" })).toBeNull();
    expect(validarEscolhaMembro(info(), { toca: false, instrumentoId: "" })).toBeNull();
  });
});

describe("valoresDaEntrada", () => {
  it("envia só o necessário", () => {
    expect(valoresDaEntrada(info({ pergunta_toca: false }), { toca: true, instrumentoId: "i1" })).toEqual({ toca: null, instrumentoId: null });
    expect(valoresDaEntrada(info(), { toca: true, instrumentoId: "i1" })).toEqual({ toca: true, instrumentoId: "i1" });
    expect(valoresDaEntrada(info(), { toca: true, instrumentoId: "" })).toEqual({ toca: true, instrumentoId: null });
    expect(valoresDaEntrada(info(), { toca: false, instrumentoId: "i1" })).toEqual({ toca: false, instrumentoId: null });
  });
});

describe("entrada sem cadastro", () => {
  it("precisaInstrumento", () => {
    expect(precisaInstrumento(linha(), true)).toBe(true);
    expect(precisaInstrumento(linha(), false)).toBe(false);
    expect(precisaInstrumento(linha(), null)).toBe(false);
    expect(precisaInstrumento(linha({ pergunta_toca: false, toca_sempre: true }), null)).toBe(true); // Músico
    expect(precisaInstrumento(linha({ instrumento: "ORGAO", pergunta_toca: false }), null)).toBe(false); // Organista
    expect(precisaInstrumento(linha({ instrumento: "NENHUM", pergunta_toca: false }), null)).toBe(false); // Ancião
  });

  it("validarEntradaAvulsa", () => {
    const base = { linha: linha(), toca: true, instrumentoId: "i1", outraLocalidade: false, localidadeTexto: "" };
    expect(validarEntradaAvulsa(base)).toBeNull();
    expect(validarEntradaAvulsa({ ...base, linha: null })).toMatch(/cargo/);
    expect(validarEntradaAvulsa({ ...base, toca: null })).toMatch(/vai tocar/);
    expect(validarEntradaAvulsa({ ...base, instrumentoId: "" })).toMatch(/instrumento/);
    expect(validarEntradaAvulsa({ ...base, toca: false, instrumentoId: "" })).toBeNull();
    expect(validarEntradaAvulsa({ ...base, outraLocalidade: true, localidadeTexto: " a " })).toMatch(/localidade/i);
    expect(validarEntradaAvulsa({ ...base, outraLocalidade: true, localidadeTexto: "Itaju do Colônia" })).toBeNull();
    // sem localidade é permitido (campo opcional)
    expect(validarEntradaAvulsa({ ...base, outraLocalidade: false, localidadeTexto: "" })).toBeNull();
  });

  it("textoDaLocalidade", () => {
    expect(textoDaLocalidade(false, "x y")).toBeNull();
    expect(textoDaLocalidade(true, "   ")).toBeNull();
    expect(textoDaLocalidade(true, "  Itaju   do  Colônia ")).toBe("Itaju do Colônia");
  });
});

describe("listas", () => {
  it("agruparLinhas segue Ministério, Músicos, Organistas", () => {
    const grupos = agruparLinhas([
      linha({ codigo: "o", bloco: "ORGANISTAS" }),
      linha({ codigo: "m", bloco: "MINISTERIO" }),
      linha({ codigo: "u", bloco: "MUSICOS" }),
    ]);
    expect(grupos.map((g) => g.bloco)).toEqual(["MINISTERIO", "MUSICOS", "ORGANISTAS"]);
    expect(agruparLinhas([linha({ bloco: "MUSICOS" })]).length).toBe(1);
  });
  it("agruparInstrumentos por família", () => {
    const g = agruparInstrumentos([
      { id: "1", nome: "Violino", familia: "Cordas" },
      { id: "2", nome: "Viola", familia: "Cordas" },
      { id: "3", nome: "Flauta", familia: "Madeiras" },
    ]);
    expect(g.map((x) => [x.familia, x.itens.length])).toEqual([["Cordas", 2], ["Madeiras", 1]]);
  });
  it("descreverAvulsa", () => {
    expect(descreverAvulsa({ linha_rotulo: "Candidato", toca: true, instrumento: "Clarinete" })).toBe("Candidato · Clarinete");
    expect(descreverAvulsa({ linha_rotulo: "Candidato", toca: false, instrumento: null })).toBe("Candidato · não vai tocar");
    expect(descreverAvulsa({ linha_rotulo: "Ancião", toca: null, instrumento: null })).toBe("Ancião");
  });
});
""",
  'src/modules/atendimento/services/entrada.ts': r"""/**
 * SysMúsica — Serviço de dados da entrada com "Vai tocar?" e da entrada SEM cadastro (migração 0028).
 * Toda regra é aplicada pelo banco; a tela só chama e mostra o resultado.
 */
import { supabase } from "@/lib/supabase";
import { mensagemDoErro } from "@/lib/erros";
import type { EntradaAvulsa, InfoEntrada, LocalidadeBusca, OpcoesEntrada } from "../tiposEntrada";

/** Como o membro é contado e se a Portaria precisa perguntar "Vai tocar?". */
export async function infoEntrada(portariaId: string, membroId: string): Promise<InfoEntrada> {
  const { data, error } = await supabase.rpc("info_entrada", { p_portaria_id: portariaId, p_membro_id: membroId });
  if (error || !data) {
    throw new Error(error ? mensagemDoErro(error, "Não foi possível consultar os dados da entrada.") : "Membro não encontrado.");
  }
  return data as unknown as InfoEntrada;
}

/** Linhas do painel e instrumentos para a entrada sem cadastro e para a pergunta "Vai tocar?". */
export async function opcoesEntrada(): Promise<OpcoesEntrada> {
  const { data, error } = await supabase.rpc("opcoes_entrada");
  if (error || !data) {
    throw new Error(error ? mensagemDoErro(error, "Não foi possível carregar as opções da entrada.") : "Opções da entrada indisponíveis.");
  }
  return data as unknown as OpcoesEntrada;
}

/** Busca de localidade (casa de oração) pelas primeiras letras; mínimo de 2 letras. */
export async function buscarLocalidades(termo: string): Promise<LocalidadeBusca[]> {
  const { data, error } = await supabase.rpc("buscar_localidades", { p_termo: termo });
  if (error) throw new Error(mensagemDoErro(error, "Não foi possível buscar a localidade."));
  return (data ?? []) as LocalidadeBusca[];
}

/** Registra a entrada de alguém SEM cadastro (candidato, visitante...). Não cria membro. */
export async function registrarEntradaAvulsa(
  portariaId: string,
  dados: {
    linhaCodigo: string;
    toca: boolean | null;
    instrumentoId: string | null;
    origemComumId: string | null;
    origemTexto: string | null;
  }
): Promise<void> {
  const { error } = await supabase.rpc("registrar_entrada_avulsa", {
    p_portaria_id: portariaId,
    p_linha_codigo: dados.linhaCodigo,
    p_toca: dados.toca,
    p_instrumento_id: dados.instrumentoId,
    p_origem_comum_id: dados.origemComumId,
    p_origem_texto: dados.origemTexto,
  });
  if (error) throw new Error(mensagemDoErro(error, "Não foi possível registrar a entrada."));
}

/** Desfaz uma entrada sem cadastro (quem registrou, ou quem pode excluir registros). */
export async function desfazerEntradaAvulsa(id: string): Promise<void> {
  const { error } = await supabase.rpc("desfazer_entrada_avulsa", { p_id: id });
  if (error) throw new Error(mensagemDoErro(error, "Não foi possível desfazer a entrada."));
}

/** Últimas entradas sem cadastro da portaria (e o total). */
export async function entradasAvulsasDaPortaria(portariaId: string): Promise<EntradaAvulsa[]> {
  const { data, error } = await supabase.rpc("entradas_avulsas_da_portaria", { p_portaria_id: portariaId });
  if (error) throw new Error(mensagemDoErro(error, "Não foi possível carregar as entradas sem cadastro."));
  return (data ?? []) as EntradaAvulsa[];
}
""",
  'src/modules/atendimento/components/PerguntaToca.tsx': r""""use client";

/**
 * SysMúsica — Pergunta "Vai tocar?" (Sim / Não) e, quando for tocar, a escolha do instrumento.
 * Usada na conferência do membro cadastrado e na entrada sem cadastro.
 * Se o membro já tem instrumento no cadastro, ele aparece como sugestão e a Portaria só troca se for outro.
 */
import { agruparInstrumentos } from "../regrasEntrada";
import type { InstrumentoEntrada } from "../tiposEntrada";

interface PerguntaTocaProps {
  /** Mostra a pergunta "Vai tocar?" (as linhas que sempre tocam só pedem o instrumento). */
  perguntar: boolean;
  /** Mostra o campo do instrumento (quando vai tocar ou quando a linha sempre toca). */
  pedirInstrumento: boolean;
  toca: boolean | null;
  onToca: (valor: boolean) => void;
  instrumentoId: string;
  onInstrumento: (id: string) => void;
  instrumentos: InstrumentoEntrada[];
  /** Instrumento já cadastrado do membro (sugestão), se houver. */
  instrumentoCadastro?: string | null;
  desabilitado?: boolean;
  /** Prefixo para os ids dos campos (a tela pode ter mais de uma pergunta). */
  prefixo: string;
}

export default function PerguntaToca({
  perguntar,
  pedirInstrumento,
  toca,
  onToca,
  instrumentoId,
  onInstrumento,
  instrumentos,
  instrumentoCadastro = null,
  desabilitado = false,
  prefixo,
}: PerguntaTocaProps) {
  const grupos = agruparInstrumentos(instrumentos);

  return (
    <div className="space-y-3">
      {perguntar && (
        <fieldset disabled={desabilitado} className="space-y-2">
          <legend className="text-sm font-medium text-slate-700">Vai tocar?</legend>
          <div className="grid grid-cols-2 gap-2">
            {[
              { valor: true, rotulo: "Sim, vai tocar" },
              { valor: false, rotulo: "Não vai tocar" },
            ].map((opcao) => (
              <label
                key={String(opcao.valor)}
                className={
                  "flex cursor-pointer items-center justify-center rounded-lg border px-3 py-3 text-sm font-medium transition " +
                  (toca === opcao.valor
                    ? "border-brand-600 bg-brand-50 text-brand-700"
                    : "border-slate-300 bg-white text-slate-700 hover:bg-slate-50")
                }
              >
                <input
                  type="radio"
                  name={`${prefixo}-toca`}
                  checked={toca === opcao.valor}
                  onChange={() => onToca(opcao.valor)}
                  className="sr-only"
                />
                {opcao.rotulo}
              </label>
            ))}
          </div>
        </fieldset>
      )}

      {pedirInstrumento && (
        <div className="space-y-1.5">
          <label htmlFor={`${prefixo}-instrumento`} className="text-sm font-medium text-slate-700">
            Instrumento
            {instrumentoCadastro ? (
              <span className="font-normal text-slate-500"> (no cadastro: {instrumentoCadastro})</span>
            ) : null}
          </label>
          <select
            id={`${prefixo}-instrumento`}
            value={instrumentoId}
            onChange={(e) => onInstrumento(e.target.value)}
            disabled={desabilitado}
            className="w-full rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 shadow-sm focus:border-brand-500 focus:outline-none focus:ring-2 focus:ring-brand-200 disabled:opacity-60"
          >
            <option value="">
              {instrumentoCadastro ? `Usar o do cadastro (${instrumentoCadastro})` : "Selecione o instrumento"}
            </option>
            {grupos.map((grupo) => (
              <optgroup key={grupo.familia} label={grupo.familia}>
                {grupo.itens.map((item) => (
                  <option key={item.id} value={item.id}>
                    {item.nome}
                  </option>
                ))}
              </optgroup>
            ))}
          </select>
        </div>
      )}
    </div>
  );
}
""",
  'src/modules/atendimento/components/BuscaLocalidade.tsx': r""""use client";

/**
 * SysMúsica — Localidade de origem (opcional) de quem entra sem cadastro.
 * Busca pelas primeiras letras do nome da casa de oração (a partir de 2 letras) ou, se não estiver na lista,
 * "Outra localidade" com texto livre. Sem escolher nada também é permitido.
 */
import { useRef, useState } from "react";
import { buscarLocalidades } from "../services/entrada";
import type { LocalidadeBusca } from "../tiposEntrada";

interface BuscaLocalidadeProps {
  escolhida: LocalidadeBusca | null;
  onEscolher: (localidade: LocalidadeBusca | null) => void;
  outra: boolean;
  onOutra: (valor: boolean) => void;
  texto: string;
  onTexto: (valor: string) => void;
  desabilitado?: boolean;
}

const classeInput =
  "w-full rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 shadow-sm placeholder:text-slate-400 focus:border-brand-500 focus:outline-none focus:ring-2 focus:ring-brand-200 disabled:opacity-60";

export default function BuscaLocalidade({
  escolhida,
  onEscolher,
  outra,
  onOutra,
  texto,
  onTexto,
  desabilitado = false,
}: BuscaLocalidadeProps) {
  const [termo, setTermo] = useState("");
  const [resultados, setResultados] = useState<LocalidadeBusca[]>([]);
  const [buscando, setBuscando] = useState(false);
  const [erro, setErro] = useState<string | null>(null);
  const temporizador = useRef<ReturnType<typeof setTimeout> | null>(null);
  const contador = useRef(0); // ignora respostas antigas quando a pessoa continua digitando

  // A busca espera 300 ms depois da última letra para não consultar a cada tecla
  function aoDigitar(valor: string) {
    setTermo(valor);
    setErro(null);
    if (temporizador.current) clearTimeout(temporizador.current);
    const atual = ++contador.current;

    if (valor.trim().length < 2) {
      setResultados([]);
      setBuscando(false);
      return;
    }
    setBuscando(true);
    temporizador.current = setTimeout(() => {
      buscarLocalidades(valor.trim())
        .then((lista) => {
          if (atual === contador.current) setResultados(lista);
        })
        .catch((e: unknown) => {
          if (atual === contador.current) {
            setResultados([]);
            setErro(e instanceof Error ? e.message : "Não foi possível buscar a localidade.");
          }
        })
        .finally(() => {
          if (atual === contador.current) setBuscando(false);
        });
    }, 300);
  }

  function escolher(localidade: LocalidadeBusca) {
    onEscolher(localidade);
    setTermo("");
    setResultados([]);
  }

  return (
    <fieldset className="space-y-3" disabled={desabilitado}>
      <legend className="text-sm font-medium text-slate-700">
        Localidade de origem <span className="font-normal text-slate-500">(opcional)</span>
      </legend>

      {escolhida ? (
        <div className="flex items-start justify-between gap-3 rounded-lg border border-emerald-200 bg-emerald-50 px-3 py-2">
          <div className="min-w-0 text-sm">
            <p className="font-medium text-emerald-900">{escolhida.nome}</p>
            <p className="text-xs text-emerald-800">{escolhida.caminho}</p>
          </div>
          <button
            type="button"
            onClick={() => onEscolher(null)}
            className="shrink-0 text-xs font-semibold text-emerald-900 hover:underline"
          >
            Trocar
          </button>
        </div>
      ) : (
        !outra && (
          <div className="space-y-2">
            <label htmlFor="busca-localidade" className="sr-only">
              Buscar a casa de oração pelas primeiras letras
            </label>
            <input
              id="busca-localidade"
              type="search"
              autoComplete="off"
              value={termo}
              onChange={(e) => aoDigitar(e.target.value)}
              placeholder="Digite as primeiras letras da casa de oração"
              className={classeInput}
            />
            {termo.trim().length > 0 && termo.trim().length < 2 && (
              <p className="text-xs text-slate-500">Digite pelo menos 2 letras.</p>
            )}
            {buscando && <p className="text-xs text-slate-500">Buscando...</p>}
            {erro && (
              <p role="alert" className="rounded-lg bg-red-50 px-3 py-2 text-xs text-red-700">
                {erro}
              </p>
            )}
            {!buscando && !erro && termo.trim().length >= 2 && resultados.length === 0 && (
              <p className="text-xs text-slate-500">Nenhuma casa de oração encontrada. Use &quot;Outra localidade&quot;.</p>
            )}
            {resultados.length > 0 && (
              <ul className="max-h-56 divide-y divide-slate-100 overflow-y-auto rounded-lg border border-slate-200">
                {resultados.map((item) => (
                  <li key={item.comum_id}>
                    <button
                      type="button"
                      onClick={() => escolher(item)}
                      className="block w-full px-3 py-2 text-left transition hover:bg-slate-50"
                    >
                      <span className="block text-sm font-medium text-slate-900">{item.nome}</span>
                      <span className="block text-xs text-slate-500">{item.caminho}</span>
                    </button>
                  </li>
                ))}
              </ul>
            )}
          </div>
        )
      )}

      {!escolhida && (
        <label className="flex items-start gap-2 text-sm text-slate-700">
          <input
            type="checkbox"
            checked={outra}
            onChange={(e) => onOutra(e.target.checked)}
            className="mt-0.5 h-4 w-4 rounded border-slate-300 text-brand-600 focus:ring-brand-300"
          />
          Outra localidade (não está na lista)
        </label>
      )}

      {outra && !escolhida && (
        <div className="space-y-1.5">
          <label htmlFor="localidade-outra" className="sr-only">
            Nome da localidade
          </label>
          <input
            id="localidade-outra"
            type="text"
            maxLength={120}
            value={texto}
            onChange={(e) => onTexto(e.target.value)}
            placeholder="Ex.: Itaju do Colônia - BA"
            className={classeInput}
          />
        </div>
      )}
    </fieldset>
  );
}
""",
  'src/modules/atendimento/components/EntradaSemCadastro.tsx': r""""use client";

/**
 * SysMúsica — Entrada SEM cadastro (candidato, visitante...). Não cria membro: registra só o cargo/categoria,
 * se vai tocar, o instrumento e a localidade de origem (opcional). A entrada entra na contagem do painel ao vivo.
 */
import { useState, type FormEvent } from "react";
import Button from "@/components/ui/Button";
import {
  agruparLinhas,
  precisaInstrumento,
  precisaPerguntar,
  textoDaLocalidade,
  validarEntradaAvulsa,
} from "../regrasEntrada";
import { registrarEntradaAvulsa } from "../services/entrada";
import type { LinhaEntrada, LocalidadeBusca, OpcoesEntrada } from "../tiposEntrada";
import BuscaLocalidade from "./BuscaLocalidade";
import PerguntaToca from "./PerguntaToca";

interface EntradaSemCadastroProps {
  portariaId: string;
  opcoes: OpcoesEntrada;
  onRegistrada: (descricao: string) => void;
}

export default function EntradaSemCadastro({ portariaId, opcoes, onRegistrada }: EntradaSemCadastroProps) {
  const [linhaCodigo, setLinhaCodigo] = useState("");
  const [toca, setToca] = useState<boolean | null>(null);
  const [instrumentoId, setInstrumentoId] = useState("");
  const [localidade, setLocalidade] = useState<LocalidadeBusca | null>(null);
  const [outra, setOutra] = useState(false);
  const [texto, setTexto] = useState("");
  const [salvando, setSalvando] = useState(false);
  const [erro, setErro] = useState<string | null>(null);

  const linha: LinhaEntrada | null = opcoes.linhas.find((item) => item.codigo === linhaCodigo) ?? null;
  const perguntar = precisaPerguntar(linha);
  const pedirInstrumento = precisaInstrumento(linha, toca);

  // Trocar a linha limpa as respostas que dependem dela
  function escolherLinha(codigo: string) {
    setLinhaCodigo(codigo);
    setToca(null);
    setInstrumentoId("");
    setErro(null);
  }

  async function salvar(submissao: FormEvent<HTMLFormElement>) {
    submissao.preventDefault();
    if (salvando) return;

    const mensagem = validarEntradaAvulsa({ linha, toca, instrumentoId, outraLocalidade: outra, localidadeTexto: texto });
    if (mensagem) return setErro(mensagem);

    setSalvando(true);
    setErro(null);
    try {
      await registrarEntradaAvulsa(portariaId, {
        linhaCodigo,
        toca: perguntar ? toca : null,
        instrumentoId: pedirInstrumento ? instrumentoId : null,
        origemComumId: localidade?.comum_id ?? null,
        origemTexto: localidade ? null : textoDaLocalidade(outra, texto),
      });
      onRegistrada(linha?.rotulo ?? "Entrada sem cadastro");
    } catch (e) {
      setErro(e instanceof Error ? e.message : "Não foi possível registrar a entrada.");
    } finally {
      setSalvando(false);
    }
  }

  return (
    <form onSubmit={salvar} noValidate className="space-y-5">
      <p className="rounded-lg bg-slate-50 px-3 py-2 text-sm text-slate-600">
        Não cria cadastro. A pessoa só entra na contagem do evento.
      </p>

      <div className="space-y-1.5">
        <label htmlFor="avulsa-linha" className="text-sm font-medium text-slate-700">
          Cargo / categoria
        </label>
        <select
          id="avulsa-linha"
          value={linhaCodigo}
          onChange={(e) => escolherLinha(e.target.value)}
          disabled={salvando}
          className="w-full rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 shadow-sm focus:border-brand-500 focus:outline-none focus:ring-2 focus:ring-brand-200 disabled:opacity-60"
        >
          <option value="">Selecione</option>
          {agruparLinhas(opcoes.linhas).map((grupo) => (
            <optgroup key={grupo.bloco} label={grupo.rotulo}>
              {grupo.linhas.map((item) => (
                <option key={item.codigo} value={item.codigo}>
                  {item.rotulo}
                </option>
              ))}
            </optgroup>
          ))}
        </select>
      </div>

      {(perguntar || pedirInstrumento) && (
        <PerguntaToca
          prefixo="avulsa"
          perguntar={perguntar}
          pedirInstrumento={pedirInstrumento}
          toca={toca}
          onToca={(valor) => {
            setToca(valor);
            if (!valor) setInstrumentoId("");
          }}
          instrumentoId={instrumentoId}
          onInstrumento={setInstrumentoId}
          instrumentos={opcoes.instrumentos}
          desabilitado={salvando}
        />
      )}

      <BuscaLocalidade
        escolhida={localidade}
        onEscolher={setLocalidade}
        outra={outra}
        onOutra={setOutra}
        texto={texto}
        onTexto={setTexto}
        desabilitado={salvando}
      />

      {erro && (
        <p role="alert" className="rounded-lg bg-red-50 px-3 py-2 text-sm text-red-700">
          {erro}
        </p>
      )}

      <Button type="submit" disabled={salvando} className="w-full py-3 text-base">
        {salvando ? "Registrando..." : "Registrar entrada"}
      </Button>
    </form>
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

for caminho in NOVOS:
    if os.path.exists(caminho):
        print("ERRO: já existe", caminho); sys.exit(1)

edicoes = {}

# ---------- Serviço: registrarEntrada leva a resposta de "Vai tocar?" e o instrumento ----------
a = "src/modules/atendimento/services/atendimento.ts"
s = abrir(a)
s = trocar(s,
  "  membroId: string,\n  origem: OrigemEntrada\n): Promise<void> {\n  const { error } = await supabase.rpc(\"registrar_entrada\", {\n    p_portaria_id: portariaId,\n    p_membro_id: membroId,\n    p_origem: origem,\n  });",
  "  membroId: string,\n  origem: OrigemEntrada,\n  toca: boolean | null = null, // resposta de \"Vai tocar?\" (só para quem a Portaria pergunta)\n  instrumentoId: string | null = null // instrumento escolhido na entrada (vazio = o do cadastro)\n): Promise<void> {\n  const { error } = await supabase.rpc(\"registrar_entrada\", {\n    p_portaria_id: portariaId,\n    p_membro_id: membroId,\n    p_origem: origem,\n    p_toca: toca,\n    p_instrumento_id: instrumentoId,\n  });", a)
edicoes[a] = s

# ---------- Conferência: mostra como a pessoa será contada e pergunta "Vai tocar?" ----------
a = "src/modules/atendimento/components/CartaoConferencia.tsx"
s = abrir(a)
s = trocar(s, 'import { horaCurta } from "../regras";\nimport type { CartaoMembro, OrigemEntrada } from "../tipos";\n',
  'import { horaCurta } from "../regras";\nimport { validarEscolhaMembro } from "../regrasEntrada";\nimport type { CartaoMembro, OrigemEntrada } from "../tipos";\n'
  'import type { EscolhaToca, InfoEntrada, InstrumentoEntrada } from "../tiposEntrada";\nimport PerguntaToca from "./PerguntaToca";\n', a)
s = trocar(s, "  podeFoto?: boolean;\n  onFotoSalva?: () => Promise<void>;\n}",
  "  podeFoto?: boolean;\n  onFotoSalva?: () => Promise<void>;\n"
  "  /** Como a pessoa será contada e se a Portaria precisa perguntar \"Vai tocar?\". */\n  info?: InfoEntrada | null;\n"
  "  instrumentos?: InstrumentoEntrada[];\n  escolha?: EscolhaToca;\n  onEscolha?: (escolha: EscolhaToca) => void;\n}", a)
s = trocar(s, "  podeFoto = false,\n  onFotoSalva,\n}: CartaoConferenciaProps) {",
  "  podeFoto = false,\n  onFotoSalva,\n  info = null,\n  instrumentos = [],\n  escolha = { toca: null, instrumentoId: \"\" },\n  onEscolha,\n}: CartaoConferenciaProps) {", a)
s = trocar(s, "  const podeConfirmar = !inativo && !jaRegistrado && !registrando && (!manual || conferi);\n",
  "  // \"Vai tocar?\": quando a Portaria precisa perguntar, a resposta é obrigatória (o banco confere de novo)\n"
  "  const respondeu = validarEscolhaMembro(info, escolha) === null;\n"
  "  const podeConfirmar = !inativo && !jaRegistrado && !registrando && (!manual || conferi) && respondeu;\n", a)
s = trocar(s, '    { rotulo: "Localidade", valor: [membro.bairro, membro.cidade].filter(Boolean).join(", ") || null },\n  ];',
  '    { rotulo: "Localidade", valor: [membro.bairro, membro.cidade].filter(Boolean).join(", ") || null },\n'
  '    { rotulo: "Conta no painel como", valor: info?.linha_rotulo ?? null },\n  ];', a)
s = trocar(s, "        {manual && !inativo && !jaRegistrado && (\n          <label className=\"mt-4 flex items-start gap-2 text-sm text-slate-700\">",
  "        {info?.pergunta_toca && !inativo && !jaRegistrado && onEscolha && (\n"
  "          <div className=\"mt-4\">\n"
  "            <PerguntaToca\n"
  "              prefixo=\"conferencia\"\n"
  "              perguntar\n"
  "              pedirInstrumento={escolha.toca === true}\n"
  "              toca={escolha.toca}\n"
  "              onToca={(valor) => onEscolha({ toca: valor, instrumentoId: valor ? escolha.instrumentoId : \"\" })}\n"
  "              instrumentoId={escolha.instrumentoId}\n"
  "              onInstrumento={(id) => onEscolha({ ...escolha, instrumentoId: id })}\n"
  "              instrumentos={instrumentos}\n"
  "              instrumentoCadastro={info.instrumento}\n"
  "              desabilitado={registrando}\n"
  "            />\n"
  "          </div>\n"
  "        )}\n\n"
  "        {manual && !inativo && !jaRegistrado && (\n          <label className=\"mt-4 flex items-start gap-2 text-sm text-slate-700\">", a)
edicoes[a] = s

# ---------- Últimas entradas: inclui as entradas sem cadastro (com "Desfazer") ----------
a = "src/modules/atendimento/components/EntradasRecentes.tsx"
s = abrir(a)
s = trocar(s, 'import { horaCurta } from "../regras";\nimport type { EntradaRecente } from "../tipos";\n',
  'import { horaCurta } from "../regras";\nimport { descreverAvulsa } from "../regrasEntrada";\nimport type { EntradaRecente } from "../tipos";\nimport type { EntradaAvulsa } from "../tiposEntrada";\n', a)
s = trocar(s, "export default function EntradasRecentes({ entradas }: { entradas: EntradaRecente[] }) {",
  "interface EntradasRecentesProps {\n  entradas: EntradaRecente[];\n  avulsas?: EntradaAvulsa[]; // entradas sem cadastro\n  onDesfazerAvulsa?: (id: string) => void;\n}\n\n"
  "export default function EntradasRecentes({ entradas, avulsas = [], onDesfazerAvulsa }: EntradasRecentesProps) {", a)
s = trocar(s, "      )}\n    </section>\n  );\n}",
  "      )}\n\n"
  "      {avulsas.length > 0 && (\n"
  "        <div className=\"mt-5 border-t border-slate-100 pt-4\">\n"
  "          <h3 className=\"text-sm font-semibold text-slate-900\">Sem cadastro</h3>\n"
  "          <p className=\"mt-1 text-xs text-slate-500\">{avulsas[0]?.total ?? avulsas.length} registro(s) nesta portaria</p>\n"
  "          <ul className=\"mt-3 divide-y divide-slate-100\">\n"
  "            {avulsas.map((entrada) => (\n"
  "              <li key={entrada.id} className=\"flex items-center justify-between gap-3 py-2\">\n"
  "                <div className=\"min-w-0\">\n"
  "                  <p className=\"truncate text-sm font-medium text-slate-900\">{descreverAvulsa(entrada)}</p>\n"
  "                  <p className=\"truncate text-xs text-slate-500\">{entrada.origem ?? \"Localidade não informada\"}</p>\n"
  "                </div>\n"
  "                <div className=\"flex shrink-0 items-center gap-3\">\n"
  "                  <span className=\"text-sm tabular-nums text-slate-600\">{horaCurta(entrada.hora_entrada)}</span>\n"
  "                  {onDesfazerAvulsa && (\n"
  "                    <button\n"
  "                      type=\"button\"\n"
  "                      onClick={() => onDesfazerAvulsa(entrada.id)}\n"
  "                      className=\"text-xs font-semibold text-red-700 hover:underline\"\n"
  "                    >\n"
  "                      Desfazer\n"
  "                    </button>\n"
  "                  )}\n"
  "                </div>\n"
  "              </li>\n"
  "            ))}\n"
  "          </ul>\n"
  "        </div>\n"
  "      )}\n"
  "    </section>\n  );\n}", a)
edicoes[a] = s

# ---------- Tela da Portaria ----------
a = "src/modules/atendimento/components/AtendimentoPortaria.tsx"
s = abrir(a)
s = trocar(s, 'import type { CartaoMembro, EntradaRecente, OrigemEntrada } from "../tipos";\n',
  'import { valoresDaEntrada } from "../regrasEntrada";\n'
  'import { desfazerEntradaAvulsa, entradasAvulsasDaPortaria, infoEntrada, opcoesEntrada } from "../services/entrada";\n'
  'import type { CartaoMembro, EntradaRecente, OrigemEntrada } from "../tipos";\n'
  'import type { EntradaAvulsa, EscolhaToca, InfoEntrada, OpcoesEntrada } from "../tiposEntrada";\n', a)
s = trocar(s, 'import FormularioVisitante from "./FormularioVisitante";\n', 'import EntradaSemCadastro from "./EntradaSemCadastro";\n', a)
s = trocar(s, "  const [cadastrandoVisitante, setCadastrandoVisitante] = useState(false);\n",
  "  const [semCadastro, setSemCadastro] = useState(false); // janela da entrada sem cadastro\n"
  "  const [avulsas, setAvulsas] = useState<EntradaAvulsa[]>([]); // entradas sem cadastro desta portaria\n"
  "  const [opcoes, setOpcoes] = useState<OpcoesEntrada | null>(null); // linhas do painel e instrumentos\n"
  "  const [info, setInfo] = useState<InfoEntrada | null>(null); // como o membro conferido será contado\n"
  "  const [escolha, setEscolha] = useState<EscolhaToca>({ toca: null, instrumentoId: \"\" }); // resposta de \"Vai tocar?\"\n", a)
s = trocar(s, "      setEntradas(await entradasDaPortaria(id));\n",
  "      const [lista, semCadastroLista] = await Promise.all([entradasDaPortaria(id), entradasAvulsasDaPortaria(id)]);\n"
  "      setEntradas(lista);\n      setAvulsas(semCadastroLista);\n", a)
s = trocar(s, "    if (portariaId) void carregarEntradas(portariaId);\n  }, [portariaId, carregarEntradas]);\n  /* eslint-enable react-hooks/set-state-in-effect */",
  "    if (portariaId) void carregarEntradas(portariaId);\n  }, [portariaId, carregarEntradas]);\n\n"
  "  // Linhas do painel e instrumentos (uma vez só): usados na pergunta \"Vai tocar?\" e na entrada sem cadastro\n"
  "  useEffect(() => {\n"
  "    opcoesEntrada()\n"
  "      .then(setOpcoes)\n"
  "      .catch((e: unknown) => console.error(\"Falha ao carregar as opções da entrada:\", e));\n"
  "  }, []);\n  /* eslint-enable react-hooks/set-state-in-effect */", a)
s = trocar(s, "    setEntradas([]);\n    setCartao(null);\n", "    setEntradas([]);\n    setAvulsas([]);\n    setCartao(null);\n", a)
s = trocar(s, "      const membro = await buscarMembroPorQr(portariaId, texto);\n      setErroCartao(null);\n      setCartao({ membro, origem: \"QR\" });\n",
  "      const membro = await buscarMembroPorQr(portariaId, texto);\n      await abrirCartao(membro, \"QR\");\n", a)
s = trocar(s,
  "  // Visitante cadastrado: abre a conferência para registrar a entrada\n"
  "  function aoCadastrarVisitante(membro: CartaoMembro) {\n"
  "    setCadastrandoVisitante(false);\n"
  "    setErroCartao(null);\n"
  "    setCartao({ membro, origem: \"MANUAL\" });\n"
  "  }\n\n"
  "  // Membro localizado pelo nome: abre a conferência\n"
  "  function aoEscolherPorNome(membro: CartaoMembro) {\n"
  "    setErroCartao(null);\n"
  "    setCartao({ membro, origem: \"MANUAL\" });\n"
  "  }\n",
  "  // Abre a conferência: antes, consulta se a pessoa precisa responder \"Vai tocar?\"\n"
  "  async function abrirCartao(membro: CartaoMembro, origem: OrigemEntrada) {\n"
  "    if (!portariaId) return;\n"
  "    try {\n"
  "      setInfo(await infoEntrada(portariaId, membro.membro_id));\n"
  "      setEscolha({ toca: null, instrumentoId: \"\" });\n"
  "      setErroCartao(null);\n"
  "      setCartao({ membro, origem });\n"
  "    } catch (e) {\n"
  "      setErroLeitura(e instanceof Error ? e.message : \"Não foi possível abrir a conferência.\");\n"
  "    }\n"
  "  }\n\n"
  "  // Membro localizado pelo nome: abre a conferência\n"
  "  function aoEscolherPorNome(membro: CartaoMembro) {\n"
  "    void abrirCartao(membro, \"MANUAL\");\n"
  "  }\n\n"
  "  // Entrada sem cadastro registrada: fecha a janela e atualiza as listas\n"
  "  async function aoRegistrarSemCadastro(descricao: string) {\n"
  "    setSemCadastro(false);\n"
  "    setAviso(`Entrada sem cadastro registrada: ${descricao}`);\n"
  "    if (portariaId) await carregarEntradas(portariaId);\n"
  "  }\n\n"
  "  // Desfaz uma entrada sem cadastro (pede confirmação)\n"
  "  async function desfazerSemCadastro(id: string) {\n"
  "    if (!portariaId || !window.confirm(\"Desfazer esta entrada sem cadastro?\")) return;\n"
  "    try {\n"
  "      await desfazerEntradaAvulsa(id);\n"
  "      setAviso(\"Entrada desfeita.\");\n"
  "      await carregarEntradas(portariaId);\n"
  "    } catch (e) {\n"
  "      setErroLeitura(e instanceof Error ? e.message : \"Não foi possível desfazer a entrada.\");\n"
  "    }\n"
  "  }\n", a)
s = trocar(s, "      await registrarEntrada(portariaId, cartao.membro.membro_id, cartao.origem);\n",
  "      const valores = valoresDaEntrada(info, escolha);\n"
  "      await registrarEntrada(portariaId, cartao.membro.membro_id, cartao.origem, valores.toca, valores.instrumentoId);\n", a)
s = trocar(s,
  "              {pode(\"portaria.cadastrar_visitante\") && (\n"
  "                <section className=\"rounded-2xl border border-dashed border-slate-300 bg-white p-4 shadow-sm\">\n"
  "                  <h2 className=\"text-sm font-semibold text-slate-900\">Irmão de outra região ou sem cadastro?</h2>\n"
  "                  <p className=\"mt-1 text-xs text-slate-500\">\n"
  "                    Cadastre o visitante aqui mesmo: ele entra na comum desta portaria e você já confere e\n"
  "                    registra a entrada.\n"
  "                  </p>\n"
  "                  <button\n"
  "                    type=\"button\"\n"
  "                    onClick={() => setCadastrandoVisitante(true)}\n"
  "                    disabled={cartao !== null}\n"
  "                    className=\"mt-3 rounded-lg border border-slate-300 bg-white px-4 py-2 text-sm font-medium text-slate-700 transition hover:bg-slate-50 disabled:cursor-not-allowed disabled:opacity-60\"\n"
  "                  >\n"
  "                    Cadastrar visitante\n"
  "                  </button>\n"
  "                </section>\n"
  "              )}\n",
  "              <section className=\"rounded-2xl border border-dashed border-slate-300 bg-white p-4 shadow-sm\">\n"
  "                <h2 className=\"text-sm font-semibold text-slate-900\">Candidato, visitante ou irmão sem cadastro?</h2>\n"
  "                <p className=\"mt-1 text-xs text-slate-500\">\n"
  "                  Registre a entrada sem criar cadastro: informe o cargo ou categoria, o instrumento e de onde a\n"
  "                  pessoa vem. Ela entra na contagem do evento.\n"
  "                </p>\n"
  "                <button\n"
  "                  type=\"button\"\n"
  "                  onClick={() => setSemCadastro(true)}\n"
  "                  disabled={cartao !== null || opcoes === null}\n"
  "                  className=\"mt-3 rounded-lg border border-slate-300 bg-white px-4 py-2 text-sm font-medium text-slate-700 transition hover:bg-slate-50 disabled:cursor-not-allowed disabled:opacity-60\"\n"
  "                >\n"
  "                  Entrada sem cadastro\n"
  "                </button>\n"
  "              </section>\n", a)
s = trocar(s, "              <EntradasRecentes entradas={entradas} />\n",
  "              <EntradasRecentes entradas={entradas} avulsas={avulsas} onDesfazerAvulsa={(id) => void desfazerSemCadastro(id)} />\n", a)
s = trocar(s, "          onFotoSalva={aoSalvarFotoNoCartao}\n        />",
  "          onFotoSalva={aoSalvarFotoNoCartao}\n          info={info}\n          instrumentos={opcoes?.instrumentos ?? []}\n          escolha={escolha}\n          onEscolha={setEscolha}\n        />", a)
s = trocar(s,
  "      <Drawer\n"
  "        aberto={cadastrandoVisitante}\n"
  "        onFechar={() => setCadastrandoVisitante(false)}\n"
  "        titulo=\"Cadastrar visitante\"\n"
  "        descricao=\"O visitante vale só para a comum e a região desta portaria.\"\n"
  "      >\n"
  "        {cadastrandoVisitante && portaria && (\n"
  "          <FormularioVisitante portariaId={portaria.id} onCadastrado={aoCadastrarVisitante} />\n"
  "        )}\n"
  "      </Drawer>\n",
  "      <Drawer\n"
  "        aberto={semCadastro}\n"
  "        onFechar={() => setSemCadastro(false)}\n"
  "        titulo=\"Entrada sem cadastro\"\n"
  "        descricao=\"Candidato, visitante ou irmão sem cadastro: não cria cadastro, só conta na presença do evento.\"\n"
  "      >\n"
  "        {semCadastro && portaria && opcoes && (\n"
  "          <EntradaSemCadastro portariaId={portaria.id} opcoes={opcoes} onRegistrada={(d) => void aoRegistrarSemCadastro(d)} />\n"
  "        )}\n"
  "      </Drawer>\n", a)
edicoes[a] = s

# ---------- Auditoria: nomes legíveis das ações novas ----------
a = "src/modules/auditoria/regras.ts"
t = abrir(a)
t = trocar(t, '  presenca_fora_da_janela: "Registrou entrada fora do horário da portaria (controle total)",\n};',
  '  presenca_fora_da_janela: "Registrou entrada fora do horário da portaria (controle total)",\n'
  '  entrada_avulsa_registrada: "Registrou entrada sem cadastro",\n'
  '  entrada_avulsa_desfeita: "Desfez entrada sem cadastro",\n};', a)
t = trocar(t, '  operacoes: "Operações",\n};',
  '  operacoes: "Operações",\n'
  '  linha: "Cargo ou categoria",\n'
  '  toca: "Vai tocar",\n'
  '  localidade: "Localidade de origem",\n'
  '  sem_cadastro: "Sem cadastro",\n};', a)
edicoes[a] = t

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
npx eslint "${ALT[@]}" src/modules/atendimento || { reverter; exit 1; }
echo; echo "=== 6) Build de produção (pode demorar alguns minutos) ==="
npm run build || { reverter; exit 1; }

echo; echo "=== TUDO CERTO: arquivos gravados e conferidos ==="
git status --short | grep -v "instalar-"
echo
echo "PRÓXIMO PASSO: rodar a migração 0028 no Supabase ANTES de publicar (git push)."
) 2>&1 | tee /tmp/portaria-toca-instalar.log
