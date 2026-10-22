import { describe, expect, it } from "vitest";
import {
  calcularFonteAutomatica,
  escaparHtml,
  gerarCsv,
  montarHtmlImpressao,
  urlSegura,
} from "@/lib/exportacao";

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

  it("completa células que faltam e mostra o total de registros no rodapé padrão", () => {
    const html = montarHtmlImpressao({ ...base, linhas: [["Só o nome"]] });
    expect(html).toContain("<td>Só o nome</td><td></td>");
    expect(html).toContain("1 registro(s)");
  });
});

describe("montarHtmlImpressao: abertura da impressão", () => {
  const base = { titulo: "T", colunas: ["A"], linhas: [["1"]], geradoEm: "agora" };

  it("abre a caixa de impressão sozinha por padrão", () => {
    expect(montarHtmlImpressao(base)).toContain("setTimeout(");
  });

  it("não abre a impressão sozinha na pré-visualização, mas mantém o botão Imprimir", () => {
    const html = montarHtmlImpressao({ ...base, abrirImpressao: false });
    expect(html).not.toContain("setTimeout(");
    expect(html).toContain('onclick="window.print()"');
  });
});

describe("montarHtmlImpressao: cabeçalho, rodapé e margens", () => {
  const base = { titulo: "T", colunas: ["A"], linhas: [["1"]], geradoEm: "agora" };

  it("mostra o quadro de informações, escapado e sem itens vazios", () => {
    const html = montarHtmlImpressao({
      ...base,
      informacoes: [
        { rotulo: "Evento", valor: "18/10 · Ensaio <b>", largo: true },
        { rotulo: "Vazio", valor: "  " },
      ],
    });
    expect(html).toContain('<div class="largo"><span class="r">Evento:</span> <b>18/10 · Ensaio &lt;b&gt;</b></div>');
    expect(html).not.toContain("Vazio");
  });

  it("usa 2 colunas de informações no retrato e 3 na paisagem", () => {
    expect(montarHtmlImpressao({ ...base, orientacao: "retrato" })).toContain("repeat(2, minmax(0, 1fr))");
    expect(montarHtmlImpressao({ ...base, orientacao: "paisagem" })).toContain("repeat(3, minmax(0, 1fr))");
  });

  it("mostra a marca em texto e só aceita logomarca de endereço seguro", () => {
    expect(montarHtmlImpressao({ ...base, marca: "Sysmusica" })).toContain("<span>Sysmusica</span>");
    expect(montarHtmlImpressao({ ...base, logoUrl: "https://exemplo.com/logo.png" })).toContain(
      '<img class="logo" src="https://exemplo.com/logo.png"'
    );
    expect(montarHtmlImpressao({ ...base, logoUrl: "javascript:alert(1)" })).not.toContain("<img");
  });

  it("usa os itens de rodapé escolhidos no lugar do rodapé padrão", () => {
    const html = montarHtmlImpressao({ ...base, rodapeItens: ["Emitido por Ana", "3 registro(s)"] });
    expect(html).toContain("Emitido por Ana · 3 registro(s)");
    expect(html).not.toContain("Gerado em");
  });

  it("sem rodapé quando a lista de itens está vazia", () => {
    expect(montarHtmlImpressao({ ...base, rodapeItens: [] })).not.toContain('<footer class="rodape">');
  });

  it("junta o texto livre ao rodapé padrão", () => {
    expect(montarHtmlImpressao({ ...base, rodape: "Confidencial" })).toContain("Confidencial · Gerado em agora");
  });

  it("liga a numeração das páginas só quando pedida", () => {
    expect(montarHtmlImpressao({ ...base, paginacao: true })).toContain("counter(page)");
    expect(montarHtmlImpressao(base)).not.toContain("counter(page)");
  });

  it("aplica a margem escolhida e abre espaço extra embaixo para a numeração", () => {
    expect(montarHtmlImpressao({ ...base, margem: 15 })).toContain("margin: 15mm 15mm 15mm;");
    expect(montarHtmlImpressao({ ...base, margem: 15, paginacao: true })).toContain("margin: 15mm 15mm 19mm;");
  });

  it("limita a margem a valores razoáveis", () => {
    expect(montarHtmlImpressao({ ...base, margem: 500 })).toContain("margin: 40mm 40mm 40mm;");
    expect(montarHtmlImpressao({ ...base, margem: -3 })).toContain("margin: 0mm 0mm 0mm;");
  });

  it("mostra as linhas de assinatura (até 4)", () => {
    const html = montarHtmlImpressao({ ...base, assinaturas: ["Responsável", "Secretário", "C", "D", "E"] });
    expect(html).toContain('<div class="traco"></div><span>Responsável</span>');
    expect(html).toContain("<span>D</span>");
    expect(html).not.toContain("<span>E</span>");
  });
});

describe("urlSegura", () => {
  it("aceita https, caminho do próprio site e imagem embutida", () => {
    expect(urlSegura("https://exemplo.com/a.png")).toBe("https://exemplo.com/a.png");
    expect(urlSegura("/logo.png")).toBe("/logo.png");
    expect(urlSegura("data:image/png;base64,AAAA")).toBe("data:image/png;base64,AAAA");
  });

  it("recusa tudo o que não é seguro", () => {
    expect(urlSegura("javascript:alert(1)")).toBeNull();
    expect(urlSegura("http://exemplo.com/a.png")).toBeNull();
    expect(urlSegura("//exemplo.com/a.png")).toBeNull();
    expect(urlSegura("data:text/html;base64,AAAA")).toBeNull();
    expect(urlSegura("")).toBeNull();
    expect(urlSegura(undefined)).toBeNull();
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
