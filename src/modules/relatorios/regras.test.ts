import { describe, expect, it } from "vitest";
import { DEFINICOES_RELATORIO } from "@/modules/relatorios/catalogo";
import {
  agoraEmSalvador,
  colunasEscolhidas,
  itensCabecalhoDisponiveis,
  lerAssinaturas,
  margemEmMm,
  montarInformacoes,
  montarItensRodape,
  resumoDeTotais,
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
  opcoesCasaOracao,
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

describe("agoraEmSalvador e margemEmMm", () => {
  it("mostra data e hora no fuso de Salvador", () => {
    expect(agoraEmSalvador(new Date("2026-10-18T04:31:00Z"))).toBe("18/10/2026 01:31");
  });

  it("traduz a margem escolhida para milímetros", () => {
    expect(margemEmMm("estreita")).toBe(8);
    expect(margemEmMm("normal")).toBe(12);
    expect(margemEmMm("larga")).toBe(18);
  });
});

describe("itensCabecalhoDisponiveis", () => {
  it("oferece só o que faz sentido para o tipo escolhido", () => {
    expect(itensCabecalhoDisponiveis(definicao("cargos"))).toEqual(["marca", "total", "emissao", "emitidoPor"]);
    expect(itensCabecalhoDisponiveis(definicao("organizacao"))).toEqual([
      "marca",
      "localizacao",
      "total",
      "emissao",
      "emitidoPor",
    ]);
    expect(itensCabecalhoDisponiveis(definicao("presenca"))).toEqual([
      "marca",
      "evento",
      "periodo",
      "localizacao",
      "filtros",
      "total",
      "resumo",
      "emissao",
      "emitidoPor",
    ]);
  });
});

describe("resumoDeTotais", () => {
  it("conta as presenças por situação e soma os eventos", () => {
    expect(resumoDeTotais("presenca", [{ status: "Presente" }, { status: "Presente" }, { status: "Ausente" }])).toBe(
      "Presentes: 2 · Ausentes: 1 · Justificados: 0"
    );
    expect(
      resumoDeTotais("eventos", [
        { registros: "5", presentes: "4" },
        { registros: "3", presentes: "3" },
      ])
    ).toBe("Presenças registradas: 8 · Presentes: 7");
  });

  it("não tem resumo nos outros tipos", () => {
    expect(resumoDeTotais("membros", [{ status: "Ativo" }])).toBe("");
  });
});

describe("montarInformacoes", () => {
  const base = {
    definicao: definicao("presenca"),
    filtros: {
      ...FILTROS_VAZIOS,
      inicio: "2026-10-01",
      fim: "2026-10-18",
      eventoId: "ev1",
      regiaoId: "r1",
      setorId: "s1",
      statusPresenca: "Presente",
    },
    rotulos: {
      evento: "17/10/2026 19:30 · Ensaio Regional · Central Itinga",
      regiao: "Salvador",
      setor: "Setor 1",
    },
    itens: {
      marca: true,
      evento: true,
      periodo: true,
      localizacao: true,
      filtros: true,
      total: true,
      resumo: true,
      emissao: true,
      emitidoPor: true,
    },
    emitidoPor: "Levi Alencar",
    geradoEm: "18/10/2026 01:31",
    linhas: [{ status: "Presente" }, { status: "Presente" }, { status: "Ausente" }],
    total: 3,
  };
  const comoTexto = (lista: { rotulo: string; valor: string }[]) => lista.map((item) => `${item.rotulo}: ${item.valor}`);

  it("monta o quadro completo na ordem certa", () => {
    expect(comoTexto(montarInformacoes(base))).toEqual([
      "Evento: 17/10/2026 19:30 · Ensaio Regional · Central Itinga",
      "Período: 01/10/2026 a 18/10/2026",
      "Localização: Salvador › Setor 1",
      "Filtros: Presença: Presente",
      "Total de registros: 3",
      "Resumo: Presentes: 2 · Ausentes: 1 · Justificados: 0",
      "Emitido em: 18/10/2026 01:31",
      "Emitido por: Levi Alencar",
    ]);
  });

  it("deixa de fora os itens desmarcados", () => {
    const lista = comoTexto(montarInformacoes({ ...base, itens: { ...base.itens, evento: false, resumo: false, emissao: false } }));
    expect(lista.some((linha) => linha.startsWith("Evento"))).toBe(false);
    expect(lista.some((linha) => linha.startsWith("Resumo"))).toBe(false);
    expect(lista.some((linha) => linha.startsWith("Emitido em"))).toBe(false);
    expect(lista).toContain("Emitido por: Levi Alencar");
  });

  it("explica quando nenhum evento ou localização foi escolhido", () => {
    const lista = comoTexto(
      montarInformacoes({
        ...base,
        filtros: { ...FILTROS_VAZIOS },
        rotulos: {},
      })
    );
    expect(lista).toContain("Evento: Todos os eventos do período");
    expect(lista).toContain("Localização: Toda a sua abrangência");
    // Sem filtro adicional, a linha "Filtros" não aparece no cabeçalho
    expect(lista.some((linha) => linha.startsWith("Filtros"))).toBe(false);
  });

  it("não inventa itens que o tipo não tem", () => {
    const lista = comoTexto(montarInformacoes({ ...base, definicao: definicao("cargos"), linhas: [], total: 0 }));
    expect(lista).toEqual(["Total de registros: 0", "Emitido em: 18/10/2026 01:31", "Emitido por: Levi Alencar"]);
  });
});

describe("montarItensRodape e lerAssinaturas", () => {
  const itens = { paginacao: true, sistema: true, emitidoPor: true, emissao: false, total: true };

  it("coloca o texto livre primeiro e só os itens marcados (a numeração é tratada à parte)", () => {
    expect(
      montarItensRodape({ itens, textoLivre: " Confidencial ", emitidoPor: "Levi", geradoEm: "agora", total: 3 })
    ).toEqual(["Confidencial", "Sysmusica", "Emitido por Levi", "3 registro(s)"]);
    expect(
      montarItensRodape({
        itens: { ...itens, sistema: false, emitidoPor: false, total: false, emissao: true },
        textoLivre: "",
        emitidoPor: "Levi",
        geradoEm: "agora",
        total: 3,
      })
    ).toEqual(["Emitido em agora"]);
  });

  it("lê os nomes das assinaturas (até 4) e usa 'Responsável' quando vazio", () => {
    expect(lerAssinaturas(false, "A, B")).toEqual([]);
    expect(lerAssinaturas(true, " Ana , Beto ,, ")).toEqual(["Ana", "Beto"]);
    expect(lerAssinaturas(true, "1,2,3,4,5")).toEqual(["1", "2", "3", "4"]);
    expect(lerAssinaturas(true, "  ")).toEqual(["Responsável"]);
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
      "Período: 01/10/2026 a 18/10/2026 · RA: Salvador · Presença: Presente"
    );
    // O tipo "Cargos" não tem filtros: nada aparece
    expect(resumoFiltros(definicao("cargos"), filtros, { regiao: "Salvador" })).toBe("");
  });

  it("traduz a situação da portaria", () => {
    const filtros = { ...FILTROS_VAZIOS, situacao: "APROVADA" };
    expect(resumoFiltros(definicao("portarias"), filtros, {})).toBe("Situação: Aprovada");
  });
});

// Bahia > RRM Salvador > RA Salvador > ADM Centro (Setor 1: Itinga e Caique · Setor 2)
//       > RRM Vitória da Conquista > RA Jequié > ADM Ipiaú (Setor 1: Central · casa "Solta" ligada direto à ADM, sem setor)
const nos: NoOrganizacao[] = [
  { nivel: "ESTADO", id: "e1", parent_id: null, nome: "Bahia", ativo: true, qtd_filhos: 2 },
  { nivel: "RRM", id: "m1", parent_id: "e1", nome: "Salvador", ativo: true, qtd_filhos: 1 },
  { nivel: "RRM", id: "m2", parent_id: "e1", nome: "Vitória da Conquista", ativo: true, qtd_filhos: 1 },
  { nivel: "RA", id: "r1", parent_id: "m1", nome: "Salvador", ativo: true, qtd_filhos: 1 },
  { nivel: "RA", id: "r2", parent_id: "m2", nome: "Jequié", ativo: true, qtd_filhos: 1 },
  { nivel: "ADM", id: "a1", parent_id: "r1", nome: "Centro", ativo: true, qtd_filhos: 2 },
  { nivel: "ADM", id: "a2", parent_id: "r2", nome: "Ipiaú", ativo: true, qtd_filhos: 2 },
  { nivel: "SETOR", id: "s1", parent_id: "a1", nome: "Setor 1", ativo: true, qtd_filhos: 2 },
  { nivel: "SETOR", id: "s2", parent_id: "a1", nome: "Setor 2", ativo: true, qtd_filhos: 0 },
  { nivel: "SETOR", id: "s3", parent_id: "a2", nome: "Setor 1", ativo: true, qtd_filhos: 1 },
  { nivel: "CASA_ORACAO", id: "c1", parent_id: "s1", nome: "Itinga", ativo: true, qtd_membros: 7, cidade: "Lauro de Freitas" },
  { nivel: "CASA_ORACAO", id: "c2", parent_id: "s1", nome: "Caique", ativo: false, qtd_membros: 2 },
  { nivel: "CASA_ORACAO", id: "c3", parent_id: "s3", nome: "Central", ativo: true, qtd_membros: 4 },
  { nivel: "CASA_ORACAO", id: "c4", parent_id: "a2", nome: "Solta", ativo: true, qtd_membros: 0 },
];

describe("opções dos filtros de organização", () => {
  it("lista RAs, setores da RA (com a ADM na frente) e casas de oração", () => {
    expect(opcoesRegiao(nos).map((o) => o.rotulo)).toEqual(["Jequié", "Salvador"]);
    expect(opcoesSetor(nos, "r1").map((o) => o.rotulo)).toEqual(["Centro › Setor 1", "Centro › Setor 2"]);
    expect(opcoesSetor(nos, "")).toEqual([]);
    expect(opcoesCasaOracao(nos, "r1", "s1").map((o) => o.rotulo)).toEqual(["Caique", "Itinga"]);
    expect(opcoesCasaOracao(nos, "", "")).toEqual([]);
  });

  it("sem setor escolhido, as casas são todas as da RA (inclusive as ligadas direto à ADM)", () => {
    expect(opcoesCasaOracao(nos, "r2", "").map((o) => o.rotulo)).toEqual(["Central", "Solta"]);
    expect(opcoesCasaOracao(nos, "r1", "").map((o) => o.rotulo)).toEqual(["Caique", "Itinga"]);
  });

  it("coloca o estado na frente da RA quando há mais de um estado", () => {
    const maisUmEstado: NoOrganizacao[] = [...nos, { nivel: "ESTADO", id: "e2", parent_id: null, nome: "Sergipe" }];
    expect(opcoesRegiao(maisUmEstado).map((o) => o.rotulo)).toContain("Bahia › Salvador");
  });
});

describe("linhasOrganizacao", () => {
  const nomeDaLinha = (l: Record<string, string>) =>
    `${l.nivel}:${l.casa_oracao || l.setor || l.adm || l.regiao || l.rrm || l.estado}`;

  it("traz a estrutura inteira, na ordem, com as casas de oração sem setor no fim de cada ADM", () => {
    const linhas = linhasOrganizacao(nos, { regiaoId: "", setorId: "" });
    expect(linhas.map(nomeDaLinha)).toEqual([
      "Estado:Bahia",
      "RRM:Salvador",
      "RA:Salvador",
      "ADM:Centro",
      "Setor:Setor 1",
      "Casa de Oração:Caique",
      "Casa de Oração:Itinga",
      "Setor:Setor 2",
      "RRM:Vitória da Conquista",
      "RA:Jequié",
      "ADM:Ipiaú",
      "Setor:Setor 1",
      "Casa de Oração:Central",
      "Casa de Oração:Solta",
    ]);
  });

  it("preenche o caminho, a situação, os membros e a cidade da casa de oração", () => {
    const linhas = linhasOrganizacao(nos, { regiaoId: "", setorId: "" });
    const itinga = linhas.find((l) => l.casa_oracao === "Itinga");
    expect(itinga).toMatchObject({
      situacao: "Ativo",
      membros: "7",
      cidade: "Lauro de Freitas",
      rrm: "Salvador",
      regiao: "Salvador",
      adm: "Centro",
      setor: "Setor 1",
    });
    expect(linhas.find((l) => l.casa_oracao === "Caique")?.situacao).toBe("Inativo");
    // casa ligada direto à ADM: sem setor no caminho
    expect(linhas.find((l) => l.casa_oracao === "Solta")).toMatchObject({ adm: "Ipiaú", setor: "" });
  });

  it("filtra por RA e por setor (separando o Setor 1 de cada ADM)", () => {
    const daRa = linhasOrganizacao(nos, { regiaoId: "r1", setorId: "" });
    expect(daRa.some((l) => l.regiao === "Jequié")).toBe(false);
    expect(daRa.some((l) => l.nivel === "Estado" || l.nivel === "RRM")).toBe(false);
    expect(linhasOrganizacao(nos, { regiaoId: "r2", setorId: "" }).some((l) => l.casa_oracao === "Solta")).toBe(true);

    const doSetor = linhasOrganizacao(nos, { regiaoId: "", setorId: "s3" });
    expect(doSetor.map((l) => l.nivel)).toEqual(["Setor", "Casa de Oração"]);
    expect(doSetor[1].casa_oracao).toBe("Central");
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
