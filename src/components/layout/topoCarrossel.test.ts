import { describe, expect, it } from "vitest";
import { proximoIndiceDoCarrossel, proximosEventosDoTopo, type ResumoEventoTopo } from "./topo";

const ev = (titulo: string, dataIso: string): ResumoEventoTopo => ({ titulo, local: "JEQUIÉ - CIDADE NOVA", dataIso });
const AGORA = new Date("2026-10-25T15:00:00Z");

describe("proximosEventosDoTopo", () => {
  it("devolve só os eventos futuros, do mais próximo ao mais distante", () => {
    const lista = [
      ev("Culto", "2026-11-10T22:00:00Z"),
      ev("Passado", "2026-10-22T22:00:00Z"),
      ev("Ensaio", "2026-10-30T22:00:00Z"),
    ];
    expect(proximosEventosDoTopo(lista, AGORA).map((e) => e.titulo)).toEqual(["Ensaio", "Culto"]);
  });

  it("ignora data ilegível e lista vazia", () => {
    expect(proximosEventosDoTopo([ev("Sem data", "lixo")], AGORA)).toEqual([]);
    expect(proximosEventosDoTopo([], AGORA)).toEqual([]);
  });

  it("respeita o máximo de eventos", () => {
    const lista = [1, 2, 3, 4].map((n) => ev(`E${n}`, `2026-11-0${n}T12:00:00Z`));
    expect(proximosEventosDoTopo(lista, AGORA, 2)).toHaveLength(2);
  });
});

describe("proximoIndiceDoCarrossel", () => {
  it("avança e volta ao primeiro depois do último (loop)", () => {
    expect(proximoIndiceDoCarrossel(0, 3)).toBe(1);
    expect(proximoIndiceDoCarrossel(2, 3)).toBe(0);
  });

  it("com 0 ou 1 evento fica no primeiro", () => {
    expect(proximoIndiceDoCarrossel(0, 1)).toBe(0);
    expect(proximoIndiceDoCarrossel(5, 0)).toBe(0);
  });
});
