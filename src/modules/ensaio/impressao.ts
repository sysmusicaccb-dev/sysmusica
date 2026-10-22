/**
 * Sysmusica — Impressão dos Dados do Ensaio. Função pura: recebe os textos já prontos (quem atendeu, encarregados,
 * hinos...) e devolve o que a folha impressa mostra. Testada em impressao.test.ts.
 */
import type { ItemInformacao, OpcoesImpressao } from "@/lib/exportacao";

export interface EntradaImpressaoEnsaio {
  tipoEvento: string; // "Ensaio Local" ou "Ensaio Regional"
  quando: string; // "17/10/2026 às 19h30"
  local: string; // casa de oração e cidade, já juntas
  atende: string; // "Nome — Ancião"
  rotuloEncarregados: string; // "Encarregado Local" etc.
  encarregados: string[]; // "Nome (Cidade-UF)"
  hinoAbertura: string;
  palavra: string; // vazio no ensaio local
  hinosExecutados: string[]; // rótulos completos, na ordem em que foram cantados
  totalParticipantes?: number; // só quando a pessoa pode ver o painel
  emitidoPor: string;
  geradoEm: string;
  marca?: string;
  logoUrl?: string;
}

export function montarImpressaoEnsaio(entrada: EntradaImpressaoEnsaio): OpcoesImpressao {
  const informacoes: ItemInformacao[] = [
    { rotulo: "Evento", valor: `${entrada.quando} · ${entrada.tipoEvento}`, largo: true },
    { rotulo: "Local", valor: entrada.local, largo: true },
    { rotulo: "Quem atendeu", valor: entrada.atende, largo: true },
    {
      rotulo: `${entrada.rotuloEncarregados} (${entrada.encarregados.length})`,
      valor: entrada.encarregados.join("; "),
      largo: true,
    },
    { rotulo: "Hino de abertura", valor: entrada.hinoAbertura, largo: true },
    { rotulo: "Palavra", valor: entrada.palavra.trim(), largo: true },
    { rotulo: "Hinos executados", valor: String(entrada.hinosExecutados.length) },
    {
      rotulo: "Total de participantes",
      valor: entrada.totalParticipantes === undefined ? "" : String(entrada.totalParticipantes),
    },
    { rotulo: "Emitido em", valor: entrada.geradoEm },
    { rotulo: "Emitido por", valor: entrada.emitidoPor },
  ];

  return {
    titulo: "Dados do Ensaio",
    colunas: ["Nº", "Hino executado"],
    linhas: entrada.hinosExecutados.map((hino, indice) => [String(indice + 1), hino]),
    informacoes,
    orientacao: "retrato",
    colunasCompactas: true,
    paginacao: true,
    marca: entrada.marca,
    logoUrl: entrada.logoUrl,
    geradoEm: entrada.geradoEm,
    rodapeItens: entrada.marca ? [entrada.marca] : [],
  };
}
