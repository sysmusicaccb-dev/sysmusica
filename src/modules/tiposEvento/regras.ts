/**
 * Sysmusica — Regras puras dos Tipos de evento (sem banco). Testadas em regras.test.ts.
 *
 * O tipo do evento (Ensaio Regional, Ensaio Local, Culto Oficial...) é um cadastro. Cada tipo diz se usa a tela
 * "Dados do Ensaio" e em qual modelo: LOCAL, REGIONAL ou nenhum. As mesmas regras valem no banco (migração 0041).
 */
import { normalizarTexto } from "@/lib/texto";

export type ModeloEnsaio = "LOCAL" | "REGIONAL";

/** Um tipo como a função listar_tipos_evento devolve. */
export interface TipoEvento {
  id: string;
  nome: string;
  descricao: string | null;
  modelo_ensaio: ModeloEnsaio | null; // nulo = o tipo não usa a tela Dados do Ensaio
  ativo: boolean;
  em_uso: number; // quantos eventos usam o tipo (tipo usado não pode ser excluído, só desativado)
}

export const NOME_MINIMO = 3;
export const NOME_MAXIMO = 60;
export const DESCRICAO_MAXIMA = 200;

export const ROTULO_MODELO: Record<ModeloEnsaio, string> = {
  LOCAL: "Ensaio Local",
  REGIONAL: "Ensaio Regional",
};

/** Texto para a coluna "Dados do Ensaio" da tabela. */
export function rotuloDoModelo(modelo: ModeloEnsaio | null): string {
  return modelo ? ROTULO_MODELO[modelo] : "Não usa";
}

/** Tira espaços das pontas e os repetidos. */
export function formatarNomeTipo(texto: string): string {
  return texto.trim().replace(/\s+/g, " ");
}

/** Confere o formulário; devolve a mensagem de erro ou null quando está tudo certo. */
export function validarTipoEvento(
  dados: { nome: string; descricao: string },
  existentes: Pick<TipoEvento, "id" | "nome">[],
  idEmEdicao?: string
): string | null {
  const nome = formatarNomeTipo(dados.nome);
  if (nome.length < NOME_MINIMO) return `Informe o nome do tipo de evento (mínimo de ${NOME_MINIMO} caracteres).`;
  if (nome.length > NOME_MAXIMO) return `O nome pode ter no máximo ${NOME_MAXIMO} caracteres.`;
  if (dados.descricao.trim().length > DESCRICAO_MAXIMA) {
    return `A descrição pode ter no máximo ${DESCRICAO_MAXIMA} caracteres.`;
  }
  const chave = normalizarTexto(nome);
  if (existentes.some((tipo) => tipo.id !== idEmEdicao && normalizarTexto(tipo.nome) === chave)) {
    return "Já existe um tipo de evento com este nome.";
  }
  return null;
}

/** Filtra a tabela pela busca no nome ou na descrição (sem acento, sem diferenciar maiúsculas). */
export function filtrarTipos<T extends Pick<TipoEvento, "nome" | "descricao">>(lista: T[], busca: string): T[] {
  const termo = normalizarTexto(busca);
  if (termo === "") return lista;
  return lista.filter(
    (tipo) => normalizarTexto(tipo.nome).includes(termo) || normalizarTexto(tipo.descricao ?? "").includes(termo)
  );
}

/**
 * Tipos que podem ser escolhidos no formulário de evento: os ativos e, ao editar, também o tipo atual do evento
 * (mesmo que já tenha sido desativado), para a tela não "perder" a escolha.
 */
export function tiposParaEscolher<T extends Pick<TipoEvento, "id" | "ativo">>(lista: T[], idAtual: string | null): T[] {
  return lista.filter((tipo) => tipo.ativo || tipo.id === idAtual);
}

/** Divide a lista em páginas. A página pedida é ajustada ao limite (ex.: depois de excluir o último item). */
export function paginar<T>(lista: T[], pagina: number, tamanho: number): { itens: T[]; pagina: number; totalPaginas: number } {
  const totalPaginas = Math.max(1, Math.ceil(lista.length / tamanho));
  const atual = Math.min(Math.max(1, Math.trunc(pagina) || 1), totalPaginas);
  const inicio = (atual - 1) * tamanho;
  return { itens: lista.slice(inicio, inicio + tamanho), pagina: atual, totalPaginas };
}

/** Números de página a mostrar; null = reticências ("…"). Ex.: 1 … 4 5 6 … 10. */
export function paginasVisiveis(atual: number, total: number): (number | null)[] {
  if (total <= 7) return Array.from({ length: total }, (_, i) => i + 1);
  const numeros = [...new Set([1, total, atual - 1, atual, atual + 1])]
    .filter((n) => n >= 1 && n <= total)
    .sort((a, b) => a - b);
  const saida: (number | null)[] = [];
  let anterior = 0;
  for (const n of numeros) {
    if (n - anterior > 1) saida.push(null);
    saida.push(n);
    anterior = n;
  }
  return saida;
}
