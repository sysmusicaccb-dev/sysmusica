/**
 * Sysmusica — Restauração do Backup, parte 1 (comparar): regras puras, sem banco nem rede.
 * Compara os dados de UMA tabela no backup com os dados de hoje e separa:
 *   - APAGADOS: estavam no backup e hoje não existem (ou foram excluídos logicamente depois do backup);
 *   - ALTERADOS: existem nos dois, mas com colunas diferentes;
 *   - NOVOS: existem hoje e não estavam no backup (criados depois).
 * "Somente as últimas alterações" é exatamente isto: só as linhas que diferem. Nada é alterado por aqui.
 * Colunas sensíveis (CPF, segredo do QR...) nunca aparecem: viram "(protegido)".
 */
import { chaveDaLinha, type DefinicaoTabela, type GrupoDados, type NomeTabela } from "./tabelas";

export type Linha = Record<string, unknown>;

export const LIMITE_AMOSTRA = 100; // itens de cada categoria que vão para a tela (os totais são sempre exatos)
const MAX_COLUNAS = 12; // colunas mostradas por linha alterada
const MAX_TEXTO = 80;

export interface DiferencaColuna {
  coluna: string;
  antes: string; // valor no backup
  depois: string; // valor de hoje
}

export interface ItemDiferenca {
  chave: string;
  rotulo: string;
  detalhe?: string;
  colunas?: DiferencaColuna[];
}

export interface ResultadoTabela {
  nome: NomeTabela;
  rotulo: string;
  ausente: boolean; // o backup não tem esta tabela (backup antigo): nada a comparar
  noBackup: number;
  hoje: number;
  apagados: number;
  alterados: number;
  novos: number;
  amostraApagados: ItemDiferenca[];
  amostraAlterados: ItemDiferenca[];
  amostraNovos: ItemDiferenca[];
}

export interface ResultadoGrupo {
  id: GrupoDados;
  rotulo: string;
  tabelas: ResultadoTabela[];
}

export interface ResultadoComparacao {
  backup: { id: string; criado_em: string; tipo: string };
  grupos: ResultadoGrupo[];
  totais: { apagados: number; alterados: number; novos: number };
}

/** Texto estável de um valor (chaves de objetos em ordem), para comparar sem falso alarme. */
function canonico(valor: unknown): string {
  if (valor === null || valor === undefined) return "null";
  if (Array.isArray(valor)) return `[${valor.map(canonico).join(",")}]`;
  if (typeof valor === "object") {
    const o = valor as Record<string, unknown>;
    return `{${Object.keys(o).sort().map((k) => `${JSON.stringify(k)}:${canonico(o[k])}`).join(",")}}`;
  }
  return JSON.stringify(valor);
}

function mostrar(def: DefinicaoTabela, coluna: string, valor: unknown): string {
  if (def.sensiveis.includes(coluna)) return "(protegido)";
  if (valor === null || valor === undefined || valor === "") return "(vazio)";
  const texto = typeof valor === "string" ? valor : canonico(valor);
  return texto.length > MAX_TEXTO ? `${texto.slice(0, MAX_TEXTO)}…` : texto;
}

const CAMPOS_ROTULO = ["nome", "titulo", "descricao", "email", "login", "codigo", "permissao_codigo", "sigla"];

/** Um nome legível para a linha (nunca usa colunas sensíveis); na falta, a própria chave. */
export function rotuloDaLinha(def: DefinicaoTabela, linha: Linha): string {
  for (const campo of CAMPOS_ROTULO) {
    const valor = linha[campo];
    if (typeof valor === "string" && valor.trim() !== "" && !def.sensiveis.includes(campo)) return valor.trim().slice(0, 80);
  }
  return chaveDaLinha(def, linha);
}

// Colunas (informadas pelo backup) cujo valor hoje é diferente
function colunasDiferentes(def: DefinicaoTabela, antes: Linha, hoje: Linha): DiferencaColuna[] {
  const lista: DiferencaColuna[] = [];
  for (const coluna of Object.keys(antes)) {
    if (!(coluna in hoje)) continue; // coluna que não existe mais: ignorada
    if (canonico(antes[coluna]) !== canonico(hoje[coluna])) {
      lista.push({ coluna, antes: mostrar(def, coluna, antes[coluna]), depois: mostrar(def, coluna, hoje[coluna]) });
    }
  }
  return lista;
}

/** Compara uma tabela: `backup` = linhas do arquivo (undefined se o backup não tem a tabela), `hoje` = linhas atuais. */
export function compararTabela(def: DefinicaoTabela, backup: Linha[] | undefined, hoje: Linha[]): ResultadoTabela {
  const base = { nome: def.nome, rotulo: def.rotulo };
  if (backup === undefined) {
    return { ...base, ausente: true, noBackup: 0, hoje: hoje.length, apagados: 0, alterados: 0, novos: 0, amostraApagados: [], amostraAlterados: [], amostraNovos: [] };
  }

  const linhasHoje = new Map(hoje.map((linha) => [chaveDaLinha(def, linha), linha] as const));
  const linhasBackup = new Map(backup.map((linha) => [chaveDaLinha(def, linha), linha] as const));

  const apagados: ItemDiferenca[] = [];
  const alterados: ItemDiferenca[] = [];
  const novos: ItemDiferenca[] = [];

  for (const [chave, antes] of linhasBackup) {
    const atual = linhasHoje.get(chave);
    if (!atual) {
      apagados.push({ chave, rotulo: rotuloDaLinha(def, antes), detalhe: "não existe mais" });
      continue;
    }
    const diferencas = colunasDiferentes(def, antes, atual);
    if (diferencas.length === 0) continue;

    // Excluído logicamente depois do backup: conta como "apagado" (restaurar é desfazer a exclusão)
    const excluidoDepois = def.exclusaoLogica && (antes.excluido_em ?? null) === null && (atual.excluido_em ?? null) !== null;
    if (excluidoDepois) {
      apagados.push({ chave, rotulo: rotuloDaLinha(def, antes), detalhe: "excluído depois do backup" });
    } else {
      alterados.push({ chave, rotulo: rotuloDaLinha(def, antes), colunas: diferencas.slice(0, MAX_COLUNAS) });
    }
  }

  for (const [chave, atual] of linhasHoje) {
    if (linhasBackup.has(chave)) continue;
    // criado e já excluído depois do backup: não interessa
    if (def.exclusaoLogica && (atual.excluido_em ?? null) !== null) continue;
    novos.push({ chave, rotulo: rotuloDaLinha(def, atual), detalhe: "criado depois do backup" });
  }

  return {
    ...base,
    ausente: false,
    noBackup: backup.length,
    hoje: hoje.length,
    apagados: apagados.length,
    alterados: alterados.length,
    novos: novos.length,
    amostraApagados: apagados.slice(0, LIMITE_AMOSTRA),
    amostraAlterados: alterados.slice(0, LIMITE_AMOSTRA),
    amostraNovos: novos.slice(0, LIMITE_AMOSTRA),
  };
}

/** Soma dos totais de várias tabelas. */
export function somarTotais(tabelas: ResultadoTabela[]): { apagados: number; alterados: number; novos: number } {
  return tabelas.reduce(
    (soma, t) => ({ apagados: soma.apagados + t.apagados, alterados: soma.alterados + t.alterados, novos: soma.novos + t.novos }),
    { apagados: 0, alterados: 0, novos: 0 }
  );
}

/** Lê o corpo recebido pela rota (id do backup + grupos marcados); nulo se estiver errado. */
export function lerEntradaComparacao(valor: unknown, gruposValidos: string[]): { id: string; grupos: GrupoDados[] } | null {
  if (valor === null || typeof valor !== "object" || Array.isArray(valor)) return null;
  const o = valor as Record<string, unknown>;
  if (typeof o.id !== "string" || !Array.isArray(o.grupos) || o.grupos.length === 0 || o.grupos.length > 20) return null;
  const grupos: GrupoDados[] = [];
  for (const g of o.grupos) {
    if (typeof g !== "string" || !gruposValidos.includes(g)) return null;
    if (!grupos.includes(g as GrupoDados)) grupos.push(g as GrupoDados);
  }
  return { id: o.id, grupos };
}
