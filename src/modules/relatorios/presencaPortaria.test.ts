import { describe, expect, it } from "vitest";
import { horaDaEntrada, montarImpressaoPresenca, type DadosPresencaPortaria } from "./presencaPortaria";

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

describe("horaDaEntrada", () => {
  it("mostra a hora no fuso de Salvador", () => {
    expect(horaDaEntrada("2026-10-19T21:40:00Z")).toBe("18:40");
    expect(horaDaEntrada("isto não é data")).toBe("");
  });
});

describe("montarImpressaoPresenca", () => {
  const saida = montarImpressaoPresenca(dados, contexto);

  it("traz logomarca, título e o evento no subtítulo", () => {
    expect(saida.titulo).toBe("Relatório de presença");
    expect(saida.logoUrl).toBe("https://exemplo.com/logo-ccb.png");
    expect(saida.subtitulo).toContain("Ensaio Local · Ensaio Técnico");
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

  it("resume os totais no quadro de informações", () => {
    const valor = (rotulo: string) => saida.informacoes?.find((item) => item.rotulo === rotulo)?.valor;
    expect(valor("Total de presentes")).toBe("3");
    expect(valor("Entradas sem cadastro")).toBe("1");
    expect(valor("Resumo")).toBe("Músicos: 2 · Organistas: 1");
    expect(valor("Instrumentos (quem toca)")).toBe("Cordas: 1");
    expect(valor("Portaria")).toContain("por Lucas");
  });

  it("evento sem presença mostra uma linha avisando", () => {
    const vazio = montarImpressaoPresenca({ ...dados, total: 0, sem_cadastro: 0, blocos: [], familias: [], grupos: [] }, contexto);
    expect(vazio.linhas).toHaveLength(1);
    expect(vazio.linhas[0][1]).toContain("Nenhuma presença");
  });

  it("marca o evento cancelado", () => {
    const cancelado = montarImpressaoPresenca({ ...dados, evento: { ...dados.evento, cancelado: true } }, contexto);
    expect(cancelado.informacoes?.[0].valor).toContain("EVENTO CANCELADO");
  });
});
