import { describe, expect, it } from "vitest";
import {
  agruparBlocos,
  cargoUsaCategoria,
  formatarHoraDoEvento,
  formatarPercentual,
  intervaloValido,
  montarFamilias,
  rotuloDaCategoria,
  validarCategoria,
} from "./regras";
import type { LinhaPainel } from "./tipos";

const linha = (parcial: Partial<LinhaPainel> & Pick<LinhaPainel, "codigo" | "bloco">): LinhaPainel => ({
  rotulo: parcial.codigo,
  ordem: 0,
  qtd: 0,
  selecionavel: true,
  ...parcial,
});

describe("intervaloValido", () => {
  it("aceita os intervalos permitidos", () => {
    expect(intervaloValido(5)).toBe(5);
    expect(intervaloValido("30")).toBe(30);
    expect(intervaloValido(60)).toBe(60);
  });
  it("qualquer outro valor volta para 10 segundos", () => {
    expect(intervaloValido(7)).toBe(10);
    expect(intervaloValido(null)).toBe(10);
    expect(intervaloValido("abc")).toBe(10);
    expect(intervaloValido(0)).toBe(10);
  });
});

describe("formatarPercentual", () => {
  it("usa vírgula e uma casa decimal", () => {
    expect(formatarPercentual(13, 47)).toBe("27,7%");
    expect(formatarPercentual(18, 47)).toBe("38,3%");
    expect(formatarPercentual(16, 47)).toBe("34,0%");
  });
  it("total zero não divide por zero", () => {
    expect(formatarPercentual(0, 0)).toBe("0,0%");
  });
});

describe("formatarHoraDoEvento", () => {
  it("em ponto mostra só a hora; senão, hora e minutos (fuso de Salvador)", () => {
    expect(formatarHoraDoEvento("2026-10-11T12:00:00Z")).toBe("09h");
    expect(formatarHoraDoEvento("2026-10-11T12:30:00Z")).toBe("09h30");
    expect(formatarHoraDoEvento("2026-10-11T22:05:00Z")).toBe("19h05");
  });
});

describe("agruparBlocos", () => {
  const linhas = [
    linha({ codigo: "MUS_B", bloco: "MUSICOS", ordem: 2, qtd: 3 }),
    linha({ codigo: "MUS_A", bloco: "MUSICOS", ordem: 1, qtd: 2 }),
    linha({ codigo: "MUS_SEM", bloco: "MUSICOS", ordem: 9, qtd: 0, selecionavel: false }),
    linha({ codigo: "MIN_A", bloco: "MINISTERIO", ordem: 1, qtd: 4 }),
    linha({ codigo: "ORG_SEM", bloco: "ORGANISTAS", ordem: 9, qtd: 1, selecionavel: false }),
  ];

  it("separa em Ministério, Músicos e Organistas, nessa ordem, com o total de cada um", () => {
    const blocos = agruparBlocos(linhas);
    expect(blocos.map((b) => b.rotulo)).toEqual(["Ministério", "Músicos", "Organistas"]);
    expect(blocos.map((b) => b.total)).toEqual([4, 5, 1]);
  });

  it("ordena as linhas e esconde 'Sem categoria' quando está zerada, mas mostra quando há gente", () => {
    const [, musicos, organistas] = agruparBlocos(linhas);
    expect(musicos.linhas.map((l) => l.codigo)).toEqual(["MUS_A", "MUS_B"]);
    expect(organistas.linhas.map((l) => l.codigo)).toEqual(["ORG_SEM"]);
  });

  it("não altera a lista original", () => {
    const copia = JSON.stringify(linhas);
    agruparBlocos(linhas);
    expect(JSON.stringify(linhas)).toBe(copia);
  });
});

describe("montarFamilias", () => {
  it("Cordas, Madeiras e Metais sempre aparecem; percentual sobre o total do bloco", () => {
    const { total, familias } = montarFamilias([
      { familia: "Cordas", qtd: 13 },
      { familia: "Madeiras", qtd: 18 },
      { familia: "Metais", qtd: 16 },
    ]);
    expect(total).toBe(47);
    expect(familias.map((f) => [f.nome, f.qtd, f.percentual])).toEqual([
      ["Cordas", 13, "27,7%"],
      ["Madeiras", 18, "38,3%"],
      ["Metais", 16, "34,0%"],
    ]);
  });

  it("sem ninguém, mostra as três com zero", () => {
    const { total, familias } = montarFamilias([]);
    expect(total).toBe(0);
    expect(familias.map((f) => f.qtd)).toEqual([0, 0, 0]);
    expect(familias[0].percentual).toBe("0,0%");
  });

  it("Teclas (acordeom) só aparece quando há alguém e entra no total", () => {
    const { total, familias } = montarFamilias([
      { familia: "Cordas", qtd: 1 },
      { familia: "Teclas", qtd: 1 },
      { familia: "Sem família", qtd: 0 },
    ]);
    expect(total).toBe(2);
    expect(familias.map((f) => f.nome)).toEqual(["Cordas", "Madeiras", "Metais", "Teclas"]);
  });
});

describe("categoria do membro", () => {
  it("só Músico e Organista usam categoria", () => {
    expect(cargoUsaCategoria("Músico")).toBe("musico");
    expect(cargoUsaCategoria("Organista")).toBe("organista");
    expect(cargoUsaCategoria("Encarregado Local")).toBeNull();
    expect(cargoUsaCategoria("Examinadora")).toBeNull();
    expect(cargoUsaCategoria(undefined)).toBeNull();
  });

  it("a organista é Oficializada (feminino) e sem valor vira 'Sem categoria'", () => {
    expect(rotuloDaCategoria("OFICIALIZADO", "musico")).toBe("Oficializado");
    expect(rotuloDaCategoria("OFICIALIZADO", "organista")).toBe("Oficializada");
    expect(rotuloDaCategoria("RJM", "musico")).toBe("RJM");
    expect(rotuloDaCategoria(null, "musico")).toBe("Sem categoria");
  });

  it("exige a categoria só para Músico e Organista", () => {
    expect(validarCategoria("Músico", "")).toMatch(/Escolha a categoria/);
    expect(validarCategoria("Organista", "")).toMatch(/Oficializada/);
    expect(validarCategoria("Músico", "RJM")).toBeNull();
    expect(validarCategoria("Ancião", "")).toBeNull();
  });
});
