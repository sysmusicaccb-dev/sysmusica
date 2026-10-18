import { describe, expect, it } from "vitest";
import { DEFINICOES_RELATORIO } from "@/modules/relatorios/catalogo";
import {
  colunasEscolhidas,
  colunasVisiveis,
  contarPor,
  FILTROS_VAZIOS,
  linhasCargos,
  linhasInstrumentos,
  linhasOrganizacao,
  linhasPortarias,
  marcadasIniciais,
  montarTabela,
  moverColuna,
  nomeDoArquivo,
  opcoesComum,
  opcoesRegiao,
  opcoesSetor,
  resumoFiltros,
  tiposDisponiveis,
  validarAjusteManual,
  validarFiltros,
} from "@/modules/relatorios/regras";
import type { NoOrganizacao } from "@/modules/organizacao/tipos";
import type { PortariaDetalhada } from "@/modules/portarias/tipos";

const definicao = (id: string) => {
  const encontrada = DEFINICOES_RELATORIO.find((item) => item.id === id);
  if (!encontrada) throw new Error(`definição ${id} não existe`);
  return encontrada;
};

describe("tiposDisponiveis e colunasVisiveis", () => {
  it("mostra só os tipos que o usuário tem permissão de ver", () => {
    const ids = tiposDisponiveis(DEFINICOES_RELATORIO, (p) => p === "membros.visualizar").map((d) => d.id);
    expect(ids).toEqual(["membros", "cargos"]);
  });

  it("esconde a coluna de CPF de quem não tem a permissão de CPF", () => {
    const membros = definicao("membros");
    expect(colunasVisiveis(membros, () => false).some((c) => c.id === "cpf_parcial")).toBe(false);
    expect(colunasVisiveis(membros, (p) => p === "membros.cpf").some((c) => c.id === "cpf_parcial")).toBe(true);
  });

  it("marca de início só as colunas padrão", () => {
    const marcadas = marcadasIniciais(definicao("presenca").colunas);
    expect(marcadas.has("membro")).toBe(true);
    expect(marcadas.has("registrado_por")).toBe(false);
  });
});

describe("moverColuna e colunasEscolhidas", () => {
  it("move uma posição e não passa das pontas", () => {
    expect(moverColuna(["a", "b", "c"], "b", -1)).toEqual(["b", "a", "c"]);
    expect(moverColuna(["a", "b", "c"], "b", 1)).toEqual(["a", "c", "b"]);
    expect(moverColuna(["a", "b", "c"], "a", -1)).toEqual(["a", "b", "c"]);
    expect(moverColuna(["a", "b", "c"], "c", 1)).toEqual(["a", "b", "c"]);
  });

  it("não altera a lista original", () => {
    const original = ["a", "b"];
    moverColuna(original, "a", 1);
    expect(original).toEqual(["a", "b"]);
  });

  it("devolve as marcadas na ordem escolhida", () => {
    expect(colunasEscolhidas(["c", "a", "b"], new Set(["a", "c"]))).toEqual(["c", "a"]);
  });
});

describe("montarTabela", () => {
  it("usa os rótulos, numera sozinho e completa valores ausentes", () => {
    const tabela = montarTabela(definicao("cargos"), ["numero", "cargo", "membros"], [
      { cargo: "Músico", membros: "5" },
      { cargo: "Ancião" },
    ]);
    expect(tabela.colunas).toEqual(["Nº", "Cargo", "Membros"]);
    expect(tabela.linhas).toEqual([
      ["1", "Músico", "5"],
      ["2", "Ancião", ""],
    ]);
  });
});

describe("validarAjusteManual", () => {
  it("aceita zoom e letra dentro dos limites (aceita vírgula)", () => {
    expect(validarAjusteManual("85", "8,5")).toBeNull();
  });

  it("recusa zoom ou letra fora dos limites ou vazios", () => {
    expect(validarAjusteManual("10", "9")).toMatch(/zoom/);
    expect(validarAjusteManual("100", "40")).toMatch(/letra/);
    expect(validarAjusteManual("", "9")).toMatch(/zoom/);
    expect(validarAjusteManual("100", "abc")).toMatch(/letra/);
  });
});

describe("nomeDoArquivo e validarFiltros", () => {
  it("tira acentos e símbolos do nome do arquivo", () => {
    expect(nomeDoArquivo("Presença por evento", "2026-10-18")).toBe("presenca-por-evento-2026-10-18");
    expect(nomeDoArquivo("***", "2026-10-18")).toBe("relatorio-2026-10-18");
  });

  it("recusa período invertido", () => {
    const presenca = definicao("presenca");
    expect(validarFiltros(presenca, { ...FILTROS_VAZIOS, inicio: "2026-10-20", fim: "2026-10-18" })).toMatch(
      /data inicial/
    );
    expect(validarFiltros(presenca, { ...FILTROS_VAZIOS, inicio: "2026-10-18", fim: "2026-10-20" })).toBeNull();
  });
});

describe("resumoFiltros", () => {
  it("resume os filtros usados, só os que o tipo tem", () => {
    const filtros = { ...FILTROS_VAZIOS, inicio: "2026-10-01", fim: "2026-10-18", regiaoId: "r1", statusPresenca: "Presente" };
    expect(resumoFiltros(definicao("presenca"), filtros, { regiao: "Salvador" })).toBe(
      "Período: 01/10/2026 a 18/10/2026 · Região: Salvador · Presença: Presente"
    );
    // O tipo "Cargos" não tem filtros: nada aparece
    expect(resumoFiltros(definicao("cargos"), filtros, { regiao: "Salvador" })).toBe("");
  });

  it("traduz a situação da portaria", () => {
    const filtros = { ...FILTROS_VAZIOS, situacao: "APROVADA" };
    expect(resumoFiltros(definicao("portarias"), filtros, {})).toBe("Situação: Aprovada");
  });
});

// Bahia > Salvador (Setor 1, Setor 2) e Jequié (Setor 1); comuns: Itinga e Caique em Salvador/Setor 1, Central em Jequié/Setor 1, Solta sem setor
const nos: NoOrganizacao[] = [
  { nivel: "ESTADO", id: "e1", parent_id: null, nome: "Bahia", ativo: true, qtd_filhos: 2 },
  { nivel: "REGIAO", id: "r1", parent_id: "e1", nome: "Salvador", ativo: true, qtd_filhos: 2 },
  { nivel: "REGIAO", id: "r2", parent_id: "e1", nome: "Jequié", ativo: true, qtd_filhos: 1 },
  { nivel: "SETOR", id: "s1", parent_id: "r1", nome: "Setor 1", ativo: true, qtd_filhos: 2 },
  { nivel: "SETOR", id: "s2", parent_id: "r1", nome: "Setor 2", ativo: true, qtd_filhos: 0 },
  { nivel: "SETOR", id: "s3", parent_id: "r2", nome: "Setor 1", ativo: true, qtd_filhos: 1 },
  { nivel: "COMUM", id: "c1", parent_id: "s1", nome: "Itinga", ativo: true, qtd_membros: 7, cidade: "Lauro de Freitas" },
  { nivel: "COMUM", id: "c2", parent_id: "s1", nome: "Caique", ativo: false, qtd_membros: 2 },
  { nivel: "COMUM", id: "c3", parent_id: "s3", nome: "Central", ativo: true, qtd_membros: 4 },
  { nivel: "COMUM", id: "c4", parent_id: null, nome: "Solta", ativo: true, qtd_membros: 0 },
];

describe("opções dos filtros de organização", () => {
  it("lista regiões, setores da região e comuns do setor", () => {
    expect(opcoesRegiao(nos).map((o) => o.rotulo)).toEqual(["Jequié", "Salvador"]);
    expect(opcoesSetor(nos, "r1").map((o) => o.rotulo)).toEqual(["Setor 1", "Setor 2"]);
    expect(opcoesSetor(nos, "")).toEqual([]);
    expect(opcoesComum(nos, "s1").map((o) => o.rotulo)).toEqual(["Caique", "Itinga"]);
    expect(opcoesComum(nos, "")).toEqual([]);
  });

  it("coloca o estado na frente da região quando há mais de um estado", () => {
    const maisUmEstado: NoOrganizacao[] = [...nos, { nivel: "ESTADO", id: "e2", parent_id: null, nome: "Sergipe" }];
    expect(opcoesRegiao(maisUmEstado).map((o) => o.rotulo)).toContain("Bahia › Salvador");
  });
});

describe("linhasOrganizacao", () => {
  it("traz a estrutura inteira, na ordem, com as comuns sem setor no fim", () => {
    const linhas = linhasOrganizacao(nos, { regiaoId: "", setorId: "" });
    expect(linhas.map((l) => `${l.nivel}:${l.comum || l.setor || l.regiao || l.estado}`)).toEqual([
      "Estado:Bahia",
      "Região:Jequié",
      "Setor:Setor 1",
      "Comum:Central",
      "Região:Salvador",
      "Setor:Setor 1",
      "Comum:Caique",
      "Comum:Itinga",
      "Setor:Setor 2",
      "Comum:Solta",
    ]);
  });

  it("preenche situação, membros e cidade da comum", () => {
    const linhas = linhasOrganizacao(nos, { regiaoId: "", setorId: "" });
    const itinga = linhas.find((l) => l.comum === "Itinga");
    expect(itinga).toMatchObject({ situacao: "Ativo", membros: "7", cidade: "Lauro de Freitas", regiao: "Salvador" });
    expect(linhas.find((l) => l.comum === "Caique")?.situacao).toBe("Inativo");
  });

  it("filtra por região e por setor (separando o Setor 1 de cada região)", () => {
    const daRegiao = linhasOrganizacao(nos, { regiaoId: "r1", setorId: "" });
    expect(daRegiao.some((l) => l.regiao === "Jequié")).toBe(false);
    expect(daRegiao.some((l) => l.nivel === "Estado")).toBe(false);

    const doSetor = linhasOrganizacao(nos, { regiaoId: "", setorId: "s3" });
    expect(doSetor.map((l) => l.nivel)).toEqual(["Setor", "Comum"]);
    expect(doSetor[1].comum).toBe("Central");
  });
});

describe("linhasInstrumentos e linhasCargos", () => {
  it("agrupa instrumentos por família, com os sem família no fim, e conta os membros", () => {
    const linhas = linhasInstrumentos(
      [
        { id: "i1", nome: "Trombone", familia_id: "f2" },
        { id: "i2", nome: "Clarinete", familia_id: "f1" },
        { id: "i3", nome: "Solto", familia_id: null },
      ] as never,
      [
        { id: "f1", nome: "Madeiras" },
        { id: "f2", nome: "Metais" },
      ] as never,
      new Map([["i2", 3]])
    );
    expect(linhas.map((l) => `${l.familia}/${l.instrumento}/${l.membros}`)).toEqual([
      "Madeiras/Clarinete/3",
      "Metais/Trombone/0",
      "Sem família definida/Solto/0",
    ]);
  });

  it("lista os cargos em ordem de nome com sim/não e a contagem", () => {
    const linhas = linhasCargos(
      [
        { id: "c2", nome: "Músico", permite_instrumento: true, exige_instrumento: true },
        { id: "c1", nome: "Ancião", permite_instrumento: false },
      ] as never,
      new Map([["c2", 9]])
    );
    expect(linhas).toEqual([
      { cargo: "Ancião", permite_instrumento: "Não", exige_instrumento: "Não", membros: "0" },
      { cargo: "Músico", permite_instrumento: "Sim", exige_instrumento: "Sim", membros: "9" },
    ]);
  });

  it("conta ignorando vazios", () => {
    expect(contarPor(["a", "b", "a", null, undefined, ""]).get("a")).toBe(2);
  });
});

describe("linhasPortarias", () => {
  const portaria = (parcial: Partial<PortariaDetalhada>): PortariaDetalhada => ({
    id: "p",
    evento_id: "e",
    status: "PENDENTE_APROVACAO",
    cidade: "Salvador › Setor 1",
    criada_em: "2026-10-10T12:00:00Z",
    criada_por: "u",
    criador_nome: "Ana",
    decidida_em: null,
    decisor_nome: null,
    motivo_rejeicao: null,
    evento_tipo: "Ensaio",
    evento_data: "2026-10-17T22:30:00Z",
    evento_local: "Central",
    evento_finalidade: null,
    pode_decidir: false,
    pode_excluir: false,
    ...parcial,
  });

  const lista = [
    portaria({ id: "1", status: "APROVADA" }),
    portaria({ id: "2", status: "REJEITADA", evento_data: "2026-09-01T22:30:00Z" }),
  ];

  it("filtra por situação", () => {
    expect(linhasPortarias(lista, { inicio: "", fim: "", situacao: "APROVADA" }).map((l) => l.situacao)).toEqual([
      "Aprovada",
    ]);
  });

  it("filtra por período da data do evento", () => {
    const linhas = linhasPortarias(lista, { inicio: "2026-10-01", fim: "2026-10-31", situacao: "" });
    expect(linhas).toHaveLength(1);
    expect(linhasPortarias(lista, { inicio: "", fim: "", situacao: "" })).toHaveLength(2);
  });
});
