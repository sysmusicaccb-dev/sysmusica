import { describe, expect, it } from "vitest";
import { escolherDesenho } from "./ilustracoes";

describe("ilustração do instrumento", () => {
  it("escolhe o desenho pelo nome (instrumentos da CCB)", () => {
    const casos: [string, string][] = [
      ["Clarinete", "clarinete"],
      ["Clarinete Alto (Clarone)", "clarone"],
      ["Clarinete Baixo (Clarone)", "clarone"],
      ["Flauta Transversal", "flauta"],
      ["Oboé", "oboe"],
      ["Saxofone Alto", "sax"],
      ["Saxofone Tenor", "sax"],
      ["Saxofone Barítono", "sax"],
      ["Saxofone Soprano Curvo", "sax_curvo"],
      ["Saxofone Soprano Reto", "sax_reto"],
      ["Bombardino", "bombardino"],
      ["Flugelhorn", "flugelhorn"],
      ["Trombone", "trombone"],
      ["Trompete", "trompete"],
      ["Tuba Sinfônica", "tuba"],
      ["Acordeon", "acordeon"],
      ["Orgão Eletrônico", "orgao"],
    ];
    for (const [nome, esperado] of casos) expect(escolherDesenho(nome), nome).toBe(esperado);
  });

  it("ignora acento, maiúsculas e espaços extras", () => {
    expect(escolherDesenho("  ORGÃO   eletrônico ")).toBe("orgao");
    expect(escolherDesenho("OBOE")).toBe("oboe");
    expect(escolherDesenho("acordeão")).toBe("acordeon");
  });

  it("instrumento sem desenho próprio usa o da família", () => {
    expect(escolherDesenho("Fagote", "Madeiras")).toBe("clarinete");
    expect(escolherDesenho("Trompa", "Metais")).toBe("trompete");
    expect(escolherDesenho("Harpa", "Cordas")).toBe("violino");
    expect(escolherDesenho("Melódica", "Teclas")).toBe("orgao");
  });

  it("sem nome conhecido e sem família, usa a nota musical", () => {
    expect(escolherDesenho("Pandeiro")).toBe("nota");
    expect(escolherDesenho("Pandeiro", null)).toBe("nota");
    expect(escolherDesenho("", "")).toBe("nota");
  });
});
