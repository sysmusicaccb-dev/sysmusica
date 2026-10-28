import { describe, expect, it } from "vitest";
import { configPadrao, descreverConfig, normalizarConfig, rotuloEncarregados, tituloBlocoEncarregados, verboAtendeu } from "./perfilConfig";

describe("configPadrao", () => {
  it("Regional: só Ancião atende e há palavra", () => {
    const c = configPadrao("REGIONAL");
    expect(c.quem_atendeu.cargos).toEqual(["ANCIAO"]);
    expect(c.palavra.ativo).toBe(true);
  });

  it("Local: os quatro cargos e sem palavra", () => {
    const c = configPadrao("LOCAL");
    expect(c.quem_atendeu.cargos).toHaveLength(4);
    expect(c.palavra.ativo).toBe(false);
  });
});

describe("normalizarConfig", () => {
  it("lixo vira o padrão do modelo", () => {
    expect(normalizarConfig(null, "LOCAL")).toEqual(configPadrao("LOCAL"));
    expect(normalizarConfig("x", "REGIONAL")).toEqual(configPadrao("REGIONAL"));
  });

  it("corrige limites, modo e cargos inválidos", () => {
    const c = normalizarConfig(
      { palavra: { ativo: true, limite: 99999 }, encarregados: { maximo: 9, minimo: 7, cargos: ["XX"] }, hino_abertura: { modo: "lixo" } },
      "LOCAL"
    );
    expect(c.palavra.limite).toBe(500);
    expect(c.encarregados.maximo).toBe(3);
    expect(c.encarregados.minimo).toBe(3);
    expect(c.encarregados.cargos).toEqual(["REGIONAL", "LOCAL", "INSTRUTOR"]);
    expect(c.hino_abertura.modo).toBe("pergunta");
  });

  it("mantém o que é válido, na ordem canônica", () => {
    const c = normalizarConfig({ encarregados: { cargos: ["INSTRUTOR", "REGIONAL"], minimo: 0, maximo: 2 } }, "LOCAL");
    expect(c.encarregados.cargos).toEqual(["REGIONAL", "INSTRUTOR"]);
    expect(c.encarregados.minimo).toBe(0);
    expect(c.encarregados.maximo).toBe(2);
  });

  it("o mínimo nunca passa do máximo", () => {
    const c = normalizarConfig({ encarregados: { minimo: 3, maximo: 1 } }, "LOCAL");
    expect(c.encarregados.minimo).toBe(1);
  });
});

describe("textos dos encarregados", () => {
  it("um cargo só usa o nome do cargo; vários listam todos", () => {
    expect(rotuloEncarregados(["LOCAL"])).toBe("Encarregado Local");
    expect(rotuloEncarregados(["REGIONAL", "LOCAL", "INSTRUTOR"])).toBe("Encarregado Regional, Encarregado Local ou Instrutor");
    expect(tituloBlocoEncarregados(["LOCAL"])).toBe("Encarregado Local");
    expect(tituloBlocoEncarregados(["REGIONAL", "LOCAL"])).toBe("Encarregados");
  });

  it("atendeu no singular e atenderam a partir de 2", () => {
    expect(verboAtendeu(1)).toBe("atendeu");
    expect(verboAtendeu(2)).toBe("atenderam");
    expect(verboAtendeu(3)).toBe("atenderam");
  });
});

describe("descreverConfig", () => {
  it("lista só o que está ligado", () => {
    const c = configPadrao("LOCAL");
    c.hinos_executados.ativo = false;
    const linhas = descreverConfig(c);
    expect(linhas.some((l) => l.startsWith("Quem atendeu"))).toBe(true);
    expect(linhas.some((l) => l.includes("Palavra"))).toBe(false);
    expect(linhas).not.toContain("Hinos executados");
  });
});
