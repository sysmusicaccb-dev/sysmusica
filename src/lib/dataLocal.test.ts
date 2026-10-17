import { describe, expect, it } from "vitest";
import { datetimeLocalParaIso, isoParaDatetimeLocal } from "@/lib/dataLocal";

describe("isoParaDatetimeLocal", () => {
  it("usa o formato AAAA-MM-DDTHH:mm", () => {
    expect(isoParaDatetimeLocal("2026-10-18T17:00:00.000Z")).toMatch(/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}$/);
  });
});

describe("datetimeLocalParaIso", () => {
  it("ida e volta mantém o mesmo instante (qualquer fuso da máquina)", () => {
    const iso = "2026-10-18T17:00:00.000Z";
    expect(datetimeLocalParaIso(isoParaDatetimeLocal(iso))).toBe(iso);
  });

  it("devolve null para valor inválido ou vazio", () => {
    expect(datetimeLocalParaIso("")).toBeNull();
    expect(datetimeLocalParaIso("não é data")).toBeNull();
  });
});
