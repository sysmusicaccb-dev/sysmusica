/**
 * SysMúsica — Regras puras da Gestão de portarias (sem banco). As regras de verdade (cota,
 * aprovação, abrangência) ficam no banco; aqui só há textos e conferências auxiliares da tela.
 */
import type { VarianteBadge } from "@/components/ui/Badge";
import { normalizarTexto } from "@/lib/texto";
import type { CotaPortarias, StatusPortaria } from "./tipos";

export const ROTULO_STATUS: Record<StatusPortaria, string> = {
  PENDENTE_APROVACAO: "Pendente de aprovação",
  APROVADA: "Aprovada",
  REJEITADA: "Rejeitada",
};

export const ROTULO_ACAO: Record<string, string> = {
  CRIADA: "Criada",
  APROVADA: "Aprovada",
  REJEITADA: "Rejeitada",
  EXCLUIDA: "Excluída",
};

/** Cor do selo de cada situação. */
export function varianteStatus(status: StatusPortaria): VarianteBadge {
  if (status === "APROVADA") return "sucesso";
  if (status === "REJEITADA") return "perigo";
  return "alerta";
}

export const MOTIVO_MINIMO = 5;
export const MOTIVO_MAXIMO = 300;

/** Valida o motivo da rejeição: devolve a mensagem de erro ou null se estiver certo. */
export function validarMotivoRejeicao(texto: string): string | null {
  const tamanho = texto.trim().length;
  if (tamanho < MOTIVO_MINIMO) return `Informe o motivo da rejeição (mínimo de ${MOTIVO_MINIMO} caracteres).`;
  if (tamanho > MOTIVO_MAXIMO) return `O motivo pode ter no máximo ${MOTIVO_MAXIMO} caracteres.`;
  return null;
}

/** Texto da cota do dia: "Hoje: 2 de 4 portarias criadas · restam 2". */
export function descreverCota(cota: CotaPortarias): string {
  const sobra =
    cota.restantes === 0 ? "limite atingido" : cota.restantes === 1 ? "resta 1" : `restam ${cota.restantes}`;
  return `Hoje: ${cota.usadas} de ${cota.limite} portarias criadas · ${sobra}`;
}

/** A cidade está na lista? (ignora acento e maiúsculas, como o banco) */
export function cidadeNaAbrangencia(cidade: string | null, cidades: string[]): boolean {
  if (!cidade) return false;
  const chave = normalizarTexto(cidade);
  return cidades.some((item) => normalizarTexto(item) === chave);
}
