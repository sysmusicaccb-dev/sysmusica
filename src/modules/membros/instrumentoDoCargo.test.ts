import { describe, expect, it } from "vitest";
import { cargoTocaSoOrgao, orgaoUnicoDoCargo } from "./instrumentoDoCargo";

const INSTRUMENTOS = [
  { id: "t1", nome: "Trompete" },
  { id: "o1", nome: "Órgão Eletrônico" },
  { id: "s1", nome: "Saxofone Alto" },
];

describe("cargoTocaSoOrgao", () => {
  it("a coluna do banco manda quando existe", () => {
    expect(cargoTocaSoOrgao({ nome: "Instrutor", somente_orgao: false })).toBe(false);
    expect(cargoTocaSoOrgao({ nome: "Qualquer", somente_orgao: true })).toBe(true);
  });

  it("sem a coluna, vale o nome: Organista, Examinadora e Instrutora (o Instrutor masculino não)", () => {
    expect(cargoTocaSoOrgao({ nome: "Organista" })).toBe(true);
    expect(cargoTocaSoOrgao({ nome: "Examinadora" })).toBe(true);
    expect(cargoTocaSoOrgao({ nome: "Instrutora" })).toBe(true);
    expect(cargoTocaSoOrgao({ nome: "Instrutor" })).toBe(false);
    expect(cargoTocaSoOrgao({ nome: "Músico" })).toBe(false);
    expect(cargoTocaSoOrgao(null)).toBe(false);
  });
});

describe("orgaoUnicoDoCargo", () => {
  it("devolve o Órgão para os cargos que só tocam Órgão", () => {
    expect(orgaoUnicoDoCargo({ nome: "Examinadora", somente_orgao: true }, INSTRUMENTOS)).toBe("o1");
    expect(orgaoUnicoDoCargo({ nome: "Organista" }, INSTRUMENTOS)).toBe("o1");
  });

  it("não preenche para quem escolhe o instrumento", () => {
    expect(orgaoUnicoDoCargo({ nome: "Músico", somente_orgao: false }, INSTRUMENTOS)).toBe("");
    expect(orgaoUnicoDoCargo({ nome: "Instrutor" }, INSTRUMENTOS)).toBe("");
  });

  it("não preenche quando não há Órgão ou há mais de um (a pessoa escolhe)", () => {
    expect(orgaoUnicoDoCargo({ nome: "Organista" }, [{ id: "t1", nome: "Trompete" }])).toBe("");
    expect(
      orgaoUnicoDoCargo({ nome: "Organista" }, [
        { id: "o1", nome: "Órgão" },
        { id: "o2", nome: "Órgão Eletrônico" },
      ])
    ).toBe("");
  });
});
