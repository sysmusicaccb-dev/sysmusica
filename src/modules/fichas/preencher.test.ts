import { describe, expect, it } from "vitest";
import { dadosIniciais, formatarTelefone, idadeEm, preencherDoCadastro } from "./dados";

const cad = {
  nome: "Levi Alencar", casa_nome: "Liberdade", instrumento_nome: "Saxofone Soprano Reto", cidade: "Salvador",
  data_nascimento: "1981-09-05", estado_civil: "Casado (a)", ddd: "71", telefone: "999998888",
};

describe("preencherDoCadastro", () => {
  it("M01: puxa nome, Casa, instrumento, nascimento, estado civil e telefone", () => {
    const d = preencherDoCadastro("M01", dadosIniciais("2026-10-25"), cad);
    expect(d).toMatchObject({
      nome: "Levi Alencar", comum: "Liberdade", instrumento: "Saxofone Soprano Reto",
      nascimento: "1981-09-05", estado_civil: "Casado (a)", telefone: "(71) 99999-8888", local: "Salvador",
    });
  });
  it("não apaga o que já foi digitado quando o cadastro não tem o dado", () => {
    const atual = { ...dadosIniciais("2026-10-25"), estado_civil: "Solteiro (a)", local: "Feira" };
    const d = preencherDoCadastro("M01", atual, { nome: "Ana" });
    expect(d.estado_civil).toBe("Solteiro (a)");
    expect(d.local).toBe("Feira");
    expect(d.nome).toBe("Ana");
  });
  it("M07: o instrumento atual vem do cadastro", () => {
    expect(preencherDoCadastro("M07", dadosIniciais(""), cad).instrumento_atual).toBe("Saxofone Soprano Reto");
  });
  it("M10: localidade é a Casa e município é a cidade", () => {
    const d = preencherDoCadastro("AVALIACAO_CANDIDATO", dadosIniciais(""), cad);
    expect(d.local).toBe("Liberdade");
    expect(d.notas.municipio).toBe("Salvador");
  });
  it("Necessidade: calcula a idade", () => {
    const d = preencherDoCadastro("NECESSIDADE_INSTRUMENTO", dadosIniciais(""), { ...cad, data_nascimento: "2000-01-01" });
    expect(Number(d.notas.idade)).toBeGreaterThanOrEqual(26);
  });
  it("aceita data com hora (2026-10-05T00:00:00)", () => {
    expect(preencherDoCadastro("M01", dadosIniciais(""), { data_nascimento: "1990-02-03T00:00:00+00:00" }).nascimento).toBe("1990-02-03");
  });
});

describe("auxiliares", () => {
  it("formatarTelefone", () => {
    expect(formatarTelefone("71", "32221111")).toBe("(71) 3222-1111");
    expect(formatarTelefone("71", "999998888")).toBe("(71) 99999-8888");
    expect(formatarTelefone("", "999998888")).toBe("99999-8888");
    expect(formatarTelefone("", "")).toBe("");
  });
  it("idadeEm", () => {
    expect(idadeEm("1981-09-05", "2026-10-25")).toBe(45);
    expect(idadeEm("1981-12-05", "2026-10-25")).toBe(44);
    expect(idadeEm("", "2026-10-25")).toBeNull();
  });
});
