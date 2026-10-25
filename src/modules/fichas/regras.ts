/**
 * Sysmusica — Regras puras do módulo Fichas Musicais (sem banco). Testadas em regras.test.ts.
 * A lista abaixo é o catálogo das fichas da Comissão Musical; "disponivel" fica true quando a tela de
 * preenchimento da ficha existe (as demais aparecem como "em breve").
 */
import type { ResultadoFicha, TipoFicha } from "./tipos";

export interface DefinicaoFicha {
  tipo: TipoFicha;
  codigo: string; // como aparece no papel (ex.: "Formulário M02")
  titulo: string;
  descricao: string;
  disponivel: boolean;
}

export const FICHAS: DefinicaoFicha[] = [
  { tipo: "M02", codigo: "M02", titulo: "Pedido de avaliação de músico — Culto Oficial", descricao: "Avalia o músico para tocar em Culto Oficial. Apto: a categoria do cadastro passa a Culto Oficial.", disponivel: false },
  { tipo: "M03", codigo: "M03", titulo: "Pedido de avaliação de músico — Oficialização", descricao: "Avalia o músico para a Oficialização. Apto: a categoria do cadastro passa a Oficializado.", disponivel: false },
  { tipo: "M05", codigo: "M05", titulo: "Pedido de avaliação de organista", descricao: "Reunião de jovens, Culto Oficial ou Oficialização. Apta: a categoria do cadastro muda conforme o pedido.", disponivel: false },
  { tipo: "M01", codigo: "M01", titulo: "Cadastro para ingresso no GEM", descricao: "Ingresso do aluno no Grupo de Estudos Musicais.", disponivel: false },
  { tipo: "M07", codigo: "M07", titulo: "Pedido de troca de instrumento", descricao: "Apto: o instrumento do cadastro é trocado.", disponivel: false },
  { tipo: "AVALIACAO_RJM", codigo: "RJM", titulo: "Avaliação de músico para RJM", descricao: "Avaliação para a Reunião de Jovens e Menores.", disponivel: false },
  { tipo: "AVALIACAO_CANDIDATO", codigo: "Ficha", titulo: "Ficha de avaliação de candidato a músico", descricao: "Leitura rítmica/métrica e prática instrumental.", disponivel: false },
  { tipo: "PRE_AVALIACAO_ORGANISTA", codigo: "Ficha", titulo: "Pré-avaliação de candidatas a organistas", descricao: "Avaliação teórica e prática da candidata, antes do exame.", disponivel: false },
  { tipo: "EXAME_ORGANISTA", codigo: "Ficha", titulo: "Testes e exames de organistas", descricao: "Teste e exame em cada fase (jovens, Culto Oficial, Oficialização).", disponivel: false },
  { tipo: "ACOMPANHAMENTO_GEM", codigo: "Ficha", titulo: "Ficha de acompanhamento do GEM", descricao: "Aulas, presença e avaliações do aluno.", disponivel: false },
  { tipo: "NECESSIDADE_INSTRUMENTO", codigo: "Formulário", titulo: "Necessidade e entrega de instrumentos e acessórios", descricao: "Pedido, orçamentos, deliberação e recibo de entrega.", disponivel: false },
];

/** Título curto da ficha pelo tipo (usado na lista). */
export function tituloDaFicha(tipo: string): string {
  const def = FICHAS.find((item) => item.tipo === tipo);
  return def ? `${def.codigo === "Ficha" || def.codigo === "Formulário" ? "" : def.codigo + " · "}${def.titulo}` : tipo;
}

/** Texto do resultado: "Apto", "Não apto" ou "Aguardando". */
export function rotuloDoResultado(resultado: ResultadoFicha | null): string {
  if (resultado === "APTO") return "Apto";
  if (resultado === "NAO_APTO") return "Não apto";
  return "Aguardando";
}
