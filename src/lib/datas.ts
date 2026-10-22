/**
 * Sysmusica — Formatação de datas para a interface (pt-BR, fuso do navegador).
 * O banco devolve timestamptz em ISO 8601 (UTC); aqui convertemos para exibição.
 * Data e hora são formatadas em separado para não depender do separador que a
 * plataforma usa entre elas.
 */

/** "2026-10-13T22:30:00Z" -> "13/10/2026 às 19:30" (no fuso local) */
export function formatarDataHora(iso: string): string {
  const data = new Date(iso);
  const dia = data.toLocaleDateString("pt-BR", {
    day: "2-digit",
    month: "2-digit",
    year: "numeric",
  });
  const hora = data.toLocaleTimeString("pt-BR", { hour: "2-digit", minute: "2-digit" });
  return `${dia} às ${hora}`;
}

/** Dia e mês abreviado, para blocos de calendário: { dia: "13", mes: "out" } */
export function partesDaData(iso: string): { dia: string; mes: string } {
  const data = new Date(iso);
  return {
    dia: data.toLocaleDateString("pt-BR", { day: "2-digit" }),
    mes: data.toLocaleDateString("pt-BR", { month: "short" }).replace(".", ""),
  };
}
