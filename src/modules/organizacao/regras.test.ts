import { describe, expect, it } from "vitest";
import {
  agruparCasasOracaoParaSelecao,
  agruparSetoresParaSelecao,
  chaveVinculo,
  filhosDe,
  lerChaveVinculo,
  motivoBloqueioExclusao,
  rotulosPorUsuario,
  validarNomeNo,
} from "@/modules/organizacao/regras";
import type { NoOrganizacao } from "@/modules/organizacao/tipos";

// Bahia > Salvador (Setor 1, Setor 2, Setor 10) e Jequié (Setor 1, Setor 9 inativo); duas casas de oração em
// Salvador/Setor 1, uma em Jequié/Setor 1 e uma sem setor
const nos: NoOrganizacao[] = [
  { nivel: "ESTADO", id: "e1", parent_id: null, nome: "Bahia", ativo: true },
  { nivel: "REGIAO", id: "r1", parent_id: "e1", nome: "Salvador", ativo: true },
  { nivel: "REGIAO", id: "r2", parent_id: "e1", nome: "Jequié", ativo: true },
  { nivel: "SETOR", id: "s1", parent_id: "r1", nome: "Setor 1", ativo: true },
  { nivel: "SETOR", id: "s2", parent_id: "r1", nome: "Setor 10", ativo: true },
  { nivel: "SETOR", id: "s3", parent_id: "r1", nome: "Setor 2", ativo: true },
  { nivel: "SETOR", id: "s4", parent_id: "r2", nome: "Setor 1", ativo: true },
  { nivel: "SETOR", id: "s5", parent_id: "r2", nome: "Setor 9", ativo: false },
  { nivel: "CASA_ORACAO", id: "c1", parent_id: "s1", nome: "Itinga" },
  { nivel: "CASA_ORACAO", id: "c2", parent_id: "s1", nome: "Caique" },
  { nivel: "CASA_ORACAO", id: "c3", parent_id: "s4", nome: "Central" },
  { nivel: "CASA_ORACAO", id: "c4", parent_id: null, nome: "Solta" },
];

describe("filhosDe", () => {
  it("traz só os itens do pai informado, em ordem natural", () => {
    expect(filhosDe(nos, "r1", "SETOR").map((n) => n.nome)).toEqual(["Setor 1", "Setor 2", "Setor 10"]);
  });

  it("separa 'Setor 1' de regiões diferentes", () => {
    expect(filhosDe(nos, "r2", "SETOR").map((n) => n.id)).toEqual(["s4", "s5"]);
    expect(filhosDe(nos, "r1", "SETOR").map((n) => n.id)).not.toContain("s4");
  });

  it("devolve as casas de oração sem setor quando o pai é nulo", () => {
    expect(filhosDe(nos, null, "CASA_ORACAO").map((n) => n.id)).toEqual(["c4"]);
  });
});

describe("agruparCasasOracaoParaSelecao", () => {
  const grupos = agruparCasasOracaoParaSelecao(nos);

  it("agrupa por Região › Setor e deixa 'sem setor' por último", () => {
    expect(grupos.map((g) => g.rotulo)).toEqual([
      "Jequié › Setor 1",
      "Salvador › Setor 1",
      "Sem setor definido",
    ]);
  });

  it("ordena as casas de oração de cada grupo pelo nome", () => {
    expect(grupos[1].casasOracao.map((c) => c.nome)).toEqual(["Caique", "Itinga"]);
  });
});

describe("agruparSetoresParaSelecao", () => {
  it("agrupa os setores ativos por região e ignora os inativos", () => {
    const grupos = agruparSetoresParaSelecao(nos);
    expect(grupos.map((g) => g.rotulo)).toEqual(["Jequié", "Salvador"]);
    expect(grupos[0].setores.map((s) => s.id)).toEqual(["s4"]);
  });
});

describe("vínculos", () => {
  it("monta e desfaz a chave de um vínculo", () => {
    const chave = chaveVinculo("SETOR", "abc-123");
    expect(chave).toBe("SETOR:abc-123");
    expect(lerChaveVinculo(chave)).toEqual({ nivel: "SETOR", alvo_id: "abc-123" });
  });

  it("recusa chaves malformadas", () => {
    expect(lerChaveVinculo("sem-separador")).toBeNull();
    expect(lerChaveVinculo("OUTRO:abc")).toBeNull();
    expect(lerChaveVinculo("SETOR:")).toBeNull();
  });

  it("lista só os rótulos por usuário", () => {
    expect(
      rotulosPorUsuario({ u1: [{ nivel: "SETOR", alvo_id: "s1", rotulo: "Salvador › Setor 1" }], u2: [] })
    ).toEqual({ u1: ["Salvador › Setor 1"], u2: [] });
  });
});

describe("motivoBloqueioExclusao", () => {
  const base = { parent_id: null, ativo: true };

  it("bloqueia o item que ainda tem itens dentro e explica o motivo", () => {
    expect(motivoBloqueioExclusao({ ...base, nivel: "ESTADO", id: "e", nome: "Bahia", qtd_filhos: 2 })).toMatch(/2 regiões/);
    expect(motivoBloqueioExclusao({ ...base, nivel: "REGIAO", id: "r", nome: "Salvador", qtd_filhos: 1 })).toMatch(/1 setor\b/);
    expect(motivoBloqueioExclusao({ ...base, nivel: "SETOR", id: "s", nome: "Setor 1", qtd_filhos: 3 })).toMatch(/3 casas de oração/);
    expect(motivoBloqueioExclusao({ ...base, nivel: "CASA_ORACAO", id: "c", nome: "Itinga", qtd_membros: 4 })).toMatch(/4 membros/);
  });

  it("libera o item vazio", () => {
    expect(motivoBloqueioExclusao({ ...base, nivel: "SETOR", id: "s", nome: "Setor 9", qtd_filhos: 0 })).toBeNull();
    expect(motivoBloqueioExclusao({ ...base, nivel: "CASA_ORACAO", id: "c", nome: "Vazia", qtd_membros: 0 })).toBeNull();
  });
});

describe("validarNomeNo", () => {
  it("exige de 2 a 80 caracteres", () => {
    expect(validarNomeNo("A")).toMatch(/entre 2 e 80/);
    expect(validarNomeNo("  Setor 1  ")).toBeNull();
    expect(validarNomeNo("x".repeat(81))).toMatch(/entre 2 e 80/);
  });
});
