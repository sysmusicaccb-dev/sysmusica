import { describe, expect, it } from "vitest";
import { STATUS_PRESENCA, validarHorarios } from "@/modules/portaria/regras";

describe("validarHorarios", () => {
  it("aceita entrada válida com saída em branco", () => {
    expect(validarHorarios("2026-10-18T14:00", "")).toBeNull();
    expect(validarHorarios("2026-10-18T14:00", "   ")).toBeNull();
  });

  it("aceita saída igual ou posterior à entrada", () => {
    expect(validarHorarios("2026-10-18T14:00", "2026-10-18T14:00")).toBeNull();
    expect(validarHorarios("2026-10-18T14:00", "2026-10-18T16:30")).toBeNull();
  });

  it("recusa saída anterior à entrada", () => {
    expect(validarHorarios("2026-10-18T14:00", "2026-10-18T13:59")).toMatch(/anterior/);
  });

  it("recusa entrada vazia ou inválida e saída inválida", () => {
    expect(validarHorarios("", "")).toMatch(/entrada/);
    expect(validarHorarios("lixo", "")).toMatch(/entrada/);
    expect(validarHorarios("2026-10-18T14:00", "lixo")).toMatch(/saída/);
  });
});

describe("STATUS_PRESENCA", () => {
  it("lista os três status usados em todo o sistema", () => {
    expect([...STATUS_PRESENCA]).toEqual(["Presente", "Ausente", "Justificado"]);
  });
});
