/**
 * Sysmusica — Guias (abas) de Administrativo > Fichas Musicais (regra pura, sem tela).
 * Formulários Musicais: Músicos (Oficialização, Culto Oficial, RJM) | Organistas (Oficialização, Culto Oficial, RJM)
 * | GEM (Músicos, Organistas) | Outros (troca de instrumento e necessidade de instrumentos).
 * Cada guia/sub-guia lista as fichas que pertencem àquela etapa. A ficha M05 aparece em cada etapa das
 * organistas já com o destino ("para") marcado.
 */
import type { DestinoOrganista } from "./dados";
import type { TipoFicha } from "./tipos";

export interface ItemDaGuia {
  tipo: TipoFicha;
  para?: DestinoOrganista; // só M05: etapa para a qual o pedido é feito
}

export interface SubGuia {
  id: string;
  rotulo: string;
  itens: ItemDaGuia[];
}

export interface Guia {
  id: string;
  rotulo: string;
  subguias: SubGuia[];
}

export const GUIAS: Guia[] = [
  {
    id: "musicos",
    rotulo: "Músicos",
    subguias: [
      { id: "oficializacao", rotulo: "Oficialização", itens: [{ tipo: "M03" }] },
      { id: "culto-oficial", rotulo: "Culto Oficial", itens: [{ tipo: "M02" }] },
      // Quem ainda está sem etapa: avaliação de candidato e avaliação para a RJM
      { id: "rjm", rotulo: "RJM", itens: [{ tipo: "AVALIACAO_CANDIDATO" }, { tipo: "AVALIACAO_RJM" }] },
    ],
  },
  {
    id: "organistas",
    rotulo: "Organistas",
    subguias: [
      { id: "oficializacao", rotulo: "Oficialização", itens: [{ tipo: "M05", para: "OFICIALIZADO" }, { tipo: "EXAME_ORGANISTA" }] },
      { id: "culto-oficial", rotulo: "Culto Oficial", itens: [{ tipo: "M05", para: "CULTO_OFICIAL" }, { tipo: "EXAME_ORGANISTA" }] },
      { id: "rjm", rotulo: "RJM", itens: [{ tipo: "PRE_AVALIACAO_ORGANISTA" }, { tipo: "M05", para: "RJM" }, { tipo: "EXAME_ORGANISTA" }] },
    ],
  },
  {
    id: "gem",
    rotulo: "GEM",
    subguias: [
      { id: "musicos", rotulo: "Músicos", itens: [{ tipo: "M01" }, { tipo: "ACOMPANHAMENTO_GEM" }] },
      { id: "organistas", rotulo: "Organistas", itens: [{ tipo: "M01" }, { tipo: "ACOMPANHAMENTO_GEM" }] },
    ],
  },
  {
    id: "outros",
    rotulo: "Outros",
    subguias: [{ id: "geral", rotulo: "Outros", itens: [{ tipo: "M07" }, { tipo: "NECESSIDADE_INSTRUMENTO" }] }],
  },
];

export const GUIA_PADRAO = GUIAS[0].id;

/** Guia pelo id (cai na primeira se o id não existir). */
export function acharGuia(id: string): Guia {
  return GUIAS.find((g) => g.id === id) ?? GUIAS[0];
}

/** Sub-guia pelo id dentro da guia (cai na primeira se não existir). */
export function acharSubguia(guiaId: string, subId: string): SubGuia {
  const guia = acharGuia(guiaId);
  return guia.subguias.find((s) => s.id === subId) ?? guia.subguias[0];
}

/** Tipos de ficha da sub-guia, sem repetição (usado para filtrar a lista de fichas preenchidas). */
export function tiposDaSubguia(guiaId: string, subId: string): TipoFicha[] {
  return Array.from(new Set(acharSubguia(guiaId, subId).itens.map((i) => i.tipo)));
}
