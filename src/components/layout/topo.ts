/**
 * Sysmusica — Regras do topo azul: atalhos e resumo do evento do dia. (Portaria e Relatório saíram do topo.)
 * Funções puras (sem React), para poderem ser testadas.
 */
import type { LucideIcon } from "lucide-react";
import type { CodigoPermissao } from "@/lib/permissoes";

export interface AtalhoTopo {
  href: string;
  rotulo: string;
  icone: LucideIcon;
  permissao: CodigoPermissao;
}

/** Atalhos fixos do topo (a engrenagem de Configurações é um botão à parte). */
export const ATALHOS_TOPO: AtalhoTopo[] = [];

/** Só os atalhos que o usuário pode abrir. */
export function atalhosDoTopo(pode: (permissao: CodigoPermissao) => boolean): AtalhoTopo[] {
  return ATALHOS_TOPO.filter((atalho) => pode(atalho.permissao));
}

/** Fuso do sistema: Bahia (UTC-3, o mesmo de Brasília). */
const FUSO_TOPO = "America/Bahia";

/**
 * Dia da semana, data e hora ATUAIS para o topo, sempre no fuso da Bahia e em 24 horas.
 * Ex.: { dia: "Sex, 23/10/2026", hora: "01:04" }. (hourCycle h23 evita "24:04" depois da meia-noite.)
 */
export function formatarRelogioDoTopo(data: Date): { dia: string; hora: string } {
  const partes = (opcoes: Intl.DateTimeFormatOptions) =>
    Object.fromEntries(
      new Intl.DateTimeFormat("pt-BR", { timeZone: FUSO_TOPO, ...opcoes })
        .formatToParts(data)
        .map((parte) => [parte.type, parte.value])
    ) as Record<string, string>;

  const d = partes({ weekday: "short", day: "2-digit", month: "2-digit", year: "numeric" });
  const semana = d.weekday.replace(".", "");
  const h = partes({ hour: "2-digit", minute: "2-digit", hourCycle: "h23" });
  return {
    dia: `${semana.charAt(0).toUpperCase()}${semana.slice(1)}, ${d.day}/${d.month}/${d.year}`,
    hora: `${h.hour}:${h.minute}`,
  };
}

export interface ResumoEventoTopo {
  titulo: string; // ex.: "Ensaio Regional"
  local: string; // ex.: "GANDÚ - CENTRAL"
  dataIso: string; // data e hora do evento (para formatar na tela)
}

function texto(origem: Record<string, unknown>, chave: string): string {
  const valor = origem[chave];
  return typeof valor === "string" ? valor.trim() : "";
}

/**
 * Resume o evento mais próximo (primeiro da lista do painel) para o topo.
 * Devolve null se não houver evento ou se faltar a data.
 */
export function resumoEventoDoTopo(evento: unknown): ResumoEventoTopo | null {
  if (!evento || typeof evento !== "object") return null;
  const dados = evento as Record<string, unknown>;
  const dataIso = texto(dados, "data_evento");
  if (!dataIso) return null;

  const titulo = texto(dados, "tipo") || "Evento";
  const casa = texto(dados, "casa_oracao_nome") || texto(dados, "local_evento");
  const local = [texto(dados, "cidade"), casa].filter(Boolean).join(" - ").toUpperCase();
  return { titulo, local, dataIso };
}
