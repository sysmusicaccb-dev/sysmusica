/**
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
