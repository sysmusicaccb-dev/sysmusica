/**
 * SysMúsica — Quais tabelas entram no backup, em que ordem e como se relacionam.
 * A ordem de TABELAS é a de dependência: quem é "pai" vem antes de quem o usa. Na restauração, o que é
 * gravado segue essa ordem e o que é apagado segue a ordem inversa.
 * Para incluir uma tabela nova no backup: acrescente aqui e na lista permitida da função backup_aplicar (banco).
 */

export type GrupoDados =
  | "organizacao"
  | "cadastros"
  | "grupos"
  | "usuarios"
  | "membros"
  | "eventos"
  | "portarias"
  | "presencas";

export type NomeTabela =
  | "estados"
  | "regioes"
  | "setores"
  | "comuns"
  | "familias"
  | "cargos"
  | "finalidades_evento"
  | "instrumentos"
  | "grupos"
  | "grupo_permissoes"
  | "usuarios"
  | "usuario_grupos"
  | "usuario_vinculos"
  | "membros"
  | "eventos"
  | "portarias"
  | "portarias_historico"
  | "presencas";

export interface ReferenciaTabela {
  coluna: string; // coluna que aponta para o "pai"
  tabela: NomeTabela; // tabela "pai" (a coluna aponta para o campo id dela)
}

export interface DefinicaoTabela {
  nome: NomeTabela;
  rotulo: string;
  grupo: GrupoDados;
  pk: string[];
  exclusaoLogica: boolean; // tem a coluna excluido_em
  somenteInserir: boolean; // histórico: só se devolve o que foi apagado, nunca se altera
  referencias: ReferenciaTabela[];
  sensiveis: string[]; // colunas que NUNCA vão para o navegador (aparecem como "(protegido)")
}

export interface DefinicaoGrupo {
  id: GrupoDados;
  rotulo: string;
  descricao: string;
  tabelas: NomeTabela[];
}

function tabela(
  nome: NomeTabela,
  rotulo: string,
  grupo: GrupoDados,
  extras: Partial<Omit<DefinicaoTabela, "nome" | "rotulo" | "grupo">> = {}
): DefinicaoTabela {
  return {
    nome,
    rotulo,
    grupo,
    pk: ["id"],
    exclusaoLogica: false,
    somenteInserir: false,
    referencias: [],
    sensiveis: [],
    ...extras,
  };
}

/** Todas as tabelas do backup, em ordem de dependência (pais primeiro). */
export const TABELAS: DefinicaoTabela[] = [
  tabela("estados", "Estados", "organizacao"),
  tabela("regioes", "Regiões", "organizacao", { referencias: [{ coluna: "estado_id", tabela: "estados" }] }),
  tabela("setores", "Setores", "organizacao", { referencias: [{ coluna: "regiao_id", tabela: "regioes" }] }),
  tabela("comuns", "Comuns", "organizacao", { referencias: [{ coluna: "setor_id", tabela: "setores" }] }),
  tabela("familias", "Famílias de instrumentos", "cadastros"),
  tabela("cargos", "Cargos", "cadastros"),
  tabela("finalidades_evento", "Finalidades de evento", "cadastros"),
  tabela("instrumentos", "Instrumentos", "cadastros", {
    referencias: [{ coluna: "familia_id", tabela: "familias" }],
  }),
  tabela("grupos", "Grupos de acesso", "grupos"),
  tabela("grupo_permissoes", "Permissões dos grupos", "grupos", {
    pk: ["grupo_id", "permissao_codigo"],
    referencias: [{ coluna: "grupo_id", tabela: "grupos" }],
  }),
  tabela("usuarios", "Usuários", "usuarios", { referencias: [{ coluna: "grupo_id", tabela: "grupos" }] }),
  tabela("usuario_grupos", "Grupos de cada usuário", "usuarios", {
    pk: ["usuario_id", "grupo_id"],
    referencias: [
      { coluna: "usuario_id", tabela: "usuarios" },
      { coluna: "grupo_id", tabela: "grupos" },
    ],
  }),
  tabela("usuario_vinculos", "Vínculos dos usuários", "usuarios", {
    pk: ["usuario_id", "nivel", "alvo_id"],
    referencias: [{ coluna: "usuario_id", tabela: "usuarios" }],
  }),
  tabela("membros", "Membros", "membros", {
    exclusaoLogica: true,
    sensiveis: ["cpf", "cpf_mascarado", "qr_secret"],
    referencias: [
      { coluna: "cargo_id", tabela: "cargos" },
      { coluna: "instrumento_id", tabela: "instrumentos" },
      { coluna: "comum_id", tabela: "comuns" },
      { coluna: "origem_comum_id", tabela: "comuns" },
    ],
  }),
  tabela("eventos", "Eventos", "eventos", {
    exclusaoLogica: true,
    referencias: [
      { coluna: "finalidade_id", tabela: "finalidades_evento" },
      { coluna: "comum_id", tabela: "comuns" },
    ],
  }),
  tabela("portarias", "Portarias", "portarias", {
    exclusaoLogica: true,
    referencias: [
      { coluna: "evento_id", tabela: "eventos" },
      { coluna: "criada_por", tabela: "usuarios" },
      { coluna: "decidida_por", tabela: "usuarios" },
      { coluna: "comum_id", tabela: "comuns" },
    ],
  }),
  tabela("portarias_historico", "Histórico das portarias", "portarias", {
    somenteInserir: true,
    referencias: [{ coluna: "portaria_id", tabela: "portarias" }],
  }),
  tabela("presencas", "Presenças", "presencas", {
    exclusaoLogica: true,
    referencias: [
      { coluna: "evento_id", tabela: "eventos" },
      { coluna: "membro_id", tabela: "membros" },
      { coluna: "portaria_id", tabela: "portarias" },
      { coluna: "registrado_por", tabela: "usuarios" },
    ],
  }),
];

/** Os grupos de dados que o administrador escolhe na hora de restaurar. */
export const GRUPOS_DADOS: DefinicaoGrupo[] = [
  {
    id: "organizacao",
    rotulo: "Organização",
    descricao: "Estados, regiões, setores e comuns",
    tabelas: ["estados", "regioes", "setores", "comuns"],
  },
  {
    id: "cadastros",
    rotulo: "Cargos, instrumentos e famílias",
    descricao: "Cargos, famílias, instrumentos e finalidades de evento",
    tabelas: ["familias", "cargos", "finalidades_evento", "instrumentos"],
  },
  {
    id: "grupos",
    rotulo: "Grupos e permissões",
    descricao: "Grupos de acesso e as permissões de cada um",
    tabelas: ["grupos", "grupo_permissoes"],
  },
  {
    id: "usuarios",
    rotulo: "Usuários",
    descricao: "Perfil, grupos e vínculos (a senha não é guardada no backup)",
    tabelas: ["usuarios", "usuario_grupos", "usuario_vinculos"],
  },
  {
    id: "membros",
    rotulo: "Membros",
    descricao: "Cadastro de membros (a fotografia entra em uma etapa posterior)",
    tabelas: ["membros"],
  },
  {
    id: "eventos",
    rotulo: "Eventos",
    descricao: "Eventos cadastrados",
    tabelas: ["eventos"],
  },
  {
    id: "portarias",
    rotulo: "Portarias",
    descricao: "Portarias e o histórico delas",
    tabelas: ["portarias", "portarias_historico"],
  },
  {
    id: "presencas",
    rotulo: "Presenças",
    descricao: "Presenças registradas nos eventos",
    tabelas: ["presencas"],
  },
];

const INDICE = new Map<NomeTabela, number>(TABELAS.map((item, indice) => [item.nome, indice] as const));

/** Dados de uma tabela (erro claro se o nome não existir). */
export function tabelaPorNome(nome: NomeTabela): DefinicaoTabela {
  const encontrada = TABELAS.find((item) => item.nome === nome);
  if (!encontrada) throw new Error(`Tabela desconhecida no backup: ${nome}`);
  return encontrada;
}

/** Tabelas de um grupo de dados, em ordem de dependência. */
export function tabelasDoGrupo(grupo: GrupoDados): DefinicaoTabela[] {
  return TABELAS.filter((item) => item.grupo === grupo);
}

/** Ordem para GRAVAR: pais primeiro. Remove repetidas e não altera a lista original. */
export function ordenarParaGravar(nomes: NomeTabela[]): NomeTabela[] {
  return [...new Set(nomes)].sort((a, b) => (INDICE.get(a) ?? 0) - (INDICE.get(b) ?? 0));
}

/** Ordem para APAGAR: filhos primeiro (o inverso da ordem de gravação). */
export function ordenarParaApagar(nomes: NomeTabela[]): NomeTabela[] {
  return ordenarParaGravar(nomes).reverse();
}

/** Identificador de uma linha pela chave primária (ex.: "uuid" ou "grupo|permissao"). */
export function chaveDaLinha(definicao: DefinicaoTabela, linha: Record<string, unknown>): string {
  return definicao.pk.map((coluna) => String(linha[coluna] ?? "")).join("|");
}
