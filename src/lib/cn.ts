/**
 * Sysmusica — Junta classes CSS ignorando valores vazios.
 * Uso: cn("base", condicao && "extra", outra ? "a" : "b")
 */
export function cn(...classes: Array<string | false | null | undefined>): string {
  return classes.filter(Boolean).join(" ");
}
