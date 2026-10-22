/** Sysmusica — Teste do cabeçalho da impressão: o título fica centralizado na folha. */
import { describe, expect, it } from "vitest";
import { montarHtmlImpressao } from "./exportacao";

describe("título da impressão", () => {
  const html = montarHtmlImpressao({ titulo: "Portarias", marca: "Sysmusica", colunas: ["A"], linhas: [["1"]] });

  it("centraliza o título e deixa a marca à esquerda", () => {
    expect(html).toContain("grid-column: 2; text-align: center;");
    expect(html).toContain(".marca { grid-column: 1; justify-self: start;");
    expect(html).toContain("<h1>Portarias</h1>");
  });
});
