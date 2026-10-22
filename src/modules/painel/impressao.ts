/**
 * Sysmusica — Impressão do Painel de Totais (Painel ao Vivo). Função pura: recebe os números do painel e devolve
 * o que a folha impressa mostra (quadro do cabeçalho + tabela com Ministério, Músicos, Organistas e Instrumentos).
 * Testada em impressao.test.ts.
 */
import type { ItemInformacao, OpcoesImpressao } from "@/lib/exportacao";
import {
  agruparBlocos,
  formatarDiaDoEvento,
  formatarHoraDaAtualizacao,
  formatarHoraDoEvento,
  montarFamilias,
} from "./regras";
import type { DadosPainel } from "./tipos";

export interface ExtrasImpressaoPainel {
  emitidoPor: string;
  geradoEm: string;
  marca?: string;
  logoUrl?: string;
}

export function montarImpressaoPainel(dados: DadosPainel, extras: ExtrasImpressaoPainel): OpcoesImpressao {
  // Blocos sem nenhuma linha não entram (a faixa do bloco ficaria sozinha)
  const blocos = agruparBlocos(dados.linhas).filter((bloco) => bloco.linhas.length > 0);
  const { total: totalInstrumentos, familias } = montarFamilias(dados.instrumentos);

  const linhas: string[][] = [];
  const agrupamento: { antesDaLinha: number; titulo: string }[] = [];
  for (const bloco of blocos) {
    agrupamento.push({ antesDaLinha: linhas.length, titulo: `${bloco.rotulo} — ${bloco.total}` });
    for (const linha of bloco.linhas) linhas.push([linha.rotulo, String(linha.qtd), ""]);
  }
  // Instrumentos: recorte de quem toca (não soma de novo no total de participantes)
  agrupamento.push({ antesDaLinha: linhas.length, titulo: `Instrumentos — ${totalInstrumentos}` });
  for (const familia of familias) linhas.push([familia.nome, String(familia.qtd), familia.percentual]);

  const evento = dados.evento;
  const local = [evento.casa_oracao ?? evento.local, evento.cidade].filter((parte): parte is string => Boolean(parte));
  const atualizado = new Date(dados.atualizado_em);

  const informacoes: ItemInformacao[] = [
    {
      rotulo: "Evento",
      valor: `${formatarDiaDoEvento(evento.data_evento)} às ${formatarHoraDoEvento(evento.data_evento)} · ${evento.tipo}`,
      largo: true,
    },
    { rotulo: "Local", valor: local.join(" · "), largo: true },
    { rotulo: "Total de participantes", valor: String(dados.total) },
    // Data inválida: o item fica vazio e é ignorado pela impressão
    { rotulo: "Atualizado às", valor: Number.isNaN(atualizado.getTime()) ? "" : formatarHoraDaAtualizacao(atualizado) },
    { rotulo: "Emitido em", valor: extras.geradoEm },
    { rotulo: "Emitido por", valor: extras.emitidoPor },
  ];

  return {
    titulo: "Painel de Totais",
    colunas: ["Item", "Quantidade", "Percentual"],
    linhas,
    agrupamento,
    informacoes,
    orientacao: "retrato",
    colunasCompactas: true,
    paginacao: true,
    marca: extras.marca,
    logoUrl: extras.logoUrl,
    geradoEm: extras.geradoEm,
    // Quem emitiu e quando já estão no cabeçalho: o rodapé leva só o nome do sistema
    rodapeItens: extras.marca ? [extras.marca] : [],
  };
}
