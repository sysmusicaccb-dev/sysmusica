import { describe, expect, it } from "vitest";
import { dadosIniciais, dataPorExtenso, lerDados, validarFicha } from "./dados";

const completo = { ...dadosIniciais("2026-10-25"), nome: "João da Silva", comum: "Central", local: "Salvador" };

describe("validarFicha", () => {
  it("pede a pessoa do cadastro", () => {
    expect(validarFicha("M02", null, completo)).toMatch(/pessoa/i);
  });
  it("pede nome, comum, cidade e data", () => {
    expect(validarFicha("M02", "x", { ...completo, nome: " " })).toMatch(/nome/i);
    expect(validarFicha("M02", "x", { ...completo, comum: "" })).toMatch(/Comum/);
    expect(validarFicha("M02", "x", { ...completo, local: "" })).toMatch(/cidade/i);
    expect(validarFicha("M02", "x", { ...completo, data: "" })).toMatch(/data/i);
  });
  it("aceita M02 completa", () => {
    expect(validarFicha("M02", "x", completo)).toBeNull();
  });
  it("na M05 exige marcar para qual avaliação", () => {
    expect(validarFicha("M05", "x", completo)).toMatch(/avaliação/i);
    expect(validarFicha("M05", "x", { ...completo, para: "RJM" })).toBeNull();
  });
});

describe("lerDados", () => {
  it("tolera lixo e campos faltando", () => {
    expect(lerDados(null).nome).toBe("");
    expect(lerDados({ nome: 5, para: "XYZ" }).para).toBe("");
    expect(lerDados({ nome: "Ana", para: "OFICIALIZADO" })).toMatchObject({ nome: "Ana", para: "OFICIALIZADO" });
  });
});

describe("dataPorExtenso", () => {
  it("escreve dia, mês e ano", () => {
    expect(dataPorExtenso("2026-10-05")).toEqual({ dia: "5", mes: "outubro", ano: "2026" });
  });
  it("data inválida vira campos vazios", () => {
    expect(dataPorExtenso("")).toEqual({ dia: "", mes: "", ano: "" });
    expect(dataPorExtenso("2026-13-01")).toEqual({ dia: "", mes: "", ano: "" });
  });
});
