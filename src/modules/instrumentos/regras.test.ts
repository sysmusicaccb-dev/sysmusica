import { describe, expect, it } from "vitest";
import { formatarNomeInstrumento, validarNomeInstrumento } from "@/modules/instrumentos/regras";
import type { Familia, Instrumento } from "@/types/database";

const familias: Familia[] = [{ id: "f1", nome: "Madeiras", palavras_chave: ["sax"] }];
const instrumentos: Instrumento[] = [
  { id: "i1", nome: "Sax Soprano", familia_id: "f1" },
  { id: "i2", nome: "Órgão", familia_id: null },
];

describe("formatarNomeInstrumento", () => {
  it("remove espaços extras e põe a primeira letra em maiúscula", () => {
    expect(formatarNomeInstrumento("  sax   tenor ")).toBe("Sax tenor");
  });
});

describe("validarNomeInstrumento", () => {
  it("aceita um nome novo e válido", () => {
    expect(validarNomeInstrumento("Clarinete", instrumentos, familias)).toBeNull();
  });

  it("recusa nome muito curto ou muito longo", () => {
    expect(validarNomeInstrumento(" a ", instrumentos, familias)).toMatch(/mínimo/);
    expect(validarNomeInstrumento("x".repeat(61), instrumentos, familias)).toMatch(/no máximo/);
  });

  it("recusa o nome de uma família", () => {
    expect(validarNomeInstrumento("madeiras", instrumentos, familias)).toMatch(/é uma família/);
  });

  it("recusa repetido, ignorando acento e maiúsculas", () => {
    expect(validarNomeInstrumento("orgao", instrumentos, familias)).toMatch(/Já existe o instrumento "Órgão"/);
    expect(validarNomeInstrumento("SAX soprano", instrumentos, familias)).toMatch(/Já existe/);
  });

  it("na edição, o próprio instrumento não conta como repetido", () => {
    expect(validarNomeInstrumento("Sax Soprano", instrumentos, familias, "i1")).toBeNull();
  });
});
