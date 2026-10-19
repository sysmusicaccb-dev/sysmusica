/**
 * SysMúsica — Regra da data do evento (pura, sem banco): não se agenda evento em data e hora que já passaram.
 * Uma tolerância de 5 minutos evita falso alarme (o campo de data só tem precisão de minutos e o usuário leva
 * alguns segundos para salvar). Ao EDITAR, só vale se a data/hora for alterada: um evento antigo continua
 * podendo ter outros dados corrigidos. A mesma regra é aplicada no banco (migração 0025).
 */
export const TOLERANCIA_MS = 5 * 60 * 1000;

export const MENSAGEM_DATA_PASSADA =
  "Não é possível agendar um evento em uma data e hora que já passaram. Escolha uma data e hora futuras.";

/**
 * Devolve a mensagem de erro ou null se a data está correta.
 * dataOriginal = data já gravada do evento (null ao cadastrar um evento novo).
 */
export function validarDataDoEvento(dataIso: string, agora: number, dataOriginal: string | null): string | null {
  const nova = new Date(dataIso).getTime();
  if (Number.isNaN(nova)) return "Informe uma data e hora válidas.";

  // Edição sem mudar a data e a hora (no minuto): não reavalia
  if (dataOriginal !== null) {
    const original = new Date(dataOriginal).getTime();
    if (!Number.isNaN(original) && Math.floor(original / 60000) === Math.floor(nova / 60000)) return null;
  }

  return nova < agora - TOLERANCIA_MS ? MENSAGEM_DATA_PASSADA : null;
}
