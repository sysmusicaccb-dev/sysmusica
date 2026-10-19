/**
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
