import { describe, expect, it } from "vitest";
import { camposFaltando, mensagemCamposFaltando, type CamposEvento } from "./camposEvento";

const completo: CamposEvento = {
  tipo: "Ensaio Regional",
  dataEvento: "2026-10-25T10:00",
  cidade: "Jequié",
  casaOracaoId: "abc",
};

describe("camposFaltando", () => {
  it("nada falta quando tudo está preenchido", () => {
    expect(camposFaltando(completo)).toEqual([]);
  });

  it("aponta o campo vazio e respeita a ordem do formulário", () => {
    expect(camposFaltando({ ...completo, cidade: "" })).toEqual(["Cidade"]);
    expect(camposFaltando({ tipo: "", dataEvento: "", cidade: "", casaOracaoId: "" })).toEqual([
      "Descrição do evento",
      "Data e hora",
      "Casa de Oração",
      "Cidade",
    ]);
  });

  it("espaços em branco contam como vazio", () => {
    expect(camposFaltando({ ...completo, cidade: "   ", tipo: " " })).toEqual(["Descrição do evento", "Cidade"]);
  });

  it("a casa de oração escolhida é obrigatória ('Nenhuma' = vazio)", () => {
    expect(camposFaltando({ ...completo, casaOracaoId: "" })).toEqual(["Casa de Oração"]);
  });
});

describe("mensagemCamposFaltando", () => {
  it("monta o texto do alerta", () => {
    expect(mensagemCamposFaltando(["Local", "Cidade"])).toBe("Preencha todos os campos obrigatórios: Local, Cidade.");
  });
});
