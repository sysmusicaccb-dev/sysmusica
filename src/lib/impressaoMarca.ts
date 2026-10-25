/**
 * Sysmusica — Marca usada nas folhas impressas (nome e logomarca), para todas as telas que imprimem.
 * A logomarca precisa de endereço completo (a janela da impressão não tem o endereço do site).
 */
import { MARCA } from "@/lib/marca";

export function opcoesMarca(): { marca: string; logoUrl: string } {
  // Sem logomarca: endereço vazio (a folha leva só o nome do sistema)
  return { marca: MARCA.nome, logoUrl: "" };
}
