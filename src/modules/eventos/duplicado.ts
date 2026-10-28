/**
 * Sysmusica — Aviso de evento duplicado (regra pura, sem banco).
 * Ao cadastrar (ou mudar a data/Casa de Oração de) um evento, a tela procura outro evento na MESMA Casa de Oração, na
 * mesma data e no mesmo minuto. É só um aviso: a pessoa pode continuar, porque pode ser outra sala ou espaço.
 */
export interface EventoNoHorario {
  id: string;
  tipo: string;
  data_evento: string;
  local: string;
}

/** Início (inclusive) e fim (exclusivo) do minuto da data informada, em ISO. Data inválida = null. */
export function janelaDoMinuto(dataIso: string): { inicio: string; fim: string } | null {
  const instante = new Date(dataIso).getTime();
  if (Number.isNaN(instante)) return null;
  const inicio = Math.floor(instante / 60000) * 60000;
  return { inicio: new Date(inicio).toISOString(), fim: new Date(inicio + 60000).toISOString() };
}

/**
 * Vale procurar duplicado? Sim ao cadastrar, ou ao editar mudando a Casa de Oração ou a data/hora (no minuto):
 * editar só o resto não deve avisar de novo sobre algo que já existia.
 */
export function deveVerificarDuplicado(
  original: { casa_oracao_id?: string | null; data_evento: string } | null,
  casaOracaoId: string,
  dataIso: string
): boolean {
  if (casaOracaoId === "") return false;
  if (original === null) return true;
  const antes = Math.floor(new Date(original.data_evento).getTime() / 60000);
  const depois = Math.floor(new Date(dataIso).getTime() / 60000);
  return (original.casa_oracao_id ?? "") !== casaOracaoId || antes !== depois;
}

/** "Ensaio Local — Casa de Oração Centro": uma linha por evento achado. */
export function descreverEventoNoHorario(evento: EventoNoHorario): string {
  return [evento.tipo, evento.local].filter((parte) => parte.trim() !== "").join(" — ");
}
