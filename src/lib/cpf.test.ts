import { describe, expect, it } from "vitest";
import { formatarCpf, limparCpf, validarCpf } from "@/lib/cpf";

describe("limparCpf", () => {
  it("remove pontos, traços e espaços", () => {
    expect(limparCpf(" 529.982.247-25 ")).toBe("52998224725");
  });
});

describe("validarCpf", () => {
  it("aceita um CPF válido, com ou sem máscara", () => {
    expect(validarCpf("52998224725")).toBe(true);
    expect(validarCpf("529.982.247-25")).toBe(true);
  });

  it("recusa dígito verificador errado", () => {
    expect(validarCpf("529.982.247-26")).toBe(false);
    expect(validarCpf("123.456.789-00")).toBe(false);
  });

  it("recusa sequências repetidas e tamanhos errados", () => {
    expect(validarCpf("111.111.111-11")).toBe(false);
    expect(validarCpf("00000000000")).toBe(false);
    expect(validarCpf("5299822472")).toBe(false);
    expect(validarCpf("")).toBe(false);
  });
});

describe("formatarCpf", () => {
  it("formata um CPF completo", () => {
    expect(formatarCpf("52998224725")).toBe("529.982.247-25");
  });

  it("formata enquanto digita (CPF incompleto) e ignora o que passar de 11 dígitos", () => {
    expect(formatarCpf("5299")).toBe("529.9");
    expect(formatarCpf("529982")).toBe("529.982");
    expect(formatarCpf("5299822472599")).toBe("529.982.247-25");
  });
});
