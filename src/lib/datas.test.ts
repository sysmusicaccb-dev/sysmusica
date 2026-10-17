import { describe, expect, it } from "vitest";
import { formatarDataHora, partesDaData } from "@/lib/datas";

describe("formatarDataHora", () => {
  it("usa o formato 'dd/mm/aaaa às hh:mm'", () => {
    // Regex em vez de valor fixo: o resultado depende do fuso da máquina que roda o teste
    expect(formatarDataHora("2026-10-13T12:00:00Z")).toMatch(/^\d{2}\/\d{2}\/\d{4} às \d{2}:\d{2}$/);
  });
});

describe("partesDaData", () => {
  it("devolve dia com 2 dígitos e mês abreviado sem ponto", () => {
    // Meio-dia em UTC mantém o mesmo dia em praticamente qualquer fuso
    expect(partesDaData("2026-10-13T12:00:00Z")).toEqual({ dia: "13", mes: "out" });
  });
});
