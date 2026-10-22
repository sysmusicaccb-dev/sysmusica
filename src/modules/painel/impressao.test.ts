/** Sysmusica — Testes da impressão do Painel de Totais. */
import { describe, expect, it } from "vitest";
import { montarImpressaoPainel } from "./impressao";
import type { DadosPainel, LinhaPainel } from "./tipos";

const linha = (codigo: string, bloco: LinhaPainel["bloco"], rotulo: string, ordem: number, qtd: number): LinhaPainel => ({
  codigo,
  bloco,
  rotulo,
  ordem,
  qtd,
  selecionavel: true,
});

const dados: DadosPainel = {
  evento: {
    id: "e1",
    tipo: "Ensaio Regional",
    local: "Central Itinga",
    data_evento: "2026-10-17T22:30:00Z",
    cidade: "Lauro de Freitas",
    casa_oracao: "Central Itinga",
  },
  total: 10,
  linhas: [
    linha("anciao", "MINISTERIO", "Ancião", 1, 1),
    linha("encarregado_local", "MUSICOS", "Encarregado Local", 1, 2),
    linha("musico", "MUSICOS", "Músico", 2, 5),
    linha("organista", "ORGANISTAS", "Organista", 1, 2),
  ],
  instrumentos: [
    { familia: "Cordas", qtd: 3 },
    { familia: "Metais", qtd: 1 },
  ],
  atualizado_em: "2026-10-17T22:45:12Z",
};
const extras = { emitidoPor: "Levi Alencar", geradoEm: "18/10/2026 01:31", marca: "Sysmusica" };

describe("montarImpressaoPainel", () => {
  const saida = montarImpressaoPainel(dados, extras);

  it("monta a tabela com os blocos e as famílias de instrumentos", () => {
    expect(saida.titulo).toBe("Painel de Totais");
    expect(saida.colunas).toEqual(["Item", "Quantidade", "Percentual"]);
    expect(saida.linhas).toEqual([
      ["Ancião", "1", ""],
      ["Encarregado Local", "2", ""],
      ["Músico", "5", ""],
      ["Organista", "2", ""],
      ["Cordas", "3", "75,0%"],
      ["Madeiras", "0", "0,0%"],
      ["Metais", "1", "25,0%"],
    ]);
  });

  it("põe a faixa de cada bloco antes da sua primeira linha, com o total do bloco", () => {
    expect(saida.agrupamento).toEqual([
      { antesDaLinha: 0, titulo: "Ministério — 1" },
      { antesDaLinha: 1, titulo: "Músicos — 7" },
      { antesDaLinha: 3, titulo: "Organistas — 2" },
      { antesDaLinha: 4, titulo: "Instrumentos — 4" },
    ]);
  });

  it("traz o total de participantes e quem emitiu no cabeçalho, sem repetir no rodapé", () => {
    const itens = Object.fromEntries((saida.informacoes ?? []).map((item) => [item.rotulo, item.valor]));
    expect(itens["Total de participantes"]).toBe("10");
    expect(itens["Emitido por"]).toBe("Levi Alencar");
    expect(itens["Local"]).toBe("Central Itinga · Lauro de Freitas");
    expect(saida.rodapeItens).toEqual(["Sysmusica"]);
  });

  it("não quebra com data de atualização inválida nem com bloco vazio", () => {
    const sem = montarImpressaoPainel(
      { ...dados, atualizado_em: "x", linhas: [linha("musico", "MUSICOS", "Músico", 1, 5)] },
      extras
    );
    const itens = Object.fromEntries((sem.informacoes ?? []).map((item) => [item.rotulo, item.valor]));
    expect(itens["Atualizado às"]).toBe("");
    expect((sem.agrupamento ?? []).map((grupo) => grupo.titulo)).toEqual(["Músicos — 5", "Instrumentos — 4"]);
  });
});
