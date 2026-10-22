/**
 * Sysmusica — Ciclo de vida do evento (regras puras, sem banco).
 *
 * A situação é CALCULADA pela data (ninguém precisa "finalizar" o evento na mão):
 *   Agendado     -> ainda falta mais de 2h para começar
 *   Em andamento -> de 2h antes até 3h depois do início (a mesma janela da portaria)
 *   Encerrado    -> passou de 3h depois do início (somente leitura; só o Administrador corrige)
 *   Arquivado    -> encerrado há mais de 30 dias (continua consultável, na aba Arquivo)
 *   Cancelado    -> só o Administrador cancela, sempre com motivo; o histórico fica guardado
 * O banco aplica as mesmas regras (migração 0034); aqui ficam só os cálculos para a tela.
 */
import type { VarianteBadge } from "@/components/ui/Badge";
import { janelaDaPortaria } from "@/modules/portarias/janela";

export type SituacaoEvento = "AGENDADO" | "EM_ANDAMENTO" | "ENCERRADO" | "ARQUIVADO" | "CANCELADO";
export type AbaEvento = "proximos" | "encerrados" | "arquivo";

/** Dias depois do encerramento em que o evento passa para o Arquivo. */
export const DIAS_ARQUIVO = 30;
const MS_DIA = 24 * 60 * 60 * 1000;

export const ROTULO_SITUACAO_EVENTO: Record<SituacaoEvento, string> = {
  AGENDADO: "Agendado",
  EM_ANDAMENTO: "Em andamento",
  ENCERRADO: "Encerrado",
  ARQUIVADO: "Arquivado",
  CANCELADO: "Cancelado",
};

export const MOTIVO_CANCELAMENTO_MINIMO = 5;
export const MOTIVO_CANCELAMENTO_MAXIMO = 250;

/** Situação do evento no instante "agora" (ms), ignorando o cancelamento. */
function situacaoPelaData(dataEvento: string, agora: number, encerradoManual = false): Exclude<SituacaoEvento, "CANCELADO"> {
  const janela = janelaDaPortaria(dataEvento, agora);
  if (!janela) return "AGENDADO"; // data inválida: mantém visível para alguém corrigir
  if (janela.situacao === "antes") return "AGENDADO";
  // Encerrado à mão (migração 0051) antes das 3h: deixa de estar em andamento
  if (janela.situacao === "aberta") return encerradoManual ? "ENCERRADO" : "EM_ANDAMENTO";
  return agora - janela.fecha.getTime() > DIAS_ARQUIVO * MS_DIA ? "ARQUIVADO" : "ENCERRADO";
}

/** Situação do evento: cancelado vence a data. */
export function situacaoDoEvento(
  dataEvento: string,
  cancelado: boolean,
  agora: number,
  encerradoEm?: string | null
): SituacaoEvento {
  if (cancelado) return "CANCELADO";
  return situacaoPelaData(dataEvento, agora, Boolean(encerradoEm));
}

/** Em qual aba da tela de Eventos o evento aparece. Cancelado nunca fica em "Próximos". */
export function abaDoEvento(
  dataEvento: string,
  cancelado: boolean,
  agora: number,
  encerradoEm?: string | null
): AbaEvento {
  const pelaData = situacaoPelaData(dataEvento, agora, Boolean(encerradoEm));
  if (pelaData === "ARQUIVADO") return "arquivo";
  if (cancelado || pelaData === "ENCERRADO") return "encerrados";
  return "proximos";
}

/** O evento ainda está aberto (agendado ou em andamento, e não cancelado)? */
export function eventoAberto(dataEvento: string, cancelado: boolean, agora: number, encerradoEm?: string | null): boolean {
  const situacao = situacaoDoEvento(dataEvento, cancelado, agora, encerradoEm);
  return situacao === "AGENDADO" || situacao === "EM_ANDAMENTO";
}

/** Cor do selo de cada situação. */
export function varianteSituacaoEvento(situacao: SituacaoEvento): VarianteBadge {
  if (situacao === "EM_ANDAMENTO") return "sucesso";
  if (situacao === "CANCELADO") return "perigo";
  return "neutro";
}

/** Valida o motivo do cancelamento: devolve a mensagem de erro ou null se estiver certo. */
export function validarMotivoCancelamento(texto: string): string | null {
  const tamanho = texto.trim().length;
  if (tamanho < MOTIVO_CANCELAMENTO_MINIMO) {
    return `Informe o motivo do cancelamento (mínimo de ${MOTIVO_CANCELAMENTO_MINIMO} caracteres).`;
  }
  if (tamanho > MOTIVO_CANCELAMENTO_MAXIMO) {
    return `O motivo pode ter no máximo ${MOTIVO_CANCELAMENTO_MAXIMO} caracteres.`;
  }
  return null;
}
