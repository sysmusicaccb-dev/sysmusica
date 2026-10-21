import { describe, expect, it } from "vitest";
import { buscarCidades, lerMunicipiosDoIbge, rotuloDaCidade, type Cidade } from "./cidades";

const lista: Cidade[] = [
  { nome: "São Paulo", uf: "SP" },
  { nome: "São Pedro", uf: "SP" },
  { nome: "São Paulo do Potengi", uf: "RN" },
  { nome: "Salvador", uf: "BA" },
  { nome: "Santos", uf: "SP" },
  { nome: "Paulo Afonso", uf: "BA" },
  { nome: "Jequié", uf: "BA" },
  { nome: "Palmas", uf: "TO" },
  { nome: "Palmas", uf: "PR" },
];

describe("rotuloDaCidade", () => {
  it("junta cidade e estado", () => {
    expect(rotuloDaCidade({ nome: "São Paulo", uf: "SP" })).toBe("São Paulo-SP");
  });
});

describe("buscarCidades", () => {
  it("não sugere nada com menos de 2 letras", () => {
    expect(buscarCidades(lista, "")).toEqual([]);
    expect(buscarCidades(lista, "s")).toEqual([]);
  });

  it("ignora acento e maiúsculas; quem começa com o texto vem antes de quem só contém", () => {
    expect(buscarCidades(lista, "sao pa").map(rotuloDaCidade)).toEqual(["São Paulo-SP", "São Paulo do Potengi-RN"]);
    expect(buscarCidades(lista, "PAULO").map(rotuloDaCidade)).toEqual(["Paulo Afonso-BA", "São Paulo-SP", "São Paulo do Potengi-RN"]);
  });

  it("aceita 'cidade-uf' e filtra pelo estado", () => {
    expect(buscarCidades(lista, "palmas-to").map(rotuloDaCidade)).toEqual(["Palmas-TO"]);
    expect(buscarCidades(lista, "Palmas - PR").map(rotuloDaCidade)).toEqual(["Palmas-PR"]);
    expect(buscarCidades(lista, "são paulo-sp").map(rotuloDaCidade)).toEqual(["São Paulo-SP"]);
  });

  it("duas letras depois de um espaço NÃO viram estado (ex.: 'sao jo' segue sendo busca por nome)", () => {
    expect(buscarCidades([{ nome: "São José", uf: "SC" }], "sao jo").map(rotuloDaCidade)).toEqual(["São José-SC"]);
  });

  it("respeita o limite de sugestões", () => {
    const muitas = Array.from({ length: 30 }, (_, i) => ({ nome: `Cidade ${i}`, uf: "BA" }));
    expect(buscarCidades(muitas, "cidade")).toHaveLength(8);
    expect(buscarCidades(muitas, "cidade", 3)).toHaveLength(3);
  });

  it("sem resultado devolve lista vazia", () => {
    expect(buscarCidades(lista, "zzzz")).toEqual([]);
  });
});

describe("lerMunicipiosDoIbge", () => {
  it("lê a forma com microrregião e a forma com região imediata, e ignora o que não presta", () => {
    const resposta = [
      { id: 1, nome: "Jequié", microrregiao: { mesorregiao: { UF: { sigla: "BA" } } } },
      { id: 2, nome: "Nova Cidade", microrregiao: null, "regiao-imediata": { "regiao-intermediaria": { UF: { sigla: "MG" } } } },
      { id: 3, nome: "Sem estado" },
      { id: 4, nome: "", microrregiao: { mesorregiao: { UF: { sigla: "SP" } } } },
      { id: 5, nome: "Sigla ruim", microrregiao: { mesorregiao: { UF: { sigla: "sp" } } } },
      null,
      "texto",
    ];
    expect(lerMunicipiosDoIbge(resposta)).toEqual([
      { nome: "Jequié", uf: "BA" },
      { nome: "Nova Cidade", uf: "MG" },
    ]);
  });

  it("resposta que não é lista vira lista vazia", () => {
    expect(lerMunicipiosDoIbge({ erro: true })).toEqual([]);
    expect(lerMunicipiosDoIbge(null)).toEqual([]);
  });
});
