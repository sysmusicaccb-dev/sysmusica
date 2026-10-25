import { describe, expect, it } from "vitest";
import {
  COLUNAS_ORGANISTA, M10_PRATICA, chaveAula, chaveAval, ehTipoExtra, mediaGem, resultadosOrganista, rotulosResultado,
} from "./layouts";

describe("layouts das fichas", () => {
  it("reconhece os tipos do formulário extra", () => {
    expect(ehTipoExtra("ACOMPANHAMENTO_GEM")).toBe(true);
    expect(ehTipoExtra("M02")).toBe(false);
  });
  it("chaves únicas nas linhas da prática do M10", () => {
    const chaves = M10_PRATICA.map((l) => l.chave);
    expect(new Set(chaves).size).toBe(chaves.length);
  });
  it("monta chaves de aula e avaliação", () => {
    expect(chaveAula(3, "data")).toBe("a03_data");
    expect(chaveAula(12, "obs")).toBe("a12_obs");
    expect(chaveAval(2, "nota")).toBe("v2_nota");
  });
  it("calcula a média ignorando notas vazias e aceitando vírgula", () => {
    expect(mediaGem({})).toBe("");
    expect(mediaGem({ v1_nota: "8", v2_nota: "9,5" })).toBe("8,8");
    expect(mediaGem({ v1_nota: "x", v2_nota: "7" })).toBe("7");
  });
  it("a coluna de oficialização fala em exame; as outras em teste", () => {
    const [rjm, , of] = COLUNAS_ORGANISTA;
    expect(resultadosOrganista(rjm)[1].rotulo).toBe("Retornar novo teste");
    expect(resultadosOrganista(of)[1].rotulo).toBe("Retornar novo exame");
  });
  it("rótulos do resultado por tipo", () => {
    expect(rotulosResultado("M02").sim).toBe("Apto");
    expect(rotulosResultado("EXAME_ORGANISTA").sim).toBe("Apta");
    expect(rotulosResultado("NECESSIDADE_INSTRUMENTO").sim).toBe("Aprovado");
  });
});
