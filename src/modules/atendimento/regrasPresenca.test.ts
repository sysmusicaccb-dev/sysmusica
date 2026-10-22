/** Sysmusica — Testes das regras da tela Registrar Presença. */
import { describe, expect, it } from "vitest";
import {
  familiasDosInstrumentos,
  instrumentosDaFamilia,
  linhasDoBloco,
  passoAtual,
  resumoCategorias,
} from "./regrasPresenca";
import type { InstrumentoEntrada, LinhaEntrada } from "./tiposEntrada";

const linha = (codigo: string, bloco: LinhaEntrada["bloco"], rotulo: string): LinhaEntrada => ({
  codigo,
  bloco,
  rotulo,
  pergunta_toca: false,
  toca_sempre: false,
  instrumento: "NENHUM",
});

const linhas = [
  linha("ANCIAO", "MINISTERIO", "Ancião"),
  linha("INSTRUTOR", "MUSICOS", "Instrutor"),
  linha("MUSICO", "MUSICOS", "Músico"),
  linha("EXAMINADORA", "ORGANISTAS", "Examinadora"),
];

const instrumentos: InstrumentoEntrada[] = [
  { id: "1", nome: "Violino", familia: "Cordas" },
  { id: "2", nome: "Flauta", familia: "Madeiras" },
  { id: "3", nome: "Viola", familia: "Cordas" },
];

describe("linhasDoBloco e resumoCategorias", () => {
  it("separa as categorias de cada bloco", () => {
    expect(linhasDoBloco(linhas, "MUSICOS").map((l) => l.codigo)).toEqual(["INSTRUTOR", "MUSICO"]);
    expect(linhasDoBloco(linhas, "ORGANISTAS").map((l) => l.codigo)).toEqual(["EXAMINADORA"]);
  });
  it("junta os nomes em uma linha", () => {
    expect(resumoCategorias(linhas, "MUSICOS")).toBe("Instrutor, Músico");
    expect(resumoCategorias([], "MUSICOS")).toBe("");
  });
});

describe("passoAtual", () => {
  it("avança conforme as escolhas", () => {
    expect(passoAtual(null, "")).toBe(1);
    expect(passoAtual("MUSICOS", "")).toBe(2);
    expect(passoAtual("MUSICOS", "MUSICO")).toBe(3);
  });
});

describe("famílias e instrumentos", () => {
  it("lista as famílias sem repetir, na ordem de chegada", () => {
    expect(familiasDosInstrumentos(instrumentos)).toEqual(["Cordas", "Madeiras"]);
  });
  it("filtra os instrumentos da família escolhida", () => {
    expect(instrumentosDaFamilia(instrumentos, "Cordas").map((i) => i.nome)).toEqual(["Violino", "Viola"]);
    expect(instrumentosDaFamilia(instrumentos, "")).toEqual([]);
  });
});
