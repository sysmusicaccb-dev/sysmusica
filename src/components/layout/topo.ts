/**
 * Sysmusica — Regras do topo azul: atalhos (Portaria, Relatório) e resumo do evento do dia.
 * Funções puras (sem React), para poderem ser testadas.
 */
import { DoorOpen, FileText, type LucideIcon } from "lucide-react";
import type { CodigoPermissao } from "@/lib/permissoes";

export interface AtalhoTopo {
  href: string;
  rotulo: string;
  icone: LucideIcon;
  permissao: CodigoPermissao;
}

/** Atalhos fixos do topo (a engrenagem de Configurações é um botão à parte). */
export const ATALHOS_TOPO: AtalhoTopo[] = [
  { href: "/portaria", rotulo: "Portaria", icone: DoorOpen, permissao: "portaria.visualizar" },
  { href: "/relatorios", rotulo: "Relatório", icone: FileText, permissao: "relatorios.visualizar" },
];

/** Só os atalhos que o usuário pode abrir. */
export function atalhosDoTopo(pode: (permissao: CodigoPermissao) => boolean): AtalhoTopo[] {
  return ATALHOS_TOPO.filter((atalho) => pode(atalho.permissao));
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
