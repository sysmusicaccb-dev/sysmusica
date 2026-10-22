/** Sysmusica — Número e título de um hino para as listas da tela Dados do Ensaio. */
import { rotuloCompleto, rotuloHino, type Hino } from "@/modules/hinos/regras";
import { separarRotulo } from "./apresentacao";

export function partesDoHino(hino: Hino): { numero: string; titulo: string } {
  return separarRotulo(rotuloCompleto(hino), rotuloHino(hino.categoria, hino.numero));
}
