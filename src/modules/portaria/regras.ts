/**
 * SysMúsica — Regras puras da Portaria (sem acesso ao banco). Testadas em regras.test.ts.
 */
import { datetimeLocalParaIso } from "@/lib/dataLocal";

/** Status possíveis de uma presença. */
export const STATUS_PRESENCA = ["Presente", "Ausente", "Justificado"] as const;

/**
 * Valida os horários do formulário de edição (valores do campo datetime-local):
 * a entrada é obrigatória e válida; a saída é opcional, mas não pode ser anterior à entrada.
 * Devolve a mensagem de erro ou null quando está tudo certo.
 */
export function validarHorarios(entradaLocal: string, saidaLocal: string): string | null {
  const entrada = datetimeLocalParaIso(entradaLocal);
  if (!entrada) return "Informe uma hora de entrada válida.";

  if (saidaLocal.trim() === "") return null; // saída em branco = ainda não saiu

  const saida = datetimeLocalParaIso(saidaLocal);
  if (!saida) return "Informe uma hora de saída válida.";
  if (new Date(saida).getTime() < new Date(entrada).getTime()) {
    return "A hora de saída não pode ser anterior à hora de entrada.";
  }
  return null;
}
