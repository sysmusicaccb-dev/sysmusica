import { describe, expect, it } from "vitest";
import {
  LOGO_MAXIMO_BYTES,
  avisoDeProporcao,
  formatarTamanho,
  nomeDoArquivoDaLogo,
  rotuloDoTipo,
  validarLogo,
} from "./regras";

const boa = { tipo: "image/png", bytes: 50_000, largura: 256, altura: 256 };

describe("validarLogo", () => {
  it("aceita uma imagem dentro das regras", () => {
    expect(validarLogo(boa)).toBeNull();
    expect(validarLogo({ ...boa, tipo: "image/svg+xml" })).toBeNull();
    expect(validarLogo({ ...boa, largura: 64, altura: 2048 })).toBeNull();
  });

  it("recusa tipo que não é PNG, JPG, WEBP ou SVG", () => {
    expect(validarLogo({ ...boa, tipo: "image/gif" })).toMatch(/Tipo de arquivo/);
    expect(validarLogo({ ...boa, tipo: "application/pdf" })).toMatch(/Tipo de arquivo/);
  });

  it("recusa arquivo vazio e arquivo acima de 1 MB", () => {
    expect(validarLogo({ ...boa, bytes: 0 })).toMatch(/vazio/);
    expect(validarLogo({ ...boa, bytes: LOGO_MAXIMO_BYTES + 1 })).toMatch(/máximo/);
    expect(validarLogo({ ...boa, bytes: LOGO_MAXIMO_BYTES })).toBeNull();
  });

  it("recusa medidas fora de 64 a 2048 pixels", () => {
    expect(validarLogo({ ...boa, largura: 63 })).toMatch(/mínimo/);
    expect(validarLogo({ ...boa, altura: 32 })).toMatch(/mínimo/);
    expect(validarLogo({ ...boa, largura: 2049 })).toMatch(/máximo/);
  });
});

describe("outras regras", () => {
  it("monta o nome do arquivo no formato que o banco exige", () => {
    const nome = nomeDoArquivoDaLogo("png", "123e4567-e89b-12d3-a456-426614174000");
    expect(nome).toBe("logo-123e4567e89b12d3a456426614174000.png");
    expect(nome).toMatch(/^logo-[0-9a-f]{32}\.(png|jpg|webp|svg)$/);
  });

  it("formata o tamanho do arquivo", () => {
    expect(formatarTamanho(500)).toBe("500 B");
    expect(formatarTamanho(2048)).toBe("2 KB");
    expect(formatarTamanho(1_572_864)).toBe("1,5 MB");
  });

  it("avisa só quando a imagem está longe de ser quadrada", () => {
    expect(avisoDeProporcao(256, 256)).toBeNull();
    expect(avisoDeProporcao(280, 256)).toBeNull();
    expect(avisoDeProporcao(512, 256)).toMatch(/não é quadrada/);
    expect(avisoDeProporcao(0, 0)).toBeNull();
  });

  it("mostra o nome do tipo", () => {
    expect(rotuloDoTipo("image/jpeg")).toBe("JPG");
    expect(rotuloDoTipo("image/x-outro")).toBe("image/x-outro");
  });
});
