import { describe, expect, it } from "vitest";
import { dadosIniciais, dataBr, lerDados, menorDeIdade, temFormulario, validarFicha } from "./dados";

const base = { ...dadosIniciais("2026-10-25"), nome: "Ana", comum: "Central", local: "Salvador" };

describe("menorDeIdade", () => {
  it("calcula pela data completa", () => {
    expect(menorDeIdade("2010-10-26", "2026-10-25")).toBe(true); // ainda 15
    expect(menorDeIdade("2008-10-25", "2026-10-25")).toBe(false); // faz 18 hoje
    expect(menorDeIdade("2008-10-26", "2026-10-25")).toBe(true); // faltou 1 dia
    expect(menorDeIdade("", "2026-10-25")).toBe(false);
  });
});

describe("M01", () => {
  it("exige nascimento e início no GEM, e responsável se menor", () => {
    expect(validarFicha("M01", "x", base)).toMatch(/nascimento/i);
    const f = { ...base, nascimento: "2012-01-01", inicio_gem: "2026-10-25" };
    expect(validarFicha("M01", "x", f)).toMatch(/responsável/i);
    expect(validarFicha("M01", "x", { ...f, responsavel_nome: "Maria" })).toBeNull();
    expect(validarFicha("M01", "x", { ...f, nascimento: "1990-01-01" })).toBeNull();
  });
  it("não exige cidade (a folha não tem essa linha)", () => {
    expect(validarFicha("M01", "x", { ...base, local: "", nascimento: "1990-01-01", inicio_gem: "2026-10-25" })).toBeNull();
  });
});

describe("M07", () => {
  it("exige instrumento novo e motivo", () => {
    expect(validarFicha("M07", "x", base)).toMatch(/instrumento/i);
    const f = { ...base, instrumento_novo_id: "abc" };
    expect(validarFicha("M07", "x", f)).toMatch(/motivo/i);
    expect(validarFicha("M07", "x", { ...f, motivo: "SAUDE" })).toBeNull();
  });
  it("lê o motivo e ignora valor estranho", () => {
    expect(lerDados({ motivo: "SAUDE" }).motivo).toBe("SAUDE");
    expect(lerDados({ motivo: "XYZ" }).motivo).toBe("");
  });
});

describe("outros", () => {
  it("RJM é como a M02 (pedido simples)", () => {
    expect(validarFicha("AVALIACAO_RJM", "x", base)).toBeNull();
  });
  it("temFormulario e dataBr", () => {
    expect(temFormulario("M07")).toBe(true);
    expect(temFormulario("TIPO_INEXISTENTE")).toBe(false);
    expect(dataBr("2026-10-05")).toBe("05/10/2026");
    expect(dataBr("x")).toBe("");
  });
});
