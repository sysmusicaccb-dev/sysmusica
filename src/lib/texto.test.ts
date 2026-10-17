import { describe, expect, it } from "vitest";
import { normalizarTexto } from "@/lib/texto";

describe("normalizarTexto", () => {
  it("remove acentos e ignora maiúsculas", () => {
    expect(normalizarTexto("Órgão")).toBe("orgao");
  });

  it("colapsa espaços repetidos e apara as pontas", () => {
    expect(normalizarTexto("  Sax   Soprano ")).toBe("sax soprano");
  });

  it("devolve texto vazio para entrada vazia", () => {
    expect(normalizarTexto("   ")).toBe("");
  });
});
