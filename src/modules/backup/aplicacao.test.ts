import { describe, expect, it } from "vitest";
import { lerEntradaAplicacao, montarPlano, planoDaTabela, resumirOperacoes, type EntradaTabela } from "./aplicacao";
import { TABELAS, type DefinicaoTabela } from "./tabelas";

const def = (nome: string): DefinicaoTabela => {
  const achada = TABELAS.find((t) => t.nome === nome);
  if (!achada) throw new Error(`Tabela ${nome} não existe`);
  return achada;
};

describe("planoDaTabela", () => {
  const membros = def("membros");
  const backup = [
    { id: "1", nome: "Ana", excluido_em: null },
    { id: "2", nome: "Bia", excluido_em: null },
    { id: "3", nome: "Caio", excluido_em: null },
  ];
  const hoje = [
    { id: "1", nome: "Ana Maria", excluido_em: null }, // alterada
    { id: "3", nome: "Caio", excluido_em: "2026-10-19T10:00:00Z" }, // excluída depois
    { id: "4", nome: "Davi", excluido_em: null }, // nova
  ]; // "2" sumiu

  it("recuperar devolve apagados e desfaz alterações, sem tocar no que é novo", () => {
    const p = planoDaTabela({ def: membros, backup, hoje }, "recuperar");
    expect(p.inserir.map((l) => l.id)).toEqual(["2"]);
    expect(p.atualizar.map((l) => l.id)).toEqual(["1", "3"]);
    expect(p.remover).toEqual([]);
  });

  it("espelhar também remove o que é novo (só a chave primária vai no plano)", () => {
    const p = planoDaTabela({ def: membros, backup, hoje }, "espelhar");
    expect(p.remover).toEqual([{ id: "4" }]);
  });

  it("espelhar ignora o que já está excluído logicamente", () => {
    const p = planoDaTabela({ def: membros, backup: [], hoje: [{ id: "9", excluido_em: "2026-10-19T10:00:00Z" }] }, "espelhar");
    expect(p.remover).toEqual([]);
  });

  it("nunca remove usuários, nem altera tabela só de inserção", () => {
    const u = planoDaTabela({ def: def("usuarios"), backup: [], hoje: [{ id: "x" }] }, "espelhar");
    expect(u.remover).toEqual([]);
    const h = planoDaTabela({ def: def("portarias_historico"), backup: [{ id: "1", a: 1 }], hoje: [{ id: "1", a: 2 }, { id: "2", a: 1 }] }, "espelhar");
    expect(h).toEqual({ inserir: [], atualizar: [], remover: [] });
  });

  it("backup sem a tabela não gera nada", () => {
    expect(planoDaTabela({ def: membros, backup: undefined, hoje }, "espelhar")).toEqual({ inserir: [], atualizar: [], remover: [] });
  });
});

describe("montarPlano", () => {
  it("grava pais antes dos filhos e remove filhos antes dos pais", () => {
    const entradas: EntradaTabela[] = [
      { def: def("presencas"), backup: [{ id: "p1", excluido_em: null }], hoje: [{ id: "p9", excluido_em: null }] },
      { def: def("membros"), backup: [{ id: "m1", excluido_em: null }], hoje: [{ id: "m9", excluido_em: null }] },
    ];
    const ops = montarPlano(entradas, "espelhar").map((o) => `${o.acao}:${o.tabela}`);
    expect(ops).toEqual(["inserir:membros", "inserir:presencas", "excluir_logico:presencas", "excluir_logico:membros"]);
  });

  it("tabela sem exclusão lógica usa exclusão de verdade, só com a chave", () => {
    const [op] = montarPlano([{ def: def("estados"), backup: [], hoje: [{ id: "e1", nome: "BA" }] }], "espelhar");
    expect(op).toMatchObject({ acao: "excluir", colunas: ["id"], linhas: [{ id: "e1" }] });
  });

  it("sem diferença não há operações", () => {
    const l = [{ id: "1", nome: "BA" }];
    expect(montarPlano([{ def: def("estados"), backup: l, hoje: [...l] }], "espelhar")).toEqual([]);
  });
});

describe("lerEntradaAplicacao", () => {
  const validos = ["membros", "eventos"];
  const base = { id: "x", grupos: ["membros"], modo: "recuperar", senha: "abc" };
  it("aceita recuperar com senha", () => {
    expect(lerEntradaAplicacao(base, validos)).toMatchObject({ id: "x", modo: "recuperar", grupos: ["membros"] });
  });
  it("espelhar exige digitar ESPELHAR", () => {
    expect(lerEntradaAplicacao({ ...base, modo: "espelhar" }, validos)).toBeNull();
    expect(lerEntradaAplicacao({ ...base, modo: "espelhar", confirmacao: "espelhar" }, validos)).toBeNull();
    expect(lerEntradaAplicacao({ ...base, modo: "espelhar", confirmacao: "ESPELHAR" }, validos)).not.toBeNull();
  });
  it("recusa senha vazia, modo ou grupo desconhecido", () => {
    expect(lerEntradaAplicacao({ ...base, senha: "" }, validos)).toBeNull();
    expect(lerEntradaAplicacao({ ...base, modo: "apagar" }, validos)).toBeNull();
    expect(lerEntradaAplicacao({ ...base, grupos: ["tudo"] }, validos)).toBeNull();
    expect(lerEntradaAplicacao(null, validos)).toBeNull();
  });
});

describe("resumirOperacoes", () => {
  it("resume só o que mudou", () => {
    const txt = resumirOperacoes(
      [
        { tabela: "instrumentos", acao: "inserir", afetados: 1, ignorados: 0 },
        { tabela: "membros", acao: "atualizar", afetados: 0, ignorados: 0 },
      ],
      { instrumentos: "Instrumentos" }
    );
    expect(txt).toBe("Instrumentos: 1 devolvidos");
    expect(resumirOperacoes([], {})).toBe("nenhum registro precisou mudar");
  });
});
