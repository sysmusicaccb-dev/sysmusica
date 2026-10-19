import { describe, expect, it } from "vitest";
import {
  agruparInstrumentos,
  agruparLinhas,
  descreverAvulsa,
  precisaInstrumento,
  textoDaLocalidade,
  validarEntradaAvulsa,
  validarEscolhaMembro,
  valoresDaEntrada,
} from "./regrasEntrada";
import type { InfoEntrada, LinhaEntrada } from "./tiposEntrada";

const info = (extra: Partial<InfoEntrada> = {}): InfoEntrada => ({
  linha_codigo: "MUS_ENC_LOCAL",
  linha_rotulo: "Encarregado Local",
  bloco: "MUSICOS",
  pergunta_toca: true,
  instrumento_id: null,
  instrumento: null,
  ...extra,
});
const linha = (extra: Partial<LinhaEntrada> = {}): LinhaEntrada => ({
  codigo: "MUS_CANDIDATO",
  bloco: "MUSICOS",
  rotulo: "Candidato",
  pergunta_toca: true,
  toca_sempre: false,
  instrumento: "LIVRE",
  ...extra,
});

describe("validarEscolhaMembro", () => {
  it("sem pergunta não exige nada", () => {
    expect(validarEscolhaMembro(info({ pergunta_toca: false }), { toca: null, instrumentoId: "" })).toBeNull();
    expect(validarEscolhaMembro(null, { toca: null, instrumentoId: "" })).toBeNull();
  });
  it("com pergunta exige a resposta", () => {
    expect(validarEscolhaMembro(info(), { toca: null, instrumentoId: "" })).toMatch(/vai tocar/);
  });
  it("quem vai tocar precisa de instrumento (do cadastro ou escolhido)", () => {
    expect(validarEscolhaMembro(info(), { toca: true, instrumentoId: "" })).toMatch(/instrumento/);
    expect(validarEscolhaMembro(info(), { toca: true, instrumentoId: "i1" })).toBeNull();
    expect(validarEscolhaMembro(info({ instrumento_id: "i9" }), { toca: true, instrumentoId: "" })).toBeNull();
    expect(validarEscolhaMembro(info(), { toca: false, instrumentoId: "" })).toBeNull();
  });
});

describe("valoresDaEntrada", () => {
  it("envia só o necessário", () => {
    expect(valoresDaEntrada(info({ pergunta_toca: false }), { toca: true, instrumentoId: "i1" })).toEqual({ toca: null, instrumentoId: null });
    expect(valoresDaEntrada(info(), { toca: true, instrumentoId: "i1" })).toEqual({ toca: true, instrumentoId: "i1" });
    expect(valoresDaEntrada(info(), { toca: true, instrumentoId: "" })).toEqual({ toca: true, instrumentoId: null });
    expect(valoresDaEntrada(info(), { toca: false, instrumentoId: "i1" })).toEqual({ toca: false, instrumentoId: null });
  });
});

describe("entrada sem cadastro", () => {
  it("precisaInstrumento", () => {
    expect(precisaInstrumento(linha(), true)).toBe(true);
    expect(precisaInstrumento(linha(), false)).toBe(false);
    expect(precisaInstrumento(linha(), null)).toBe(false);
    expect(precisaInstrumento(linha({ pergunta_toca: false, toca_sempre: true }), null)).toBe(true); // Músico
    expect(precisaInstrumento(linha({ instrumento: "ORGAO", pergunta_toca: false }), null)).toBe(false); // Organista
    expect(precisaInstrumento(linha({ instrumento: "NENHUM", pergunta_toca: false }), null)).toBe(false); // Ancião
  });

  it("validarEntradaAvulsa", () => {
    const base = { linha: linha(), toca: true, instrumentoId: "i1", outraLocalidade: false, localidadeTexto: "" };
    expect(validarEntradaAvulsa(base)).toBeNull();
    expect(validarEntradaAvulsa({ ...base, linha: null })).toMatch(/cargo/);
    expect(validarEntradaAvulsa({ ...base, toca: null })).toMatch(/vai tocar/);
    expect(validarEntradaAvulsa({ ...base, instrumentoId: "" })).toMatch(/instrumento/);
    expect(validarEntradaAvulsa({ ...base, toca: false, instrumentoId: "" })).toBeNull();
    expect(validarEntradaAvulsa({ ...base, outraLocalidade: true, localidadeTexto: " a " })).toMatch(/localidade/i);
    expect(validarEntradaAvulsa({ ...base, outraLocalidade: true, localidadeTexto: "Itaju do Colônia" })).toBeNull();
    // sem localidade é permitido (campo opcional)
    expect(validarEntradaAvulsa({ ...base, outraLocalidade: false, localidadeTexto: "" })).toBeNull();
  });

  it("textoDaLocalidade", () => {
    expect(textoDaLocalidade(false, "x y")).toBeNull();
    expect(textoDaLocalidade(true, "   ")).toBeNull();
    expect(textoDaLocalidade(true, "  Itaju   do  Colônia ")).toBe("Itaju do Colônia");
  });
});

describe("listas", () => {
  it("agruparLinhas segue Ministério, Músicos, Organistas", () => {
    const grupos = agruparLinhas([
      linha({ codigo: "o", bloco: "ORGANISTAS" }),
      linha({ codigo: "m", bloco: "MINISTERIO" }),
      linha({ codigo: "u", bloco: "MUSICOS" }),
    ]);
    expect(grupos.map((g) => g.bloco)).toEqual(["MINISTERIO", "MUSICOS", "ORGANISTAS"]);
    expect(agruparLinhas([linha({ bloco: "MUSICOS" })]).length).toBe(1);
  });
  it("agruparInstrumentos por família", () => {
    const g = agruparInstrumentos([
      { id: "1", nome: "Violino", familia: "Cordas" },
      { id: "2", nome: "Viola", familia: "Cordas" },
      { id: "3", nome: "Flauta", familia: "Madeiras" },
    ]);
    expect(g.map((x) => [x.familia, x.itens.length])).toEqual([["Cordas", 2], ["Madeiras", 1]]);
  });
  it("descreverAvulsa", () => {
    expect(descreverAvulsa({ linha_rotulo: "Candidato", toca: true, instrumento: "Clarinete" })).toBe("Candidato · Clarinete");
    expect(descreverAvulsa({ linha_rotulo: "Candidato", toca: false, instrumento: null })).toBe("Candidato · não vai tocar");
    expect(descreverAvulsa({ linha_rotulo: "Ancião", toca: null, instrumento: null })).toBe("Ancião");
  });
});
