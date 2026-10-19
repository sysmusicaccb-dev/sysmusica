import { describe, expect, it } from "vitest";
import { camposFaltando, mensagemCamposFaltando, type CamposEvento } from "./camposEvento";

const completo: CamposEvento = {
  tipo: "Ensaio",
  finalidade: "Ensaio Regional",
  dataEvento: "2026-10-25T10:00",
  local: "Casa de Oração de Cidade Nova",
  cidade: "Jequié",
  comumId: "abc",
};

describe("camposFaltando", () => {
  it("nada falta quando tudo está preenchido", () => {
    expect(camposFaltando(completo)).toEqual([]);
  });

  it("aponta o Local vazio (caso do print) e a ordem do formulário", () => {
    expect(camposFaltando({ ...completo, local: "" })).toEqual(["Local"]);
    expect(camposFaltando({ tipo: "", finalidade: "", dataEvento: "", local: "", cidade: "", comumId: "" })).toEqual([
      "Tipo",
      "Finalidade do evento",
      "Data e hora",
      "Local",
      "Cidade",
      "Comum",
    ]);
  });

  it("espaços em branco contam como vazio", () => {
    expect(camposFaltando({ ...completo, cidade: "   ", local: " " })).toEqual(["Local", "Cidade"]);
  });

  it("a comum escolhida é obrigatória ('Nenhuma' = vazio)", () => {
    expect(camposFaltando({ ...completo, comumId: "" })).toEqual(["Comum"]);
  });
});

describe("mensagemCamposFaltando", () => {
  it("monta o texto do alerta", () => {
    expect(mensagemCamposFaltando(["Local", "Cidade"])).toBe("Preencha todos os campos obrigatórios: Local, Cidade.");
  });
});
