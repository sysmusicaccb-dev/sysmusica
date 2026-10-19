cd /workspaces/sysmusica/sysmusica || { echo "Pasta do projeto não encontrada"; exit 1; }
(
set -u
BKP="/tmp/bkp-agendamento-$(date +%H%M%S)"; mkdir -p "$BKP/a"
ALT=("src/modules/auditoria/regras.ts" "src/modules/backup/components/AbasBackup.tsx" "src/modules/backup/server/operacoes.ts")
for f in "${ALT[@]}"; do mkdir -p "$BKP/a/$(dirname "$f")"; cp "$f" "$BKP/a/$f"; done

reverter() {
  echo ">>> REVERTENDO tudo (nada do que foi tentado fica no projeto)"
  for f in "${ALT[@]}"; do cp "$BKP/a/$f" "$f"; done
  rm -rf "src/app/api/cron" "src/app/api/backup/agendamento" "src/app/(painel)/administracao/backup/agendamento"
  rm -f supabase/migrations/0023_backup_agendamento.sql src/modules/backup/agendamento.ts src/modules/backup/agendamento.test.ts \
        src/modules/backup/server/agendamento.ts src/modules/backup/services/agendamentoApi.ts vercel.json
  echo ">>> REVERTIDO. Me mande o log: /tmp/agendamento-instalar.log"
}

echo "=== 0) Conferência prévia (só leitura) ==="
for f in "${ALT[@]}" "src/app/(painel)/administracao/backup/destinos/layout.tsx" "src/app/(painel)/administracao/backup/page.tsx"; do
  [ -f "$f" ] || { echo "ERRO: arquivo esperado não existe: $f (a aba Destinos foi instalada?)"; exit 1; }
done
[ -f vercel.json ] && { echo "ERRO: já existe um vercel.json neste projeto. Me mande o conteúdo dele antes de continuar."; cat vercel.json; exit 1; }
ls src/proxy.ts src/middleware.ts proxy.ts middleware.ts 2>/dev/null && echo "(AVISO: existe proxy/middleware; vou testar a rota do cron localmente no final)"
echo "Início da página Backups (referência de formatação):"
grep -n -A12 "return (" "src/app/(painel)/administracao/backup/page.tsx" | head -40

echo; echo "=== 1) Gravando os arquivos ==="
python3 - <<'PYSCRIPT'
import os, re, sys
NOVOS = {
  'supabase/migrations/0023_backup_agendamento.sql': r"""-- =====================================================================
-- SysMúsica — Migração 0023: agendamento dos backups (diário, semanal, quinzenal e mensal)
--   * Tabela backup_agendamento (uma única linha): chave geral, tipos ligados, quantos backups guardar de cada
--     tipo (retenção), dia da semana do semanal e dia do mês do mensal, e o resultado da última execução.
--   * Só o servidor do sistema (chave secreta) lê e grava: anon/authenticated não têm acesso.
-- Requer a migração 0020. Idempotente, uma única transação.
-- Ao final, a migração TESTA que valores inválidos são recusados e que usuários comuns não têm acesso:
-- se algo falhar, tudo é desfeito.
-- =====================================================================
begin;

do $$
begin
  if to_regclass('public.backup_arquivos') is null then
    raise exception 'Aplique primeiro a migração 0020 (backup).';
  end if;
end $$;

create table if not exists public.backup_agendamento (
  id                    int primary key default 1 check (id = 1),
  ativo                 boolean not null default false,
  diario_ativo          boolean not null default true,
  diario_retencao       int not null default 7  check (diario_retencao between 1 and 90),
  semanal_ativo         boolean not null default true,
  semanal_retencao      int not null default 5  check (semanal_retencao between 1 and 90),
  semanal_dia           int not null default 0  check (semanal_dia between 0 and 6),
  quinzenal_ativo       boolean not null default true,
  quinzenal_retencao    int not null default 3  check (quinzenal_retencao between 1 and 90),
  mensal_ativo          boolean not null default true,
  mensal_retencao       int not null default 12 check (mensal_retencao between 1 and 90),
  mensal_dia            int not null default 1  check (mensal_dia between 1 and 28),
  ultimo_em             timestamptz,
  ultimo_resultado      text check (ultimo_resultado in ('ok', 'falhou', 'pulado')),
  ultimo_detalhe        text,
  ultima_verificacao_em timestamptz,
  atualizado_em         timestamptz not null default now(),
  atualizado_por        uuid
);
insert into public.backup_agendamento (id) values (1) on conflict (id) do nothing;

alter table public.backup_agendamento enable row level security;
revoke all on public.backup_agendamento from anon, authenticated;

-- VERIFICAÇÃO DE SEGURANÇA: se qualquer teste falhar, a migração INTEIRA é desfeita.
do $$
declare
  v_bloqueou boolean := false;
begin
  -- 1) uma retenção inválida (zero) precisa ser recusada
  begin
    update public.backup_agendamento set diario_retencao = 0 where id = 1;
    raise exception 'sysmusica_sem_bloqueio';
  exception when others then
    if sqlstate = '23514' then
      v_bloqueou := true;
    elsif sqlerrm <> 'sysmusica_sem_bloqueio' then
      raise exception 'Verificação falhou (teste da retenção): %', sqlerrm;
    end if;
  end;
  if not v_bloqueou then
    raise exception 'Verificação falhou: o banco aceitou uma retenção inválida. Nada foi alterado.';
  end if;

  -- 2) usuários comuns não podem ler nem gravar a tabela
  if has_table_privilege('anon', 'public.backup_agendamento', 'select')
     or has_table_privilege('authenticated', 'public.backup_agendamento', 'select')
     or has_table_privilege('anon', 'public.backup_agendamento', 'update')
     or has_table_privilege('authenticated', 'public.backup_agendamento', 'update') then
    raise exception 'Verificação falhou: anon/authenticated ainda têm acesso a backup_agendamento. Nada foi alterado.';
  end if;

  -- 3) a proteção por linha (RLS) precisa estar ligada e a linha única precisa existir
  if not exists (
    select 1 from pg_class c join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relname = 'backup_agendamento' and c.relrowsecurity
  ) then
    raise exception 'Verificação falhou: a proteção por linha (RLS) não está ligada. Nada foi alterado.';
  end if;
  if not exists (select 1 from public.backup_agendamento where id = 1) then
    raise exception 'Verificação falhou: a linha de configuração não foi criada. Nada foi alterado.';
  end if;
end $$;

commit;
""",
  'src/modules/backup/agendamento.ts': r"""/**
 * SysMúsica — Agendamento dos backups: regras puras (sem banco nem rede), compartilhadas entre a tela e o servidor.
 *  - Uma tarefa automática roda UMA vez por dia (limite do Vercel gratuito) às 06:00 UTC = 03:00 em Salvador
 *    (o Brasil não tem horário de verão). A cada dia o sistema decide QUAL tipo de backup fazer:
 *    mensal > quinzenal > semanal > diário (só o de maior prioridade que estiver ligado e valer hoje).
 *  - Retenção: cada tipo guarda só os N backups mais recentes JÁ VERIFICADOS; o resto é apagado.
 *  - Nunca se apagam backups manuais nem de segurança.
 * No plano gratuito do Vercel, o horário exato pode variar até uma hora.
 */

export type TipoAgendado = "diario" | "semanal" | "quinzenal" | "mensal";
export const TIPOS_AGENDADOS: TipoAgendado[] = ["diario", "semanal", "quinzenal", "mensal"];

export const HORA_CRON_UTC = 6; // 03:00 em Salvador
export const HORA_CRON_SALVADOR = 3;
export const DIA_VERIFICACAO_SEMANAL = 1; // segunda-feira (0 = domingo)
export const NOMES_DIA_SEMANA = ["domingo", "segunda-feira", "terça-feira", "quarta-feira", "quinta-feira", "sexta-feira", "sábado"];

export interface ConfigAgendamento {
  ativo: boolean; // chave geral
  diario_ativo: boolean;
  diario_retencao: number;
  semanal_ativo: boolean;
  semanal_retencao: number;
  semanal_dia: number; // 0 = domingo ... 6 = sábado
  quinzenal_ativo: boolean; // dias 1 e 16
  quinzenal_retencao: number;
  mensal_ativo: boolean;
  mensal_retencao: number;
  mensal_dia: number; // 1 a 28
}

export const PADRAO_AGENDAMENTO: ConfigAgendamento = {
  ativo: false,
  diario_ativo: true,
  diario_retencao: 7,
  semanal_ativo: true,
  semanal_retencao: 5,
  semanal_dia: 0,
  quinzenal_ativo: true,
  quinzenal_retencao: 3,
  mensal_ativo: true,
  mensal_retencao: 12,
  mensal_dia: 1,
};

export interface AgendamentoPublico {
  config: ConfigAgendamento;
  ultimo_em: string | null;
  ultimo_resultado: "ok" | "falhou" | "pulado" | null;
  ultimo_detalhe: string | null;
  ultima_verificacao_em: string | null;
  proximo: { quando: string; tipo: TipoAgendado } | null; // calculado com a configuração salva
}

// ---------- Datas em Salvador (UTC-3 fixo) ----------

const MS_HORA = 3_600_000;

export function partesSalvador(data: Date): { ano: number; mes: number; dia: number; diaSemana: number } {
  const s = new Date(data.getTime() - 3 * MS_HORA);
  return { ano: s.getUTCFullYear(), mes: s.getUTCMonth() + 1, dia: s.getUTCDate(), diaSemana: s.getUTCDay() };
}

/** Meia-noite de Salvador do dia da data informada (como instante UTC). */
export function inicioDoDiaSalvador(data: Date): Date {
  const p = partesSalvador(data);
  return new Date(Date.UTC(p.ano, p.mes - 1, p.dia, 3, 0, 0));
}

/** Qual tipo de backup vale para o dia da data informada (nulo = nenhum, ou agendamento desligado). */
export function escolherTipo(config: ConfigAgendamento, quando: Date): TipoAgendado | null {
  if (!config.ativo) return null;
  const { dia, diaSemana } = partesSalvador(quando);
  if (config.mensal_ativo && dia === config.mensal_dia) return "mensal";
  if (config.quinzenal_ativo && (dia === 1 || dia === 16)) return "quinzenal";
  if (config.semanal_ativo && diaSemana === config.semanal_dia) return "semanal";
  if (config.diario_ativo) return "diario";
  return null;
}

/** Próxima execução automática depois de "agora" (nulo se nada vai rodar nos próximos dois meses). */
export function proximoBackup(config: ConfigAgendamento, agora: Date): { quando: Date; tipo: TipoAgendado } | null {
  if (!config.ativo) return null;
  const base = inicioDoDiaSalvador(agora).getTime();
  for (let i = 0; i <= 62; i++) {
    const quando = new Date(base + i * 24 * MS_HORA + HORA_CRON_SALVADOR * MS_HORA);
    if (quando.getTime() <= agora.getTime()) continue;
    const tipo = escolherTipo(config, quando);
    if (tipo) return { quando, tipo };
  }
  return null;
}

// ---------- Retenção ----------

/** Dos backups de UM tipo, devolve os que passam do limite (os mais antigos). Mantém sempre pelo menos 1. */
export function excedentes<T extends { criado_em: string }>(linhas: T[], manter: number): T[] {
  const ordenadas = [...linhas].sort((a, b) => Date.parse(b.criado_em) - Date.parse(a.criado_em));
  return ordenadas.slice(Math.max(1, Math.floor(manter)));
}

// ---------- Validação ----------

const inteiro = (valor: unknown, min: number, max: number): number | null =>
  typeof valor === "number" && Number.isInteger(valor) && valor >= min && valor <= max ? valor : null;

/** Lê o corpo recebido pela rota; devolve null se o formato estiver errado. */
export function lerEntradaAgendamento(valor: unknown): ConfigAgendamento | null {
  if (valor === null || typeof valor !== "object" || Array.isArray(valor)) return null;
  const o = valor as Record<string, unknown>;
  const booleanos = ["ativo", "diario_ativo", "semanal_ativo", "quinzenal_ativo", "mensal_ativo"] as const;
  for (const campo of booleanos) if (typeof o[campo] !== "boolean") return null;

  const diarioRet = inteiro(o.diario_retencao, 1, 90);
  const semanalRet = inteiro(o.semanal_retencao, 1, 90);
  const quinzenalRet = inteiro(o.quinzenal_retencao, 1, 90);
  const mensalRet = inteiro(o.mensal_retencao, 1, 90);
  const semanalDia = inteiro(o.semanal_dia, 0, 6);
  const mensalDia = inteiro(o.mensal_dia, 1, 28);
  if (diarioRet === null || semanalRet === null || quinzenalRet === null || mensalRet === null || semanalDia === null || mensalDia === null) {
    return null;
  }
  return {
    ativo: o.ativo as boolean,
    diario_ativo: o.diario_ativo as boolean,
    diario_retencao: diarioRet,
    semanal_ativo: o.semanal_ativo as boolean,
    semanal_retencao: semanalRet,
    semanal_dia: semanalDia,
    quinzenal_ativo: o.quinzenal_ativo as boolean,
    quinzenal_retencao: quinzenalRet,
    mensal_ativo: o.mensal_ativo as boolean,
    mensal_retencao: mensalRet,
    mensal_dia: mensalDia,
  };
}

/** Mensagem de erro (para a tela) ou null se está tudo certo. */
export function validarAgendamento(config: ConfigAgendamento): string | null {
  if (config.ativo && !(config.diario_ativo || config.semanal_ativo || config.quinzenal_ativo || config.mensal_ativo)) {
    return "Ligue pelo menos um tipo de backup (diário, semanal, quinzenal ou mensal) para ativar o agendamento.";
  }
  return null;
}

export function descreverTipoDoDia(tipo: TipoAgendado): string {
  return { diario: "diário", semanal: "semanal", quinzenal: "quinzenal", mensal: "mensal" }[tipo];
}
""",
  'src/modules/backup/agendamento.test.ts': r"""import { describe, expect, it } from "vitest";
import {
  PADRAO_AGENDAMENTO,
  escolherTipo,
  excedentes,
  inicioDoDiaSalvador,
  lerEntradaAgendamento,
  partesSalvador,
  proximoBackup,
  validarAgendamento,
  type ConfigAgendamento,
} from "./agendamento";

const ligado: ConfigAgendamento = { ...PADRAO_AGENDAMENTO, ativo: true };
// Cron das 06:00 UTC = 03:00 em Salvador
const cron = (iso: string) => new Date(`${iso}T06:00:00Z`);

describe("datas em Salvador", () => {
  it("usa o dia de Salvador, não o de UTC", () => {
    // 01:00 UTC de 20/10 ainda é 22:00 de 19/10 em Salvador
    expect(partesSalvador(new Date("2026-10-20T01:00:00Z"))).toMatchObject({ dia: 19, mes: 10 });
    expect(partesSalvador(new Date("2026-10-20T03:00:00Z"))).toMatchObject({ dia: 20 });
  });
  it("início do dia é 03:00 UTC", () => {
    expect(inicioDoDiaSalvador(new Date("2026-10-20T01:00:00Z")).toISOString()).toBe("2026-10-19T03:00:00.000Z");
    expect(inicioDoDiaSalvador(new Date("2026-10-20T15:00:00Z")).toISOString()).toBe("2026-10-20T03:00:00.000Z");
  });
});

describe("escolherTipo", () => {
  it("devolve nulo se o agendamento está desligado", () => {
    expect(escolherTipo({ ...ligado, ativo: false }, cron("2026-11-01"))).toBeNull();
  });
  it("mensal vence quinzenal, semanal e diário", () => {
    // 01/11/2026 é domingo: valem mensal, quinzenal, semanal e diário
    expect(escolherTipo(ligado, cron("2026-11-01"))).toBe("mensal");
  });
  it("quinzenal nos dias 1 e 16 quando o mensal não vale", () => {
    expect(escolherTipo({ ...ligado, mensal_ativo: false }, cron("2026-11-01"))).toBe("quinzenal");
    expect(escolherTipo(ligado, cron("2026-11-16"))).toBe("quinzenal");
  });
  it("semanal no dia da semana escolhido", () => {
    expect(escolherTipo(ligado, cron("2026-10-18"))).toBe("semanal"); // domingo
    expect(escolherTipo({ ...ligado, semanal_dia: 3 }, cron("2026-10-21"))).toBe("semanal"); // quarta
  });
  it("diário nos demais dias, e nulo se nada vale", () => {
    expect(escolherTipo(ligado, cron("2026-10-20"))).toBe("diario"); // terça
    expect(escolherTipo({ ...ligado, diario_ativo: false }, cron("2026-10-20"))).toBeNull();
  });
  it("respeita o dia do mês escolhido para o mensal", () => {
    expect(escolherTipo({ ...ligado, mensal_dia: 10 }, cron("2026-10-10"))).toBe("mensal");
    expect(escolherTipo({ ...ligado, mensal_dia: 10 }, cron("2026-11-01"))).toBe("quinzenal");
  });
});

describe("proximoBackup", () => {
  it("é nulo com o agendamento desligado", () => {
    expect(proximoBackup(PADRAO_AGENDAMENTO, new Date("2026-10-19T12:00:00Z"))).toBeNull();
  });
  it("antes das 03:00 de Salvador, o próximo é hoje às 06:00 UTC", () => {
    const p = proximoBackup(ligado, new Date("2026-10-20T04:00:00Z")); // 01:00 em Salvador, terça
    expect(p?.quando.toISOString()).toBe("2026-10-20T06:00:00.000Z");
    expect(p?.tipo).toBe("diario");
  });
  it("depois das 03:00 de Salvador, o próximo é amanhã", () => {
    const p = proximoBackup(ligado, new Date("2026-10-20T09:00:00Z")); // 06:00 em Salvador
    expect(p?.quando.toISOString()).toBe("2026-10-21T06:00:00.000Z");
  });
  it("à noite em Salvador (já é o dia seguinte em UTC), não pula um dia", () => {
    const p = proximoBackup(ligado, new Date("2026-10-21T01:00:00Z")); // 22:00 de terça em Salvador
    expect(p?.quando.toISOString()).toBe("2026-10-21T06:00:00.000Z");
  });
});

describe("excedentes (retenção)", () => {
  const mk = (n: number) => ({ id: `b${n}`, criado_em: `2026-10-${String(n).padStart(2, "0")}T06:00:00Z` });
  const dez = [3, 1, 10, 5, 2, 9, 4, 8, 7, 6].map(mk);
  it("apaga só os mais antigos além do limite", () => {
    expect(excedentes(dez, 7).map((l) => l.id).sort()).toEqual(["b1", "b2", "b3"]);
  });
  it("não apaga nada se há menos que o limite", () => {
    expect(excedentes(dez.slice(0, 3), 7)).toEqual([]);
  });
  it("sempre mantém pelo menos um, mesmo com limite zero ou inválido", () => {
    expect(excedentes(dez, 0)).toHaveLength(9);
    expect(excedentes(dez, -5)).toHaveLength(9);
  });
});

describe("validação", () => {
  const corpo = { ...ligado };
  it("lê um corpo válido e recusa formatos errados", () => {
    expect(lerEntradaAgendamento(corpo)).toEqual(corpo);
    expect(lerEntradaAgendamento(null)).toBeNull();
    expect(lerEntradaAgendamento({ ...corpo, diario_retencao: 0 })).toBeNull();
    expect(lerEntradaAgendamento({ ...corpo, diario_retencao: 91 })).toBeNull();
    expect(lerEntradaAgendamento({ ...corpo, diario_retencao: 7.5 })).toBeNull();
    expect(lerEntradaAgendamento({ ...corpo, semanal_dia: 7 })).toBeNull();
    expect(lerEntradaAgendamento({ ...corpo, mensal_dia: 29 })).toBeNull();
    expect(lerEntradaAgendamento({ ...corpo, ativo: "sim" })).toBeNull();
  });
  it("não deixa ligar o agendamento sem nenhum tipo", () => {
    const nenhum = { ...ligado, diario_ativo: false, semanal_ativo: false, quinzenal_ativo: false, mensal_ativo: false };
    expect(validarAgendamento(nenhum)).toMatch(/pelo menos um/);
    expect(validarAgendamento({ ...nenhum, ativo: false })).toBeNull();
    expect(validarAgendamento(ligado)).toBeNull();
  });
});
""",
  'src/modules/backup/server/agendamento.ts': r"""/**
 * SysMúsica — Agendamento dos backups no servidor: configuração, rotina diária (backup + retenção) e conferência
 * da tarde (aviso de atraso + verificação semanal). As duas rotinas são chamadas pelo Vercel (vercel.json) com o
 * segredo CRON_SECRET; quem aperta o botão "Executar a rotina agora" passa pela permissão de Administrador.
 *
 * SEGURANÇA DA RETENÇÃO: só são apagados backups AGENDADOS (diário, semanal, quinzenal, mensal) que já foram
 * VERIFICADOS, e sempre fica pelo menos um. Backup manual, de segurança, com falha ou ainda não verificado
 * nunca é apagado automaticamente. Cópias já enviadas ao servidor local NÃO são apagadas daqui.
 */
import { timingSafeEqual } from "node:crypto";
import type { SupabaseClient } from "@supabase/supabase-js";
import {
  PADRAO_AGENDAMENTO,
  DIA_VERIFICACAO_SEMANAL,
  TIPOS_AGENDADOS,
  descreverTipoDoDia,
  escolherTipo,
  excedentes,
  inicioDoDiaSalvador,
  proximoBackup,
  validarAgendamento,
  type AgendamentoPublico,
  type ConfigAgendamento,
  type TipoAgendado,
} from "../agendamento";
import { ROTULO_TIPO, dataHoraSalvador, descreverVerificacao } from "../regras";
import type { UsuarioAutenticado } from "./autorizacao";
import { clienteAdmin } from "./clienteAdmin";
import { ErroBackup } from "./erros";
import { notificar } from "./notificar";
import { fazerBackup, verificarPeloSistema } from "./operacoes";

const BUCKET = "backups";
const COLUNAS =
  "ativo, diario_ativo, diario_retencao, semanal_ativo, semanal_retencao, semanal_dia, quinzenal_ativo, quinzenal_retencao, " +
  "mensal_ativo, mensal_retencao, mensal_dia, ultimo_em, ultimo_resultado, ultimo_detalhe, ultima_verificacao_em";

interface LinhaAgendamento extends ConfigAgendamento {
  ultimo_em: string | null;
  ultimo_resultado: "ok" | "falhou" | "pulado" | null;
  ultimo_detalhe: string | null;
  ultima_verificacao_em: string | null;
}

export interface ResultadoRotina {
  resultado: "ok" | "falhou" | "pulado";
  tipo: TipoAgendado | null;
  detalhe: string;
  apagados: number;
}

/** Confere o segredo que o Vercel manda nas tarefas automáticas (cabeçalho Authorization: Bearer ...). */
export function exigirCron(request: Request): void {
  const segredo = process.env.CRON_SECRET;
  if (!segredo || segredo.length < 16) {
    throw new ErroBackup(500, "A variável CRON_SECRET não está configurada (mínimo de 16 caracteres).");
  }
  const recebido = Buffer.from(request.headers.get("authorization") ?? "");
  const esperado = Buffer.from(`Bearer ${segredo}`);
  if (recebido.length !== esperado.length || !timingSafeEqual(recebido, esperado)) {
    throw new ErroBackup(401, "Não autorizado.");
  }
}

// Registra na Auditoria; uma falha aqui nunca derruba a operação
async function auditar(
  admin: SupabaseClient,
  usuarioId: string | null,
  acao: string,
  detalhes: Record<string, unknown>
): Promise<void> {
  const { error } = await admin
    .from("auditoria")
    .insert({ usuario_id: usuarioId, acao, entidade: "backup", entidade_id: null, detalhes });
  if (error) console.error("Falha ao registrar a auditoria do agendamento:", error.message);
}

async function lerLinha(admin: SupabaseClient): Promise<LinhaAgendamento> {
  const { data, error } = await admin.from("backup_agendamento").select(COLUNAS).eq("id", 1).maybeSingle();
  if (error) throw new ErroBackup(500, "Não foi possível ler o agendamento. A migração 0023 foi aplicada?");
  const vazio = { ultimo_em: null, ultimo_resultado: null, ultimo_detalhe: null, ultima_verificacao_em: null };
  return data ? (data as unknown as LinhaAgendamento) : { ...PADRAO_AGENDAMENTO, ...vazio };
}

function soConfig(linha: LinhaAgendamento): ConfigAgendamento {
  return {
    ativo: linha.ativo,
    diario_ativo: linha.diario_ativo,
    diario_retencao: linha.diario_retencao,
    semanal_ativo: linha.semanal_ativo,
    semanal_retencao: linha.semanal_retencao,
    semanal_dia: linha.semanal_dia,
    quinzenal_ativo: linha.quinzenal_ativo,
    quinzenal_retencao: linha.quinzenal_retencao,
    mensal_ativo: linha.mensal_ativo,
    mensal_retencao: linha.mensal_retencao,
    mensal_dia: linha.mensal_dia,
  };
}

// ---------- Ler e salvar ----------

export async function lerAgendamentoPublico(): Promise<AgendamentoPublico> {
  const linha = await lerLinha(clienteAdmin());
  const config = soConfig(linha);
  const proximo = proximoBackup(config, new Date());
  return {
    config,
    ultimo_em: linha.ultimo_em,
    ultimo_resultado: linha.ultimo_resultado,
    ultimo_detalhe: linha.ultimo_detalhe,
    ultima_verificacao_em: linha.ultima_verificacao_em,
    proximo: proximo ? { quando: proximo.quando.toISOString(), tipo: proximo.tipo } : null,
  };
}

export async function salvarAgendamento(entrada: ConfigAgendamento, usuario: UsuarioAutenticado): Promise<AgendamentoPublico> {
  const erro = validarAgendamento(entrada);
  if (erro) throw new ErroBackup(400, erro);

  const admin = clienteAdmin();
  const atual = soConfig(await lerLinha(admin));
  const alterados = (Object.keys(entrada) as (keyof ConfigAgendamento)[]).filter((campo) => entrada[campo] !== atual[campo]);

  const { error } = await admin
    .from("backup_agendamento")
    .upsert({ id: 1, ...entrada, atualizado_em: new Date().toISOString(), atualizado_por: usuario.id }, { onConflict: "id" });
  if (error) throw new ErroBackup(500, "Não foi possível salvar o agendamento.");

  if (alterados.length > 0) await auditar(admin, usuario.id, "backup_agendamento_alterado", { alterados });
  return lerAgendamentoPublico();
}

// ---------- Retenção ----------

// Apaga os backups verificados de UM tipo que passam do limite. Devolve quantos foram apagados.
async function aplicarRetencao(admin: SupabaseClient, tipo: TipoAgendado, manter: number): Promise<number> {
  const { data, error } = await admin
    .from("backup_arquivos")
    .select("id, caminho, criado_em")
    .eq("tipo", tipo)
    .eq("situacao", "ok")
    .eq("verificacao", "ok") // só conta e só apaga backup verificado
    .order("criado_em", { ascending: false })
    .limit(500);
  if (error) {
    console.error("Falha ao consultar a retenção do backup:", error.message);
    return 0;
  }

  const apagar = excedentes((data ?? []) as { id: string; caminho: string | null; criado_em: string }[], manter).slice(0, 50);
  let apagados = 0;
  for (const linha of apagar) {
    if (linha.caminho) {
      const remocao = await admin.storage.from(BUCKET).remove([linha.caminho]);
      if (remocao.error) {
        console.error("Falha ao apagar o arquivo na retenção:", remocao.error.message);
        continue; // sem apagar o arquivo, não apaga o registro
      }
    }
    const { error: erroLinha } = await admin.from("backup_arquivos").delete().eq("id", linha.id);
    if (erroLinha) console.error("Falha ao apagar o registro na retenção:", erroLinha.message);
    else apagados += 1;
  }
  if (apagados > 0) await auditar(admin, null, "backup_retencao_aplicada", { tipo, apagados, mantidos: manter });
  return apagados;
}

function retencaoDe(config: ConfigAgendamento, tipo: TipoAgendado): number {
  return config[`${tipo}_retencao` as const];
}

async function registrarExecucao(
  admin: SupabaseClient,
  resultado: "ok" | "falhou" | "pulado",
  detalhe: string
): Promise<void> {
  const { error } = await admin
    .from("backup_agendamento")
    .update({ ultimo_em: new Date().toISOString(), ultimo_resultado: resultado, ultimo_detalhe: detalhe.slice(0, 500) })
    .eq("id", 1);
  if (error) console.error("Falha ao gravar a última execução do agendamento:", error.message);
}

// Já existe backup agendado criado hoje (dia de Salvador)?
async function existeAgendadoHoje(admin: SupabaseClient, agora: Date, apenasOk: boolean): Promise<boolean> {
  let consulta = admin
    .from("backup_arquivos")
    .select("id")
    .in("tipo", TIPOS_AGENDADOS)
    .gte("criado_em", inicioDoDiaSalvador(agora).toISOString());
  if (apenasOk) consulta = consulta.eq("situacao", "ok");
  const { data } = await consulta.limit(1);
  return (data ?? []).length > 0;
}

// ---------- Rotina diária ----------

/**
 * Decide o tipo do dia, faz o backup (que verifica, copia para o servidor local e avisa) e aplica a retenção.
 * "forcar" é o botão manual: ignora a chave geral e a trava de "já fez hoje", mas respeita o tipo do dia.
 */
export async function executarRotina(opcoes: { forcar: boolean; usuario: UsuarioAutenticado | null }): Promise<ResultadoRotina> {
  const admin = clienteAdmin();
  const agora = new Date();
  const linha = await lerLinha(admin);
  const config = soConfig(linha);

  const tipo = escolherTipo({ ...config, ativo: opcoes.forcar ? true : config.ativo }, agora);
  if (!tipo) {
    const detalhe = config.ativo || opcoes.forcar ? "nenhum tipo de backup vale para hoje" : "o agendamento está desligado";
    await registrarExecucao(admin, "pulado", detalhe);
    return { resultado: "pulado", tipo: null, detalhe, apagados: 0 };
  }
  if (!opcoes.forcar && (await existeAgendadoHoje(admin, agora, false))) {
    const detalhe = "já existe um backup agendado hoje";
    await registrarExecucao(admin, "pulado", detalhe);
    return { resultado: "pulado", tipo, detalhe, apagados: 0 };
  }

  try {
    const resposta = await fazerBackup({
      tipo,
      usuario: opcoes.usuario,
      observacao: `Backup agendado (${descreverTipoDoDia(tipo)})`,
    });
    const verificado = resposta.verificacao.ok;
    const apagados = verificado ? await aplicarRetencao(admin, tipo, retencaoDe(config, tipo)) : 0;
    const detalhe =
      `backup ${descreverTipoDoDia(tipo)} ${verificado ? "feito e verificado" : "feito, mas FALHOU na verificação"}` +
      (apagados > 0 ? `; ${apagados} antigo(s) apagado(s) pela retenção` : "");
    await registrarExecucao(admin, verificado ? "ok" : "falhou", detalhe);
    await auditar(admin, opcoes.usuario?.id ?? null, "backup_agendado_executado", { tipo, forcado: opcoes.forcar, verificado, apagados });
    return { resultado: verificado ? "ok" : "falhou", tipo, detalhe, apagados };
  } catch (e) {
    // fazerBackup já avisou a falha por Telegram e e-mail
    const detalhe = e instanceof Error ? e.message : "erro desconhecido";
    await registrarExecucao(admin, "falhou", detalhe);
    await auditar(admin, opcoes.usuario?.id ?? null, "backup_agendado_executado", { tipo, forcado: opcoes.forcar, verificado: false, erro: detalhe.slice(0, 200) });
    return { resultado: "falhou", tipo, detalhe, apagados: 0 };
  }
}

// ---------- Conferência da tarde ----------

export interface ResultadoConferencia {
  atrasado: boolean;
  verificados: number;
  problemas: number;
}

/**
 * Roda à tarde: (1) se o backup de hoje deveria ter sido feito e não existe, avisa o atraso;
 * (2) às segundas-feiras, reverifica os 3 backups mais recentes e manda um aviso único com o resultado.
 */
export async function conferirDia(): Promise<ResultadoConferencia> {
  const admin = clienteAdmin();
  const agora = new Date();
  const config = soConfig(await lerLinha(admin));
  const resultado: ResultadoConferencia = { atrasado: false, verificados: 0, problemas: 0 };
  if (!config.ativo) return resultado;

  // 1) Aviso de atraso
  const tipo = escolherTipo(config, agora);
  if (tipo && !(await existeAgendadoHoje(admin, agora, true))) {
    resultado.atrasado = true;
    await auditar(admin, null, "backup_agendado_atrasado", { tipo });
    await notificar("falha", {
      assunto: "SysMúsica: o backup agendado de hoje não foi feito",
      texto:
        `Quando: ${dataHoraSalvador(agora)}\n` +
        `Era esperado um backup ${descreverTipoDoDia(tipo)} às 03:00, mas não há nenhum backup concluído hoje.\n` +
        `Entre em Administração > Backup, veja a lista e use "Fazer backup agora" ou "Executar a rotina agora" na aba Agendamento.`,
    });
  }

  // 2) Verificação semanal (segunda-feira)
  const hoje = new Date(agora.getTime() - 3 * 3_600_000).getUTCDay();
  if (hoje === DIA_VERIFICACAO_SEMANAL) {
    const { data } = await admin
      .from("backup_arquivos")
      .select("id, tipo, criado_em")
      .eq("situacao", "ok")
      .order("criado_em", { ascending: false })
      .limit(3);
    const lista = (data ?? []) as { id: string; tipo: keyof typeof ROTULO_TIPO; criado_em: string }[];

    const linhas: string[] = [];
    for (const backup of lista) {
      const verificacao = await verificarPeloSistema(backup.id);
      resultado.verificados += 1;
      if (!verificacao.ok) resultado.problemas += 1;
      linhas.push(
        `- ${ROTULO_TIPO[backup.tipo] ?? backup.tipo} de ${dataHoraSalvador(new Date(backup.criado_em))}: ` +
          (verificacao.ok ? "íntegro" : `PROBLEMA (${descreverVerificacao(verificacao)})`)
      );
    }
    if (lista.length > 0) {
      await admin.from("backup_agendamento").update({ ultima_verificacao_em: agora.toISOString() }).eq("id", 1);
      await notificar(resultado.problemas === 0 ? "sucesso" : "falha", {
        assunto:
          resultado.problemas === 0
            ? "SysMúsica: verificação semanal dos backups concluída"
            : "SysMúsica: ALERTA na verificação semanal dos backups",
        texto:
          `Quando: ${dataHoraSalvador(agora)}\n` +
          `Backups reverificados: ${resultado.verificados}. Com problema: ${resultado.problemas}.\n\n${linhas.join("\n")}`,
      });
    }
  }
  return resultado;
}
""",
  'src/modules/backup/services/agendamentoApi.ts': r"""/**
 * SysMúsica — Chamadas do navegador às rotas /api/backup/agendamento. Cada chamada leva o token do login
 * (o servidor confere a sessão e a permissão).
 */
import { supabase } from "@/lib/supabase";
import type { AgendamentoPublico, ConfigAgendamento } from "../agendamento";

async function chamar<T>(caminho: string, metodo: "GET" | "POST" | "PUT", corpo?: unknown): Promise<T> {
  const { data } = await supabase.auth.getSession();
  const token = data.session?.access_token;
  if (!token) throw new Error("Sua sessão expirou. Entre de novo.");

  const resposta = await fetch(caminho, {
    method: metodo,
    headers: { Authorization: `Bearer ${token}`, ...(corpo !== undefined ? { "Content-Type": "application/json" } : {}) },
    body: corpo !== undefined ? JSON.stringify(corpo) : undefined,
    cache: "no-store",
  });
  const json = (await resposta.json().catch(() => null)) as { erro?: string } | null;
  if (!resposta.ok) throw new Error(json?.erro ?? "Não foi possível concluir a operação.");
  return json as T;
}

export async function obterAgendamento(): Promise<AgendamentoPublico> {
  return (await chamar<{ agendamento: AgendamentoPublico }>("/api/backup/agendamento", "GET")).agendamento;
}

export async function salvarAgendamento(config: ConfigAgendamento): Promise<AgendamentoPublico> {
  return (await chamar<{ agendamento: AgendamentoPublico }>("/api/backup/agendamento", "PUT", config)).agendamento;
}

export function executarRotinaAgora(): Promise<{ mensagem: string }> {
  return chamar<{ mensagem: string }>("/api/backup/agendamento/executar", "POST");
}
""",
  'src/app/api/cron/backup/route.ts': r"""/**
 * SysMúsica — GET /api/cron/backup: rotina diária do agendamento (chamada pelo Vercel às 06:00 UTC = 03:00 em
 * Salvador). Protegida pelo segredo CRON_SECRET que o próprio Vercel envia. Não usamos "runtime" nem "dynamic":
 * o projeto usa cacheComponents, que não aceita essas opções.
 */
import type { NextRequest } from "next/server";
import { exigirCron, executarRotina } from "@/modules/backup/server/agendamento";
import { responder } from "@/modules/backup/server/rota";

export const maxDuration = 60; // backup + verificação + cópia para o servidor local

export async function GET(request: NextRequest) {
  return responder(async () => {
    exigirCron(request);
    return await executarRotina({ forcar: false, usuario: null });
  });
}
""",
  'src/app/api/cron/conferir/route.ts': r"""/**
 * SysMúsica — GET /api/cron/conferir: conferência da tarde (18:00 UTC = 15:00 em Salvador): avisa se o backup de
 * hoje não foi feito e, às segundas-feiras, reverifica os backups mais recentes. Protegida pelo CRON_SECRET.
 */
import type { NextRequest } from "next/server";
import { conferirDia, exigirCron } from "@/modules/backup/server/agendamento";
import { responder } from "@/modules/backup/server/rota";

export const maxDuration = 60;

export async function GET(request: NextRequest) {
  return responder(async () => {
    exigirCron(request);
    return await conferirDia();
  });
}
""",
  'src/app/api/backup/agendamento/route.ts': r"""/**
 * SysMúsica — Rotas /api/backup/agendamento: GET lê o agendamento; PUT salva. Só o Administrador entra
 * (backup.configurar, conferida no banco a cada chamada).
 */
import type { NextRequest } from "next/server";
import { lerEntradaAgendamento } from "@/modules/backup/agendamento";
import { autenticar } from "@/modules/backup/server/autorizacao";
import { lerAgendamentoPublico, salvarAgendamento } from "@/modules/backup/server/agendamento";
import { ErroBackup } from "@/modules/backup/server/erros";
import { responder } from "@/modules/backup/server/rota";

export async function GET(request: NextRequest) {
  return responder(async () => {
    await autenticar(request, "backup.configurar");
    return { agendamento: await lerAgendamentoPublico() };
  });
}

export async function PUT(request: NextRequest) {
  return responder(async () => {
    const usuario = await autenticar(request, "backup.configurar");
    const entrada = lerEntradaAgendamento(await request.json().catch(() => null));
    if (!entrada) throw new ErroBackup(400, "Os dados enviados estão em um formato inválido.");
    return { agendamento: await salvarAgendamento(entrada, usuario) };
  });
}
""",
  'src/app/api/backup/agendamento/executar/route.ts': r"""/** SysMúsica — POST /api/backup/agendamento/executar: roda a rotina de hoje agora (botão do Administrador). */
import type { NextRequest } from "next/server";
import { autenticar } from "@/modules/backup/server/autorizacao";
import { executarRotina } from "@/modules/backup/server/agendamento";
import { responder } from "@/modules/backup/server/rota";

export const maxDuration = 60;

export async function POST(request: NextRequest) {
  return responder(async () => {
    const usuario = await autenticar(request, "backup.criar");
    const r = await executarRotina({ forcar: true, usuario });
    return { ...r, mensagem: r.resultado === "falhou" ? `A rotina terminou com problema: ${r.detalhe}.` : `Rotina concluída: ${r.detalhe}.` };
  });
}
""",
  'src/app/(painel)/administracao/backup/agendamento/page.tsx': r""""use client";

/**
 * SysMúsica — Página /administracao/backup/agendamento (só o Administrador): backups automáticos diário, semanal,
 * quinzenal e mensal, com a retenção (quantos guardar de cada tipo). A tarefa roda uma vez por dia às 03:00 em
 * Salvador e escolhe o tipo do dia (mensal > quinzenal > semanal > diário). Os botões usam a configuração JÁ SALVA.
 */
import { useCallback, useEffect, useState, type ReactNode } from "react";
import ErrorState from "@/components/ui/ErrorState";
import PageHeader from "@/components/ui/PageHeader";
import Skeleton from "@/components/ui/Skeleton";
import {
  NOMES_DIA_SEMANA,
  descreverTipoDoDia,
  type AgendamentoPublico,
  type ConfigAgendamento,
} from "@/modules/backup/agendamento";
import AbasBackup from "@/modules/backup/components/AbasBackup";
import { dataHoraSalvador } from "@/modules/backup/regras";
import { executarRotinaAgora, obterAgendamento, salvarAgendamento } from "@/modules/backup/services/agendamentoApi";

const classeCampo =
  "rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 shadow-sm " +
  "focus:border-brand-500 focus:outline-none focus:ring-2 focus:ring-brand-200 disabled:opacity-60";
const classeBotao =
  "inline-flex items-center gap-2 rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm font-medium " +
  "text-slate-700 transition hover:bg-slate-50 disabled:cursor-not-allowed disabled:opacity-60";
const classeBotaoPrimario =
  "inline-flex items-center gap-2 rounded-lg bg-brand-600 px-4 py-2 text-sm font-semibold text-white shadow-sm " +
  "transition hover:bg-brand-700 disabled:cursor-not-allowed disabled:opacity-60";
const classeCaixa = "h-4 w-4 rounded border-slate-300 text-brand-600 focus:ring-brand-300";

function Secao({ titulo, children }: { titulo: string; children: ReactNode }) {
  return (
    <section className="rounded-2xl border border-slate-200 bg-white p-5 shadow-sm">
      <h2 className="mb-4 text-sm font-semibold text-slate-900">{titulo}</h2>
      <div className="space-y-4">{children}</div>
    </section>
  );
}

type TipoComCampos = "diario" | "semanal" | "quinzenal" | "mensal";

const LINHAS: { tipo: TipoComCampos; titulo: string; quando: string }[] = [
  { tipo: "diario", titulo: "Diário", quando: "Todos os dias em que não vale outro tipo." },
  { tipo: "semanal", titulo: "Semanal", quando: "Uma vez por semana, no dia escolhido." },
  { tipo: "quinzenal", titulo: "Quinzenal", quando: "Nos dias 1 e 16 de cada mês." },
  { tipo: "mensal", titulo: "Mensal", quando: "Uma vez por mês, no dia escolhido." },
];

export default function AgendamentoBackupPage() {
  const [dados, setDados] = useState<AgendamentoPublico | null>(null);
  const [form, setForm] = useState<ConfigAgendamento | null>(null);
  const [alterado, setAlterado] = useState(false); // há mudanças ainda não salvas
  const [carregando, setCarregando] = useState(true); // inicia true: primeira busca no mount
  const [erro, setErro] = useState<string | null>(null);
  const [ocupado, setOcupado] = useState<string | null>(null);
  const [erroAcao, setErroAcao] = useState<string | null>(null);
  const [aviso, setAviso] = useState<string | null>(null);

  const carregar = useCallback(async () => {
    try {
      const resposta = await obterAgendamento();
      setDados(resposta);
      setForm(resposta.config);
      setAlterado(false);
      setErro(null);
    } catch (e) {
      setErro(e instanceof Error ? e.message : "Não foi possível carregar o agendamento.");
    } finally {
      setCarregando(false);
    }
  }, []);

  // Primeira carga
  useEffect(() => {
    // O setState só roda DEPOIS do await (nunca de forma síncrona). Ignorado apenas nesta linha.
    // eslint-disable-next-line react-hooks/set-state-in-effect
    void carregar();
  }, [carregar]);

  function mudar(parcial: Partial<ConfigAgendamento>) {
    setForm((atual) => (atual ? { ...atual, ...parcial } : atual));
    setAlterado(true);
  }

  // Número inteiro dentro do intervalo; texto vazio ou inválido volta para o mínimo
  function numero(texto: string, min: number, max: number): number {
    const n = Number.parseInt(texto, 10);
    return Number.isNaN(n) ? min : Math.min(max, Math.max(min, n));
  }

  // Roda uma ação mostrando "ocupado" e trata o erro; a mensagem devolvida vira o aviso da tela
  async function executar(chave: string, tarefa: () => Promise<string | void>) {
    if (ocupado) return; // evita dois cliques seguidos
    setOcupado(chave);
    setErroAcao(null);
    setAviso(null);
    try {
      const mensagem = await tarefa();
      if (mensagem) setAviso(mensagem);
    } catch (e) {
      setErroAcao(e instanceof Error ? e.message : "Não foi possível concluir a operação.");
    } finally {
      setOcupado(null);
    }
  }

  function aoSalvar() {
    if (!form) return;
    void executar("salvar", async () => {
      const novo = await salvarAgendamento(form);
      setDados(novo);
      setForm(novo.config);
      setAlterado(false);
      return "Agendamento salvo.";
    });
  }

  function aoExecutar() {
    if (!window.confirm("Isto faz um backup de verdade agora, do tipo que vale para hoje, e aplica a retenção. Continuar?")) return;
    void executar("executar", async () => {
      const resposta = await executarRotinaAgora();
      await carregar(); // atualiza "última execução" e "próximo backup"
      return resposta.mensagem;
    });
  }

  const desabilitado = ocupado !== null;

  return (
    <main className="text-slate-900">
      <div className="__CONTENEDOR__">
        <PageHeader
          titulo="Backup"
          descricao="Backups automáticos e quantos guardar de cada tipo. Somente o Administrador tem acesso."
          acoes={
            <button type="button" className={classeBotaoPrimario} onClick={aoSalvar} disabled={desabilitado || !alterado || !form}>
              {ocupado === "salvar" ? "Salvando..." : "Salvar agendamento"}
            </button>
          }
        />

        <AbasBackup />

        {erroAcao && (
          <p role="alert" className="mb-4 rounded-lg bg-red-50 px-3 py-2 text-sm text-red-700">
            {erroAcao}
          </p>
        )}
        {aviso && (
          <p role="status" className="mb-4 rounded-lg bg-emerald-50 px-3 py-2 text-sm text-emerald-700">
            {aviso}
          </p>
        )}

        {carregando ? (
          <div role="status" aria-live="polite" className="space-y-3">
            <span className="sr-only">Carregando o agendamento...</span>
            {[0, 1, 2].map((i) => (
              <Skeleton key={i} className="h-24" />
            ))}
          </div>
        ) : erro || !dados || !form ? (
          <ErrorState
            titulo="Não foi possível carregar o agendamento."
            mensagem={erro ?? "Tente novamente."}
            onTentarNovamente={() => {
              setCarregando(true);
              void carregar();
            }}
          />
        ) : (
          <div className="space-y-6">
            {alterado && (
              <p className="rounded-lg bg-slate-50 px-3 py-2 text-sm text-slate-600">
                Há mudanças não salvas. Salve antes de usar o botão de executar, que usa o agendamento salvo.
              </p>
            )}

            <Secao titulo="Backup automático">
              <label className="flex items-center gap-2 text-sm text-slate-700">
                <input type="checkbox" className={classeCaixa} checked={form.ativo} onChange={(e) => mudar({ ativo: e.target.checked })} />
                Fazer backups automáticos
              </label>
              <p className="text-xs text-slate-500">
                A rotina roda uma vez por dia, às 03:00 (horário de Salvador). No plano gratuito do Vercel o horário pode variar até uma hora. Em cada dia
                é feito um único backup, do tipo de maior prioridade que valer: mensal, quinzenal, semanal ou diário. Cada backup é verificado, copiado para o
                servidor local (se ligado em Destinos) e avisado por Telegram e e-mail.
              </p>
              <p className="text-sm text-slate-700">
                {dados.proximo
                  ? `Próximo backup automático: ${dataHoraSalvador(new Date(dados.proximo.quando))} (${descreverTipoDoDia(dados.proximo.tipo)}).`
                  : dados.config.ativo
                    ? "Nenhum backup automático previsto: confira os tipos ligados."
                    : "O backup automático está desligado."}
              </p>
            </Secao>

            <Secao titulo="Tipos de backup e retenção">
              <div className="divide-y divide-slate-100 rounded-xl border border-slate-200">
                {LINHAS.map((linha) => {
                  const campoAtivo = `${linha.tipo}_ativo` as const;
                  const campoRetencao = `${linha.tipo}_retencao` as const;
                  return (
                    <div key={linha.tipo} className="flex flex-wrap items-center justify-between gap-3 px-4 py-3">
                      <label className="flex min-w-[14rem] items-start gap-2 text-sm text-slate-700">
                        <input
                          type="checkbox"
                          className={`${classeCaixa} mt-0.5`}
                          checked={form[campoAtivo]}
                          onChange={(e) => mudar({ [campoAtivo]: e.target.checked } as Partial<ConfigAgendamento>)}
                        />
                        <span>
                          <span className="block font-medium text-slate-900">{linha.titulo}</span>
                          <span className="block text-xs text-slate-500">{linha.quando}</span>
                        </span>
                      </label>

                      <div className="flex flex-wrap items-center gap-3 text-sm text-slate-700">
                        {linha.tipo === "semanal" && (
                          <label className="flex items-center gap-2">
                            Dia
                            <select
                              className={classeCampo}
                              value={form.semanal_dia}
                              onChange={(e) => mudar({ semanal_dia: numero(e.target.value, 0, 6) })}
                            >
                              {NOMES_DIA_SEMANA.map((nome, indice) => (
                                <option key={nome} value={indice}>
                                  {nome}
                                </option>
                              ))}
                            </select>
                          </label>
                        )}
                        {linha.tipo === "mensal" && (
                          <label className="flex items-center gap-2">
                            Dia do mês
                            <input
                              type="number"
                              min={1}
                              max={28}
                              className={`${classeCampo} w-20`}
                              value={form.mensal_dia}
                              onChange={(e) => mudar({ mensal_dia: numero(e.target.value, 1, 28) })}
                            />
                          </label>
                        )}
                        <label className="flex items-center gap-2">
                          Guardar os últimos
                          <input
                            type="number"
                            min={1}
                            max={90}
                            className={`${classeCampo} w-20`}
                            value={form[campoRetencao]}
                            onChange={(e) => mudar({ [campoRetencao]: numero(e.target.value, 1, 90) } as Partial<ConfigAgendamento>)}
                          />
                        </label>
                      </div>
                    </div>
                  );
                })}
              </div>
              <p className="text-xs text-slate-500">
                A retenção apaga sozinha os backups antigos de cada tipo, mas só os que já foram verificados, e sempre deixa pelo menos um. Backups manuais e de
                segurança nunca são apagados automaticamente. Os arquivos já copiados para o servidor local não são apagados por aqui.
              </p>
            </Secao>

            <Secao titulo="Conferência e última execução">
              <ul className="list-disc space-y-1 pl-5 text-sm text-slate-700">
                <li>Às 15:00 o sistema confere se o backup do dia foi feito. Se não foi, avisa o atraso por Telegram e e-mail.</li>
                <li>Toda segunda-feira, reverifica os 3 backups mais recentes e manda um resumo.</li>
              </ul>
              <p className="text-sm text-slate-700">
                {dados.ultimo_em
                  ? `Última execução: ${dataHoraSalvador(new Date(dados.ultimo_em))}, ${dados.ultimo_resultado === "ok" ? "concluída" : dados.ultimo_resultado === "pulado" ? "não necessária" : "COM PROBLEMA"}${dados.ultimo_detalhe ? ` (${dados.ultimo_detalhe})` : ""}.`
                  : "Nenhuma execução automática ainda."}
              </p>
              {dados.ultima_verificacao_em && (
                <p className="text-sm text-slate-700">Última verificação semanal: {dataHoraSalvador(new Date(dados.ultima_verificacao_em))}.</p>
              )}
              <div>
                <button type="button" className={classeBotao} onClick={aoExecutar} disabled={desabilitado || alterado}>
                  {ocupado === "executar" ? "Executando..." : "Executar a rotina de hoje agora"}
                </button>
              </div>
            </Secao>
          </div>
        )}
      </div>
    </main>
  );
}
""",
  'vercel.json': r"""{
  "crons": [
    { "path": "/api/cron/backup", "schedule": "0 6 * * *" },
    { "path": "/api/cron/conferir", "schedule": "0 18 * * *" }
  ]
}
""",
}

# 1) nada existente pode ser sobrescrito (inclui o vercel.json: se já existir, paramos para não perder nada)
for caminho in NOVOS:
    if os.path.exists(caminho):
        print("ERRO: já existe", caminho); sys.exit(1)

def trocar(texto, arquivo, antigo, novo):
    if texto.count(antigo) != 1:
        print("ERRO: trecho esperado não encontrado (ou repetido) em", arquivo); sys.exit(1)
    return texto.replace(antigo, novo)

def abrir(arquivo): return open(arquivo, encoding="utf-8").read()

# 2) edições nos arquivos existentes (conferidas antes de gravar qualquer coisa)
ed = {}
a = "src/modules/auditoria/regras.ts"
ed[a] = trocar(abrir(a), a,
  '  backup_copiado_destino: "Copiou o backup para o servidor local",\n',
  '  backup_copiado_destino: "Copiou o backup para o servidor local",\n'
  '  backup_agendamento_alterado: "Alterou o agendamento do backup",\n'
  '  backup_agendado_executado: "Executou o backup agendado",\n'
  '  backup_retencao_aplicada: "Apagou backups antigos (retenção)",\n'
  '  backup_agendado_atrasado: "Backup agendado não foi feito",\n')
a = "src/modules/backup/components/AbasBackup.tsx"
ed[a] = trocar(abrir(a), a,
  '  { href: "/administracao/backup/destinos", rotulo: "Destinos", permissao: "backup.configurar" },\n',
  '  { href: "/administracao/backup/destinos", rotulo: "Destinos", permissao: "backup.configurar" },\n'
  '  { href: "/administracao/backup/agendamento", rotulo: "Agendamento", permissao: "backup.configurar" },\n')
a = "src/modules/backup/server/operacoes.ts"
txt = abrir(a)
if "verificarPeloSistema" in txt:
    print("ERRO: verificarPeloSistema já existe em operacoes.ts"); sys.exit(1)
ed[a] = txt.rstrip("\n") + """

// ---------- Verificação feita pelo sistema (agendamento) ----------

/** Verifica um backup sem usuário (conferência semanal do agendamento): grava o resultado e registra na Auditoria. */
export async function verificarPeloSistema(id: string): Promise<ResultadoVerificacao> {
  const admin = clienteAdmin();
  const linha = await buscarLinha(admin, id);
  const resultado = await verificarArquivo(admin, linha);
  await gravarVerificacao(admin, linha.id, resultado, null);
  await auditar(admin, null, "backup_verificado", linha.id, {
    resultado: resultado.ok ? "integro" : "falhou",
    automatica: true,
    semanal: true,
  });
  return resultado;
}
"""

# 3) contêiner da nova página = o da página Backups (referência de formatação)
ref = abrir("src/app/(painel)/administracao/backup/page.tsx")
achou = re.search(r'<div className="(mx-auto max-w-[^"]+)"', ref)
contenedor = achou.group(1) if achou else "mx-auto max-w-6xl px-4 py-8 sm:px-6 lg:px-8"
print("Contêiner usado:", contenedor, "" if achou else "(padrão: não achei na página Backups)")
pg = "src/app/(painel)/administracao/backup/agendamento/page.tsx"
NOVOS[pg] = NOVOS[pg].replace("__CONTENEDOR__", contenedor)
assert "__CONTENEDOR__" not in NOVOS[pg]

# 4) grava (só chega aqui se todas as conferências passaram)
for caminho, conteudo in NOVOS.items():
    os.makedirs(os.path.dirname(caminho) or ".", exist_ok=True)
    open(caminho, "w", encoding="utf-8").write(conteudo)
for caminho, conteudo in ed.items():
    open(caminho, "w", encoding="utf-8").write(conteudo)

# 5) layout da nova página: cópia do layout dos Destinos (só o nome muda)
origem = "src/app/(painel)/administracao/backup/destinos/layout.tsx"
destino = "src/app/(painel)/administracao/backup/agendamento/layout.tsx"
lay = abrir(origem).replace("Destinos", "Agendamento").replace("destinos", "agendamento")
open(destino, "w", encoding="utf-8").write(lay)
print("Arquivos gravados:", len(NOVOS) + 1, "novos,", len(ed), "alterados.")

PYSCRIPT
[ $? -eq 0 ] || { reverter; exit 1; }

echo; echo "=== 2) Parando o servidor de teste e limpando o cache ==="
pkill -f "next dev" 2>/dev/null; pkill -f next-server 2>/dev/null; pkill -f "next/dist" 2>/dev/null; sleep 2
for i in 1 2 3 4 5; do rm -rf .next 2>/dev/null; [ -d .next ] || break; sleep 1; done

echo; echo "=== 3) Conferência de tipos ==="
npx tsc --noEmit || { reverter; exit 1; }
echo; echo "=== 4) Testes automáticos ==="
npx vitest run src/modules/backup || { reverter; exit 1; }
echo; echo "=== 5) Lint dos arquivos novos e alterados ==="
npx eslint "${ALT[@]}" src/modules/backup/agendamento.ts src/modules/backup/server/agendamento.ts src/modules/backup/services/agendamentoApi.ts \
  "src/app/(painel)/administracao/backup/agendamento" src/app/api/cron src/app/api/backup/agendamento || { reverter; exit 1; }
echo; echo "=== 6) Build de produção (pode demorar alguns minutos) ==="
npm run build || { reverter; exit 1; }

echo; echo "=== 7) Segredo das tarefas automáticas (CRON_SECRET) ==="
if grep -q "^CRON_SECRET=" .env.local 2>/dev/null; then
  echo "CRON_SECRET já existe no .env.local (mantido)."
else
  printf '\nCRON_SECRET=%s\n' "$(openssl rand -hex 32)" >> .env.local && echo "CRON_SECRET criado no .env.local (o valor NÃO é mostrado aqui)."
fi

echo; echo "=== TUDO CERTO: arquivos instalados e conferidos ==="
git status --short
) 2>&1 | tee /tmp/agendamento-instalar.log
