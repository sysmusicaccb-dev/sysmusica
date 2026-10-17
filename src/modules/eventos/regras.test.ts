import { describe, expect, it } from "vitest";
import { formatarNomeFinalidade, validarFinalidade } from "@/modules/eventos/regras";

describe("formatarNomeFinalidade", () => {
  it("remove espaços extras e põe a primeira letra em maiúscula", () => {
    expect(formatarNomeFinalidade("  reunião   geral  ")).toBe("Reunião geral");
  });
});

describe("validarFinalidade", () => {
  it("aceita as finalidades de exemplo do cadastro", () => {
    const exemplos = [
      "Reunião Geral para Músicos e Organistas",
      "Reunião Geral para Músicos, Organistas, Examinadoras, Instrutores (as), Encarregados Locais e Regionais",
      "Reunião Geral para Examinadoras, Encarregados Locais e Regionais",
      "Reunião Geral para Instrutores (as), Examinadoras, Encarregados Locais e Regionais",
    ];
    for (const exemplo of exemplos) expect(validarFinalidade(exemplo)).toBeNull();
  });

  it("recusa texto curto demais (ignorando espaços) e longo demais", () => {
    expect(validarFinalidade("  ab ")).toMatch(/mínimo/);
    expect(validarFinalidade("x".repeat(151))).toMatch(/no máximo/);
  });
});
