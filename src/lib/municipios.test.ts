import { describe, expect, it } from "vitest";
import {
  UFS_BRASIL,
  acharMunicipio,
  extrairNomesDeMunicipios,
  montarLocalidadeTexto,
  validarLocalidadeAvulsa,
} from "./municipios";

describe("municípios do IBGE", () => {
  it("extrai e ordena os nomes, ignorando itens inválidos e repetidos", () => {
    const json = [{ nome: "Salvador" }, { nome: "Abaíra" }, { nome: "Salvador" }, { nome: 3 }, null, {}];
    expect(extrairNomesDeMunicipios(json)).toEqual(["Abaíra", "Salvador"]);
    expect(extrairNomesDeMunicipios({ erro: true })).toEqual([]);
  });

  it("acha o nome oficial ignorando acento e maiúsculas", () => {
    const lista = ["Itaju do Colônia", "Jequié", "São Paulo"];
    expect(acharMunicipio(lista, "  jequie ")).toBe("Jequié");
    expect(acharMunicipio(lista, "SAO PAULO")).toBe("São Paulo");
    expect(acharMunicipio(lista, "Jequ")).toBeNull();
    expect(acharMunicipio(lista, "")).toBeNull();
  });

  it("tem as 27 UFs", () => {
    expect(UFS_BRASIL).toHaveLength(27);
    expect(UFS_BRASIL).toContain("BA");
  });
});

describe("texto da localidade", () => {
  it("monta 'Casa - Cidade/UF' e fica vazio se faltar dado", () => {
    expect(montarLocalidadeTexto(" Centro ", "Jequié", "BA")).toBe("Centro - Jequié/BA");
    expect(montarLocalidadeTexto("Centro", "", "BA")).toBe("");
    expect(montarLocalidadeTexto("Centro", "Jequié", "")).toBe("");
  });

  it("cabe em 120 caracteres no pior caso", () => {
    const texto = montarLocalidadeTexto("x".repeat(70), "Santa Terezinha de Goiás de Tal", "BA");
    expect(texto.length).toBeLessThanOrEqual(120);
  });

  it("valida nome, estado e cidade", () => {
    expect(validarLocalidadeAvulsa({ casa: "", cidade: "A", uf: "BA" })).toContain("nome");
    expect(validarLocalidadeAvulsa({ casa: "X", cidade: "A", uf: "" })).toContain("estado");
    expect(validarLocalidadeAvulsa({ casa: "X", cidade: " ", uf: "BA" })).toContain("cidade");
    expect(validarLocalidadeAvulsa({ casa: "X", cidade: "A", uf: "BA" })).toBeNull();
  });
});
