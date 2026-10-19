import { describe, expect, it } from "vitest";
import { descreverJanela, janelaDaPortaria } from "./janela";

// Evento às 14h00 de Salvador (UTC-3) = 17h00 UTC
const EVENTO = "2026-10-19T17:00:00Z";
const t = (iso: string) => new Date(iso).getTime();

describe("janelaDaPortaria", () => {
  it("abre 2h antes e encerra 3h depois do início (limites inclusivos)", () => {
    expect(janelaDaPortaria(EVENTO, t("2026-10-19T14:59:59Z"))?.situacao).toBe("antes");
    expect(janelaDaPortaria(EVENTO, t("2026-10-19T15:00:00Z"))?.situacao).toBe("aberta");
    expect(janelaDaPortaria(EVENTO, t("2026-10-19T17:00:00Z"))?.situacao).toBe("aberta");
    expect(janelaDaPortaria(EVENTO, t("2026-10-19T20:00:00Z"))?.situacao).toBe("aberta");
    expect(janelaDaPortaria(EVENTO, t("2026-10-19T20:00:01Z"))?.situacao).toBe("encerrada");
  });

  it("sem data válida não há janela", () => {
    expect(janelaDaPortaria(null, 0)).toBeNull();
    expect(janelaDaPortaria("lixo", 0)).toBeNull();
  });
});

describe("descreverJanela", () => {
  it("mostra os horários de Salvador (12h às 17h para um evento das 14h)", () => {
    const agora = t("2026-10-19T13:00:00Z"); // 10h em Salvador, mesmo dia
    expect(descreverJanela(janelaDaPortaria(EVENTO, agora)!, agora)).toBe("Abre às 12h00");
    const durante = t("2026-10-19T17:30:00Z");
    expect(descreverJanela(janelaDaPortaria(EVENTO, durante)!, durante)).toBe("Aberta até 17h00");
    const depois = t("2026-10-19T21:00:00Z");
    expect(descreverJanela(janelaDaPortaria(EVENTO, depois)!, depois)).toBe("Encerrada às 17h00");
  });

  it("inclui a data quando o horário não é de hoje", () => {
    const ontem = t("2026-10-18T13:00:00Z");
    expect(descreverJanela(janelaDaPortaria(EVENTO, ontem)!, ontem)).toBe("Abre 19/10 às 12h00");
  });
});
