import { describe, expect, it } from "vitest";
import { dividirEmDuas, escalaDoGrafico, fatiasDaRosca, montarInstrumentos, type DadosPainelTotais } from "./detalhe";

const base: DadosPainelTotais = {
  evento: { id: "e", tipo: "Ensaio Regional", local: null, data_evento: "2026-10-11T12:00:00Z", cidade: null, casa_oracao: null },
  total: 10,
  linhas: [],
  instrumentos: [
    { familia: "Metais", qtd: 3 },
    { familia: "Cordas", qtd: 2 },
    { familia: "Madeiras", qtd: 1 },
  ],
  atualizado_em: "2026-10-11T12:00:00Z",
};

describe("montarInstrumentos", () => {
  it("sem o detalhe do banco devolve só as famílias", () => {
    const r = montarInstrumentos(base);
    expect(r.instrumentos).toBeNull();
    expect(r.total).toBe(6);
    expect(r.familias.map((f) => f.nome)).toEqual(["Cordas", "Madeiras", "Metais"]);
  });

  it("ordena por família (Cordas, Madeiras, Metais), depois por quantidade e nome, com percentual", () => {
    const r = montarInstrumentos({
      ...base,
      instrumentos_detalhe: [
        { familia: "Metais", instrumento: "Trombone", qtd: 1 },
        { familia: "Metais", instrumento: "Trompete", qtd: 2 },
        { familia: "Cordas", instrumento: "Viola", qtd: 1 },
        { familia: "Cordas", instrumento: "Violino", qtd: 1 },
        { familia: "Madeiras", instrumento: "Flauta", qtd: 1 },
        { familia: "Madeiras", instrumento: "Oboé", qtd: 0 },
      ],
    });
    expect(r.instrumentos?.map((i) => i.nome)).toEqual(["Viola", "Violino", "Flauta", "Trompete", "Trombone"]);
    expect(r.instrumentos?.find((i) => i.nome === "Trompete")?.percentual).toBe("33,3%");
  });

  it("família desconhecida vai para o fim", () => {
    const r = montarInstrumentos({
      ...base,
      instrumentos_detalhe: [
        { familia: "Sem família", instrumento: "Gaita", qtd: 1 },
        { familia: "Cordas", instrumento: "Viola", qtd: 1 },
      ],
    });
    expect(r.instrumentos?.map((i) => i.nome)).toEqual(["Viola", "Gaita"]);
  });
});

describe("dividirEmDuas", () => {
  it("a primeira coluna fica com a metade maior", () => {
    expect(dividirEmDuas([1, 2, 3, 4, 5])).toEqual([[1, 2, 3], [4, 5]]);
    expect(dividirEmDuas([])).toEqual([[], []]);
  });
});

describe("escalaDoGrafico", () => {
  it("cobre o maior valor com marcas redondas", () => {
    expect(escalaDoGrafico([5, 6, 13, 14, 9])).toEqual({ topo: 15, marcas: [0, 5, 10, 15] });
    expect(escalaDoGrafico([0, 0])).toEqual({ topo: 4, marcas: [0, 1, 2, 3, 4] });
    expect(escalaDoGrafico([]).topo).toBe(4);
    expect(escalaDoGrafico([37]).topo).toBe(40);
  });
});

describe("fatiasDaRosca", () => {
  it("calcula arcos e percentuais", () => {
    const f = fatiasDaRosca([{ rotulo: "A", qtd: 1 }, { rotulo: "B", qtd: 3 }], 100);
    expect(f.map((x) => x.comprimento)).toEqual([25, 75]);
    expect(f.map((x) => x.deslocamento)).toEqual([0, 25]);
    expect(f[0].percentual).toBe("25,0%");
  });
  it("total zero não gera arcos", () => {
    const f = fatiasDaRosca([{ rotulo: "A", qtd: 0 }], 100);
    expect(f[0].comprimento).toBe(0);
    expect(f[0].percentual).toBe("0,0%");
  });
});
