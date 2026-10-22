/** SysMúsica — Tipos do módulo Relatórios. */
import type { OrientacaoPagina } from "@/lib/exportacao";
import type { CodigoPermissao } from "@/lib/permissoes";
import type { NoOrganizacao } from "@/modules/organizacao/tipos";

export type TipoRelatorioId =
  | "presenca"
  | "membros"
  | "eventos"
  | "instrumentos"
  | "cargos"
  | "organizacao"
  | "portarias";

/** Filtros que cada tipo de relatório pode mostrar. */
export type CampoFiltro =
  | "periodo"
  | "evento"
  | "rrm"
  | "regiao"
  | "adm"
  | "setor"
  | "casa_oracao"
  | "cargo"
  | "instrumento"
  | "situacaoMembro"
  | "statusPresenca"
  | "visitante"
  | "situacaoPortaria";

export interface ColunaRelatorio {
  id: string;
  rotulo: string;
  padrao: boolean; // vem marcada ao escolher o tipo
  exigePermissao?: CodigoPermissao; // a coluna só existe para quem tem esta permissão
}

export interface DefinicaoRelatorio {
  id: TipoRelatorioId;
  titulo: string;
  descricao: string;
  permissoes: CodigoPermissao[]; // basta ter UMA para ver este tipo
  filtros: CampoFiltro[];
  colunas: ColunaRelatorio[];
}

/** Uma linha do relatório: valor de cada coluna, já em texto, pelo id da coluna. */
export type LinhaRelatorio = Record<string, string>;

export interface ResultadoRelatorio {
  linhas: LinhaRelatorio[];
  total: number; // total do filtro (pode ser maior que as linhas trazidas, quando passa do limite)
}

export interface FiltrosRelatorio {
  inicio: string; // AAAA-MM-DD ("" = sem limite)
  fim: string;
  eventoId: string;
  rrmId?: string; // RRM escolhida (vazio = todas)
  regiaoId: string;
  admId?: string; // ADM escolhida (vazio = todas)
  setorId: string;
  casaOracaoId: string;
  cargoId: string;
  instrumentoId: string;
  situacao: string; // membros: Ativo/Inativo; portarias: código da situação
  statusPresenca: string; // Presente, Ausente ou Justificado
  visitante: string; // "", "sim" ou "nao"
}

export type AjustePagina = "automatico" | "manual";

/** Margem da página impressa: estreita, normal ou larga (os valores em mm ficam em regras.ts). */
export type MargemPagina = "estreita" | "normal" | "larga";

/** O que pode aparecer no quadro de informações do cabeçalho. */
export type ItemCabecalho =
  | "marca"
  | "evento"
  | "periodo"
  | "localizacao"
  | "filtros"
  | "total"
  | "resumo"
  | "emissao"
  | "emitidoPor";

/** O que pode aparecer no rodapé (além do texto livre). */
export type ItemRodape = "paginacao" | "sistema" | "emitidoPor" | "emissao" | "total";

export interface OpcoesPagina {
  titulo: string;
  rodape: string;
  orientacao: OrientacaoPagina;
  ajuste: AjustePagina;
  escala: string; // zoom em % (só no ajuste manual)
  fonte: string; // tamanho da letra em pt (só no ajuste manual)
  subtitulo: string; // linha opcional sob o título
  margem: MargemPagina;
  cabecalho: Record<ItemCabecalho, boolean>; // o que aparece no quadro do cabeçalho
  rodapeMarcado: Record<ItemRodape, boolean>; // o que aparece no rodapé (o texto livre é o campo "rodape")
  assinaturas: boolean; // mostra as linhas de assinatura no fim
  nomesAssinaturas: string; // nomes das linhas, separados por vírgula
}

export interface EventoFiltro {
  id: string;
  tipo: string;
  data_evento: string;
  local: string;
}

/** Listas dos filtros (já limitadas pelo que o usuário pode ver). */
export interface OpcoesFiltros {
  organizacao: NoOrganizacao[];
  cargos: { id: string; nome: string }[];
  instrumentos: { id: string; nome: string }[];
  eventos: EventoFiltro[];
}
