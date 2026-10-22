/**
 * Sysmusica — Regra pura: cidade do evento a partir da Casa de Oração escolhida (sem banco).
 * A cidade vem do cadastro da casa e fica travada na tela. Se a casa não tem cidade cadastrada
 * (ou o cadastro não pôde ser lido), o campo fica livre para digitar e um aviso orienta a completar o cadastro.
 */
export interface DadosDaCasa {
  nome: string;
  cidade: string | null;
}

export interface CidadeDaCasa {
  cidade: string; // texto para o campo Cidade ("" = a pessoa precisa informar)
  travada: boolean; // true = veio do cadastro da casa (campo somente leitura)
  aviso: string | null;
}

export const AVISO_SEM_CIDADE =
  "Esta Casa de Oração ainda não tem cidade cadastrada. Informe a cidade abaixo e depois complete o cadastro dela em Organização.";

export function cidadeDaCasa(casa: DadosDaCasa | null): CidadeDaCasa {
  const cidade = casa?.cidade?.trim() ?? "";
  if (cidade) return { cidade, travada: true, aviso: null };
  return { cidade: "", travada: false, aviso: AVISO_SEM_CIDADE };
}
