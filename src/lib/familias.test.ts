import { describe, expect, it } from "vitest";
import { ehNomeDeFamilia, inferirFamilia } from "@/lib/familias";
import type { Familia } from "@/types/database";

// Mesmas famílias e palavras-chave do seed do supabase/schema.sql
const familias: Familia[] = [
  { id: "1", nome: "Cordas", palavras_chave: ["violino", "viola", "violoncelo", "cello", "contrabaixo", "harpa"] },
  {
    id: "2",
    nome: "Madeiras",
    palavras_chave: ["flauta", "flautim", "piccolo", "oboe", "corne ingles", "clarinete", "clarone", "fagote", "contrafagote", "saxofone", "sax"],
  },
  {
    id: "3",
    nome: "Metais",
    palavras_chave: ["trompete", "corneta", "flugelhorn", "flugel", "trompa", "trombone", "bombardino", "eufonio", "euphonium", "tuba", "bombardao", "sousafone", "saxhorn"],
  },
  { id: "4", nome: "Teclas", palavras_chave: ["orgao", "piano", "teclado", "acordeon", "acordeao"] },
];

describe("inferirFamilia", () => {
  it("classifica pelo nome ignorando acento e maiúsculas", () => {
    expect(inferirFamilia("Órgão", familias)?.nome).toBe("Teclas");
    expect(inferirFamilia("CLARINETE baixo", familias)?.nome).toBe("Madeiras");
  });

  it("classifica variações do mesmo instrumento", () => {
    expect(inferirFamilia("Sax Soprano", familias)?.nome).toBe("Madeiras");
    expect(inferirFamilia("Flauta transversal", familias)?.nome).toBe("Madeiras");
  });

  it("a palavra-chave mais longa vence (saxhorn é Metais, não Madeiras)", () => {
    expect(inferirFamilia("Saxhorn", familias)?.nome).toBe("Metais");
  });

  it("devolve null quando nada casa ou o texto é vazio", () => {
    expect(inferirFamilia("Zabumba", familias)).toBeNull();
    expect(inferirFamilia("  ", familias)).toBeNull();
  });
});

describe("ehNomeDeFamilia", () => {
  it("reconhece o nome de uma família", () => {
    expect(ehNomeDeFamilia("madeiras", familias)).toBe(true);
    expect(ehNomeDeFamilia(" Metais ", familias)).toBe(true);
  });

  it("não confunde instrumento com família", () => {
    expect(ehNomeDeFamilia("Clarinete", familias)).toBe(false);
    expect(ehNomeDeFamilia("", familias)).toBe(false);
  });
});
