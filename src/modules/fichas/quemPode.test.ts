import { describe, expect, it } from "vitest";
import { FICHAS } from "./regras";
import { quemPode } from "./quemPode";

describe("quemPode", () => {
  it("toda ficha do catálogo tem o texto de quem pode", () => {
    for (const ficha of FICHAS) expect(quemPode(ficha.tipo), ficha.tipo).not.toBe("");
  });
  it("tipo desconhecido volta vazio", () => {
    expect(quemPode("XYZ")).toBe("");
  });
  it("a necessidade de instrumentos não tem trava", () => {
    expect(quemPode("NECESSIDADE_INSTRUMENTO")).toMatch(/Qualquer pessoa/);
  });
});
