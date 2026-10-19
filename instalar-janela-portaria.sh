cd /workspaces/sysmusica/sysmusica || { echo "Pasta do projeto não encontrada"; exit 1; }
(
set -u
BKP="/tmp/bkp-janela-$(date +%H%M%S)"; mkdir -p "$BKP/a"
ALT=("src/modules/atendimento/components/AtendimentoPortaria.tsx" "src/modules/atendimento/components/SelecaoPortaria.tsx" "src/modules/portarias/components/FormularioNovaPortaria.tsx")
for f in "${ALT[@]}"; do mkdir -p "$BKP/a/$(dirname "$f")"; cp "$f" "$BKP/a/$f"; done

reverter() {
  echo ">>> REVERTENDO tudo (nada do que foi tentado fica no projeto)"
  for f in "${ALT[@]}"; do cp "$BKP/a/$f" "$f"; done
  rm -f src/modules/portarias/janela.ts src/modules/portarias/janela.test.ts supabase/migrations/0024_janela_portaria.sql
  echo ">>> REVERTIDO. Me mande o log: /tmp/janela-instalar.log"
}

echo "=== 0) Conferência prévia (só leitura) ==="
for f in "${ALT[@]}" supabase/migrations/0012_hierarquia_organizacional.sql; do
  [ -f "$f" ] || { echo "ERRO: arquivo esperado não existe: $f"; exit 1; }
done
[ -e src/modules/portarias/janela.ts ] && { echo "ERRO: a janela já parece instalada."; exit 1; }
grep -n "portarias.controle_total" src/lib/permissoes.ts | head -2

echo; echo "=== 1) Gravando os arquivos ==="
python3 - <<'PYSCRIPT'
import os, sys
NOVOS = {
  'src/modules/portarias/janela.ts': r"""/**
 * SysMúsica — Janela de atendimento da portaria (regras puras, sem banco).
 * A portaria abre 2 horas ANTES do início do evento e encerra 2 horas DEPOIS do início (horário de Salvador).
 * Ex.: ensaio às 14h -> aberta das 12h às 16h. A regra de verdade é aplicada pelo banco (migração 0024);
 * aqui ficam só os cálculos para a tela mostrar quando abre, até quando vale e se está liberada.
 */

export const HORAS_ANTES = 2;
export const HORAS_DEPOIS = 2;
const MS_HORA = 60 * 60 * 1000;
const FUSO = "America/Sao_Paulo";

export type SituacaoJanela = "antes" | "aberta" | "encerrada";

export interface JanelaPortaria {
  abre: Date;
  fecha: Date;
  situacao: SituacaoJanela;
}

/** Janela do evento no instante "agora" (ms). Nulo se o evento não tem data válida. Os limites são inclusivos. */
export function janelaDaPortaria(dataEvento: string | null, agora: number): JanelaPortaria | null {
  if (!dataEvento) return null;
  const inicio = new Date(dataEvento).getTime();
  if (Number.isNaN(inicio)) return null;

  const abre = inicio - HORAS_ANTES * MS_HORA;
  const fecha = inicio + HORAS_DEPOIS * MS_HORA;
  const situacao: SituacaoJanela = agora < abre ? "antes" : agora > fecha ? "encerrada" : "aberta";
  return { abre: new Date(abre), fecha: new Date(fecha), situacao };
}

// Dia (AAAA-MM-DD) e hora no fuso de Salvador
function diaSalvador(data: Date): string {
  return new Intl.DateTimeFormat("en-CA", { timeZone: FUSO, year: "numeric", month: "2-digit", day: "2-digit" }).format(data);
}

function horaSalvador(data: Date): string {
  const [h, m] = new Intl.DateTimeFormat("pt-BR", { timeZone: FUSO, hour: "2-digit", minute: "2-digit", hour12: false })
    .format(data)
    .split(":");
  return `${h}h${m}`;
}

/** "12h00" quando é hoje; "19/10 às 12h00" quando é em outro dia. */
export function rotuloDoHorario(data: Date, agora: number): string {
  if (diaSalvador(data) === diaSalvador(new Date(agora))) return horaSalvador(data);
  const [, mes, dia] = diaSalvador(data).split("-");
  return `${dia}/${mes} às ${horaSalvador(data)}`;
}

/** Texto curto para a tela: "Abre às 12h00", "Aberta até 16h00" ou "Encerrada às 16h00" (com a data se não for hoje). */
export function descreverJanela(janela: JanelaPortaria, agora: number): string {
  if (janela.situacao === "antes") return `Abre ${comPreposicao(janela.abre, agora)}`;
  if (janela.situacao === "aberta") return `Aberta até ${rotuloDoHorario(janela.fecha, agora)}`;
  return `Encerrada ${comPreposicao(janela.fecha, agora)}`;
}

// "às 12h00" (hoje) ou "19/10 às 12h00" (outro dia)
function comPreposicao(data: Date, agora: number): string {
  const rotulo = rotuloDoHorario(data, agora);
  return rotulo.includes("às") ? rotulo : `às ${rotulo}`;
}
""",
  'src/modules/portarias/janela.test.ts': r"""import { describe, expect, it } from "vitest";
import { descreverJanela, janelaDaPortaria } from "./janela";

// Evento às 14h00 de Salvador (UTC-3) = 17h00 UTC
const EVENTO = "2026-10-19T17:00:00Z";
const t = (iso: string) => new Date(iso).getTime();

describe("janelaDaPortaria", () => {
  it("abre 2h antes e encerra 2h depois do início (limites inclusivos)", () => {
    expect(janelaDaPortaria(EVENTO, t("2026-10-19T14:59:59Z"))?.situacao).toBe("antes");
    expect(janelaDaPortaria(EVENTO, t("2026-10-19T15:00:00Z"))?.situacao).toBe("aberta");
    expect(janelaDaPortaria(EVENTO, t("2026-10-19T17:00:00Z"))?.situacao).toBe("aberta");
    expect(janelaDaPortaria(EVENTO, t("2026-10-19T19:00:00Z"))?.situacao).toBe("aberta");
    expect(janelaDaPortaria(EVENTO, t("2026-10-19T19:00:01Z"))?.situacao).toBe("encerrada");
  });

  it("sem data válida não há janela", () => {
    expect(janelaDaPortaria(null, 0)).toBeNull();
    expect(janelaDaPortaria("lixo", 0)).toBeNull();
  });
});

describe("descreverJanela", () => {
  it("mostra os horários de Salvador (12h às 16h para um evento das 14h)", () => {
    const agora = t("2026-10-19T13:00:00Z"); // 10h em Salvador, mesmo dia
    expect(descreverJanela(janelaDaPortaria(EVENTO, agora)!, agora)).toBe("Abre às 12h00");
    const durante = t("2026-10-19T17:30:00Z");
    expect(descreverJanela(janelaDaPortaria(EVENTO, durante)!, durante)).toBe("Aberta até 16h00");
    const depois = t("2026-10-19T20:00:00Z");
    expect(descreverJanela(janelaDaPortaria(EVENTO, depois)!, depois)).toBe("Encerrada às 16h00");
  });

  it("inclui a data quando o horário não é de hoje", () => {
    const ontem = t("2026-10-18T13:00:00Z");
    expect(descreverJanela(janelaDaPortaria(EVENTO, ontem)!, ontem)).toBe("Abre 19/10 às 12h00");
  });
});
""",
  'supabase/migrations/0024_janela_portaria.sql': r"""-- =====================================================================
-- SysMúsica — Migração 0024: janela de atendimento da portaria
--   A entrada só é registrada de 2 HORAS ANTES até 2 HORAS DEPOIS do início do evento (horário de Salvador).
--   Ex.: ensaio às 14h -> portaria aberta das 12h às 16h.
--   Quem tem a permissão "portarias.controle_total" (o Administrador) pode registrar FORA da janela:
--   o registro é permitido e fica gravado na Auditoria (ação "presenca_fora_da_janela").
-- Requer as migrações 0007 e 0012. Idempotente, uma única transação.
-- Ao final, a migração TESTA os limites da janela: se algo falhar, tudo é desfeito.
-- =====================================================================
begin;

do $$
begin
  if to_regprocedure('public.validar_registro_presenca(uuid,uuid,uuid)') is null
     or to_regprocedure('public.comum_na_abrangencia(uuid)') is null
     or to_regprocedure('public.tem_permissao(text)') is null then
    raise exception 'Aplique primeiro as migrações 0007 e 0012.';
  end if;
end $$;

-- 1) A regra da janela em um só lugar (limites inclusivos): de 2h antes a 2h depois do início
create or replace function public.portaria_janela_aberta(p_data timestamptz, p_agora timestamptz default now())
returns boolean
language sql
immutable
set search_path = public
as $$
  select p_data is not null
     and p_agora >= p_data - interval '2 hours'
     and p_agora <= p_data + interval '2 hours'
$$;

-- 2) A validação do registro (a de 0012) ganha a conferência da janela, logo após a abrangência
create or replace function public.validar_registro_presenca(
  p_portaria_id uuid, p_evento_id uuid, p_membro_id uuid
)
returns void language plpgsql security definer set search_path = public as $$
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
  if not public.comum_na_abrangencia(v_p.comum_id) then
    raise exception 'Você não tem acesso a esta portaria (fora da sua abrangência).' using errcode = '42501';
  end if;

  -- JANELA: de 2 horas antes a 2 horas depois do início do evento (horário de Salvador)
  select e.data_evento into v_data from public.eventos e where e.id = v_p.evento_id;
  if v_data is null then
    raise exception 'O evento desta portaria não foi encontrado.';
  end if;
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
      raise exception 'Fora do horário da portaria. Ela abre em % e encerra em % (2 horas antes e 2 horas depois do início do evento, horário de Salvador).',
        to_char((v_data - interval '2 hours') at time zone 'America/Sao_Paulo', 'DD/MM "às" HH24"h"MI'),
        to_char((v_data + interval '2 hours') at time zone 'America/Sao_Paulo', 'DD/MM "às" HH24"h"MI');
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
$$;

-- 3) VERIFICAÇÃO: os limites da janela (evento às 14h de Salvador = 17h UTC). Se falhar, tudo é desfeito.
do $$
declare
  v_ev constant timestamptz := '2026-10-19T17:00:00Z';
begin
  if public.portaria_janela_aberta(v_ev, '2026-10-19T14:59:59Z') then
    raise exception 'Teste falhou: abriu antes das 12h.';
  end if;
  if not public.portaria_janela_aberta(v_ev, '2026-10-19T15:00:00Z') then
    raise exception 'Teste falhou: não abriu às 12h.';
  end if;
  if not public.portaria_janela_aberta(v_ev, '2026-10-19T19:00:00Z') then
    raise exception 'Teste falhou: fechou antes das 16h.';
  end if;
  if public.portaria_janela_aberta(v_ev, '2026-10-19T19:00:01Z') then
    raise exception 'Teste falhou: não encerrou depois das 16h.';
  end if;
  if public.portaria_janela_aberta(null, now()) then
    raise exception 'Teste falhou: evento sem data não pode estar aberto.';
  end if;
end $$;

commit;
""",
}

def abrir(c):
    return open(c, encoding="utf-8").read()

def trocar(texto, antigo, novo, onde):
    if texto.count(antigo) != 1:
        print("ERRO: trecho não encontrado exatamente uma vez em", onde, "->", antigo[:70].replace("\n", "\\n")); sys.exit(1)
    return texto.replace(antigo, novo)

# ---------- Atendimento da portaria: só entra em portaria com a janela aberta (Administrador: sempre, com aviso) ----------
at = "src/modules/atendimento/components/AtendimentoPortaria.tsx"
s = abrir(at)
s = trocar(s, 'import type { PortariaDetalhada } from "@/modules/portarias/tipos";',
  'import { descreverJanela, janelaDaPortaria } from "@/modules/portarias/janela";\nimport type { PortariaDetalhada } from "@/modules/portarias/tipos";', at)
s = trocar(s, "export default function AtendimentoPortaria() {",
  "// A portaria só pode ser usada de 2h antes a 2h depois do início do evento (quem tem controle total usa sempre)\n"
  "function janelaLiberada(portaria: PortariaDetalhada, agora: number, controleTotal: boolean): boolean {\n"
  "  if (controleTotal) return true;\n"
  "  return janelaDaPortaria(portaria.evento_data, agora)?.situacao === \"aberta\";\n"
  "}\n\n"
  "export default function AtendimentoPortaria() {", at)
s = trocar(s, "  const podeCorrigir = pode(\"portaria.editar\") || pode(\"portaria.excluir\");\n",
  "  const podeCorrigir = pode(\"portaria.editar\") || pode(\"portaria.excluir\");\n"
  "  const controleTotal = pode(\"portarias.controle_total\");\n", at)
s = trocar(s, "  const [cadastrandoVisitante, setCadastrandoVisitante] = useState(false);\n",
  "  const [cadastrandoVisitante, setCadastrandoVisitante] = useState(false);\n"
  "  const [agora, setAgora] = useState(0); // relógio da tela (atualiza a cada 30 s) para abrir e fechar a janela sozinho\n", at)
s = trocar(s, "      const ordenadas = ordenarPorProximidade(aprovadas, Date.now());\n      setPortarias(ordenadas);\n",
  "      const agoraMs = Date.now();\n      const ordenadas = ordenarPorProximidade(aprovadas, agoraMs);\n      setPortarias(ordenadas);\n      setAgora(agoraMs);\n"
  "      const liberadas = ordenadas.filter((portaria) => janelaLiberada(portaria, agoraMs, controleTotal));\n", at)
s = trocar(s, "        if (atual && ordenadas.some((portaria) => portaria.id === atual)) return atual;\n"
  "        const guardada = lerPortariaGuardada();\n"
  "        if (guardada && ordenadas.some((portaria) => portaria.id === guardada)) return guardada;\n"
  "        return ordenadas.length === 1 ? ordenadas[0].id : null;\n",
  "        if (atual && liberadas.some((portaria) => portaria.id === atual)) return atual;\n"
  "        const guardada = lerPortariaGuardada();\n"
  "        if (guardada && liberadas.some((portaria) => portaria.id === guardada)) return guardada;\n"
  "        return liberadas.length === 1 ? liberadas[0].id : null;\n", at)
s = trocar(s, "  }, []);\n\n  const carregarEntradas = useCallback", "  }, [controleTotal]);\n\n  const carregarEntradas = useCallback", at)
s = trocar(s, "  function tentarNovamente() {",
  "  // Relógio da tela: a cada 30 segundos recalcula quais portarias estão com a janela aberta\n"
  "  useEffect(() => {\n"
  "    const temporizador = setInterval(() => setAgora(Date.now()), 30_000);\n"
  "    return () => clearInterval(temporizador);\n"
  "  }, []);\n\n"
  "  function tentarNovamente() {", at)
s = trocar(s, "<SelecaoPortaria portarias={portarias} onEscolher={(id) => escolherPortaria(id)} />",
  "<SelecaoPortaria\n          portarias={portarias}\n          agora={agora}\n          controleTotal={controleTotal}\n          onEscolher={(id) => escolherPortaria(id)}\n        />", at)
s = trocar(s, "  const portaria = portarias.find((item) => item.id === portariaId) ?? null;\n",
  "  const portaria = portarias.find((item) => item.id === portariaId) ?? null;\n"
  "  const janela = portaria ? janelaDaPortaria(portaria.evento_data, agora) : null;\n", at)
s = trocar(s, "                {[portaria.evento_tipo, portaria.evento_local, portaria.cidade].filter(Boolean).join(\" · \")}\n              </p>\n",
  "                {[portaria.evento_tipo, portaria.evento_local, portaria.cidade].filter(Boolean).join(\" · \")}\n              </p>\n"
  "              {janela && agora > 0 && (\n"
  "                <p className={\"mt-1 text-xs font-medium \" + (janela.situacao === \"aberta\" ? \"text-emerald-700\" : \"text-amber-700\")}>\n"
  "                  {descreverJanela(janela, agora)}\n"
  "                  {janela.situacao !== \"aberta\" && \" — fora do horário: o controle total permite o registro e ele fica na Auditoria.\"}\n"
  "                </p>\n"
  "              )}\n", at)
open(at, "w", encoding="utf-8").write(s)

# ---------- Escolha da portaria: as fechadas aparecem desabilitadas (menos para o controle total) ----------
sel = "src/modules/atendimento/components/SelecaoPortaria.tsx"
t = abrir(sel)
t = trocar(t, 'import type { PortariaDetalhada } from "@/modules/portarias/tipos";',
  'import { descreverJanela, janelaDaPortaria } from "@/modules/portarias/janela";\nimport type { PortariaDetalhada } from "@/modules/portarias/tipos";', sel)
t = trocar(t, "interface SelecaoPortariaProps {\n  portarias: PortariaDetalhada[];\n  onEscolher: (portariaId: string) => void;\n}\n\nexport default function SelecaoPortaria({ portarias, onEscolher }: SelecaoPortariaProps) {",
  "interface SelecaoPortariaProps {\n  portarias: PortariaDetalhada[];\n  agora: number; // relógio da tela (ms); 0 = ainda não carregou\n  controleTotal: boolean; // pode atender fora da janela de 2h antes a 2h depois\n  onEscolher: (portariaId: string) => void;\n}\n\nexport default function SelecaoPortaria({ portarias, agora, controleTotal, onEscolher }: SelecaoPortariaProps) {", sel)
t = trocar(t, "        {portarias.map((portaria) => (\n          <li key={portaria.id}>\n            <button\n              type=\"button\"\n              onClick={() => onEscolher(portaria.id)}\n",
  "        {portarias.map((portaria) => {\n          const janela = agora > 0 ? janelaDaPortaria(portaria.evento_data, agora) : null;\n          const fechada = janela !== null && janela.situacao !== \"aberta\";\n          const bloqueada = fechada && !controleTotal;\n          return (\n          <li key={portaria.id}>\n            <button\n              type=\"button\"\n              disabled={bloqueada}\n              onClick={() => onEscolher(portaria.id)}\n", sel)
t = trocar(t, "              <p className=\"mt-1 text-xs text-slate-500\">\n                {[portaria.evento_local, portaria.cidade].filter(Boolean).join(\" · \")}\n              </p>\n            </button>\n          </li>\n        ))}\n",
  "              <p className=\"mt-1 text-xs text-slate-500\">\n                {[portaria.evento_local, portaria.cidade].filter(Boolean).join(\" · \")}\n              </p>\n"
  "              {janela && (\n"
  "                <p className={\"mt-1 text-xs font-medium \" + (fechada ? \"text-amber-700\" : \"text-emerald-700\")}>\n"
  "                  {descreverJanela(janela, agora)}\n"
  "                  {bloqueada && \" — indisponível agora\"}\n"
  "                  {fechada && controleTotal && \" — controle total: permitido e auditado\"}\n"
  "                </p>\n"
  "              )}\n"
  "            </button>\n          </li>\n          );\n        })}\n", sel)
t = trocar(t, "className=\"w-full rounded-2xl border border-slate-200 bg-white p-4 text-left shadow-sm transition hover:border-brand-300 hover:bg-slate-50 focus:outline-none focus-visible:ring-2 focus-visible:ring-brand-300\"",
  "className=\"w-full rounded-2xl border border-slate-200 bg-white p-4 text-left shadow-sm transition hover:border-brand-300 hover:bg-slate-50 focus:outline-none focus-visible:ring-2 focus-visible:ring-brand-300 disabled:cursor-not-allowed disabled:opacity-60 disabled:hover:border-slate-200 disabled:hover:bg-white\"", sel)
open(sel, "w", encoding="utf-8").write(t)

# ---------- Nova portaria: explica por que um evento pode não aparecer ----------
fn = "src/modules/portarias/components/FormularioNovaPortaria.tsx"
u = abrir(fn)
u = trocar(u, "Aparecem só os eventos das suas comuns. Os de comum sem setor ficam desabilitados",
  "Aparecem só os eventos que têm uma comum escolhida (na tela de Eventos, botão Editar) dentro da sua abrangência. Os de comum sem setor ficam desabilitados", fn)
open(fn, "w", encoding="utf-8").write(u)

for caminho in NOVOS:
    if os.path.exists(caminho):
        print("ERRO: já existe", caminho); sys.exit(1)
for caminho, conteudo in NOVOS.items():
    os.makedirs(os.path.dirname(caminho) or ".", exist_ok=True)
    open(caminho, "w", encoding="utf-8").write(conteudo)
print("Arquivos gravados:", len(NOVOS), "novos, 3 alterados.")
PYSCRIPT
[ $? -eq 0 ] || { reverter; exit 1; }

echo; echo "=== 2) Parando o servidor de teste e limpando o cache ==="
pkill -f "next dev" 2>/dev/null; pkill -f next-server 2>/dev/null; pkill -f "next/dist" 2>/dev/null; sleep 2
for i in 1 2 3 4 5; do rm -rf .next 2>/dev/null; [ -d .next ] || break; sleep 1; done

echo; echo "=== 3) Conferência de tipos ==="
npx tsc --noEmit || { reverter; exit 1; }
echo; echo "=== 4) Testes automáticos ==="
npx vitest run src/modules/portarias src/modules/atendimento || { reverter; exit 1; }
echo; echo "=== 5) Lint ==="
npx eslint "${ALT[@]}" src/modules/portarias/janela.ts src/modules/portarias/janela.test.ts || { reverter; exit 1; }
echo; echo "=== 6) Build de produção (pode demorar alguns minutos) ==="
npm run build || { reverter; exit 1; }

echo; echo "=== TUDO CERTO: arquivos instalados e conferidos ==="
echo "FALTA UM PASSO: aplicar a migração no Supabase (arquivo supabase/migrations/0024_janela_portaria.sql)."
git status --short
) 2>&1 | tee /tmp/janela-instalar.log
