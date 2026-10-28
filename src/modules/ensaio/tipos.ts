/** Sysmusica — Tipos do módulo Dados do Ensaio (campos = o que as funções do banco devolvem, migração 0041). */
import type { ModeloEnsaio } from "@/modules/tiposEvento/regras";
import type { ConfigEnsaio } from "./perfilConfig";

export type CargoAtende = "ANCIAO" | "DIACONO" | "COOPERADOR_OFICIO" | "COOPERADOR_RJM";

/** Um ensaio da lista para escolher (eventos_para_ensaio). */
export interface EventoParaEnsaio {
  id: string;
  tipo: string;
  modelo_ensaio: ModeloEnsaio;
  data_evento: string;
  local_evento: string | null;
  cidade: string | null;
  casa_oracao_nome: string | null;
  preenchido: boolean;
  encerrado: boolean;
}

/** O evento como obter_dados_ensaio devolve (inclui as situações que decidem se dá para preencher). */
export interface EventoDoEnsaio {
  id: string;
  tipo: string;
  modelo_ensaio: ModeloEnsaio;
  data_evento: string;
  local: string | null;
  cidade: string | null;
  casa_oracao: string | null;
  cancelado: boolean;
  iniciado: boolean; // já passou de 2h antes do horário
  encerrado: boolean; // já passou de 3h depois do horário
}

export interface EncarregadoSalvo {
  ordem: number;
  nome: string;
  cidade_uf: string | null; // vazio quando o perfil não pede a cidade
  cargo?: string | null; // REGIONAL, LOCAL ou INSTRUTOR (vazio nos ensaios antigos)
}

/** Dados já gravados do ensaio. */
export interface DadosSalvos {
  atende_cargo: CargoAtende | null; // vazio quando o perfil não usa "Quem atendeu"
  atende_nome: string | null;
  palavra: string | null;
  hino_abertura_id: string | null; // vazio quando não houve hino de abertura
  atualizado_em: string;
  encarregados: EncarregadoSalvo[];
  hinos: string[]; // ids dos hinos executados, na ordem
}

export interface RespostaEnsaio {
  evento: EventoDoEnsaio;
  /** O banco já calcula: tem a permissão e o ensaio está dentro do prazo (ou é o Administrador). */
  pode_editar: boolean;
  dados: DadosSalvos | null;
  /** Campos que o perfil do tipo de evento manda mostrar (o banco já manda normalizada). */
  config?: ConfigEnsaio;
}

/** O que a tela envia para salvar_dados_ensaio. */
export interface CargaEnsaio {
  atende_cargo: CargoAtende;
  atende_nome: string;
  palavra: string | null;
  hino_abertura_id: string;
  encarregados: { nome: string; cidade_uf: string }[];
  hinos: string[];
}
