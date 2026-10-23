import { describe, expect, it } from "vitest";
import { normalizarRotulo, rotuloEfetivo, validarRotulo } from "./regras";

describe("nomes do menu", () => {
  it("normaliza espaços", () => {
    expect(normalizarRotulo("  Painel   ao  Vivo ")).toBe("Painel ao Vivo");
  });
  it("valida vazio, tamanho e símbolos", () => {
    expect(validarRotulo("   ")).not.toBeNull();
    expect(validarRotulo("a".repeat(41))).not.toBeNull();
    expect(validarRotulo("<b>")).not.toBeNull();
    expect(validarRotulo("Painel ao Vivo")).toBeNull();
  });
  it("usa o nome salvo ou o padrão", () => {
    expect(rotuloEfetivo("/a", "Padrão", { "/a": "Novo" })).toBe("Novo");
    expect(rotuloEfetivo("/b", "Padrão", { "/a": "Novo" })).toBe("Padrão");
    expect(rotuloEfetivo("/a", "Padrão", { "/a": "  " })).toBe("Padrão");
  });
});
