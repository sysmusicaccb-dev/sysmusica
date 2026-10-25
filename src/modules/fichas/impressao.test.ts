import { describe, expect, it } from "vitest";
import { dadosIniciais } from "./dados";
import { montarHtmlFicha } from "./impressao";

const d = { ...dadosIniciais("2026-10-25"), nome: "João <b>Silva</b>", comum: "Central", local: "Salvador", instrumento: "Trompete" };

describe("montarHtmlFicha", () => {
  it("M02: título, culto oficial, código e data por extenso", () => {
    const html = montarHtmlFicha({ tipo: "M02", dados: d, resultado: null });
    expect(html).toContain("PEDIDO DE AVALIAÇÃO DE MÚSICO");
    expect(html).toContain("CULTO OFICIAL");
    expect(html).toContain("FORMULÁRIO M02");
    expect(html).toContain("Salvador, 25 de outubro de 2026");
    expect(html).toContain("Trompete");
  });
  it("M03: oficialização e assinaturas Ancião + Encarregado regional", () => {
    const html = montarHtmlFicha({ tipo: "M03", dados: d, resultado: null });
    expect(html).toContain("OFICIALIZAÇÃO");
    expect(html).toContain("Encarregado regional</span>");
  });
  it("M05: organista, professora e opção marcada", () => {
    const html = montarHtmlFicha({ tipo: "M05", dados: { ...d, para: "CULTO_OFICIAL", professora_nome: "Maria" }, resultado: null });
    expect(html).toContain("PEDIDO DE AVALIAÇÃO DE ORGANISTA");
    expect(html).toContain("&#9746; Culto oficial");
    expect(html).toContain("&#9744; Reunião de jovens");
    expect(html).toContain("Maria");
    expect(html).toContain("Examinadora");
  });
  it("escapa HTML digitado pelo usuário", () => {
    const html = montarHtmlFicha({ tipo: "M02", dados: d, resultado: null });
    expect(html).not.toContain("<b>Silva</b>");
    expect(html).toContain("&lt;b&gt;Silva&lt;/b&gt;");
  });
  it("marca Apto Sim quando o resultado é APTO", () => {
    const html = montarHtmlFicha({ tipo: "M02", dados: d, resultado: "APTO" });
    expect(html).toContain("Apto: &#9746; Sim");
  });
});
