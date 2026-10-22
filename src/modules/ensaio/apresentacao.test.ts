/** Sysmusica — Testes dos textos de apresentação dos Dados do Ensaio. */
import { describe, expect, it } from "vitest";
import { localDoEvento, pluralEncarregado, separarRotulo } from "./apresentacao";

describe("localDoEvento", () => {
  it("junta cidade e casa de oração em maiúsculas", () => {
    expect(localDoEvento({ cidade: "Gandu", casa_oracao: "Central", local: null })).toBe("GANDU - CENTRAL");
  });
  it("usa o local digitado quando não há casa de oração e ignora o que falta", () => {
    expect(localDoEvento({ cidade: null, casa_oracao: null, local: "Salão" })).toBe("SALÃO");
    expect(localDoEvento({ cidade: "Jequié", casa_oracao: null, local: null })).toBe("JEQUIÉ");
    expect(localDoEvento({ cidade: null, casa_oracao: null, local: null })).toBe("");
  });
});

describe("separarRotulo", () => {
  it("tira o número do começo do rótulo completo", () => {
    expect(separarRotulo("12 — Saudai o nome de Jesus", "12")).toEqual({ numero: "12", titulo: "Saudai o nome de Jesus" });
    expect(separarRotulo("Coro 3 - Firmes nas promessas", "Coro 3")).toEqual({ numero: "Coro 3", titulo: "Firmes nas promessas" });
  });
  it("mantém o rótulo inteiro quando não começa pelo número", () => {
    expect(separarRotulo("Saudai", "12")).toEqual({ numero: "12", titulo: "Saudai" });
    expect(separarRotulo("12", "12")).toEqual({ numero: "12", titulo: "12" });
  });
});

describe("pluralEncarregado", () => {
  it("coloca o rótulo no plural", () => {
    expect(pluralEncarregado("Encarregado Regional")).toBe("Encarregados Regionais");
    expect(pluralEncarregado("Encarregado Local")).toBe("Encarregados Locais");
    expect(pluralEncarregado("Encarregado")).toBe("Encarregados");
  });
});
