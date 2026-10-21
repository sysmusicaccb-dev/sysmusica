/**
 * SysMúsica — Campos obrigatórios do evento (regra pura, sem banco).
 * Todos os campos do formulário de evento são obrigatórios. Devolve os NOMES (como aparecem na tela) dos
 * campos que estão vazios, na ordem do formulário, para a tela marcar cada um e mostrar o alerta.
 */
export interface CamposEvento {
  tipo: string; // "Descrição do evento" na tela
  dataEvento: string; // valor do campo data e hora (vazio = não preenchido)
  cidade: string;
  casaOracaoId: string;
}

export const ROTULO_TIPO = "Descrição do evento";
export const ROTULO_DATA = "Data e hora";
export const ROTULO_CIDADE = "Cidade";
export const ROTULO_CASA_ORACAO = "Casa de Oração";

export function camposFaltando(campos: CamposEvento): string[] {
  const faltando: string[] = [];
  // Ordem do formulário: Descrição do evento, Data e hora, Casa de Oração, Cidade
  if (!campos.tipo.trim()) faltando.push(ROTULO_TIPO);
  if (!campos.dataEvento.trim()) faltando.push(ROTULO_DATA);
  if (!campos.casaOracaoId.trim()) faltando.push(ROTULO_CASA_ORACAO);
  if (!campos.cidade.trim()) faltando.push(ROTULO_CIDADE);
  return faltando;
}

/** Mensagem do alerta: "Preencha todos os campos obrigatórios: Local, Cidade." */
export function mensagemCamposFaltando(faltando: string[]): string {
  return `Preencha todos os campos obrigatórios: ${faltando.join(", ")}.`;
}
