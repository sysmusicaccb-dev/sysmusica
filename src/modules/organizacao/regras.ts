/**
 * SysMúsica — Regras puras da organização (sem banco). Testadas em regras.test.ts.
 * As regras de verdade (permissão, nomes repetidos, abrangência) ficam no banco; aqui há
 * montagem de listas para a tela e conferências rápidas.
 */
import type { NivelOrganizacao, NoOrganizacao, VinculoRotulado, VinculoUsuario } from "./tipos";

export const ROTULO_NIVEL: Record<NivelOrganizacao, string> = {
  ESTADO: "Estado",
  REGIAO: "Região",
  SETOR: "Setor",
  CASA_ORACAO: "Casa de Oração",
};

/** Nível que fica logo abaixo de cada nível. */
export const FILHO_DE: Record<NivelOrganizacao, NivelOrganizacao | null> = {
  ESTADO: "REGIAO",
  REGIAO: "SETOR",
  SETOR: "CASA_ORACAO",
  CASA_ORACAO: null,
};

const NIVEIS: NivelOrganizacao[] = ["ESTADO", "REGIAO", "SETOR", "CASA_ORACAO"];

// Ordem natural em português ("Setor 2" antes de "Setor 10")
const porNome = (a: NoOrganizacao, b: NoOrganizacao) => a.nome.localeCompare(b.nome, "pt-BR", { numeric: true });

/** Itens de um nível que pertencem a um pai (pai nulo = os do topo / sem pai), em ordem de nome. */
export function filhosDe(nos: NoOrganizacao[], pai: string | null, nivel: NivelOrganizacao): NoOrganizacao[] {
  return nos.filter((no) => no.nivel === nivel && no.parent_id === pai).sort(porNome);
}

/**
 * Se o item ainda tem algo dentro (itens filhos ou membros), explica por que não pode ser excluído;
 * senão devolve null. É só uma resposta rápida da tela: o banco confere tudo de novo, inclusive eventos,
 * portarias e usuários vinculados.
 */
export function motivoBloqueioExclusao(no: NoOrganizacao): string | null {
  const filhos = no.qtd_filhos ?? 0;
  const membros = no.qtd_membros ?? 0;

  if (no.nivel === "ESTADO" && filhos > 0) {
    return `"${no.nome}" ainda tem ${filhos} ${filhos === 1 ? "região" : "regiões"}. Exclua as regiões antes.`;
  }
  if (no.nivel === "REGIAO" && filhos > 0) {
    return `"${no.nome}" ainda tem ${filhos} ${filhos === 1 ? "setor" : "setores"}. Exclua os setores antes.`;
  }
  if (no.nivel === "SETOR" && filhos > 0) {
    return `"${no.nome}" ainda tem ${filhos} ${filhos === 1 ? "casa de oração" : "casas de oração"}. Transfira as casas de oração para outro setor antes.`;
  }
  if (no.nivel === "CASA_ORACAO" && membros > 0) {
    return `"${no.nome}" ainda tem ${membros} ${membros === 1 ? "membro" : "membros"}. Mude os membros para outra casa de oração (ou exclua-os) antes.`;
  }
  return null;
}

/** Valida o nome de um item da organização; devolve a mensagem de erro ou null. */
export function validarNomeNo(nome: string): string | null {
  const tamanho = nome.trim().replace(/\s+/g, " ").length;
  return tamanho < 2 || tamanho > 80 ? "O nome deve ter entre 2 e 80 caracteres." : null;
}

export interface GrupoCasasOracao {
  rotulo: string; // ex.: "Salvador › Setor 1"
  casasOracao: NoOrganizacao[];
}

/** Agrupa as casas de oração por "Região › Setor" (com o estado na frente se houver mais de um). Casas de Oração sem setor vão para o fim. */
export function agruparCasasOracaoParaSelecao(nos: NoOrganizacao[]): GrupoCasasOracao[] {
  const porChave = new Map(nos.map((no) => [`${no.nivel}:${no.id}`, no] as const));
  const estados = nos.filter((no) => no.nivel === "ESTADO");
  const grupos = new Map<string, NoOrganizacao[]>();
  const semSetor: NoOrganizacao[] = [];

  for (const casaOracao of nos.filter((no) => no.nivel === "CASA_ORACAO")) {
    const setor = casaOracao.parent_id ? porChave.get(`SETOR:${casaOracao.parent_id}`) : undefined;
    const regiao = setor?.parent_id ? porChave.get(`REGIAO:${setor.parent_id}`) : undefined;
    if (!setor || !regiao) {
      semSetor.push(casaOracao);
      continue;
    }
    const estado = regiao.parent_id ? porChave.get(`ESTADO:${regiao.parent_id}`) : undefined;
    const prefixo = estados.length > 1 && estado ? `${estado.nome} › ` : "";
    const rotulo = `${prefixo}${regiao.nome} › ${setor.nome}`;
    grupos.set(rotulo, [...(grupos.get(rotulo) ?? []), casaOracao]);
  }

  const lista: GrupoCasasOracao[] = [...grupos.entries()]
    .sort(([a], [b]) => a.localeCompare(b, "pt-BR", { numeric: true }))
    .map(([rotulo, casasOracao]) => ({ rotulo, casasOracao: [...casasOracao].sort(porNome) }));
  if (semSetor.length > 0) lista.push({ rotulo: "Sem setor definido", casasOracao: [...semSetor].sort(porNome) });
  return lista;
}

export interface GrupoSetores {
  rotulo: string; // ex.: "Salvador" (ou "Bahia › Salvador")
  setores: NoOrganizacao[];
}

/** Agrupa os setores ATIVOS por região (para escolher o destino de uma transferência). */
export function agruparSetoresParaSelecao(nos: NoOrganizacao[]): GrupoSetores[] {
  const porChave = new Map(nos.map((no) => [`${no.nivel}:${no.id}`, no] as const));
  const estados = nos.filter((no) => no.nivel === "ESTADO");
  const grupos = new Map<string, NoOrganizacao[]>();

  for (const setor of nos.filter((no) => no.nivel === "SETOR" && no.ativo !== false)) {
    const regiao = setor.parent_id ? porChave.get(`REGIAO:${setor.parent_id}`) : undefined;
    if (!regiao || regiao.ativo === false) continue;
    const estado = regiao.parent_id ? porChave.get(`ESTADO:${regiao.parent_id}`) : undefined;
    const rotulo = `${estados.length > 1 && estado ? `${estado.nome} › ` : ""}${regiao.nome}`;
    grupos.set(rotulo, [...(grupos.get(rotulo) ?? []), setor]);
  }

  return [...grupos.entries()]
    .sort(([a], [b]) => a.localeCompare(b, "pt-BR", { numeric: true }))
    .map(([rotulo, setores]) => ({ rotulo, setores: [...setores].sort(porNome) }));
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
