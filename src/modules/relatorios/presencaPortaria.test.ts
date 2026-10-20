import { describe, expect, it } from "vitest";
import {
  horaDaEntrada,
  montarImpressaoPresenca,
  OPCOES_PADRAO,
  type DadosPresencaPortaria,
  type OpcoesRelatorioPresenca,
} from "./presencaPortaria";

const dados: DadosPresencaPortaria = {
  total: 3,
  sem_cadastro: 1,
  blocos: [
    { bloco: "MUSICOS", qtd: 2 },
    { bloco: "ORGANISTAS", qtd: 1 },
  ],
  familias: [{ familia: "Cordas", qtd: 1 }],
  grupos: [
    {
      codigo: "MUS_OFICIALIZADO",
      bloco: "MUSICOS",
      rotulo: "Oficializado",
      qtd: 2,
      itens: [
        { nome: "Ana", cargo: "Músico", instrumento: "Violino", toca: null, origem: "Itinga", entrada: "2026-10-19T21:40:00Z", sem_cadastro: false },
        { nome: null, cargo: null, instrumento: "Flauta", toca: true, origem: "Jequié", entrada: "2026-10-19T22:00:00Z", sem_cadastro: true },
      ],
    },
    {
      codigo: "ORG_OFICIALIZADA",
      bloco: "ORGANISTAS",
      rotulo: "Oficializada",
      qtd: 1,
      itens: [
        { nome: "Carla", cargo: "Organista", instrumento: "Órgão", toca: false, origem: "Itinga", entrada: "2026-10-19T21:50:00Z", sem_cadastro: false },
      ],
    },
  ],
  evento: {
    id: "e1",
    tipo: "Ensaio Local",
    local: "Itinga",
    data_evento: "2026-10-19T22:30:00Z",
    cidade: "Lauro de Freitas",
    finalidade: "Ensaio Técnico",
    casa_oracao: "Itinga",
    setor: "Setor 4",
    regiao: "Lauro de Freitas",
    cancelado: false,
  },
  portaria: { status: "APROVADA", criada_por: "Levi", criada_em: "2026-10-19T20:00:00Z", decidida_por: "Lucas", decidida_em: "2026-10-19T20:10:00Z" },
  gerado_em: "2026-10-20T03:00:00Z",
};
const contexto = { emitidoPor: "Levi Alencar", geradoEm: "20/10/2026 00:30", logoUrl: "https://exemplo.com/logo-ccb.png" };
const rotulos = (saida: ReturnType<typeof montarImpressaoPresenca>) => (saida.informacoes ?? []).map((item) => item.rotulo);
const tudo: OpcoesRelatorioPresenca = Object.fromEntries(
  Object.keys(OPCOES_PADRAO).map((chave) => [chave, true])
) as unknown as OpcoesRelatorioPresenca;

describe("horaDaEntrada", () => {
  it("mostra a hora no fuso de Salvador", () => {
    expect(horaDaEntrada("2026-10-19T21:40:00Z")).toBe("18:40");
    expect(horaDaEntrada("isto não é data")).toBe("");
  });
});

describe("montarImpressaoPresenca (padrão = mínimo)", () => {
  const saida = montarImpressaoPresenca(dados, contexto);

  it("tem logomarca da CCB e título, sem o nome do sistema no topo", () => {
    expect(saida.titulo).toBe("Relatório de presença");
    expect(saida.logoUrl).toBe("https://exemplo.com/logo-ccb.png");
    expect(saida.marca).toBeUndefined();
    expect(saida.subtitulo).toBe("Ensaio Local · Ensaio Técnico — 19/10/2026 às 22:30");
  });

  it("no cabeçalho só vão local e total (a data não se repete)", () => {
    expect(rotulos(saida)).toEqual(["Local", "Total de presentes"]);
  });

  it("não traz quem aprovou, nem quem emitiu, nem assinaturas", () => {
    expect(saida.assinaturas).toEqual([]);
    expect(saida.rodapeItens).toEqual(["SysMúsica", "Emitido em 20/10/2026 00:30"]);
    expect(JSON.stringify(saida)).not.toContain("Lucas");
    expect(JSON.stringify(saida)).not.toContain("Levi Alencar");
  });

  it("numera as linhas em sequência e agrupa com subtotal", () => {
    expect(saida.linhas.map((linha) => linha[0])).toEqual(["1", "2", "3"]);
    expect(saida.agrupamento).toEqual([
      { antesDaLinha: 0, titulo: "Músicos › Oficializado (2)" },
      { antesDaLinha: 2, titulo: "Organistas › Oficializada (1)" },
    ]);
  });

  it("identifica entrada sem cadastro e quem não toca", () => {
    expect(saida.linhas[1][1]).toBe("(entrada sem cadastro)");
    expect(saida.linhas[2][3]).toBe("Não toca");
  });
});

describe("montarImpressaoPresenca (opções)", () => {
  it("com tudo ligado traz o cabeçalho completo, assinaturas e quem emitiu", () => {
    const saida = montarImpressaoPresenca(dados, contexto, tudo);
    expect(rotulos(saida)).toEqual([
      "Local", "Casa de Oração", "Região › Setor", "Total de presentes", "Entradas sem cadastro", "Portaria", "Resumo", "Instrumentos (quem toca)",
    ]);
    expect(saida.informacoes?.find((i) => i.rotulo === "Portaria")?.valor).toContain("por Lucas");
    expect(saida.informacoes?.find((i) => i.rotulo === "Resumo")?.valor).toBe("Músicos: 2 · Organistas: 1");
    expect(saida.assinaturas).toHaveLength(2);
    expect(saida.rodapeItens).toContain("Emitido por Levi Alencar");
  });

  it("tira colunas e a logomarca quando desligadas", () => {
    const saida = montarImpressaoPresenca(dados, contexto, {
      ...OPCOES_PADRAO,
      colCargo: false,
      colOrigem: false,
      logoCcb: false,
    });
    expect(saida.colunas).toEqual(["Nº", "Nome", "Instrumento", "Entrada"]);
    expect(saida.linhas[0]).toHaveLength(4);
    expect(saida.logoUrl).toBeUndefined();
  });

  it("evento sem presença mostra uma linha avisando", () => {
    const vazio = montarImpressaoPresenca({ ...dados, total: 0, sem_cadastro: 0, blocos: [], familias: [], grupos: [] }, contexto);
    expect(vazio.linhas).toHaveLength(1);
    expect(vazio.linhas[0][1]).toContain("Nenhuma presença");
  });

  it("marca o evento cancelado no subtítulo", () => {
    const cancelado = montarImpressaoPresenca({ ...dados, evento: { ...dados.evento, cancelado: true } }, contexto);
    expect(cancelado.subtitulo).toContain("EVENTO CANCELADO");
  });
});
