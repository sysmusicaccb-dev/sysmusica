/**
 * Sysmusica — Textos de apresentação dos Dados do Ensaio (funções puras, sem React).
 */

/** Local do evento no formato do topo e do resumo: "CIDADE - CASA DE ORAÇÃO" (ou o local digitado). */
export function localDoEvento(evento: {
  cidade: string | null;
  casa_oracao: string | null;
  local: string | null;
}): string {
  const casa = evento.casa_oracao || evento.local || "";
  return [evento.cidade, casa].filter(Boolean).join(" - ").toUpperCase();
}

/**
 * Separa "Coro 3 — Título do hino" em número ("Coro 3") e título ("Título do hino"), a partir do rótulo curto.
 * Se o rótulo completo não começar pelo curto, devolve o completo inteiro como título.
 */
export function separarRotulo(completo: string, curto: string): { numero: string; titulo: string } {
  if (curto !== "" && completo.startsWith(curto)) {
    const titulo = completo.slice(curto.length).replace(/^[\s\-–—:.]+/, "");
    if (titulo !== "") return { numero: curto, titulo };
  }
  return { numero: curto, titulo: completo };
}

/** "Encarregado Regional" -> "Encarregados Regionais"; "Encarregado Local" -> "Encarregados Locais". */
export function pluralEncarregado(rotulo: string): string {
  const m = /^Encarregado (\S+)l$/.exec(rotulo);
  return m ? `Encarregados ${m[1]}is` : `${rotulo}s`;
}
