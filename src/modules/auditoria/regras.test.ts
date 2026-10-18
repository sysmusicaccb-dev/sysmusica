import { describe, expect, it } from "vitest";
import {
  descreverDetalhes,
  formatarValor,
  humanizar,
  intervaloDoFiltro,
  resumoAlteracoes,
  rotuloAcao,
  rotuloCampo,
  rotuloDoItem,
  rotuloEntidade,
} from "@/modules/auditoria/regras";

describe("rótulos", () => {
  it("traduz códigos conhecidos e humaniza os desconhecidos", () => {
    expect(rotuloAcao("registro_alterado")).toBe("Alterou");
    expect(rotuloAcao("acao_nova_qualquer")).toBe("Acao nova qualquer");
    expect(rotuloEntidade("membro")).toBe("Membro");
    expect(rotuloEntidade("tabela_nova")).toBe("Tabela nova");
    expect(rotuloCampo("cargo_id")).toBe("Cargo");
    expect(humanizar("a_b_c")).toBe("A b c");
  });
});

describe("formatarValor", () => {
  it("trata vazios, booleanos, datas e identificadores", () => {
    expect(formatarValor(null)).toBe("—");
    expect(formatarValor("")).toBe("—");
    expect(formatarValor(true)).toBe("Sim");
    expect(formatarValor(false)).toBe("Não");
    expect(formatarValor("2026-10-17")).toBe("17/10/2026");
    expect(formatarValor("0f8fad5b-d9cb-469f-a165-70867728950e")).toBe("0f8fad5b…");
    expect(formatarValor(7)).toBe("7");
    expect(formatarValor("texto comum")).toBe("texto comum");
  });
});

describe("descreverDetalhes", () => {
  it("mostra o antes e o depois de uma alteração", () => {
    const itens = descreverDetalhes({ mudancas: { nome: { de: "Ana", para: "Ana Maria" }, cpf: "(alterado)" } });
    expect(itens).toEqual([
      { campo: "Nome", de: "Ana", para: "Ana Maria" },
      { campo: "CPF", de: null, para: "(alterado)" },
    ]);
  });

  it("mostra só os dados preenchidos de um cadastro e de uma exclusão", () => {
    expect(descreverDetalhes({ depois: { nome: "Ana", bairro: null } })).toEqual([
      { campo: "Nome", de: null, para: "Ana" },
    ]);
    expect(descreverDetalhes({ antes: { nome: "Ana" } })).toEqual([{ campo: "Nome", de: "Ana", para: null }]);
  });

  it("lista os dados informados das ações antigas, sem o rótulo", () => {
    expect(descreverDetalhes({ rotulo: "X", motivo: "Conflito" })).toEqual([
      { campo: "Motivo", de: null, para: "Conflito" },
    ]);
  });

  it("devolve lista vazia sem detalhes", () => {
    expect(descreverDetalhes(null)).toEqual([]);
    expect(descreverDetalhes({})).toEqual([]);
  });
});

describe("resumoAlteracoes e rotuloDoItem", () => {
  it("resume em uma linha", () => {
    expect(resumoAlteracoes({ mudancas: { status: { de: "Ativo", para: "Inativo" } } })).toBe(
      "Situação: Ativo → Inativo"
    );
    expect(resumoAlteracoes(null)).toBe("");
  });

  it("junta o tipo do item ao nome do registro", () => {
    expect(rotuloDoItem({ entidade: "membro", detalhes: { rotulo: "Maria" } })).toBe("Membro · Maria");
    expect(rotuloDoItem({ entidade: "evento", detalhes: null })).toBe("Evento");
  });
});

describe("intervaloDoFiltro", () => {
  it("vai do início do primeiro dia ao início do dia seguinte ao último (Salvador)", () => {
    expect(intervaloDoFiltro("2026-10-17", "2026-10-18")).toEqual({
      inicio: "2026-10-17T00:00:00-03:00",
      fim: "2026-10-19T00:00:00-03:00",
    });
  });

  it("passa corretamente pela virada do mês e do ano", () => {
    expect(intervaloDoFiltro("", "2026-10-31").fim).toBe("2026-11-01T00:00:00-03:00");
    expect(intervaloDoFiltro("", "2026-12-31").fim).toBe("2027-01-01T00:00:00-03:00");
  });

  it("trata data vazia ou inválida como sem limite", () => {
    expect(intervaloDoFiltro("", "")).toEqual({ inicio: null, fim: null });
    expect(intervaloDoFiltro("17/10/2026", "abc")).toEqual({ inicio: null, fim: null });
  });
});
