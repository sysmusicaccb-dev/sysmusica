import { describe, expect, it } from "vitest";
import { compararTabela, lerEntradaComparacao, rotuloDaLinha, somarTotais } from "./restauracao";
import { TABELAS, type DefinicaoTabela } from "./tabelas";

const def = (nome: string): DefinicaoTabela => {
  const achada = TABELAS.find((t) => t.nome === nome);
  if (!achada) throw new Error(`Tabela ${nome} não existe`);
  return achada;
};
const membros = def("membros");

describe("compararTabela", () => {
  it("sem diferença não aponta nada", () => {
    const linhas = [{ id: "1", nome: "Ana", excluido_em: null }];
    const r = compararTabela(membros, linhas, [...linhas]);
    expect([r.apagados, r.alterados, r.novos]).toEqual([0, 0, 0]);
  });

  it("separa apagados, alterados e novos", () => {
    const backup = [
      { id: "1", nome: "Ana", excluido_em: null },
      { id: "2", nome: "Bia", excluido_em: null },
      { id: "3", nome: "Caio", excluido_em: null },
    ];
    const hoje = [
      { id: "1", nome: "Ana Maria", excluido_em: null }, // alterado
      { id: "3", nome: "Caio", excluido_em: null }, // igual
      { id: "4", nome: "Davi", excluido_em: null }, // novo
    ]; // "2" sumiu: apagado
    const r = compararTabela(membros, backup, hoje);
    expect([r.apagados, r.alterados, r.novos]).toEqual([1, 1, 1]);
    expect(r.amostraApagados[0]).toMatchObject({ chave: "2", rotulo: "Bia" });
    expect(r.amostraAlterados[0].colunas).toEqual([{ coluna: "nome", antes: "Ana", depois: "Ana Maria" }]);
    expect(r.amostraNovos[0]).toMatchObject({ chave: "4", rotulo: "Davi" });
  });

  it("exclusão lógica depois do backup conta como apagado, não como alterado", () => {
    const backup = [{ id: "1", nome: "Ana", excluido_em: null }];
    const hoje = [{ id: "1", nome: "Ana", excluido_em: "2026-10-19T10:00:00Z" }];
    const r = compararTabela(membros, backup, hoje);
    expect([r.apagados, r.alterados]).toEqual([1, 0]);
    expect(r.amostraApagados[0].detalhe).toMatch(/excluído depois/);
  });

  it("registro criado e já excluído depois do backup é ignorado", () => {
    const r = compararTabela(membros, [], [{ id: "9", nome: "X", excluido_em: "2026-10-19T10:00:00Z" }]);
    expect(r.novos).toBe(0);
  });

  it("nunca mostra colunas sensíveis", () => {
    const backup = [{ id: "1", nome: "Ana", cpf: "11122233344", qr_secret: "abc", excluido_em: null }];
    const hoje = [{ id: "1", nome: "Ana", cpf: "99988877766", qr_secret: "xyz", excluido_em: null }];
    const r = compararTabela(membros, backup, hoje);
    const texto = JSON.stringify(r);
    expect(texto).not.toContain("11122233344");
    expect(texto).not.toContain("99988877766");
    expect(texto).not.toContain("xyz");
    expect(r.amostraAlterados[0].colunas?.every((c) => c.antes === "(protegido)" && c.depois === "(protegido)")).toBe(true);
  });

  it("o rótulo nunca usa uma coluna sensível", () => {
    expect(rotuloDaLinha({ ...membros, sensiveis: ["nome"] }, { id: "7", nome: "Segredo" })).toBe("7");
  });

  it("objetos iguais com chaves em outra ordem não contam como alteração", () => {
    const r = compararTabela(membros, [{ id: "1", extra: { a: 1, b: 2 } }], [{ id: "1", extra: { b: 2, a: 1 } }]);
    expect(r.alterados).toBe(0);
  });

  it("chave composta e tabela ausente no backup", () => {
    const perm = def("grupo_permissoes");
    const r = compararTabela(perm, [{ grupo_id: "g", permissao_codigo: "a" }, { grupo_id: "g", permissao_codigo: "b" }], [{ grupo_id: "g", permissao_codigo: "a" }]);
    expect(r.apagados).toBe(1);
    const ausente = compararTabela(perm, undefined, [{ grupo_id: "g", permissao_codigo: "a" }]);
    expect(ausente).toMatchObject({ ausente: true, apagados: 0, alterados: 0, novos: 0, hoje: 1 });
  });

  it("limita a amostra mas conta tudo", () => {
    const muitos = Array.from({ length: 250 }, (_, i) => ({ id: String(i), nome: `m${i}`, excluido_em: null }));
    const r = compararTabela(membros, muitos, []);
    expect(r.apagados).toBe(250);
    expect(r.amostraApagados).toHaveLength(100);
  });

  it("soma os totais", () => {
    const a = compararTabela(membros, [{ id: "1" }], []);
    const b = compararTabela(membros, [], [{ id: "2", excluido_em: null }]);
    expect(somarTotais([a, b])).toEqual({ apagados: 1, alterados: 0, novos: 1 });
  });
});

describe("lerEntradaComparacao", () => {
  const validos = ["membros", "usuarios"];
  it("aceita só grupos conhecidos, sem repetir", () => {
    expect(lerEntradaComparacao({ id: "x", grupos: ["membros", "membros", "usuarios"] }, validos)).toEqual({ id: "x", grupos: ["membros", "usuarios"] });
    expect(lerEntradaComparacao({ id: "x", grupos: ["tudo"] }, validos)).toBeNull();
    expect(lerEntradaComparacao({ id: "x", grupos: [] }, validos)).toBeNull();
    expect(lerEntradaComparacao({ id: 5, grupos: ["membros"] }, validos)).toBeNull();
    expect(lerEntradaComparacao(null, validos)).toBeNull();
  });
});
