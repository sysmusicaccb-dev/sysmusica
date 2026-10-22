/** Sysmusica — Tipos do painel ao vivo (campos = o que as funções do banco devolvem, migração 0026). */

export type BlocoPainel = "MINISTERIO" | "MUSICOS" | "ORGANISTAS";

/** Uma linha do painel (por exemplo, "Encarregado Local") com a quantidade de presentes. */
export interface LinhaPainel {
  codigo: string;
  bloco: BlocoPainel;
  rotulo: string;
  ordem: number;
  qtd: number;
  selecionavel: boolean;
}

/** Quantidade de quem toca instrumentos de uma família (o órgão não entra aqui: conta em Organistas). */
export interface ContagemFamilia {
  familia: string;
  qtd: number;
}

export interface EventoDoPainel {
  id: string;
  tipo: string;
  local: string | null;
  data_evento: string;
  cidade: string | null;
  casa_oracao: string | null;
}

/** Resposta de painel_ao_vivo: só números, nenhuma linha de presença. */
export interface DadosPainel {
  evento: EventoDoPainel;
  total: number;
  linhas: LinhaPainel[];
  instrumentos: ContagemFamilia[];
  atualizado_em: string;
}

/** Um evento da lista para escolher (eventos_do_painel). */
export interface EventoParaEscolher {
  id: string;
  tipo: string;
  local_evento: string | null;
  data_evento: string;
  cidade: string | null;
  casa_oracao_nome: string | null;
}

/** Um bloco pronto para mostrar: Ministério, Músicos ou Organistas. */
export interface BlocoResumo {
  bloco: BlocoPainel;
  rotulo: string;
  total: number;
  linhas: LinhaPainel[];
}

export interface FamiliaResumo {
  nome: string;
  qtd: number;
  percentual: string; // "27,7%"
}

export type TipoCategoria = "musico" | "organista";
