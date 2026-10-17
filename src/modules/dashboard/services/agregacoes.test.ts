import { describe, expect, it } from "vitest";
import {
  agruparFrequencia,
  calcularFrequenciaMedia,
  contarPor,
  montarDistribuicoes,
  topComOutros,
} from "@/modules/dashboard/services/agregacoes";
import type { Cargo, Familia, Instrumento } from "@/types/database";

describe("contarPor", () => {
  it("ordena do maior para o menor e desempata por nome", () => {
    const resultado = contarPor(["b", "a", "b", "c", "a", "b"], (letra) => letra);
    expect(resultado).toEqual([
      { rotulo: "b", valor: 3 },
      { rotulo: "a", valor: 2 },
      { rotulo: "c", valor: 1 },
    ]);
  });

  it("devolve lista vazia quando não há itens", () => {
    expect(contarPor([], () => "x")).toEqual([]);
  });
});

describe("topComOutros", () => {
  const itens = [
    { rotulo: "A", valor: 5 },
    { rotulo: "B", valor: 4 },
    { rotulo: "C", valor: 2 },
    { rotulo: "D", valor: 1 },
  ];

  it("mantém os N maiores e soma o resto em 'Outros'", () => {
    expect(topComOutros(itens, 2)).toEqual([
      { rotulo: "A", valor: 5 },
      { rotulo: "B", valor: 4 },
      { rotulo: "Outros", valor: 3 },
    ]);
  });

  it("não altera a lista quando ela cabe no limite", () => {
    expect(topComOutros(itens, 4)).toEqual(itens);
  });
});

describe("montarDistribuicoes", () => {
  const cargos: Cargo[] = [
    { id: "c1", nome: "Músico", permite_instrumento: true },
    { id: "c2", nome: "Ancião", permite_instrumento: false },
  ];
  const familias: Familia[] = [{ id: "f1", nome: "Madeiras", palavras_chave: ["sax"] }];
  const instrumentos: Instrumento[] = [
    { id: "i1", nome: "Sax Soprano", familia_id: "f1" },
    { id: "i2", nome: "Zabumba", familia_id: null },
  ];
  const membros = [
    { id: "1", cargo_id: "c1", instrumento_id: "i1", congregacao: "Central", status: "Ativo" },
    { id: "2", cargo_id: "c1", instrumento_id: "i1", congregacao: "Central", status: "Ativo" },
    { id: "3", cargo_id: "c1", instrumento_id: "i2", congregacao: " ", status: "Ativo" },
    { id: "4", cargo_id: "c2", instrumento_id: null, congregacao: "Itinga", status: "Ativo" },
  ];
  const resultado = montarDistribuicoes({ membros, cargos, instrumentos, familias });

  it("conta membros por cargo", () => {
    expect(resultado.porCargo).toEqual([
      { rotulo: "Músico", valor: 3 },
      { rotulo: "Ancião", valor: 1 },
    ]);
  });

  it("conta membros por família do instrumento, separando 'Sem família' e 'Sem instrumento'", () => {
    expect(resultado.porFamilia).toEqual([
      { rotulo: "Madeiras", valor: 2 },
      { rotulo: "Sem família", valor: 1 },
      { rotulo: "Sem instrumento", valor: 1 },
    ]);
  });

  it("lista só instrumentos que têm membros", () => {
    expect(resultado.porInstrumento).toEqual([
      { rotulo: "Sax Soprano", valor: 2 },
      { rotulo: "Zabumba", valor: 1 },
    ]);
  });

  it("trata congregação vazia como 'Sem congregação'", () => {
    expect(resultado.porCongregacao.map((item) => item.rotulo)).toContain("Sem congregação");
  });
});

describe("agruparFrequencia e calcularFrequenciaMedia", () => {
  // Meio-dia em UTC mantém o mesmo dia em praticamente qualquer fuso
  const eventos = [
    { id: "e2", data_evento: "2026-10-20T12:00:00Z" }, // mais recente primeiro (como vem do banco)
    { id: "e1", data_evento: "2026-10-13T12:00:00Z" },
  ];
  const presencas = [
    { evento_id: "e1", status: "Presente" },
    { evento_id: "e1", status: "Ausente" },
    { evento_id: "e2", status: "Presente" },
    { evento_id: "e2", status: "Presente" },
    { evento_id: "e2", status: "Justificado" },
    { evento_id: "outro", status: "Presente" }, // evento fora da lista: ignorado
  ];
  const frequencia = agruparFrequencia(eventos, presencas);

  it("devolve os eventos em ordem cronológica", () => {
    expect(frequencia.map((item) => item.eventoId)).toEqual(["e1", "e2"]);
    expect(frequencia[0].rotulo).toBe("13/10");
  });

  it("conta cada status por evento", () => {
    expect(frequencia[0]).toMatchObject({ presentes: 1, ausentes: 1, justificados: 0, total: 2 });
    expect(frequencia[1]).toMatchObject({ presentes: 2, ausentes: 0, justificados: 1, total: 3 });
  });

  it("calcula a frequência média (presentes sobre o total de registros)", () => {
    expect(calcularFrequenciaMedia(frequencia)).toBe(60); // 3 presentes em 5 registros
  });

  it("devolve null quando não há registros", () => {
    expect(calcularFrequenciaMedia([])).toBeNull();
  });
});
