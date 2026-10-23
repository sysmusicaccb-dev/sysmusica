import { describe, expect, it } from "vitest";
import { proximoEventoDoTopo, resumosDosEventos } from "./topo";

const evento = (data_evento: string, tipo = "Ensaio") => ({ data_evento, tipo, casa_oracao_nome: "Centro", cidade: "Gandu" });

describe("proximoEventoDoTopo", () => {
  const agora = new Date("2026-10-23T04:55:00Z"); // 01:55 na Bahia

  it("não mostra evento que já passou", () => {
    const r = resumosDosEventos([evento("2026-10-22T23:24:00-03:00")]);
    expect(proximoEventoDoTopo(r, agora)).toBeNull();
  });

  it("ignora os passados e escolhe o futuro mais próximo, mesmo fora de ordem", () => {
    const r = resumosDosEventos([
      evento("2026-10-22T23:24:00-03:00", "Passado"),
      evento("2026-11-05T19:00:00-03:00", "Longe"),
      evento("2026-10-25T09:00:00-03:00", "Perto"),
    ]);
    expect(proximoEventoDoTopo(r, agora)?.titulo).toBe("Perto");
  });

  it("evento de hoje que ainda não começou aparece", () => {
    const r = resumosDosEventos([evento("2026-10-23T19:00:00-03:00", "Hoje")]);
    expect(proximoEventoDoTopo(r, agora)?.titulo).toBe("Hoje");
  });

  it("lista vazia ou sem data devolve nulo", () => {
    expect(proximoEventoDoTopo(resumosDosEventos([]), agora)).toBeNull();
    expect(proximoEventoDoTopo(resumosDosEventos([{ tipo: "x" }, null]), agora)).toBeNull();
  });
});
