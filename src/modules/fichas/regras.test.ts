import { describe, expect, it } from "vitest";
import { FICHAS, rotuloDoResultado, tituloDaFicha } from "./regras";

describe("catálogo de fichas", () => {
  it("não repete o tipo da ficha", () => {
    const tipos = FICHAS.map((ficha) => ficha.tipo);
    expect(new Set(tipos).size).toBe(tipos.length);
  });

  it("tem as 11 fichas da Comissão Musical", () => {
    expect(FICHAS).toHaveLength(11);
  });

  it("mostra o código no título quando a ficha tem número", () => {
    expect(tituloDaFicha("M02")).toBe("M02 · Pedido de avaliação de músico — Culto Oficial");
    expect(tituloDaFicha("EXAME_ORGANISTA")).toBe("Testes e exames de organistas");
  });

  it("devolve o próprio tipo se for desconhecido", () => {
    expect(tituloDaFicha("XYZ")).toBe("XYZ");
  });
});

describe("rotuloDoResultado", () => {
  it("traduz os resultados", () => {
    expect(rotuloDoResultado("APTO")).toBe("Apto");
    expect(rotuloDoResultado("NAO_APTO")).toBe("Não apto");
    expect(rotuloDoResultado(null)).toBe("Aguardando");
  });
});
