import { describe, expect, it } from "vitest";
import { lerConteudoQr, montarConteudoQr } from "@/lib/qr";

const CODIGO = "123e4567-e89b-42d3-a456-426614174000";

describe("QR Code do membro", () => {
  it("monta e lê o conteúdo (ida e volta)", () => {
    expect(lerConteudoQr(montarConteudoQr(CODIGO))).toBe(CODIGO);
  });

  it("aceita espaços nas pontas e letras maiúsculas", () => {
    expect(lerConteudoQr(`  sysmusica:1:${CODIGO.toUpperCase()}  `)).toBe(CODIGO);
  });

  it("recusa QR de outro sistema, código inválido e texto vazio", () => {
    expect(lerConteudoQr("https://exemplo.com/abc")).toBeNull();
    expect(lerConteudoQr("SYSMUSICA:1:nao-e-um-codigo")).toBeNull();
    expect(lerConteudoQr(CODIGO)).toBeNull(); // sem o prefixo
    expect(lerConteudoQr("")).toBeNull();
  });

  it("o conteúdo não carrega nenhum dado pessoal, só o prefixo e o código", () => {
    expect(montarConteudoQr(CODIGO)).toBe(`SYSMUSICA:1:${CODIGO}`);
  });
});
