import { describe, expect, it } from "vitest";
import {
  chaveDaLinha,
  GRUPOS_DADOS,
  ordenarParaApagar,
  ordenarParaGravar,
  tabelaPorNome,
  TABELAS,
  tabelasDoGrupo,
} from "@/modules/backup/tabelas";

describe("TABELAS", () => {
  it("não repete nomes e todas têm chave primária", () => {
    const nomes = TABELAS.map((item) => item.nome);
    expect(new Set(nomes).size).toBe(nomes.length);
    for (const item of TABELAS) expect(item.pk.length).toBeGreaterThan(0);
  });

  it("toda referência aponta para uma tabela que vem ANTES (pais primeiro)", () => {
    TABELAS.forEach((item, indice) => {
      for (const referencia of item.referencias) {
        const indicePai = TABELAS.findIndex((outra) => outra.nome === referencia.tabela);
        expect(indicePai, `${item.nome}.${referencia.coluna}`).toBeGreaterThanOrEqual(0);
        expect(indicePai, `${item.nome}.${referencia.coluna}`).toBeLessThan(indice);
      }
    });
  });

  it("protege o CPF e o QR Code dos membros", () => {
    expect(tabelaPorNome("membros").sensiveis).toEqual(["cpf", "cpf_mascarado", "qr_secret"]);
  });
});

describe("GRUPOS_DADOS", () => {
  it("cobrem todas as tabelas, cada uma em um único grupo, e batem com o grupo da própria tabela", () => {
    const todas = GRUPOS_DADOS.flatMap((grupo) => grupo.tabelas);
    expect(new Set(todas).size).toBe(todas.length);
    expect([...todas].sort()).toEqual(TABELAS.map((item) => item.nome).sort());
    for (const grupo of GRUPOS_DADOS) {
      for (const nome of grupo.tabelas) expect(tabelaPorNome(nome).grupo).toBe(grupo.id);
    }
  });

  it("tabelasDoGrupo devolve as tabelas na ordem de dependência", () => {
    expect(tabelasDoGrupo("usuarios").map((item) => item.nome)).toEqual([
      "usuarios",
      "usuario_grupos",
      "usuario_vinculos",
      "usuario_cidades",
      "usuario_preferencias",
    ]);
  });
});

describe("ordenação", () => {
  it("grava os pais primeiro, apaga os filhos primeiro e remove repetidas", () => {
    expect(ordenarParaGravar(["presencas", "membros", "casas_oracao", "membros"])).toEqual(["casas_oracao", "membros", "presencas"]);
    expect(ordenarParaApagar(["presencas", "membros", "casas_oracao"])).toEqual(["presencas", "membros", "casas_oracao"]);
  });

  it("não altera a lista original", () => {
    const original = ["presencas", "estados"] as const;
    ordenarParaGravar([...original]);
    expect(original).toEqual(["presencas", "estados"]);
  });
});

describe("chaveDaLinha e tabelaPorNome", () => {
  it("usa a chave primária (simples ou composta)", () => {
    expect(chaveDaLinha(tabelaPorNome("membros"), { id: "m1", nome: "Ana" })).toBe("m1");
    expect(chaveDaLinha(tabelaPorNome("grupo_permissoes"), { grupo_id: "g1", permissao_codigo: "x.y" })).toBe("g1|x.y");
  });

  it("falha com clareza para uma tabela desconhecida", () => {
    expect(() => tabelaPorNome("inexistente" as never)).toThrow(/desconhecida/);
  });
});
