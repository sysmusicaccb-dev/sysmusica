/**
 * Sysmusica — Regras puras de instrumentos (sem acesso ao banco). Testadas em regras.test.ts.
 */
import { ehNomeDeFamilia } from "@/lib/familias";
import { normalizarTexto } from "@/lib/texto";
import type { Familia, Instrumento } from "@/types/database";

export const NOME_INSTRUMENTO_MAXIMO = 60;

/** Ajusta o nome antes de salvar: tira espaços extras e põe a 1ª letra em maiúscula ("sax  soprano" -> "Sax soprano"). */
export function formatarNomeInstrumento(texto: string): string {
  const limpo = texto.trim().replace(/\s+/g, " ");
  return limpo.charAt(0).toUpperCase() + limpo.slice(1);
}

/**
 * Valida o nome de um instrumento: tamanho, não ser nome de família e não repetir outro
 * (ignorando acento e maiúsculas). Em edição, informe o id do próprio instrumento.
 * Devolve a mensagem de erro ou null quando está tudo certo.
 */
export function validarNomeInstrumento(
  nome: string,
  instrumentos: Instrumento[],
  familias: Familia[],
  idAtual?: string
): string | null {
  const limpo = nome.trim().replace(/\s+/g, " ");
  if (limpo.length < 2) return "Informe o nome do instrumento (mínimo de 2 caracteres).";
  if (limpo.length > NOME_INSTRUMENTO_MAXIMO) {
    return `O nome pode ter no máximo ${NOME_INSTRUMENTO_MAXIMO} caracteres.`;
  }
  if (ehNomeDeFamilia(limpo, familias)) {
    return `"${limpo}" é uma família de instrumentos. Informe o instrumento (ex.: Clarinete).`;
  }

  const chave = normalizarTexto(limpo);
  const repetido = instrumentos.find(
    (instrumento) => instrumento.id !== idAtual && normalizarTexto(instrumento.nome) === chave
  );
  if (repetido) return `Já existe o instrumento "${repetido.nome}".`;

  return null;
}
