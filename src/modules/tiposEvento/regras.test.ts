import { describe, expect, it } from "vitest";
import {
  DESCRICAO_MAXIMA,
  filtrarTipos,
  formatarNomeTipo,
  rotuloDoModelo,
  tiposParaEscolher,
  validarTipoEvento,
} from "./regras";

const existentes = [
  { id: "1", nome: "Ensaio Regional" },
  { id: "2", nome: "Reunião Musical" },
];

describe("validarTipoEvento", () => {
  it("aceita um nome novo, com ou sem descrição", () => {
    expect(validarTipoEvento({ nome: "Culto Oficial", descricao: "" }, existentes)).toBeNull();
    expect(validarTipoEvento({ nome: "Culto Oficial", descricao: "Culto com participação musical" }, existentes)).toBeNull();
  });

  it("recusa nome curto (ignorando espaços), longo e descrição longa", () => {
    expect(validarTipoEvento({ nome: "  ab ", descricao: "" }, existentes)).toMatch(/mínimo/);
    expect(validarTipoEvento({ nome: "x".repeat(61), descricao: "" }, existentes)).toMatch(/no máximo/);
    expect(validarTipoEvento({ nome: "Novo tipo", descricao: "a".repeat(DESCRICAO_MAXIMA + 1) }, existentes)).toMatch(/descrição/);
  });

  it("recusa nome repetido sem diferenciar acento, maiúsculas e espaços", () => {
    expect(validarTipoEvento({ nome: "reuniao   MUSICAL", descricao: "" }, existentes)).toMatch(/Já existe/);
  });

  it("na edição, o próprio tipo não conta como repetido", () => {
    expect(validarTipoEvento({ nome: "Reunião Musical", descricao: "" }, existentes, "2")).toBeNull();
    expect(validarTipoEvento({ nome: "Reunião Musical", descricao: "" }, existentes, "1")).toMatch(/Já existe/);
  });
});

describe("formatarNomeTipo e rotuloDoModelo", () => {
  it("limpa os espaços", () => {
    expect(formatarNomeTipo("  Ensaio   Técnico ")).toBe("Ensaio Técnico");
  });

  it("mostra o modelo do ensaio ou 'Não usa'", () => {
    expect(rotuloDoModelo("LOCAL")).toBe("Ensaio Local");
    expect(rotuloDoModelo("REGIONAL")).toBe("Ensaio Regional");
    expect(rotuloDoModelo(null)).toBe("Não usa");
  });
});

describe("filtrarTipos", () => {
  const lista = [
    { nome: "Ensaio Regional", descricao: "Ensaio do ministério regional" },
    { nome: "Congresso", descricao: "Congresso ou convenção" },
    { nome: "Outro", descricao: null },
  ];
  it("busca no nome e na descrição, sem acento", () => {
    expect(filtrarTipos(lista, "").length).toBe(3);
    expect(filtrarTipos(lista, "convencao").map((t) => t.nome)).toEqual(["Congresso"]);
    expect(filtrarTipos(lista, "ENSAIO").map((t) => t.nome)).toEqual(["Ensaio Regional"]);
    expect(filtrarTipos(lista, "zzz")).toEqual([]);
  });
});

describe("tiposParaEscolher", () => {
  const lista = [
    { id: "a", ativo: true },
    { id: "b", ativo: false },
    { id: "c", ativo: false },
  ];
  it("só os ativos para um evento novo", () => {
    expect(tiposParaEscolher(lista, null).map((t) => t.id)).toEqual(["a"]);
  });
  it("na edição mantém o tipo atual do evento, mesmo desativado", () => {
    expect(tiposParaEscolher(lista, "b").map((t) => t.id)).toEqual(["a", "b"]);
  });
});
