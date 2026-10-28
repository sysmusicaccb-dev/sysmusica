import { afterEach, describe, expect, it } from "vitest";
import { HORAS_DEPOIS, definirRegraEncerramento, descreverJanela, janelaDaPortaria } from "@/modules/portarias/janela";

const HORA = 60 * 60 * 1000;
const inicio = "2026-10-20T15:00:00.000Z";
const t0 = new Date(inicio).getTime();

// Devolve a regra ao padrão para não afetar os outros testes
afterEach(() => definirRegraEncerramento(true, HORAS_DEPOIS));

describe("regra de encerramento da portaria (Eventos > Configurações)", () => {
  it("com encerramento sozinho em 24 h: 10 h depois está aberta e 25 h depois encerrada", () => {
    definirRegraEncerramento(true, 24);
    expect(janelaDaPortaria(inicio, t0 + 10 * HORA)?.situacao).toBe("aberta");
    expect(janelaDaPortaria(inicio, t0 + 25 * HORA)?.situacao).toBe("encerrada");
  });

  it("sem encerramento sozinho: nunca encerra pelo relógio e o texto avisa que é manual", () => {
    definirRegraEncerramento(false, 24);
    const janela = janelaDaPortaria(inicio, t0 + 500 * HORA);
    expect(janela?.situacao).toBe("aberta");
    if (janela) expect(descreverJanela(janela, t0 + 500 * HORA)).toContain("manual");
  });

  it("a portaria continua abrindo 2 h antes, com ou sem encerramento sozinho", () => {
    definirRegraEncerramento(false, 24);
    expect(janelaDaPortaria(inicio, t0 - 3 * HORA)?.situacao).toBe("antes");
    expect(janelaDaPortaria(inicio, t0 - 1 * HORA)?.situacao).toBe("aberta");
  });
});
