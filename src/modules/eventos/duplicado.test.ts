import { describe, expect, it } from "vitest";
import { deveVerificarDuplicado, descreverEventoNoHorario, janelaDoMinuto } from "./duplicado";

describe("janelaDoMinuto", () => {
  it("vai do início do minuto até o início do próximo", () => {
    const j = janelaDoMinuto("2026-10-30T22:00:37.500Z");
    expect(j).toEqual({ inicio: "2026-10-30T22:00:00.000Z", fim: "2026-10-30T22:01:00.000Z" });
  });
  it("data inválida não tem janela", () => {
    expect(janelaDoMinuto("lixo")).toBeNull();
  });
});

describe("deveVerificarDuplicado", () => {
  const original = { casa_oracao_id: "c1", data_evento: "2026-10-30T22:00:00.000Z" };
  it("sempre ao cadastrar (com casa escolhida)", () => {
    expect(deveVerificarDuplicado(null, "c1", "2026-10-30T22:00:00.000Z")).toBe(true);
    expect(deveVerificarDuplicado(null, "", "2026-10-30T22:00:00.000Z")).toBe(false);
  });
  it("ao editar, só se mudou a casa ou o minuto", () => {
    expect(deveVerificarDuplicado(original, "c1", "2026-10-30T22:00:30.000Z")).toBe(false);
    expect(deveVerificarDuplicado(original, "c2", "2026-10-30T22:00:00.000Z")).toBe(true);
    expect(deveVerificarDuplicado(original, "c1", "2026-10-30T22:05:00.000Z")).toBe(true);
  });
});

describe("descreverEventoNoHorario", () => {
  it("junta tipo e local sem sobrar traço", () => {
    expect(descreverEventoNoHorario({ id: "1", tipo: "Ensaio Local", data_evento: "x", local: "Centro" })).toBe("Ensaio Local — Centro");
    expect(descreverEventoNoHorario({ id: "1", tipo: "Ensaio Local", data_evento: "x", local: " " })).toBe("Ensaio Local");
  });
});
