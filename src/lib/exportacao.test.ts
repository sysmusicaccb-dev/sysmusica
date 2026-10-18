import { describe, expect, it } from "vitest";
import { calcularFonteAutomatica, escaparHtml, gerarCsv, montarHtmlImpressao } from "@/lib/exportacao";

describe("escaparHtml", () => {
  it("troca os símbolos do HTML", () => {
    expect(escaparHtml(`<b>"A" & 'B'</b>`)).toBe("&lt;b&gt;&quot;A&quot; &amp; &#39;B&#39;&lt;/b&gt;");
  });
});

describe("calcularFonteAutomatica", () => {
  it("mantém a letra normal com poucas colunas", () => {
    expect(calcularFonteAutomatica(5, "paisagem")).toBe(10);
    expect(calcularFonteAutomatica(6, "retrato")).toBe(9.5);
  });

  it("reduz a letra com muitas colunas, sem passar do mínimo", () => {
    expect(calcularFonteAutomatica(12, "paisagem")).toBe(7.6);
    expect(calcularFonteAutomatica(30, "retrato")).toBe(6.5);
  });
});

describe("montarHtmlImpressao", () => {
  const base = {
    titulo: "Relatório <teste>",
    colunas: ["Nome", "Cargo"],
    linhas: [["Maria <script>", "Músico"]],
    geradoEm: "17/10/2026 20:00",
  };

  it("escapa título e células e traz o cabeçalho da tabela", () => {
    const html = montarHtmlImpressao(base);
    expect(html).toContain("Relatório &lt;teste&gt;");
    expect(html).toContain("<td>Maria &lt;script&gt;</td>");
    expect(html).toContain("<th>Nome</th>");
    expect(html).not.toContain("<td>Maria <script>");
  });

  it("usa paisagem por padrão e retrato quando pedido", () => {
    expect(montarHtmlImpressao(base)).toContain("size: A4 landscape");
    expect(montarHtmlImpressao({ ...base, orientacao: "retrato" })).toContain("size: A4 portrait");
  });

  it("aplica o ajuste manual de escala e de letra", () => {
    const html = montarHtmlImpressao({ ...base, escala: 80, tamanhoFonte: 8 });
    expect(html).toContain("zoom: 0.8");
    expect(html).toContain("font-size: 8pt");
  });

  it("completa células que faltam e mostra o total de registros", () => {
    const html = montarHtmlImpressao({ ...base, linhas: [["Só o nome"]] });
    expect(html).toContain("<td>Só o nome</td><td></td>");
    expect(html).toContain("1 registro(s)");
  });
});

describe("gerarCsv", () => {
  it("usa ponto e vírgula, aspas e a marca de acentos do Excel", () => {
    const csv = gerarCsv(["Nome", "Obs"], [["Ana", 'disse "oi"']]);
    expect(csv.startsWith("\uFEFF")).toBe(true);
    expect(csv).toContain('"Nome";"Obs"');
    expect(csv).toContain('"Ana";"disse ""oi"""');
  });

  it("protege contra fórmulas do Excel e remove quebras de linha", () => {
    const csv = gerarCsv(["A"], [["=SOMA(1;2)"], ["linha1\nlinha2"]]);
    expect(csv).toContain(`"'=SOMA(1;2)"`);
    expect(csv).toContain('"linha1 linha2"');
  });
});
