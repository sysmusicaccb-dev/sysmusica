/**
 * SysMúsica — Relatório de presença de uma portaria (regras puras, sem banco).
 * Recebe o que a função do banco entrega (relatorio_presenca_portaria) e monta a folha de impressão:
 * logomarca da CCB, título com o evento, quadro de informações com o resumo, a lista de presentes agrupada
 * pelas mesmas linhas do Painel ao vivo (com subtotal), linhas de assinatura e rodapé com paginação.
 */
import type { ItemInformacao, OpcoesImpressao } from "@/lib/exportacao";
import { formatarDataHora } from "@/lib/datas";
import { ROTULO_STATUS } from "@/modules/portarias/regras";
import type { StatusPortaria } from "@/modules/portarias/tipos";

export interface ItemPresenca {
  nome: string | null; // vazio nas entradas sem cadastro
  cargo: string | null;
  instrumento: string | null;
  toca: boolean | null;
  origem: string | null; // Casa de Oração (ou texto) de onde a pessoa vem
  entrada: string;
  sem_cadastro: boolean;
}

export interface GrupoPresenca {
  codigo: string;
  bloco: string;
  rotulo: string;
  qtd: number | string;
  itens: ItemPresenca[];
}

export interface DadosPresencaPortaria {
  total: number | string;
  sem_cadastro: number | string;
  blocos: { bloco: string; qtd: number | string }[];
  familias: { familia: string; qtd: number | string }[];
  grupos: GrupoPresenca[];
  evento: {
    id: string;
    tipo: string;
    local: string;
    data_evento: string;
    cidade: string | null;
    finalidade: string | null;
    casa_oracao: string | null;
    setor: string | null;
    regiao: string | null;
    cancelado: boolean;
  };
  portaria: {
    status: StatusPortaria;
    criada_por: string | null;
    criada_em: string;
    decidida_por: string | null;
    decidida_em: string | null;
  };
  gerado_em: string;
}

export const ROTULO_BLOCO: Record<string, string> = {
  MINISTERIO: "Ministério e outros cargos",
  MUSICOS: "Músicos",
  ORGANISTAS: "Organistas",
};

export const COLUNAS_PRESENCA = ["Nº", "Nome", "Cargo", "Instrumento", "Casa de Oração de origem", "Entrada"];

/** Hora da entrada no fuso de Salvador ("19:42"). */
export function horaDaEntrada(iso: string): string {
  const data = new Date(iso);
  if (Number.isNaN(data.getTime())) return "";
  return new Intl.DateTimeFormat("pt-BR", {
    timeZone: "America/Sao_Paulo",
    hour: "2-digit",
    minute: "2-digit",
    hour12: false,
  }).format(data);
}

function instrumentoDoItem(item: ItemPresenca): string {
  if (item.toca === false) return "Não toca";
  return item.instrumento ?? "—";
}

/** "Cordas: 10 · Madeiras: 4" a partir de uma lista de nome e quantidade. */
function juntarContagens(lista: { nome: string; qtd: number }[]): string {
  return lista.map((item) => `${item.nome}: ${item.qtd}`).join(" · ");
}

interface ContextoPresenca {
  emitidoPor: string;
  geradoEm: string;
  logoUrl?: string;
  abrirImpressao?: boolean;
}

/** Monta tudo o que a folha de impressão precisa. */
export function montarImpressaoPresenca(dados: DadosPresencaPortaria, contexto: ContextoPresenca): OpcoesImpressao {
  const { evento, portaria } = dados;
  const total = Number(dados.total) || 0;
  const semCadastro = Number(dados.sem_cadastro) || 0;
  const dataEvento = formatarDataHora(evento.data_evento);

  // Linhas da tabela, com o título de cada grupo (linha do painel) e o seu subtotal
  const linhas: string[][] = [];
  const agrupamento: { antesDaLinha: number; titulo: string }[] = [];
  let numero = 0;
  for (const grupo of dados.grupos) {
    agrupamento.push({
      antesDaLinha: linhas.length,
      titulo: `${ROTULO_BLOCO[grupo.bloco] ?? grupo.bloco} › ${grupo.rotulo} (${Number(grupo.qtd)})`,
    });
    for (const item of grupo.itens) {
      numero += 1;
      linhas.push([
        String(numero),
        item.sem_cadastro ? "(entrada sem cadastro)" : (item.nome ?? ""),
        item.cargo ?? "",
        instrumentoDoItem(item),
        item.origem ?? "",
        horaDaEntrada(item.entrada),
      ]);
    }
  }
  if (linhas.length === 0) {
    linhas.push(["", "Nenhuma presença registrada neste evento.", "", "", "", ""]);
  }

  // Quadro de informações
  const informacoes: ItemInformacao[] = [];
  informacoes.push({
    rotulo: "Evento",
    valor: [evento.tipo, evento.finalidade].filter(Boolean).join(" · ") + (evento.cancelado ? " · EVENTO CANCELADO" : ""),
    largo: true,
  });
  informacoes.push({ rotulo: "Data e hora", valor: dataEvento });
  informacoes.push({ rotulo: "Local", valor: [evento.local, evento.cidade].filter(Boolean).join(" · ") });
  informacoes.push({ rotulo: "Casa de Oração", valor: evento.casa_oracao ?? "" });
  informacoes.push({ rotulo: "Região › Setor", valor: [evento.regiao, evento.setor].filter(Boolean).join(" › ") });

  let situacaoPortaria = ROTULO_STATUS[portaria.status] ?? portaria.status;
  if (portaria.decidida_por && portaria.decidida_em) {
    situacaoPortaria += ` por ${portaria.decidida_por} em ${formatarDataHora(portaria.decidida_em)}`;
  }
  informacoes.push({ rotulo: "Portaria", valor: situacaoPortaria, largo: true });

  informacoes.push({ rotulo: "Total de presentes", valor: String(total) });
  if (semCadastro > 0) informacoes.push({ rotulo: "Entradas sem cadastro", valor: String(semCadastro) });

  const blocos = dados.blocos.map((bloco) => ({ nome: ROTULO_BLOCO[bloco.bloco] ?? bloco.bloco, qtd: Number(bloco.qtd) }));
  if (blocos.length > 0) informacoes.push({ rotulo: "Resumo", valor: juntarContagens(blocos), largo: true });
  const familias = dados.familias.map((familia) => ({ nome: familia.familia, qtd: Number(familia.qtd) }));
  if (familias.length > 0) informacoes.push({ rotulo: "Instrumentos (quem toca)", valor: juntarContagens(familias), largo: true });

  informacoes.push({ rotulo: "Emitido em", valor: contexto.geradoEm });
  informacoes.push({ rotulo: "Emitido por", valor: contexto.emitidoPor });

  return {
    titulo: "Relatório de presença",
    subtitulo: [evento.tipo, evento.finalidade].filter(Boolean).join(" · ") + ` — ${dataEvento}`,
    colunas: COLUNAS_PRESENCA,
    linhas,
    agrupamento,
    colunasCompactas: true,
    orientacao: "retrato",
    tamanhoFonte: 9,
    margem: 12,
    marca: "SysMúsica",
    logoUrl: contexto.logoUrl,
    informacoes,
    paginacao: true,
    assinaturas: ["Responsável pela portaria", "Encarregado Local"],
    rodapeItens: ["SysMúsica", `Emitido por ${contexto.emitidoPor}`, `Emitido em ${contexto.geradoEm}`, `${total} presente(s)`],
    geradoEm: contexto.geradoEm,
    abrirImpressao: contexto.abrirImpressao ?? true,
  };
}
