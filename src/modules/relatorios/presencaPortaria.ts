/**
 * Sysmusica — Relatório de presença de uma portaria (regras puras, sem banco).
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

/** O que aparece na folha. Por padrão o mínimo: logomarca, título, evento, local e total. */
export interface OpcoesRelatorioPresenca {
  // Quadro de informações do cabeçalho
  local: boolean;
  casaOracao: boolean;
  regiaoSetor: boolean;
  total: boolean;
  semCadastro: boolean; // quantas entradas sem cadastro
  resumo: boolean; // Ministério / Músicos / Organistas
  familias: boolean; // quem toca, por família de instrumento
  portaria: boolean; // situação da portaria (quem aprovou e quando)
  // Colunas da lista (Nº e Nome sempre aparecem)
  colCargo: boolean;
  colInstrumento: boolean;
  colOrigem: boolean;
  colEntrada: boolean;
  // Folha
  logoCcb: boolean;
  assinaturas: boolean;
  emitidoPor: boolean;
  emitidoEm: boolean;
  paginacao: boolean;
}

export const OPCOES_PADRAO: OpcoesRelatorioPresenca = {
  local: true,
  casaOracao: false,
  regiaoSetor: false,
  total: true,
  semCadastro: false,
  resumo: false,
  familias: false,
  portaria: false,
  colCargo: true,
  colInstrumento: true,
  colOrigem: true,
  colEntrada: true,
  logoCcb: true,
  assinaturas: false,
  emitidoPor: false,
  emitidoEm: true,
  paginacao: true,
};

const CHAVE_OPCOES = "sysmusica.relatorioPresenca.opcoes";

/** Lê as opções guardadas neste navegador (o que faltar ou vier errado volta ao padrão). */
export function lerOpcoesSalvas(): OpcoesRelatorioPresenca {
  try {
    const bruto = typeof window === "undefined" ? null : window.localStorage.getItem(CHAVE_OPCOES);
    if (!bruto) return { ...OPCOES_PADRAO };
    const lido = JSON.parse(bruto) as Record<string, unknown>;
    const opcoes = { ...OPCOES_PADRAO };
    for (const chave of Object.keys(OPCOES_PADRAO) as (keyof OpcoesRelatorioPresenca)[]) {
      if (typeof lido[chave] === "boolean") opcoes[chave] = lido[chave];
    }
    return opcoes;
  } catch {
    return { ...OPCOES_PADRAO };
  }
}

/** Guarda as opções escolhidas (se o navegador não deixar, simplesmente não guarda). */
export function salvarOpcoes(opcoes: OpcoesRelatorioPresenca): void {
  try {
    window.localStorage.setItem(CHAVE_OPCOES, JSON.stringify(opcoes));
  } catch {
    /* sem armazenamento: a escolha vale só desta vez */
  }
}

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

/** Monta tudo o que a folha de impressão precisa, só com o que as opções pedem. */
export function montarImpressaoPresenca(
  dados: DadosPresencaPortaria,
  contexto: ContextoPresenca,
  opcoes: OpcoesRelatorioPresenca = OPCOES_PADRAO
): OpcoesImpressao {
  const { evento, portaria } = dados;
  const total = Number(dados.total) || 0;
  const semCadastro = Number(dados.sem_cadastro) || 0;
  const dataEvento = formatarDataHora(evento.data_evento);

  // Colunas: Nº e Nome sempre; as demais conforme as opções
  const colunas: { titulo: string; valor: (item: ItemPresenca, numero: number) => string }[] = [
    { titulo: "Nº", valor: (_item, numero) => String(numero) },
    { titulo: "Nome", valor: (item) => (item.sem_cadastro ? "(entrada sem cadastro)" : (item.nome ?? "")) },
  ];
  if (opcoes.colCargo) colunas.push({ titulo: "Cargo", valor: (item) => item.cargo ?? "" });
  if (opcoes.colInstrumento) colunas.push({ titulo: "Instrumento", valor: (item) => instrumentoDoItem(item) });
  if (opcoes.colOrigem) colunas.push({ titulo: "Casa de Oração de origem", valor: (item) => item.origem ?? "" });
  if (opcoes.colEntrada) colunas.push({ titulo: "Entrada", valor: (item) => horaDaEntrada(item.entrada) });

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
      linhas.push(colunas.map((coluna) => coluna.valor(item, numero)));
    }
  }
  if (linhas.length === 0) {
    linhas.push(colunas.map((_, indice) => (indice === 1 ? "Nenhuma presença registrada neste evento." : "")));
  }

  // Quadro de informações: só o que foi pedido (a data já está no subtítulo)
  const informacoes: ItemInformacao[] = [];
  if (opcoes.local) {
    informacoes.push({ rotulo: "Local", valor: [evento.local, evento.cidade].filter(Boolean).join(" · ") });
  }
  if (opcoes.casaOracao) informacoes.push({ rotulo: "Casa de Oração", valor: evento.casa_oracao ?? "" });
  if (opcoes.regiaoSetor) {
    informacoes.push({ rotulo: "Região › Setor", valor: [evento.regiao, evento.setor].filter(Boolean).join(" › ") });
  }
  if (opcoes.total) informacoes.push({ rotulo: "Total de presentes", valor: String(total) });
  if (opcoes.semCadastro && semCadastro > 0) {
    informacoes.push({ rotulo: "Entradas sem cadastro", valor: String(semCadastro) });
  }
  if (opcoes.portaria) {
    let situacao = ROTULO_STATUS[portaria.status] ?? portaria.status;
    if (portaria.decidida_por && portaria.decidida_em) {
      situacao += ` por ${portaria.decidida_por} em ${formatarDataHora(portaria.decidida_em)}`;
    }
    informacoes.push({ rotulo: "Portaria", valor: situacao, largo: true });
  }
  if (opcoes.resumo && dados.blocos.length > 0) {
    const blocos = dados.blocos.map((bloco) => ({ nome: ROTULO_BLOCO[bloco.bloco] ?? bloco.bloco, qtd: Number(bloco.qtd) }));
    informacoes.push({ rotulo: "Resumo", valor: juntarContagens(blocos), largo: true });
  }
  if (opcoes.familias && dados.familias.length > 0) {
    const familias = dados.familias.map((familia) => ({ nome: familia.familia, qtd: Number(familia.qtd) }));
    informacoes.push({ rotulo: "Instrumentos (quem toca)", valor: juntarContagens(familias), largo: true });
  }

  // Rodapé: o nome do sistema fica só aqui
  const rodapeItens = ["Sysmusica"];
  if (opcoes.emitidoPor) rodapeItens.push(`Emitido por ${contexto.emitidoPor}`);
  if (opcoes.emitidoEm) rodapeItens.push(`Emitido em ${contexto.geradoEm}`);

  return {
    titulo: "Relatório de presença",
    subtitulo:
      [evento.tipo, evento.finalidade].filter(Boolean).join(" · ") +
      ` — ${dataEvento}` +
      (evento.cancelado ? " (EVENTO CANCELADO)" : ""),
    colunas: colunas.map((coluna) => coluna.titulo),
    linhas,
    agrupamento,
    colunasCompactas: true,
    orientacao: "retrato",
    tamanhoFonte: 9,
    margem: 12,
    logoUrl: opcoes.logoCcb ? contexto.logoUrl : undefined, // só a logomarca da CCB; sem o nome do sistema no topo
    informacoes,
    paginacao: opcoes.paginacao,
    assinaturas: opcoes.assinaturas ? ["Responsável pela portaria", "Encarregado Local"] : [],
    rodapeItens,
    geradoEm: contexto.geradoEm,
    abrirImpressao: contexto.abrirImpressao ?? true,
  };
}
