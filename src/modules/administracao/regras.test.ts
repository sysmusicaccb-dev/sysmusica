import { describe, expect, it } from "vitest";
import {
  agruparPermissoesPorModulo,
  alternarModulo,
  alternarPermissao,
  validarNovoUsuario,
  validarSenha,
} from "@/modules/administracao/regras";
import type { PermissaoCatalogo } from "@/modules/administracao/tipos";

const GRUPO_ID = "123e4567-e89b-12d3-a456-426614174000";

describe("validarSenha", () => {
  it("aceita senha com 10+ caracteres misturando letras e números", () => {
    expect(validarSenha("Orquestra2026")).toBeNull();
  });

  it("recusa senha curta, só com letras ou só com números", () => {
    expect(validarSenha("Abc123")).toMatch(/pelo menos 10/);
    expect(validarSenha("somenteletras")).toMatch(/letras e números/);
    expect(validarSenha("1234567890")).toMatch(/letras e números/);
  });

  it("recusa senha acima do limite", () => {
    expect(validarSenha("a1".repeat(40))).toMatch(/no máximo/);
  });
});

describe("validarNovoUsuario", () => {
  const valido = { nome: "  Ana Souza ", email: " ANA@Exemplo.com ", senha: "Orquestra2026", grupoId: GRUPO_ID };

  it("normaliza nome e e-mail", () => {
    const resultado = validarNovoUsuario(valido);
    expect(resultado).toEqual({
      ok: true,
      dados: { nome: "Ana Souza", email: "ana@exemplo.com", senha: "Orquestra2026", grupoId: GRUPO_ID },
    });
  });

  it("recusa entradas que não são objeto", () => {
    expect(validarNovoUsuario(null)).toMatchObject({ ok: false });
    expect(validarNovoUsuario("texto")).toMatchObject({ ok: false });
  });

  it("recusa campos ausentes ou de tipo errado", () => {
    expect(validarNovoUsuario({ ...valido, senha: 123 })).toMatchObject({ ok: false });
    expect(validarNovoUsuario({ nome: "Ana" })).toMatchObject({ ok: false });
  });

  it("recusa nome curto, e-mail inválido, senha fraca e grupo inválido", () => {
    expect(validarNovoUsuario({ ...valido, nome: "A" })).toMatchObject({ ok: false });
    expect(validarNovoUsuario({ ...valido, email: "sem-arroba" })).toMatchObject({ ok: false });
    expect(validarNovoUsuario({ ...valido, senha: "curta1" })).toMatchObject({ ok: false });
    expect(validarNovoUsuario({ ...valido, grupoId: "nao-e-uuid" })).toMatchObject({ ok: false });
  });
});

describe("grade de permissões", () => {
  const catalogo: PermissaoCatalogo[] = [
    { codigo: "membros.excluir", modulo: "Membros", acao: "Excluir", descricao: "" },
    { codigo: "membros.visualizar", modulo: "Membros", acao: "Visualizar", descricao: "" },
    { codigo: "membros.editar", modulo: "Membros", acao: "Editar", descricao: "" },
    { codigo: "dashboard.visualizar", modulo: "Dashboard", acao: "Visualizar", descricao: "" },
  ];

  it("agrupa por módulo e ordena as ações", () => {
    const modulos = agruparPermissoesPorModulo(catalogo);
    expect(modulos.map((modulo) => modulo.chave)).toEqual(["membros", "dashboard"]);
    expect(modulos[0].itens.map((item) => item.acao)).toEqual(["Visualizar", "Editar", "Excluir"]);
  });

  it("marcar uma ação marca também 'visualizar'", () => {
    const novas = alternarPermissao(new Set(), "membros.editar", catalogo);
    expect([...novas].sort()).toEqual(["membros.editar", "membros.visualizar"]);
  });

  it("desmarcar 'visualizar' desmarca todas as ações do módulo, sem mexer nos outros", () => {
    const inicio = new Set(["membros.visualizar", "membros.editar", "dashboard.visualizar"]);
    const novas = alternarPermissao(inicio, "membros.visualizar", catalogo);
    expect([...novas]).toEqual(["dashboard.visualizar"]);
  });

  it("não altera o conjunto original", () => {
    const inicio = new Set(["membros.visualizar"]);
    alternarPermissao(inicio, "membros.editar", catalogo);
    expect([...inicio]).toEqual(["membros.visualizar"]);
  });

  it("alternarModulo marca todas e, se já estavam todas, desmarca todas", () => {
    const [membros] = agruparPermissoesPorModulo(catalogo);
    const marcadas = alternarModulo(new Set(), membros);
    expect(marcadas.size).toBe(3);
    expect(alternarModulo(marcadas, membros).size).toBe(0);
  });
});
