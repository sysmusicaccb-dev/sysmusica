import { describe, expect, it } from "vitest";
import { itemAtivo, montarMigalhas } from "@/components/layout/navegacao";

describe("itemAtivo", () => {
  it("a raiz só fica ativa exatamente em '/'", () => {
    expect(itemAtivo("/", "/")).toBe(true);
    expect(itemAtivo("/", "/membros")).toBe(false);
  });

  it("um item fica ativo na própria rota e nas subrotas", () => {
    expect(itemAtivo("/membros", "/membros")).toBe(true);
    expect(itemAtivo("/membros", "/membros/123")).toBe(true);
  });

  it("não confunde rotas com o mesmo prefixo", () => {
    expect(itemAtivo("/membros", "/membrosX")).toBe(false);
  });
});

describe("montarMigalhas", () => {
  it("mostra só 'Dashboard' na raiz", () => {
    expect(montarMigalhas("/")).toEqual([{ rotulo: "Dashboard" }]);
  });

  it("monta Início > Grupo > Página", () => {
    expect(montarMigalhas("/membros")).toEqual([
      { rotulo: "Início", href: "/" },
      { rotulo: "Cadastros" },
      { rotulo: "Membros" },
    ]);
    expect(montarMigalhas("/presencas")).toEqual([
      { rotulo: "Início", href: "/" },
      { rotulo: "Operações" },
      { rotulo: "Presenças" },
    ]);
  });

  it("subrotas usam os mesmos breadcrumbs da página", () => {
    expect(montarMigalhas("/membros/123")).toEqual(montarMigalhas("/membros"));
  });

  it("rota desconhecida volta ao início", () => {
    expect(montarMigalhas("/inexistente")).toEqual([{ rotulo: "Início", href: "/" }]);
  });
});
