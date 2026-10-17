import { describe, expect, it } from "vitest";
import {
  cidadeNaAbrangencia,
  descreverCota,
  ROTULO_STATUS,
  validarMotivoRejeicao,
  varianteStatus,
} from "@/modules/portarias/regras";

describe("validarMotivoRejeicao", () => {
  it("aceita um motivo com tamanho adequado", () => {
    expect(validarMotivoRejeicao("Horário em conflito")).toBeNull();
  });

  it("recusa motivo curto (ignorando espaços) ou longo demais", () => {
    expect(validarMotivoRejeicao("  ab  ")).toMatch(/mínimo/);
    expect(validarMotivoRejeicao("x".repeat(301))).toMatch(/no máximo/);
  });
});

describe("descreverCota", () => {
  it("descreve quantas portarias restam", () => {
    expect(descreverCota({ usadas: 2, limite: 4, restantes: 2 })).toBe(
      "Hoje: 2 de 4 portarias criadas · restam 2"
    );
    expect(descreverCota({ usadas: 3, limite: 4, restantes: 1 })).toContain("resta 1");
  });

  it("avisa quando o limite foi atingido", () => {
    expect(descreverCota({ usadas: 4, limite: 4, restantes: 0 })).toContain("limite atingido");
  });
});

describe("descreverCota com controle total", () => {
  it("mostra que não há limite diário", () => {
    const texto = descreverCota({ usadas: 7, limite: 4, restantes: 4, ilimitada: true });
    expect(texto).toBe("Hoje: 7 portarias criadas · sem limite (controle total)");
  });
});

describe("cidadeNaAbrangencia", () => {
  it("compara ignorando acento e maiúsculas", () => {
    expect(cidadeNaAbrangencia("lauro de freitas", ["Lauro de Freitas", "Salvador"])).toBe(true);
    expect(cidadeNaAbrangencia("São Paulo", ["Sao Paulo"])).toBe(true);
  });

  it("recusa cidade fora da lista, vazia ou nula", () => {
    expect(cidadeNaAbrangencia("Camaçari", ["Salvador"])).toBe(false);
    expect(cidadeNaAbrangencia("Salvador", [])).toBe(false);
    expect(cidadeNaAbrangencia(null, ["Salvador"])).toBe(false);
  });
});

describe("situações da portaria", () => {
  it("tem texto e cor para cada situação", () => {
    expect(ROTULO_STATUS.PENDENTE_APROVACAO).toBe("Pendente de aprovação");
    expect(varianteStatus("APROVADA")).toBe("sucesso");
    expect(varianteStatus("REJEITADA")).toBe("perigo");
    expect(varianteStatus("PENDENTE_APROVACAO")).toBe("alerta");
  });
});
