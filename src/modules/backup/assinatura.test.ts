import { describe, expect, it } from "vitest";
import { assinarEnvio } from "./assinatura";

describe("assinarEnvio", () => {
  it("gera a assinatura esperada (mesma conta do receptor do servidor)", () => {
    expect(assinarEnvio("segredo-de-teste-1234567890", "1760000000", "manual-2026.sysbk", "a".repeat(64))).toBe(
      "621224994a7bed36ab669d52e782f52b4123f74e28f626d3227c85e8aefe8cb5"
    );
  });

  it("muda se qualquer parte mudar", () => {
    const base = assinarEnvio("segredo-de-teste-1234567890", "1760000000", "a.sysbk", "b".repeat(64));
    expect(assinarEnvio("outra-chave-de-teste-123456", "1760000000", "a.sysbk", "b".repeat(64))).not.toBe(base);
    expect(assinarEnvio("segredo-de-teste-1234567890", "1760000001", "a.sysbk", "b".repeat(64))).not.toBe(base);
    expect(assinarEnvio("segredo-de-teste-1234567890", "1760000000", "b.sysbk", "b".repeat(64))).not.toBe(base);
    expect(assinarEnvio("segredo-de-teste-1234567890", "1760000000", "a.sysbk", "c".repeat(64))).not.toBe(base);
  });
});
