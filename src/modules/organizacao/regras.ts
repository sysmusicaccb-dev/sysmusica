/**
 * Sysmusica — Regras puras da organização (sem banco). Testadas em regras.test.ts.
 * Árvore: Estado › RRM › RA › ADM › Setor (opcional) › Casa de Oração.
 * As regras de verdade (permissão, nomes repetidos, abrangência) ficam no banco; aqui há
 * montagem de listas para a tela e conferências rápidas.
 */
import type { NivelOrganizacao, NoOrganizacao, VinculoRotulado, VinculoUsuario } from "./tipos";

/** Nome curto de cada nível (aparece nas telas). */
export const ROTULO_NIVEL: Record<NivelOrganizacao, string> = {
  ESTADO: "Estado",
  RRM: "RRM",
  RA: "RA",
  ADM: "ADM",
  SETOR: "Setor",
  CASA_ORACAO: "Casa de Oração",
};

/** Significado de cada sigla (dica nas telas). */
export const NOME_COMPLETO_NIVEL: Record<NivelOrganizacao, string> = {
  ESTADO: "Estado",
  RRM: "Reunião Regional Ministerial",
  RA: "Regional Administrativa",
  ADM: "Administração",
  SETOR: "Setor (opcional)",
  CASA_ORACAO: "Casa de Oração",
};

/**
 * Níveis que ficam logo abaixo de cada nível. A ADM tem DOIS tipos de filho: setores e casas de oração
 * ligadas direto a ela (o setor é opcional).
 */
export const FILHOS_DE: Record<NivelOrganizacao, NivelOrganizacao[]> = {
  ESTADO: ["RRM"],
  RRM: ["RA"],
  RA: ["ADM"],
  ADM: ["SETOR", "CASA_ORACAO"],
  SETOR: ["CASA_ORACAO"],
  CASA_ORACAO: [],
};

const NIVEIS: NivelOrganizacao[] = ["ESTADO", "RRM", "RA", "ADM", "SETOR", "CASA_ORACAO"];

// Ordem natural em português ("Setor 2" antes de "Setor 10")
const porNome = (a: NoOrganizacao, b: NoOrganizacao) => a.nome.localeCompare(b.nome, "pt-BR", { numeric: true });

/** Itens de um nível que pertencem a um pai (pai nulo = os do topo / sem pai), em ordem de nome. */
export function filhosDe(nos: NoOrganizacao[], pai: string | null, nivel: NivelOrganizacao): NoOrganizacao[] {
  return nos.filter((no) => no.nivel === nivel && no.parent_id === pai).sort(porNome);
}

/** Todos os filhos diretos de um item, na ordem dos níveis (na ADM: primeiro os setores, depois as casas sem setor). */
export function filhosDoNo(nos: NoOrganizacao[], no: NoOrganizacao): NoOrganizacao[] {
  return FILHOS_DE[no.nivel].flatMap((nivel) => filhosDe(nos, no.id, nivel));
}

/** Os itens acima de um item (do mais alto ao mais próximo). Para quando o pai não existe na lista. */
export function ancestraisDe(nos: NoOrganizacao[], no: NoOrganizacao): NoOrganizacao[] {
  const porId = new Map(nos.map((item) => [item.id, item] as const));
  const caminho: NoOrganizacao[] = [];
  let atual = no.parent_id ? porId.get(no.parent_id) : undefined;
  while (atual && caminho.length < NIVEIS.length) {
    caminho.unshift(atual);
    atual = atual.parent_id ? porId.get(atual.parent_id) : undefined;
  }
  return caminho;
}

const plural = (n: number, singular: string, plurais: string) => `${n} ${n === 1 ? singular : plurais}`;

/**
 * Se o item ainda tem algo dentro (itens filhos ou membros), explica por que não pode ser excluído;
 * senão devolve null. É só uma resposta rápida da tela: o banco confere tudo de novo, inclusive eventos,
 * portarias e usuários vinculados.
 */
export function motivoBloqueioExclusao(no: NoOrganizacao): string | null {
  const filhos = no.qtd_filhos ?? 0;
  const membros = no.qtd_membros ?? 0;

  if (no.nivel === "ESTADO" && filhos > 0) {
    return `"${no.nome}" ainda tem ${plural(filhos, "RRM", "RRMs")}. Exclua as RRMs antes.`;
  }
  if (no.nivel === "RRM" && filhos > 0) {
    return `"${no.nome}" ainda tem ${plural(filhos, "RA", "RAs")}. Exclua as RAs antes.`;
  }
  if (no.nivel === "RA" && filhos > 0) {
    return `"${no.nome}" ainda tem ${plural(filhos, "ADM", "ADMs")}. Exclua as ADMs antes.`;
  }
  if (no.nivel === "ADM" && filhos > 0) {
    return `"${no.nome}" ainda tem ${plural(filhos, "item", "itens")} (setores e casas de oração). Transfira ou exclua esses itens antes.`;
  }
  if (no.nivel === "SETOR" && filhos > 0) {
    return `"${no.nome}" ainda tem ${plural(filhos, "casa de oração", "casas de oração")}. Transfira as casas de oração para outro local antes.`;
  }
  if (no.nivel === "CASA_ORACAO" && membros > 0) {
    return `"${no.nome}" ainda tem ${plural(membros, "membro", "membros")}. Mude os membros para outra casa de oração (ou exclua-os) antes.`;
  }
  return null;
}

/** Valida o nome de um item da organização; devolve a mensagem de erro ou null. */
export function validarNomeNo(nome: string): string | null {
  const tamanho = nome.trim().replace(/\s+/g, " ").length;
  return tamanho < 2 || tamanho > 80 ? "O nome deve ter entre 2 e 80 caracteres." : null;
}

export interface GrupoCasasOracao {
  rotulo: string; // ex.: "Jequié › Ipiaú › Setor 1" (ou "Jequié › Ipiaú" para casas sem setor)
  casasOracao: NoOrganizacao[];
}

/**
 * Agrupa as casas de oração por "RA › ADM › Setor" (com o estado na frente se houver mais de um; o setor
 * só aparece quando a casa tem setor). Casas cujo caminho não está na lista vão para o fim.
 */
export function agruparCasasOracaoParaSelecao(nos: NoOrganizacao[]): GrupoCasasOracao[] {
  const porId = new Map(nos.map((no) => [no.id, no] as const));
  const estados = nos.filter((no) => no.nivel === "ESTADO");
  const grupos = new Map<string, NoOrganizacao[]>();
  const semLocal: NoOrganizacao[] = [];

  for (const casaOracao of nos.filter((no) => no.nivel === "CASA_ORACAO")) {
    const pai = casaOracao.parent_id ? porId.get(casaOracao.parent_id) : undefined;
    const setor = pai?.nivel === "SETOR" ? pai : undefined;
    const adm = setor ? (setor.parent_id ? porId.get(setor.parent_id) : undefined) : pai?.nivel === "ADM" ? pai : undefined;
    const ra = adm?.parent_id ? porId.get(adm.parent_id) : undefined;
    if (!adm || !ra) {
      semLocal.push(casaOracao);
      continue;
    }
    const rrm = ra.parent_id ? porId.get(ra.parent_id) : undefined;
    const estado = rrm?.parent_id ? porId.get(rrm.parent_id) : undefined;
    const prefixo = estados.length > 1 && estado ? `${estado.nome} › ` : "";
    const rotulo = `${prefixo}${ra.nome} › ${adm.nome}${setor ? ` › ${setor.nome}` : ""}`;
    grupos.set(rotulo, [...(grupos.get(rotulo) ?? []), casaOracao]);
  }

  const lista: GrupoCasasOracao[] = [...grupos.entries()]
    .sort(([a], [b]) => a.localeCompare(b, "pt-BR", { numeric: true }))
    .map(([rotulo, casasOracao]) => ({ rotulo, casasOracao: [...casasOracao].sort(porNome) }));
  if (semLocal.length > 0) lista.push({ rotulo: "Sem local definido", casasOracao: [...semLocal].sort(porNome) });
  return lista;
}

export interface OpcaoDestino {
  id: string; // id do setor OU da ADM (o banco reconhece qual é)
  nome: string;
  nivel: "ADM" | "SETOR";
}

export interface GrupoDestinos {
  rotulo: string; // ex.: "Jequié › Ipiaú"
  opcoes: OpcaoDestino[];
}

/**
 * Destinos possíveis de uma transferência, agrupados por ADM ativa: a própria ADM (casa sem setor) e cada
 * setor ativo dela. Itens com algum pai inativo ficam de fora.
 */
export function agruparDestinosTransferencia(nos: NoOrganizacao[]): GrupoDestinos[] {
  const porId = new Map(nos.map((no) => [no.id, no] as const));
  const estados = nos.filter((no) => no.nivel === "ESTADO");
  const grupos: GrupoDestinos[] = [];

  for (const adm of nos.filter((no) => no.nivel === "ADM" && no.ativo !== false)) {
    const ra = adm.parent_id ? porId.get(adm.parent_id) : undefined;
    const rrm = ra?.parent_id ? porId.get(ra.parent_id) : undefined;
    const estado = rrm?.parent_id ? porId.get(rrm.parent_id) : undefined;
    if (!ra || ra.ativo === false || !rrm || rrm.ativo === false) continue;
    const prefixo = estados.length > 1 && estado ? `${estado.nome} › ` : "";
    const setores = filhosDe(nos, adm.id, "SETOR").filter((setor) => setor.ativo !== false);
    grupos.push({
      rotulo: `${prefixo}${ra.nome} › ${adm.nome}`,
      opcoes: [
        { id: adm.id, nome: "Sem setor (direto na ADM)", nivel: "ADM" },
        ...setores.map((setor) => ({ id: setor.id, nome: setor.nome, nivel: "SETOR" as const })),
      ],
    });
  }
  return grupos.sort((a, b) => a.rotulo.localeCompare(b.rotulo, "pt-BR", { numeric: true }));
}

/** Chave única de um vínculo, para guardar em conjuntos (ex.: "SETOR:abc"). */
export function chaveVinculo(nivel: NivelOrganizacao, id: string): string {
  return `${nivel}:${id}`;
}

/** Desfaz a chave de um vínculo; devolve nulo se estiver malformada. */
export function lerChaveVinculo(chave: string): VinculoUsuario | null {
  const posicao = chave.indexOf(":");
  if (posicao < 0) return null;
  const nivel = chave.slice(0, posicao);
  const alvo = chave.slice(posicao + 1);
  if (!NIVEIS.includes(nivel as NivelOrganizacao) || alvo === "") return null;
  return { nivel: nivel as NivelOrganizacao, alvo_id: alvo };
}

/** De { usuario: [vínculos com rótulo] } para { usuario: ["rótulo", ...] } (coluna da tabela de usuários). */
export function rotulosPorUsuario(mapa: Record<string, VinculoRotulado[]>): Record<string, string[]> {
  const resultado: Record<string, string[]> = {};
  for (const [usuarioId, vinculos] of Object.entries(mapa)) {
    resultado[usuarioId] = vinculos.map((vinculo) => vinculo.rotulo);
  }
  return resultado;
}
