/**
 * SysMúsica — Classificação de instrumentos em famílias (Cordas, Madeiras, Metais, Teclas...).
 *
 * ATENÇÃO: este algoritmo é o MESMO da função SQL inferir_familia_instrumento
 * (supabase/schema.sql). Aqui ele serve para MOSTRAR a família antes de salvar; o banco
 * repete a classificação no INSERT. Se mudar a lógica de um lado, mude do outro.
 *
 * Regra: o nome do instrumento é normalizado (minúsculas, sem acento) e a família escolhida
 * é a que tiver a palavra-chave MAIS LONGA contida no nome
 * (ex: "saxhorn" em Metais vence "sax" em Madeiras).
 */
import { normalizarTexto } from "@/lib/texto";
import type { Familia } from "@/types/database";

/** Devolve a família do instrumento, ou null quando nenhuma palavra-chave casar. */
export function inferirFamilia(nomeInstrumento: string, familias: Familia[]): Familia | null {
  const nome = normalizarTexto(nomeInstrumento);
  if (nome === "") return null;

  let melhorFamilia: Familia | null = null;
  let melhorTamanho = 0;

  for (const familia of familias) {
    for (const palavra of familia.palavras_chave) {
      if (palavra !== "" && nome.includes(palavra) && palavra.length > melhorTamanho) {
        melhorFamilia = familia;
        melhorTamanho = palavra.length;
      }
    }
  }

  return melhorFamilia;
}

/** True quando o texto é o nome de uma família (ex: "Madeiras"), e não de um instrumento. */
export function ehNomeDeFamilia(nome: string, familias: Familia[]): boolean {
  const chave = normalizarTexto(nome);
  return chave !== "" && familias.some((familia) => normalizarTexto(familia.nome) === chave);
}
