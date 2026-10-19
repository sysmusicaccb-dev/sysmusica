import { describe, expect, it } from "vitest";
import {
  horaCurta,
  mensagemCamera,
  nomeCompletoValido,
  ordenarPorProximidade,
  pareceQrSysMusica,
  validarDadosVisitante,
} from "@/modules/atendimento/regras";

describe("pareceQrSysMusica", () => {
  it("reconhece o prefixo do QR Code do SysMúsica (ignorando espaços e maiúsculas)", () => {
    expect(pareceQrSysMusica("SYSMUSICA:1:abc")).toBe(true);
    expect(pareceQrSysMusica("  sysmusica:1:abc ")).toBe(true);
  });

  it("recusa outros conteúdos", () => {
    expect(pareceQrSysMusica("https://exemplo.com")).toBe(false);
    expect(pareceQrSysMusica("")).toBe(false);
  });
});

describe("nomeCompletoValido", () => {
  it("exige nome e sobrenome", () => {
    expect(nomeCompletoValido("Maria")).toBe(false);
    expect(nomeCompletoValido("Jo Li")).toBe(false);
    expect(nomeCompletoValido("Maria Silva")).toBe(true);
    expect(nomeCompletoValido("  Ana   Lima ")).toBe(true);
  });
});

describe("validarDadosVisitante", () => {
  const completo = { nome: "Maria da Silva", cargoId: "c1", origemCasaOracaoId: "o1" };

  it("aceita os dados completos", () => {
    expect(validarDadosVisitante(completo)).toBeNull();
  });

  it("exige nome e sobrenome", () => {
    expect(validarDadosVisitante({ ...completo, nome: "Maria" })).toMatch(/nome completo/);
  });

  it("exige o cargo ou ministério", () => {
    expect(validarDadosVisitante({ ...completo, cargoId: "" })).toMatch(/cargo/);
  });

  it("exige a igreja de origem escolhida na lista", () => {
    expect(validarDadosVisitante({ ...completo, origemCasaOracaoId: "" })).toMatch(/igreja de origem/);
  });
});

describe("horaCurta", () => {
  it("mostra a hora no fuso de Salvador", () => {
    expect(horaCurta("2026-10-17T21:42:00Z")).toBe("18h42");
  });
});

describe("ordenarPorProximidade", () => {
  const agora = Date.parse("2026-10-17T12:00:00Z");
  const itens = [
    { id: "longe", evento_data: "2026-10-17T20:00:00Z" },
    { id: "sem-data", evento_data: null },
    { id: "perto", evento_data: "2026-10-17T11:30:00Z" },
  ];

  it("coloca o evento mais próximo primeiro e o sem data por último", () => {
    expect(ordenarPorProximidade(itens, agora).map((item) => item.id)).toEqual(["perto", "longe", "sem-data"]);
  });

  it("não altera a lista original", () => {
    ordenarPorProximidade(itens, agora);
    expect(itens.map((item) => item.id)).toEqual(["longe", "sem-data", "perto"]);
  });
});

describe("mensagemCamera", () => {
  it("traduz os erros mais comuns", () => {
    expect(mensagemCamera(new Error("INSEGURO"))).toMatch(/https/);
    expect(mensagemCamera("Camera not found.")).toMatch(/Nenhuma câmera/);
    const negado = new Error("Permission denied");
    negado.name = "NotAllowedError";
    expect(mensagemCamera(negado)).toMatch(/permissão/);
  });

  it("tem uma mensagem geral para o resto", () => {
    expect(mensagemCamera(new Error("falha qualquer"))).toMatch(/Não foi possível iniciar a câmera/);
  });
});
