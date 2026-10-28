/** Sysmusica — Tipos do Relatório do Ensaio (o que a função relatorio_ensaio, migração 0083, devolve). */
import type { ConfigEnsaio } from "../perfilConfig";
import type { DadosPainelTotais } from "@/modules/painel/detalhe";

/** O painel que a função devolve: só os números (sem evento nem hora, que vêm no próprio relatório). */
export type PainelRelatorio = Pick<DadosPainelTotais, "total" | "linhas" | "instrumentos" | "instrumentos_detalhe">;

export interface HinoRelatorio {
  categoria: "HINO" | "CORO";
  numero: number;
  nome: string;
}

export interface DadosRelatorio {
  atende_cargo: string | null;
  atende_nome: string | null;
  palavra: string | null;
  extras: Record<string, unknown> | null;
  abertura: HinoRelatorio | null;
  encarregados: { ordem: number; nome: string; cidade_uf: string | null; cargo: string | null }[];
  hinos: HinoRelatorio[];
}

export interface RespostaRelatorioEnsaio {
  evento: {
    id: string;
    tipo: string;
    data_evento: string;
    local: string | null;
    cidade: string | null;
    casa_oracao: string | null;
    modelo_ensaio: string | null; // vazio: o tipo do evento não tem perfil de ensaio
  };
  config: ConfigEnsaio | null;
  dados: DadosRelatorio | null; // vazio: o ensaio ainda não teve os dados registrados
  painel: PainelRelatorio;
  atualizado_em: string;
}
