import { describe, expect, it } from "vitest";
import { rotuloNomeEncarregado } from "./perfilConfig";

describe("rotuloNomeEncarregado", () => {
  it("perfil só com Instrutor: um só não numera, vários numeram", () => {
    expect(rotuloNomeEncarregado(0, 1, ["INSTRUTOR"], "")).toBe("Nome do Instrutor");
    expect(rotuloNomeEncarregado(1, 3, ["INSTRUTOR"], "")).toBe("Nome do 2º Instrutor");
  });
  it("perfil com vários cargos usa o cargo escolhido na linha", () => {
    expect(rotuloNomeEncarregado(0, 2, ["LOCAL", "INSTRUTOR"], "LOCAL")).toBe("Nome do 1º Encarregado Local");
    expect(rotuloNomeEncarregado(0, 1, ["LOCAL", "INSTRUTOR"], "")).toBe("Nome do Encarregado");
  });
});
