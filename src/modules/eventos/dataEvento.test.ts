import { describe, expect, it } from "vitest";
import { MENSAGEM_DATA_PASSADA, validarDataDoEvento } from "./dataEvento";

const AGORA = new Date("2026-10-19T12:00:00Z").getTime();

describe("validarDataDoEvento", () => {
  it("recusa data que já passou ao cadastrar", () => {
    expect(validarDataDoEvento("2026-10-01T04:34:00Z", AGORA, null)).toBe(MENSAGEM_DATA_PASSADA);
    expect(validarDataDoEvento("2026-10-19T11:00:00Z", AGORA, null)).toBe(MENSAGEM_DATA_PASSADA);
  });

  it("aceita agora, dentro da tolerância de 5 minutos, e datas futuras", () => {
    expect(validarDataDoEvento("2026-10-19T11:56:00Z", AGORA, null)).toBeNull();
    expect(validarDataDoEvento("2026-10-19T12:00:00Z", AGORA, null)).toBeNull();
    expect(validarDataDoEvento("2026-12-25T20:00:00Z", AGORA, null)).toBeNull();
  });

  it("recusa 6 minutos no passado", () => {
    expect(validarDataDoEvento("2026-10-19T11:54:00Z", AGORA, null)).toBe(MENSAGEM_DATA_PASSADA);
  });

  it("ao editar sem mudar a data, não reclama (mesmo sendo antiga)", () => {
    expect(validarDataDoEvento("2026-10-01T04:34:00Z", AGORA, "2026-10-01T04:34:00+00:00")).toBeNull();
    expect(validarDataDoEvento("2026-10-01T04:34:00Z", AGORA, "2026-10-01T04:34:20Z")).toBeNull();
  });

  it("ao editar mudando a data para o passado, recusa", () => {
    expect(validarDataDoEvento("2026-09-01T04:34:00Z", AGORA, "2026-10-01T04:34:00Z")).toBe(MENSAGEM_DATA_PASSADA);
  });

  it("ao editar mudando a data para o futuro, aceita", () => {
    expect(validarDataDoEvento("2026-11-01T04:34:00Z", AGORA, "2026-10-01T04:34:00Z")).toBeNull();
  });

  it("data inválida", () => {
    expect(validarDataDoEvento("lixo", AGORA, null)).toBe("Informe uma data e hora válidas.");
  });
});
