/**
 * Sysmusica — Cópia das preferências neste aparelho (localStorage).
 * Serve para a aparência aparecer logo ao abrir o sistema e para funcionar mesmo sem a conta.
 * Qualquer falha (navegador sem armazenamento, modo privado) é ignorada: o sistema usa o padrão.
 */
import { lerPreferencias } from "./regras";
import type { Preferencias } from "./tipos";

const CHAVE = "sysmusica.preferencias";

/** Preferências guardadas neste aparelho, ou nulo se não houver. */
export function lerPreferenciasLocais(): Preferencias | null {
  if (typeof window === "undefined") return null;
  try {
    const texto = window.localStorage.getItem(CHAVE);
    return texto ? lerPreferencias(JSON.parse(texto)) : null;
  } catch {
    return null;
  }
}

export function guardarPreferenciasLocais(preferencias: Preferencias): void {
  try {
    window.localStorage.setItem(CHAVE, JSON.stringify(preferencias));
  } catch {
    // sem armazenamento disponível: a aparência só não é lembrada neste aparelho
  }
}
