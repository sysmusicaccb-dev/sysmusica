import { describe, expect, it } from "vitest";
import { motivoNaoExcluir, validarPerfil, type PerfilEvento } from "./regras";

const existentes: Pick<PerfilEvento, "id" | "nome">[] = [
  { id: "1", nome: "Ensaio Local" },
  { id: "2", nome: "Ensaio Regional" },
];

describe("validarPerfil", () => {
  it("aceita nome e descrição válidos", () => {
    expect(validarPerfil({ nome: "Ensaio Técnico", descricao: "" }, existentes)).toBeNull();
  });

  it("recusa nome curto demais", () => {
    expect(validarPerfil({ nome: "ab", descricao: "" }, existentes)).toMatch(/mínimo/);
  });

  it("recusa nome repetido, sem diferenciar acento nem maiúsculas", () => {
    expect(validarPerfil({ nome: "ensaio  LOCAL", descricao: "" }, existentes)).toMatch(/Já existe/);
  });

  it("permite manter o próprio nome ao editar", () => {
    expect(validarPerfil({ nome: "Ensaio Local", descricao: "" }, existentes, "1")).toBeNull();
  });

  it("recusa descrição longa demais", () => {
    expect(validarPerfil({ nome: "Perfil novo", descricao: "x".repeat(201) }, existentes)).toMatch(/descrição/);
  });
});

describe("motivoNaoExcluir", () => {
  it("explica quando o perfil está em uso", () => {
    expect(motivoNaoExcluir({ nome: "Ensaio Local", em_uso: 2 })).toMatch(/2 tipo/);
  });
  it("devolve nulo quando pode excluir", () => {
    expect(motivoNaoExcluir({ nome: "Ensaio Local", em_uso: 0 })).toBeNull();
  });
});
