import { describe, expect, it } from "vitest";
import {
  atributosDoTema,
  CORES,
  FONTES,
  lerPreferencias,
  PREFERENCIAS_PADRAO,
  temaEfetivo,
  TEMAS,
} from "@/modules/preferencias/regras";

describe("lerPreferencias", () => {
  it("aceita valores válidos", () => {
    expect(lerPreferencias({ tema: "escuro", cor: "verde", fonte: "grande" })).toEqual({
      tema: "escuro",
      cor: "verde",
      fonte: "grande",
    });
  });

  it("troca só o campo inválido pelo padrão", () => {
    expect(lerPreferencias({ tema: "roxo", cor: "azul", fonte: 12 })).toEqual({
      tema: "claro",
      cor: "azul",
      fonte: "normal",
    });
  });

  it("devolve o padrão para qualquer coisa que não seja um objeto", () => {
    for (const entrada of [null, undefined, "texto", 7, [], [1, 2]]) {
      expect(lerPreferencias(entrada)).toEqual(PREFERENCIAS_PADRAO);
    }
  });

  it("ignora campos extras", () => {
    expect(lerPreferencias({ tema: "sistema", cor: "vinho", fonte: "media", x: 1 })).toEqual({
      tema: "sistema",
      cor: "vinho",
      fonte: "media",
    });
  });
});

describe("temaEfetivo e atributosDoTema", () => {
  it("claro e escuro valem como escolhidos, e automático segue o aparelho", () => {
    expect(temaEfetivo("claro", true)).toBe("claro");
    expect(temaEfetivo("escuro", false)).toBe("escuro");
    expect(temaEfetivo("sistema", true)).toBe("escuro");
    expect(temaEfetivo("sistema", false)).toBe("claro");
  });

  it("monta os atributos da página", () => {
    expect(atributosDoTema({ tema: "sistema", cor: "azul", fonte: "media" }, true)).toEqual({
      tema: "escuro",
      cor: "azul",
      fonte: "media",
    });
  });
});

describe("listas de opções", () => {
  it("o padrão faz parte das opções e os identificadores não se repetem", () => {
    expect(TEMAS.map((t) => t.id)).toContain(PREFERENCIAS_PADRAO.tema);
    expect(CORES.map((c) => c.id)).toContain(PREFERENCIAS_PADRAO.cor);
    expect(FONTES.map((f) => f.id)).toContain(PREFERENCIAS_PADRAO.fonte);
    for (const lista of [TEMAS, CORES, FONTES]) {
      expect(new Set(lista.map((item) => item.id)).size).toBe(lista.length);
    }
  });
});
