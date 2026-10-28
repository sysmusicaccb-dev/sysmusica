import { describe, expect, it } from "vitest";
import { corDaFamilia, montarModeloRelatorio } from "./modelo";
import { escalaParaA4, montarHtmlRelatorio } from "./impressaoFolha";
import type { RespostaRelatorioEnsaio } from "./tipos";

const linha = (codigo: string, bloco: "MINISTERIO" | "MUSICOS" | "ORGANISTAS", rotulo: string, ordem: number, qtd: number) => ({
  codigo, bloco, rotulo, ordem, qtd, selecionavel: true,
});

function resposta(extra: Partial<RespostaRelatorioEnsaio> = {}): RespostaRelatorioEnsaio {
  return {
    evento: { id: "e1", tipo: "Ensaio Regional", data_evento: "2026-10-11T12:00:00Z", local: null, cidade: "Gandu", casa_oracao: "Central", modelo_ensaio: null },
    config: null,
    dados: null,
    painel: {
      total: 30,
      linhas: [
        linha("ANCIAO", "MINISTERIO", "Ancião", 1, 2),
        linha("DIACONO", "MINISTERIO", "Diácono", 2, 1),
        linha("MUS", "MUSICOS", "Oficializado", 3, 20),
        linha("ORG", "ORGANISTAS", "Organista", 4, 7),
      ],
      instrumentos: [{ familia: "Cordas", qtd: 12 }, { familia: "Metais", qtd: 3 }],
      instrumentos_detalhe: [
        { familia: "Cordas", instrumento: "Violino", qtd: 12 },
        { familia: "Metais", instrumento: "Trombone", qtd: 3 },
      ],
    },
    atualizado_em: "2026-10-11T13:00:00Z",
    ...extra,
  };
}
const extras = { emitidoPor: "Levi", geradoEm: "11/10/2026 10:00", marca: "Sysmusica" };

describe("montarModeloRelatorio", () => {
  it("calcula Orquestra e Total geral a partir do painel", () => {
    const m = montarModeloRelatorio(resposta(), extras);
    expect(m.ministerio.total).toBe(3);
    expect(m.orquestra).toBe(27);
    expect(m.totalGeral).toBe(30);
    expect(m.totalInstrumentos).toBe(15);
  });
  it("monta título e subtítulo com cidade e casa de oração", () => {
    const m = montarModeloRelatorio(resposta(), extras);
    expect(m.titulo).toBe("ENSAIO REGIONAL");
    expect(m.subtitulo).toBe("GANDU - CENTRAL");
  });
  it("sem perfil de ensaio, esconde os blocos do ensaio", () => {
    const m = montarModeloRelatorio(resposta(), extras);
    expect(m.atendimento).toBeNull();
    expect(m.palavra).toBeNull();
    expect(m.regencia).toBeNull();
    expect(m.hinos).toBeNull();
    expect(m.extras).toEqual([]);
  });
  it("instrumentos seguem a ordem das famílias", () => {
    const m = montarModeloRelatorio(resposta(), extras);
    expect(m.instrumentos.map((i) => i.nome)).toEqual(["Violino", "Trombone"]);
  });
});

describe("cores e impressão", () => {
  it("usa as cores do modelo nas famílias fixas", () => {
    expect(corDaFamilia("Cordas", 0)).toBe("#2563eb");
    expect(corDaFamilia("Metais", 0)).toBe("#f5b400");
    expect(corDaFamilia("Teclas", 0)).toBe("#10b981");
  });
  it("a escala cabe no A4 paisagem", () => {
    const k = escalaParaA4();
    expect(k).toBeGreaterThan(0.7);
    expect(k * 1280).toBeLessThanOrEqual(((297 - 12) * 96) / 25.4);
    expect(k * 905).toBeLessThanOrEqual(((210 - 12) * 96) / 25.4);
  });
  it("o HTML de impressão não tem script e escapa o título", () => {
    const html = montarHtmlRelatorio("<b>x</b>", "<div>folha</div>");
    expect(html).not.toContain("<script");
    expect(html).toContain("&lt;b&gt;");
    expect(html).toContain("size:A4 landscape");
    expect(html).toContain("<div>folha</div>");
  });
});
