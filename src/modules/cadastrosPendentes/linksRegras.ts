/**
 * Sysmusica — Regras puras dos links de cadastro por região (sem banco, para poder ser testado sem o Supabase).
 */
export type NivelLink = "RRM" | "RA" | "ADM";

/** Endereço que as pessoas recebem: o do sistema + /cadastro?l=CÓDIGO. */
export function urlDoLinkDeCadastro(origem: string, codigo: string): string {
  return `${origem}/cadastro?l=${encodeURIComponent(codigo)}`;
}
