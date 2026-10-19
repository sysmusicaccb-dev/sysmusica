/**
 * SysMúsica — Campos obrigatórios do evento (regra pura, sem banco).
 * Todos os campos do formulário de evento são obrigatórios. Devolve os NOMES (como aparecem na tela) dos
 * campos que estão vazios, na ordem do formulário, para a tela marcar cada um e mostrar o alerta.
 */
export interface CamposEvento {
  tipo: string;
  finalidade: string;
  dataEvento: string; // valor do campo data e hora (vazio = não preenchido)
  local: string;
  cidade: string;
  comumId: string;
}

export const ROTULO_TIPO = "Tipo";
export const ROTULO_FINALIDADE = "Finalidade do evento";
export const ROTULO_DATA = "Data e hora";
export const ROTULO_LOCAL = "Local";
export const ROTULO_CIDADE = "Cidade";
export const ROTULO_COMUM = "Comum";

export function camposFaltando(campos: CamposEvento): string[] {
  const faltando: string[] = [];
  if (!campos.tipo.trim()) faltando.push(ROTULO_TIPO);
  if (!campos.finalidade.trim()) faltando.push(ROTULO_FINALIDADE);
  if (!campos.dataEvento.trim()) faltando.push(ROTULO_DATA);
  if (!campos.local.trim()) faltando.push(ROTULO_LOCAL);
  if (!campos.cidade.trim()) faltando.push(ROTULO_CIDADE);
  if (!campos.comumId.trim()) faltando.push(ROTULO_COMUM);
  return faltando;
}

/** Mensagem do alerta: "Preencha todos os campos obrigatórios: Local, Cidade." */
export function mensagemCamposFaltando(faltando: string[]): string {
  return `Preencha todos os campos obrigatórios: ${faltando.join(", ")}.`;
}
