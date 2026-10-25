import { describe, expect, it } from "vitest";
import { dadosIniciais } from "./dados";
import { montarHtmlFicha } from "./impressao";

const d = { ...dadosIniciais("2026-10-25"), nome: "Ana", comum: "Central", local: "Salvador" };

describe("folhas do lote 4", () => {
  it("M01: título, campos do GEM e assinaturas do aluno e do responsável", () => {
    const html = montarHtmlFicha({ tipo: "M01", dados: { ...d, nascimento: "2010-03-04", inicio_gem: "2026-02-01", responsavel_nome: "Maria" }, resultado: null });
    expect(html).toContain("CADASTRO PARA INGRESSO NO GEM");
    expect(html).toContain("04/03/2010");
    expect(html).toContain("01/02/2026");
    expect(html).toContain("Maria");
    expect(html).toContain("FORMULÁRIO M01");
    expect(html).toContain("Encarregado local");
  });
  it("M07: motivo marcado, instrumentos e resultado", () => {
    const html = montarHtmlFicha({
      tipo: "M07",
      dados: { ...d, motivo: "SAUDE", instrumento_atual: "Trompete", instrumento_novo: "Eufônio" },
      resultado: "APTO",
    });
    expect(html).toContain("PEDIDO DE TROCA DE INSTRUMENTO");
    expect(html).toContain("&#9746; Saúde ou orientação médica");
    expect(html).toContain("&#9744; Necessidade da orquestra");
    expect(html).toContain("Eufônio");
    expect(html).toContain("Apto: &#9746; Sim");
    expect(html).toContain("Reunião ministerial");
    expect(html).toContain("FORMULÁRIO M07");
  });
  it("RJM: pede avaliação para a reunião de jovens e menores", () => {
    const html = montarHtmlFicha({ tipo: "AVALIACAO_RJM", dados: d, resultado: null });
    expect(html).toContain("REUNIÃO DE JOVENS E MENORES");
    expect(html).toContain("PEDIDO DE AVALIAÇÃO DE MÚSICO");
  });
});
