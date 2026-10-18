import { describe, expect, it } from "vitest";
import {
  agruparInstrumentosPorFamilia,
  nomeDaFamiliaDoInstrumento,
  validarInstrumentoDoCargo,
} from "@/modules/instrumentos/selecao";

const familias = [
  { id: "f-metais", nome: "Metais" },
  { id: "f-cordas", nome: "Cordas" },
  { id: "f-madeiras", nome: "Madeiras" },
  { id: "f-vazia", nome: "Teclas" },
];

const instrumentos = [
  { id: "i1", nome: "Trombone", familia_id: "f-metais" },
  { id: "i2", nome: "Clarinete", familia_id: "f-madeiras" },
  { id: "i3", nome: "Violino", familia_id: "f-cordas" },
  { id: "i4", nome: "Oboé", familia_id: "f-madeiras" },
  { id: "i5", nome: "Instrumento solto", familia_id: null },
  { id: "i6", nome: "Familia apagada", familia_id: "f-inexistente" },
];

describe("agruparInstrumentosPorFamilia", () => {
  const grupos = agruparInstrumentosPorFamilia(instrumentos, familias);

  it("ordena as famílias pelo nome, ignora família sem instrumento e deixa 'sem família' por último", () => {
    expect(grupos.map((grupo) => grupo.rotulo)).toEqual(["Cordas", "Madeiras", "Metais", "Sem família definida"]);
  });

  it("ordena os instrumentos de cada grupo pelo nome", () => {
    expect(grupos[1].instrumentos.map((item) => item.nome)).toEqual(["Clarinete", "Oboé"]);
  });

  it("junta no fim os sem família e os de família que não existe mais", () => {
    expect(grupos[3].instrumentos.map((item) => item.id)).toEqual(["i6", "i5"]);
  });

  it("não altera as listas originais", () => {
    agruparInstrumentosPorFamilia(instrumentos, familias);
    expect(instrumentos[0].nome).toBe("Trombone");
    expect(familias[0].nome).toBe("Metais");
  });
});

describe("nomeDaFamiliaDoInstrumento", () => {
  it("devolve a família do instrumento escolhido", () => {
    expect(nomeDaFamiliaDoInstrumento("i2", instrumentos, familias)).toBe("Madeiras");
  });

  it("devolve nulo sem instrumento, sem família ou com família desconhecida", () => {
    expect(nomeDaFamiliaDoInstrumento("", instrumentos, familias)).toBeNull();
    expect(nomeDaFamiliaDoInstrumento("i5", instrumentos, familias)).toBeNull();
    expect(nomeDaFamiliaDoInstrumento("i6", instrumentos, familias)).toBeNull();
  });
});

describe("validarInstrumentoDoCargo", () => {
  it("exige o instrumento quando o cargo exige", () => {
    expect(validarInstrumentoDoCargo(true, "", "Músico")).toBe(
      "O cargo Músico exige o instrumento. Escolha o instrumento na lista."
    );
  });

  it("aceita quando o instrumento foi escolhido ou o cargo não exige", () => {
    expect(validarInstrumentoDoCargo(true, "i1", "Músico")).toBeNull();
    expect(validarInstrumentoDoCargo(false, "", "Ancião")).toBeNull();
  });
});
