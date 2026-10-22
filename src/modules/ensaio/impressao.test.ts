/** Sysmusica — Testes da impressão dos Dados do Ensaio. */
import { describe, expect, it } from "vitest";
import { montarImpressaoEnsaio, type EntradaImpressaoEnsaio } from "./impressao";

const base: EntradaImpressaoEnsaio = {
  tipoEvento: "Ensaio Regional",
  quando: "17/10/2026 às 19h30",
  local: "Central Itinga · Lauro de Freitas",
  atende: "João Silva — Ancião",
  rotuloEncarregados: "Encarregados Regionais",
  encarregados: ["Pedro Souza (Salvador-BA)", "Paulo Lima (Jequié-BA)"],
  hinoAbertura: "12 - Exemplo de hino",
  palavra: " Salmo 23 ",
  hinosExecutados: ["45 - Primeiro", "46 - Segundo"],
  emitidoPor: "Levi Alencar",
  geradoEm: "18/10/2026 01:31",
  marca: "Sysmusica",
};

const comoMapa = (saida: ReturnType<typeof montarImpressaoEnsaio>) =>
  Object.fromEntries((saida.informacoes ?? []).map((item) => [item.rotulo, item.valor]));

describe("montarImpressaoEnsaio", () => {
  it("lista os hinos executados na ordem, numerados", () => {
    const saida = montarImpressaoEnsaio(base);
    expect(saida.titulo).toBe("Dados do Ensaio");
    expect(saida.linhas).toEqual([
      ["1", "45 - Primeiro"],
      ["2", "46 - Segundo"],
    ]);
  });

  it("mostra quem atendeu, os encarregados, a abertura e a palavra no cabeçalho", () => {
    const itens = comoMapa(montarImpressaoEnsaio(base));
    expect(itens["Quem atendeu"]).toBe("João Silva — Ancião");
    expect(itens["Encarregados Regionais (2)"]).toBe("Pedro Souza (Salvador-BA); Paulo Lima (Jequié-BA)");
    expect(itens["Hino de abertura"]).toBe("12 - Exemplo de hino");
    expect(itens["Palavra"]).toBe("Salmo 23");
    expect(itens["Hinos executados"]).toBe("2");
    expect(itens["Emitido por"]).toBe("Levi Alencar");
  });

  it("deixa vazios (e portanto fora da folha) a palavra do ensaio local e o total sem permissão", () => {
    const itens = comoMapa(montarImpressaoEnsaio({ ...base, palavra: "", tipoEvento: "Ensaio Local" }));
    expect(itens["Palavra"]).toBe("");
    expect(itens["Total de participantes"]).toBe("");
    expect(comoMapa(montarImpressaoEnsaio({ ...base, totalParticipantes: 31 }))["Total de participantes"]).toBe("31");
  });

  it("o rodapé leva só o nome do sistema", () => {
    expect(montarImpressaoEnsaio(base).rodapeItens).toEqual(["Sysmusica"]);
    expect(montarImpressaoEnsaio({ ...base, marca: undefined }).rodapeItens).toEqual([]);
  });
});
