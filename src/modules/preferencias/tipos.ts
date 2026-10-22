/** Sysmusica — Tipos das preferências de aparência de cada usuário. */

export type TemaId = "claro" | "escuro" | "sistema"; // "sistema" = segue o modo do aparelho
export type CorId = "indigo" | "azul" | "verde" | "vinho" | "grafite";
export type FonteId = "normal" | "media" | "grande";

export interface Preferencias {
  tema: TemaId;
  cor: CorId;
  fonte: FonteId;
}
