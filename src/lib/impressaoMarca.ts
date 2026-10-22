/**
 * Sysmusica — Marca usada nas folhas impressas (nome e logomarca), para todas as telas que imprimem.
 * A logomarca precisa de endereço completo (a janela da impressão não tem o endereço do site).
 */
import { MARCA } from "@/lib/marca";

export function opcoesMarca(): { marca: string; logoUrl: string } {
  const https = typeof window !== "undefined" && window.location.protocol === "https:";
  return {
    marca: MARCA.nome,
    logoUrl: https ? `${window.location.origin}${MARCA.logoCaminho}` : MARCA.logoCaminho,
  };
}
