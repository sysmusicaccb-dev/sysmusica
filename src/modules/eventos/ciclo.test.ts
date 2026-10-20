import { describe, expect, it } from "vitest";
import {
  abaDoEvento,
  DIAS_ARQUIVO,
  eventoAberto,
  situacaoDoEvento,
  validarMotivoCancelamento,
  varianteSituacaoEvento,
} from "./ciclo";

const HORA = 60 * 60 * 1000;
const DIA = 24 * HORA;
const INICIO = new Date("2026-10-20T19:30:00-03:00").getTime();
const DATA = new Date(INICIO).toISOString();

describe("situacaoDoEvento", () => {
  it("fica Agendado até 2h antes do início", () => {
    expect(situacaoDoEvento(DATA, false, INICIO - 2 * HORA - 1)).toBe("AGENDADO");
  });
  it("fica Em andamento de 2h antes até 3h depois do início (limites incluídos)", () => {
    expect(situacaoDoEvento(DATA, false, INICIO - 2 * HORA)).toBe("EM_ANDAMENTO");
    expect(situacaoDoEvento(DATA, false, INICIO)).toBe("EM_ANDAMENTO");
    expect(situacaoDoEvento(DATA, false, INICIO + 3 * HORA)).toBe("EM_ANDAMENTO");
  });
  it("fica Encerrado depois de 3h do início", () => {
    expect(situacaoDoEvento(DATA, false, INICIO + 3 * HORA + 1)).toBe("ENCERRADO");
  });
  it("vira Arquivado só depois de 30 dias do encerramento", () => {
    const fecha = INICIO + 3 * HORA;
    expect(situacaoDoEvento(DATA, false, fecha + DIAS_ARQUIVO * DIA)).toBe("ENCERRADO");
    expect(situacaoDoEvento(DATA, false, fecha + DIAS_ARQUIVO * DIA + 1)).toBe("ARQUIVADO");
  });
  it("cancelado vence a data", () => {
    expect(situacaoDoEvento(DATA, true, INICIO - 10 * DIA)).toBe("CANCELADO");
    expect(situacaoDoEvento(DATA, true, INICIO + 90 * DIA)).toBe("CANCELADO");
  });
  it("data inválida continua visível como Agendado", () => {
    expect(situacaoDoEvento("isto não é data", false, INICIO)).toBe("AGENDADO");
  });
});

describe("abaDoEvento", () => {
  it("agendado e em andamento ficam em Próximos", () => {
    expect(abaDoEvento(DATA, false, INICIO - 5 * DIA)).toBe("proximos");
    expect(abaDoEvento(DATA, false, INICIO)).toBe("proximos");
  });
  it("encerrado vai para Encerrados e depois de 30 dias para o Arquivo", () => {
    expect(abaDoEvento(DATA, false, INICIO + 4 * HORA)).toBe("encerrados");
    expect(abaDoEvento(DATA, false, INICIO + 40 * DIA)).toBe("arquivo");
  });
  it("cancelado nunca fica em Próximos", () => {
    expect(abaDoEvento(DATA, true, INICIO - 5 * DIA)).toBe("encerrados");
    expect(abaDoEvento(DATA, true, INICIO + 40 * DIA)).toBe("arquivo");
  });
});

describe("eventoAberto", () => {
  it("só é aberto quando agendado ou em andamento e não cancelado", () => {
    expect(eventoAberto(DATA, false, INICIO - DIA)).toBe(true);
    expect(eventoAberto(DATA, false, INICIO)).toBe(true);
    expect(eventoAberto(DATA, false, INICIO + 4 * HORA)).toBe(false);
    expect(eventoAberto(DATA, true, INICIO - DIA)).toBe(false);
  });
});

describe("varianteSituacaoEvento", () => {
  it("destaca o que está acontecendo e o que foi cancelado", () => {
    expect(varianteSituacaoEvento("EM_ANDAMENTO")).toBe("sucesso");
    expect(varianteSituacaoEvento("CANCELADO")).toBe("perigo");
    expect(varianteSituacaoEvento("ENCERRADO")).toBe("neutro");
  });
});

describe("validarMotivoCancelamento", () => {
  it("exige entre 5 e 250 caracteres", () => {
    expect(validarMotivoCancelamento("   ab  ")).not.toBeNull();
    expect(validarMotivoCancelamento("Chuva forte")).toBeNull();
    expect(validarMotivoCancelamento("a".repeat(251))).not.toBeNull();
  });
});
