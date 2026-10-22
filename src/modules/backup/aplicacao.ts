/**
 * Sysmusica — Restauração, parte 2 (aplicar): regras puras que transformam a comparação em um PLANO de
 * operações para a função backup_aplicar do banco (uma única transação: ou tudo, ou nada).
 *
 * Dois modos:
 *   - RECUPERAR (padrão, seguro): devolve o que foi apagado e desfaz as alterações. NÃO mexe no que foi criado
 *     depois do backup.
 *   - ESPELHAR: além do acima, remove o que foi criado depois do backup (os dados ficam idênticos ao backup).
 *     Nunca remove usuários nem o histórico das portarias.
 */
import { chaveDaLinha, ordenarParaApagar, ordenarParaGravar, type DefinicaoTabela, type GrupoDados, type NomeTabela } from "./tabelas";
import type { Linha } from "./restauracao";

export type ModoRestauracao = "recuperar" | "espelhar";
export const TEXTO_ESPELHAR = "ESPELHAR";

export type AcaoBanco = "inserir" | "atualizar" | "excluir_logico" | "excluir";

export interface OperacaoBanco {
  tabela: NomeTabela;
  acao: AcaoBanco;
  colunas: string[];
  linhas: Linha[];
}

export interface EntradaAplicacao {
  id: string;
  grupos: GrupoDados[];
  modo: ModoRestauracao;
  senha: string;
}

export interface ResultadoOperacao {
  tabela: string;
  acao: string;
  afetados: number;
  ignorados: number;
}

export interface RespostaRestauracao {
  restaurado: boolean;
  mensagem: string;
  operacoes: ResultadoOperacao[];
  segurancaId: string | null;
}

// Tabelas em que o modo Espelhar nunca remove nada
const NUNCA_REMOVER: NomeTabela[] = ["usuarios"];

function canonico(valor: unknown): string {
  if (valor === null || valor === undefined) return "null";
  if (Array.isArray(valor)) return `[${valor.map(canonico).join(",")}]`;
  if (typeof valor === "object") {
    const o = valor as Record<string, unknown>;
    return `{${Object.keys(o).sort().map((k) => `${JSON.stringify(k)}:${canonico(o[k])}`).join(",")}}`;
  }
  return JSON.stringify(valor);
}

function diferente(antes: Linha, hoje: Linha): boolean {
  return Object.keys(antes).some((c) => c in hoje && canonico(antes[c]) !== canonico(hoje[c]));
}

/** Lê o corpo recebido pela rota; nulo se estiver errado. */
export function lerEntradaAplicacao(valor: unknown, gruposValidos: string[]): (EntradaAplicacao & { confirmacao: string }) | null {
  if (valor === null || typeof valor !== "object" || Array.isArray(valor)) return null;
  const o = valor as Record<string, unknown>;
  if (typeof o.id !== "string" || typeof o.senha !== "string" || o.senha === "" || o.senha.length > 200) return null;
  if (o.modo !== "recuperar" && o.modo !== "espelhar") return null;
  if (!Array.isArray(o.grupos) || o.grupos.length === 0 || o.grupos.length > 20) return null;
  const confirmacao = typeof o.confirmacao === "string" ? o.confirmacao : "";
  if (o.modo === "espelhar" && confirmacao !== TEXTO_ESPELHAR) return null;
  const grupos: GrupoDados[] = [];
  for (const g of o.grupos) {
    if (typeof g !== "string" || !gruposValidos.includes(g)) return null;
    if (!grupos.includes(g as GrupoDados)) grupos.push(g as GrupoDados);
  }
  return { id: o.id, grupos, modo: o.modo, senha: o.senha, confirmacao };
}

export interface EntradaTabela {
  def: DefinicaoTabela;
  backup: Linha[] | undefined; // linhas do arquivo (undefined = o backup não tem a tabela: nada a fazer)
  hoje: Linha[];
}

function uniaoDeColunas(linhas: Linha[]): string[] {
  const todas = new Set<string>();
  for (const l of linhas) for (const c of Object.keys(l)) todas.add(c);
  return [...todas];
}

/** Plano de uma tabela: o que devolver, o que desfazer e (no modo Espelhar) o que remover. */
export function planoDaTabela(entrada: EntradaTabela, modo: ModoRestauracao): { inserir: Linha[]; atualizar: Linha[]; remover: Linha[] } {
  const { def, backup, hoje } = entrada;
  const vazio = { inserir: [], atualizar: [], remover: [] };
  if (backup === undefined) return vazio;

  const linhasHoje = new Map(hoje.map((l) => [chaveDaLinha(def, l), l] as const));
  const linhasBackup = new Map(backup.map((l) => [chaveDaLinha(def, l), l] as const));
  const inserir: Linha[] = [];
  const atualizar: Linha[] = [];
  const remover: Linha[] = [];

  for (const [chave, antes] of linhasBackup) {
    const atual = linhasHoje.get(chave);
    if (!atual) {
      inserir.push(antes);
    } else if (!def.somenteInserir && diferente(antes, atual)) {
      atualizar.push(antes); // inclui desfazer exclusão lógica (excluido_em volta ao valor do backup)
    }
  }

  if (modo === "espelhar" && !def.somenteInserir && !NUNCA_REMOVER.includes(def.nome)) {
    for (const [chave, atual] of linhasHoje) {
      if (linhasBackup.has(chave)) continue;
      if (def.exclusaoLogica && (atual.excluido_em ?? null) !== null) continue; // já está excluído
      remover.push(Object.fromEntries(def.pk.map((c) => [c, atual[c]])));
    }
  }
  return { inserir, atualizar, remover };
}

/** Plano completo, na ordem certa: gravar (pais primeiro) e depois remover (filhos primeiro). */
export function montarPlano(entradas: EntradaTabela[], modo: ModoRestauracao): OperacaoBanco[] {
  const porNome = new Map(entradas.map((e) => [e.def.nome, e] as const));
  const planos = new Map(entradas.map((e) => [e.def.nome, planoDaTabela(e, modo)] as const));
  const nomes = entradas.map((e) => e.def.nome);
  const ops: OperacaoBanco[] = [];

  for (const nome of ordenarParaGravar(nomes)) {
    const plano = planos.get(nome);
    const entrada = porNome.get(nome);
    if (!plano || !entrada) continue;
    if (plano.inserir.length > 0) ops.push({ tabela: nome, acao: "inserir", colunas: uniaoDeColunas(plano.inserir), linhas: plano.inserir });
    if (plano.atualizar.length > 0) ops.push({ tabela: nome, acao: "atualizar", colunas: uniaoDeColunas(plano.atualizar), linhas: plano.atualizar });
  }
  for (const nome of ordenarParaApagar(nomes)) {
    const plano = planos.get(nome);
    const entrada = porNome.get(nome);
    if (!plano || !entrada || plano.remover.length === 0) continue;
    ops.push({
      tabela: nome,
      acao: entrada.def.exclusaoLogica ? "excluir_logico" : "excluir",
      colunas: [...entrada.def.pk],
      linhas: plano.remover,
    });
  }
  return ops;
}

export function totalDeLinhasDoPlano(ops: OperacaoBanco[]): number {
  return ops.reduce((soma, op) => soma + op.linhas.length, 0);
}

const ROTULO_ACAO: Record<string, string> = {
  inserir: "devolvidos",
  atualizar: "corrigidos",
  excluir_logico: "removidos",
  excluir: "removidos",
};

/** Texto curto para a tela e para os avisos: "Instrumentos: 1 devolvidos; ...". */
export function resumirOperacoes(ops: ResultadoOperacao[], rotulos: Record<string, string>): string {
  const partes = ops.filter((o) => o.afetados > 0).map((o) => `${rotulos[o.tabela] ?? o.tabela}: ${o.afetados} ${ROTULO_ACAO[o.acao] ?? o.acao}`);
  return partes.length > 0 ? partes.join("; ") : "nenhum registro precisou mudar";
}
