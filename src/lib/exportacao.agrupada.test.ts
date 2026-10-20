import { describe, expect, it } from "vitest";
import { montarHtmlImpressao } from "@/lib/exportacao";

const base = { titulo: "T", colunas: ["Nº", "Nome", "Situação"], geradoEm: "agora" };

describe("montarHtmlImpressao: grupos e colunas compactas", () => {
  it("coloca o título do grupo antes da linha indicada, ocupando a linha toda", () => {
    const html = montarHtmlImpressao({
      ...base,
      linhas: [["1", "Ana", "Presente"], ["2", "Bia", "Presente"]],
      agrupamento: [{ antesDaLinha: 1, titulo: "Grupo <B>" }],
    });
    expect(html).toContain('<tr class="grp"><td colspan="3">Grupo &lt;B&gt;</td></tr><tr><td');
    expect(html).toContain('class="agrupada"');
  });

  it("sem agrupamento nada muda na tabela", () => {
    const html = montarHtmlImpressao({ ...base, linhas: [["1", "Ana", "Presente"]] });
    expect(html).not.toContain('class="grp"');
    expect(html).toContain("<td>Ana</td>");
  });

  it("colunas compactas não quebram a linha; as longas continuam quebrando", () => {
    const html = montarHtmlImpressao({
      ...base,
      colunasCompactas: true,
      linhas: [["1", "Um nome muito mais comprido do que o limite da coluna compacta", "Aprovada"]],
    });
    expect(html).toContain('<th class="nq">Nº</th>');
    expect(html).toContain('<td class="nq">Aprovada</td>');
    expect(html).toContain("<th>Nome</th>");
    expect(html).toContain("<td>Um nome muito mais comprido");
  });
});
