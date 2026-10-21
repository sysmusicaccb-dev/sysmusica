import { describe, expect, it } from "vitest";
import { AVISO_SEM_CIDADE, cidadeDaCasa } from "./casaDoEvento";

describe("cidadeDaCasa", () => {
  it("usa a cidade cadastrada na casa e trava o campo", () => {
    expect(cidadeDaCasa({ nome: "Cidade Nova", cidade: "Jequié" })).toEqual({
      cidade: "Jequié",
      travada: true,
      aviso: null,
    });
  });

  it("tira espaços extras da cidade", () => {
    expect(cidadeDaCasa({ nome: "Cidade Nova", cidade: "  Jequié  " }).cidade).toBe("Jequié");
  });

  it("casa sem cidade cadastrada: campo livre e aviso", () => {
    for (const cidade of [null, "", "   "]) {
      expect(cidadeDaCasa({ nome: "Cidade Nova", cidade })).toEqual({
        cidade: "",
        travada: false,
        aviso: AVISO_SEM_CIDADE,
      });
    }
  });

  it("casa não encontrada (fora da abrangência): campo livre e aviso", () => {
    expect(cidadeDaCasa(null)).toEqual({ cidade: "", travada: false, aviso: AVISO_SEM_CIDADE });
  });
});
