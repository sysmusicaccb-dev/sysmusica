import { describe, expect, it } from "vitest";
import {
  agruparCasasOracaoParaSelecao,
  agruparDestinosTransferencia,
  ancestraisDe,
  chaveVinculo,
  filhosDe,
  filhosDoNo,
  lerChaveVinculo,
  motivoBloqueioExclusao,
  rotulosPorUsuario,
  validarNomeNo,
} from "@/modules/organizacao/regras";
import type { NoOrganizacao } from "@/modules/organizacao/tipos";

// Bahia
//  ├─ RRM Vitória da Conquista › RA Jequié › ADM Ipiaú ─ Setor 1 (Central) · casa "Solta" direto na ADM
//  └─ RRM Salvador › RA Salvador › ADM Centro ─ Setor 1 (Itinga, Caique) · Setor 2 · Setor 10 (inativo) · ADM Norte (inativa)
const nos: NoOrganizacao[] = [
  { nivel: "ESTADO", id: "e1", parent_id: null, nome: "Bahia", ativo: true },
  { nivel: "RRM", id: "m1", parent_id: "e1", nome: "Vitória da Conquista", ativo: true },
  { nivel: "RRM", id: "m2", parent_id: "e1", nome: "Salvador", ativo: true },
  { nivel: "RA", id: "r1", parent_id: "m1", nome: "Jequié", ativo: true },
  { nivel: "RA", id: "r2", parent_id: "m2", nome: "Salvador", ativo: true },
  { nivel: "ADM", id: "a1", parent_id: "r1", nome: "Ipiaú", ativo: true },
  { nivel: "ADM", id: "a2", parent_id: "r2", nome: "Centro", ativo: true },
  { nivel: "ADM", id: "a3", parent_id: "r2", nome: "Norte", ativo: false },
  { nivel: "SETOR", id: "s1", parent_id: "a1", nome: "Setor 1", ativo: true },
  { nivel: "SETOR", id: "s2", parent_id: "a2", nome: "Setor 1", ativo: true },
  { nivel: "SETOR", id: "s3", parent_id: "a2", nome: "Setor 10", ativo: false },
  { nivel: "SETOR", id: "s4", parent_id: "a2", nome: "Setor 2", ativo: true },
  { nivel: "CASA_ORACAO", id: "c1", parent_id: "s2", nome: "Itinga" },
  { nivel: "CASA_ORACAO", id: "c2", parent_id: "s2", nome: "Caique" },
  { nivel: "CASA_ORACAO", id: "c3", parent_id: "s1", nome: "Central" },
  { nivel: "CASA_ORACAO", id: "c4", parent_id: "a1", nome: "Solta" }, // direto na ADM, sem setor
];

describe("filhosDe e filhosDoNo", () => {
  it("traz só os itens do pai informado, em ordem natural", () => {
    expect(filhosDe(nos, "a2", "SETOR").map((n) => n.nome)).toEqual(["Setor 1", "Setor 2", "Setor 10"]);
  });

  it("separa 'Setor 1' de ADMs diferentes", () => {
    expect(filhosDe(nos, "a1", "SETOR").map((n) => n.id)).toEqual(["s1"]);
    expect(filhosDe(nos, "a2", "SETOR").map((n) => n.id)).not.toContain("s1");
  });

  it("a ADM tem setores E casas de oração diretas (setores primeiro)", () => {
    expect(filhosDoNo(nos, nos.find((n) => n.id === "a1")!).map((n) => `${n.nivel}:${n.nome}`)).toEqual([
      "SETOR:Setor 1",
      "CASA_ORACAO:Solta",
    ]);
  });

  it("cada nível desce para o seguinte", () => {
    expect(filhosDoNo(nos, nos[0]).map((n) => n.nome)).toEqual(["Salvador", "Vitória da Conquista"]);
    expect(filhosDoNo(nos, nos.find((n) => n.id === "m1")!).map((n) => n.nome)).toEqual(["Jequié"]);
    expect(filhosDoNo(nos, nos.find((n) => n.id === "c1")!)).toEqual([]);
  });
});

describe("ancestraisDe", () => {
  it("devolve o caminho do estado até o pai", () => {
    const casa = nos.find((n) => n.id === "c3")!;
    expect(ancestraisDe(nos, casa).map((n) => n.nome)).toEqual(["Bahia", "Vitória da Conquista", "Jequié", "Ipiaú", "Setor 1"]);
  });

  it("para uma casa sem setor o último é a ADM", () => {
    const casa = nos.find((n) => n.id === "c4")!;
    expect(ancestraisDe(nos, casa).at(-1)?.nome).toBe("Ipiaú");
  });

  it("não quebra quando o pai não está na lista", () => {
    expect(ancestraisDe(nos, { nivel: "CASA_ORACAO", id: "x", parent_id: "inexistente", nome: "Órfã" })).toEqual([]);
  });
});

describe("agruparCasasOracaoParaSelecao", () => {
  const grupos = agruparCasasOracaoParaSelecao(nos);

  it("agrupa por RA › ADM › Setor e mostra a ADM sozinha para casas sem setor", () => {
    expect(grupos.map((g) => g.rotulo)).toEqual([
      "Jequié › Ipiaú",
      "Jequié › Ipiaú › Setor 1",
      "Salvador › Centro › Setor 1",
    ]);
    expect(grupos[0].casasOracao.map((c) => c.nome)).toEqual(["Solta"]);
  });

  it("ordena as casas de oração de cada grupo pelo nome", () => {
    expect(grupos[2].casasOracao.map((c) => c.nome)).toEqual(["Caique", "Itinga"]);
  });

  it("casa cujo caminho não está na lista vai para 'Sem local definido', no fim", () => {
    const comOrfa = agruparCasasOracaoParaSelecao([...nos, { nivel: "CASA_ORACAO", id: "c9", parent_id: null, nome: "Órfã" }]);
    expect(comOrfa.at(-1)).toMatchObject({ rotulo: "Sem local definido" });
    expect(comOrfa.at(-1)?.casasOracao.map((c) => c.nome)).toEqual(["Órfã"]);
  });

  it("coloca o estado na frente quando há mais de um estado", () => {
    const maisUm = agruparCasasOracaoParaSelecao([...nos, { nivel: "ESTADO", id: "e2", parent_id: null, nome: "Sergipe" }]);
    expect(maisUm[0].rotulo).toBe("Bahia › Jequié › Ipiaú");
  });
});

describe("agruparDestinosTransferencia", () => {
  const grupos = agruparDestinosTransferencia(nos);

  it("lista cada ADM ativa com 'sem setor' e os setores ativos, ignorando ADM e setor inativos", () => {
    expect(grupos.map((g) => g.rotulo)).toEqual(["Jequié › Ipiaú", "Salvador › Centro"]);
    expect(grupos[1].opcoes.map((o) => `${o.nivel}:${o.nome}`)).toEqual([
      "ADM:Sem setor (direto na ADM)",
      "SETOR:Setor 1",
      "SETOR:Setor 2",
    ]);
  });

  it("a opção 'sem setor' leva o id da ADM e as demais o id do setor", () => {
    expect(grupos[0].opcoes.map((o) => o.id)).toEqual(["a1", "s1"]);
  });

  it("ADM de uma RA inativa não é oferecida", () => {
    const semRa = nos.map((n) => (n.id === "r1" ? { ...n, ativo: false } : n));
    expect(agruparDestinosTransferencia(semRa).map((g) => g.rotulo)).toEqual(["Salvador › Centro"]);
  });
});

describe("vínculos", () => {
  it("monta e desfaz a chave de um vínculo (todos os níveis)", () => {
    for (const nivel of ["ESTADO", "RRM", "RA", "ADM", "SETOR", "CASA_ORACAO"] as const) {
      const chave = chaveVinculo(nivel, "abc-123");
      expect(chave).toBe(`${nivel}:abc-123`);
      expect(lerChaveVinculo(chave)).toEqual({ nivel, alvo_id: "abc-123" });
    }
  });

  it("recusa chaves malformadas e o nível antigo REGIAO", () => {
    expect(lerChaveVinculo("sem-separador")).toBeNull();
    expect(lerChaveVinculo("OUTRO:abc")).toBeNull();
    expect(lerChaveVinculo("REGIAO:abc")).toBeNull();
    expect(lerChaveVinculo("SETOR:")).toBeNull();
  });

  it("lista só os rótulos por usuário", () => {
    expect(
      rotulosPorUsuario({ u1: [{ nivel: "ADM", alvo_id: "a1", rotulo: "Jequié › Ipiaú" }], u2: [] })
    ).toEqual({ u1: ["Jequié › Ipiaú"], u2: [] });
  });
});

describe("motivoBloqueioExclusao", () => {
  const base = { parent_id: null, ativo: true };

  it("bloqueia o item que ainda tem itens dentro e explica o motivo, em cada nível", () => {
    expect(motivoBloqueioExclusao({ ...base, nivel: "ESTADO", id: "e", nome: "Bahia", qtd_filhos: 2 })).toMatch(/2 RRMs/);
    expect(motivoBloqueioExclusao({ ...base, nivel: "RRM", id: "m", nome: "Salvador", qtd_filhos: 1 })).toMatch(/1 RA\b/);
    expect(motivoBloqueioExclusao({ ...base, nivel: "RA", id: "r", nome: "Jequié", qtd_filhos: 3 })).toMatch(/3 ADMs/);
    expect(motivoBloqueioExclusao({ ...base, nivel: "ADM", id: "a", nome: "Ipiaú", qtd_filhos: 4 })).toMatch(/4 itens/);
    expect(motivoBloqueioExclusao({ ...base, nivel: "SETOR", id: "s", nome: "Setor 1", qtd_filhos: 3 })).toMatch(/3 casas de oração/);
    expect(motivoBloqueioExclusao({ ...base, nivel: "CASA_ORACAO", id: "c", nome: "Itinga", qtd_membros: 4 })).toMatch(/4 membros/);
  });

  it("libera o item vazio", () => {
    expect(motivoBloqueioExclusao({ ...base, nivel: "ADM", id: "a", nome: "Vazia", qtd_filhos: 0 })).toBeNull();
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
