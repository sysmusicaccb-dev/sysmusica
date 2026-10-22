/** Sysmusica — Testes da paginação da lista de tipos de evento. */
import { describe, expect, it } from "vitest";
import { paginar, paginasVisiveis } from "./regras";

describe("paginar", () => {
  const lista = Array.from({ length: 10 }, (_, i) => i + 1);

  it("devolve a página pedida e o total de páginas", () => {
    expect(paginar(lista, 1, 8)).toEqual({ itens: [1, 2, 3, 4, 5, 6, 7, 8], pagina: 1, totalPaginas: 2 });
    expect(paginar(lista, 2, 8)).toEqual({ itens: [9, 10], pagina: 2, totalPaginas: 2 });
  });

  it("ajusta páginas fora do limite (ex.: depois de excluir) e aceita lista vazia", () => {
    expect(paginar(lista, 9, 8).pagina).toBe(2);
    expect(paginar(lista, 0, 8).pagina).toBe(1);
    expect(paginar([], 3, 8)).toEqual({ itens: [], pagina: 1, totalPaginas: 1 });
  });
});

describe("paginasVisiveis", () => {
  it("mostra todas quando são poucas", () => {
    expect(paginasVisiveis(2, 3)).toEqual([1, 2, 3]);
  });

  it("usa reticências (null) quando são muitas", () => {
    expect(paginasVisiveis(1, 10)).toEqual([1, 2, null, 10]);
    expect(paginasVisiveis(5, 10)).toEqual([1, null, 4, 5, 6, null, 10]);
    expect(paginasVisiveis(10, 10)).toEqual([1, null, 9, 10]);
  });
});
