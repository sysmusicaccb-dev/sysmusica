import { describe, expect, it } from "vitest";
import { abaDoEvento, eventoAberto, situacaoDoEvento } from "./ciclo";

// Ensaio às 14h de Salvador (17h UTC); a Portaria vale das 12h às 17h (locais).
const EVENTO = "2026-10-22T17:00:00Z";
const HORA = 60 * 60 * 1000;
const inicio = new Date(EVENTO).getTime();

describe("encerramento manual do evento", () => {
  it("sem encerramento à mão, a situação continua vindo só da data", () => {
    expect(situacaoDoEvento(EVENTO, false, inicio)).toBe("EM_ANDAMENTO");
    expect(situacaoDoEvento(EVENTO, false, inicio + 4 * HORA)).toBe("ENCERRADO");
    expect(situacaoDoEvento(EVENTO, false, inicio, null)).toBe("EM_ANDAMENTO");
  });

  it("encerrado à mão dentro da janela: vira Encerrado, sai de Próximos e não está mais aberto", () => {
    const encerradoEm = "2026-10-22T18:00:00Z";
    expect(situacaoDoEvento(EVENTO, false, inicio + HORA, encerradoEm)).toBe("ENCERRADO");
    expect(abaDoEvento(EVENTO, false, inicio + HORA, encerradoEm)).toBe("encerrados");
    expect(eventoAberto(EVENTO, false, inicio + HORA, encerradoEm)).toBe(false);
  });

  it("evento em andamento sem encerramento continua em Próximos e aberto", () => {
    expect(abaDoEvento(EVENTO, false, inicio + HORA)).toBe("proximos");
    expect(eventoAberto(EVENTO, false, inicio + HORA)).toBe(true);
  });

  it("cancelado vence tudo e o arquivo continua valendo depois de 30 dias", () => {
    expect(situacaoDoEvento(EVENTO, true, inicio + HORA, "2026-10-22T18:00:00Z")).toBe("CANCELADO");
    expect(situacaoDoEvento(EVENTO, false, inicio + 40 * 24 * HORA, "2026-10-22T18:00:00Z")).toBe("ARQUIVADO");
  });
});
