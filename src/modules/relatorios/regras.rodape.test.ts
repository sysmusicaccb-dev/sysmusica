/** Sysmusica — Teste do padrão do rodapé: não repete o que já está no cabeçalho. */
import { describe, expect, it } from "vitest";
import { PAGINA_INICIAL } from "./regras";

describe("padrão do rodapé do relatório", () => {
  it("quem emitiu, a data e o total ficam só no cabeçalho", () => {
    expect(PAGINA_INICIAL.cabecalho.emitidoPor).toBe(true);
    expect(PAGINA_INICIAL.cabecalho.total).toBe(true);
    expect(PAGINA_INICIAL.rodapeMarcado.emitidoPor).toBe(false);
    expect(PAGINA_INICIAL.rodapeMarcado.total).toBe(false);
  });

  it("o rodapé mantém o nome do sistema e a numeração das páginas", () => {
    expect(PAGINA_INICIAL.rodapeMarcado.sistema).toBe(true);
    expect(PAGINA_INICIAL.rodapeMarcado.paginacao).toBe(true);
  });
});
