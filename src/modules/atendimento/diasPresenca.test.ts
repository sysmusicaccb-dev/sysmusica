import { describe, expect, it } from "vitest";
import { diaDoEvento, diasComEvento, filtrarPorDia } from "./regrasPresenca";

const dia = (a: number, m: number, d: number, h = 19) => new Date(a, m - 1, d, h, 0).toISOString();

describe("seletor de data da Registrar Presença", () => {
  const portarias = [
    { id: "a", evento_data: dia(2026, 10, 27, 21) },
    { id: "b", evento_data: dia(2026, 10, 28) },
    { id: "c", evento_data: dia(2026, 10, 28, 8) },
    { id: "d", evento_data: null },
  ];

  it("o dia é o do horário local do evento", () => {
    expect(diaDoEvento(dia(2026, 10, 27, 23))).toBe("2026-10-27");
    expect(diaDoEvento(null)).toBe("");
    expect(diaDoEvento("lixo")).toBe("");
  });

  it("filtra pelo dia escolhido e, sem dia, mostra todas", () => {
    expect(filtrarPorDia(portarias, "2026-10-28").map((p) => p.id)).toEqual(["b", "c"]);
    expect(filtrarPorDia(portarias, "2026-10-30")).toEqual([]);
    expect(filtrarPorDia(portarias, "")).toHaveLength(4);
  });

  it("lista os dias com evento, sem repetir e em ordem", () => {
    expect(diasComEvento(portarias)).toEqual(["2026-10-27", "2026-10-28"]);
  });
});
