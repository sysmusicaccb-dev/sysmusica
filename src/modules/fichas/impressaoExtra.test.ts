import { describe, expect, it } from "vitest";
import { dadosIniciais } from "./dados";
import { montarHtmlExtra } from "./impressaoExtra";

const base = { ...dadosIniciais("2026-10-25"), nome: "Ana <b>", comum: "Central", local: "Salvador" };

describe("folhas extras", () => {
  it("M10 marca a nota e escapa HTML", () => {
    const html = montarHtmlExtra({ tipo: "AVALIACAO_CANDIDATO", dados: { ...base, notas: { nota_lr: "BOM", nota_teoria: "9" } }, resultado: "APTO" })!;
    expect(html).toContain("FICHA DE AVALIAÇÃO DE CANDIDATO A MÚSICO");
    expect(html).toContain("FORMULÁRIO M10");
    expect(html).toContain("Ana &lt;b&gt;");
    expect(html).toContain("Apto: &#9746; Sim");
  });
  it("M11 calcula a média e imprime 20 aulas", () => {
    const html = montarHtmlExtra({ tipo: "ACOMPANHAMENTO_GEM", dados: { ...base, notas: { v1_nota: "8", v2_nota: "9", a01_pres: "P" } }, resultado: null })!;
    expect(html).toContain("FICHA DE ACOMPANHAMENTO - GEM");
    expect(html).toContain("<b>MÉDIA:</b> 8,5");
    expect(html).toContain(">20<");
    expect(html).toContain("FORMULÁRIO M11");
  });
  it("organistas: pré-avaliação e exames têm títulos diferentes", () => {
    const pre = montarHtmlExtra({ tipo: "PRE_AVALIACAO_ORGANISTA", dados: base, resultado: null })!;
    const ex = montarHtmlExtra({ tipo: "EXAME_ORGANISTA", dados: { ...base, notas: { of_resultado: "RETORNAR" } }, resultado: null })!;
    expect(pre).toContain("PRÉ AVALIAÇÃO DE CANDIDATAS A ORGANISTAS");
    expect(ex).toContain("TESTES E EXAMES DE ORGANISTAS");
    expect(ex).toContain("&#9746; Retornar novo exame");
  });
  it("necessidade: duas páginas e aprovado marcado", () => {
    const html = montarHtmlExtra({ tipo: "NECESSIDADE_INSTRUMENTO", dados: { ...base, notas: { fase: "RJM", item_instrumento: "1" } }, resultado: "APTO" })!;
    expect(html).toContain("quebra");
    expect(html).toContain("&#9746; REUNIÃO DE JOVENS E MENORES");
    expect(html).toContain("&#9746; INSTRUMENTO MUSICAL");
    expect(html).toContain("&#9746; APROVADO");
    expect(html).toContain("RECIBO DE ENTREGA");
  });
  it("tipos comuns não são tratados aqui", () => {
    expect(montarHtmlExtra({ tipo: "M02", dados: base, resultado: null })).toBeNull();
  });
});
