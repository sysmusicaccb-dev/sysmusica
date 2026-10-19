/**
 * SysMúsica — Regras puras da entrada na Portaria (sem banco). Testadas em regrasEntrada.test.ts.
 * Quem decide de verdade é o banco (registrar_entrada e registrar_entrada_avulsa conferem tudo de novo);
 * aqui ficam as conferências rápidas para a tela responder na hora.
 */
import type {
  BlocoEntrada,
  EscolhaToca,
  InfoEntrada,
  InstrumentoEntrada,
  LinhaEntrada,
} from "./tiposEntrada";

export const ROTULO_BLOCO_ENTRADA: Record<BlocoEntrada, string> = {
  MINISTERIO: "Ministério",
  MUSICOS: "Músicos",
  ORGANISTAS: "Organistas",
};

const ORDEM_BLOCOS: BlocoEntrada[] = ["MINISTERIO", "MUSICOS", "ORGANISTAS"];

// ---------- Membro cadastrado: "Vai tocar?" ----------

/** Confere a resposta da conferência; devolve a mensagem de erro ou null. */
export function validarEscolhaMembro(info: InfoEntrada | null, escolha: EscolhaToca): string | null {
  if (!info || !info.pergunta_toca) return null;
  if (escolha.toca === null) return "Informe se a pessoa vai tocar.";
  if (escolha.toca && !escolha.instrumentoId && !info.instrumento_id) {
    return "Escolha o instrumento que a pessoa vai tocar.";
  }
  return null;
}

/** Valores a enviar ao banco na entrada de um membro (sem pergunta: nada é enviado). */
export function valoresDaEntrada(
  info: InfoEntrada | null,
  escolha: EscolhaToca
): { toca: boolean | null; instrumentoId: string | null } {
  if (!info || !info.pergunta_toca) return { toca: null, instrumentoId: null };
  return {
    toca: escolha.toca,
    instrumentoId: escolha.toca && escolha.instrumentoId ? escolha.instrumentoId : null,
  };
}

// ---------- Entrada sem cadastro ----------

/** A linha escolhida pede o instrumento? (Músicos sempre; os demais só se a pessoa for tocar) */
export function precisaInstrumento(linha: LinhaEntrada | null, toca: boolean | null): boolean {
  if (!linha || linha.instrumento !== "LIVRE") return false;
  return linha.toca_sempre || (linha.pergunta_toca && toca === true);
}

/** A tela deve perguntar "Vai tocar?" para esta linha? */
export function precisaPerguntar(linha: LinhaEntrada | null): boolean {
  return linha?.pergunta_toca === true;
}

/** Confere a entrada sem cadastro; devolve a mensagem de erro ou null. */
export function validarEntradaAvulsa(dados: {
  linha: LinhaEntrada | null;
  toca: boolean | null;
  instrumentoId: string;
  outraLocalidade: boolean;
  localidadeTexto: string;
}): string | null {
  if (!dados.linha) return "Escolha o cargo ou a categoria da pessoa.";
  if (precisaPerguntar(dados.linha) && dados.toca === null) return "Informe se a pessoa vai tocar.";
  if (precisaInstrumento(dados.linha, dados.toca) && !dados.instrumentoId) {
    return "Escolha o instrumento que a pessoa vai tocar.";
  }
  if (dados.outraLocalidade) {
    const tamanho = dados.localidadeTexto.trim().replace(/\s+/g, " ").length;
    if (tamanho < 2 || tamanho > 120) return "Escreva a localidade (de 2 a 120 letras) ou desmarque a opção.";
  }
  return null;
}

/** Texto da localidade a enviar: nulo quando "Outra" não está marcada ou o campo está vazio. */
export function textoDaLocalidade(outra: boolean, texto: string): string | null {
  if (!outra) return null;
  const limpo = texto.trim().replace(/\s+/g, " ");
  return limpo === "" ? null : limpo;
}

// ---------- Listas para os campos ----------

/** Linhas agrupadas por bloco, na ordem Ministério, Músicos, Organistas. */
export function agruparLinhas(linhas: LinhaEntrada[]): { bloco: BlocoEntrada; rotulo: string; linhas: LinhaEntrada[] }[] {
  return ORDEM_BLOCOS.map((bloco) => ({
    bloco,
    rotulo: ROTULO_BLOCO_ENTRADA[bloco],
    linhas: linhas.filter((linha) => linha.bloco === bloco),
  })).filter((grupo) => grupo.linhas.length > 0);
}

/** Instrumentos agrupados por família (a ordem de chegada do banco é mantida). */
export function agruparInstrumentos(
  instrumentos: InstrumentoEntrada[]
): { familia: string; itens: InstrumentoEntrada[] }[] {
  const grupos = new Map<string, InstrumentoEntrada[]>();
  for (const item of instrumentos) {
    const lista = grupos.get(item.familia) ?? [];
    lista.push(item);
    grupos.set(item.familia, lista);
  }
  return [...grupos.entries()].map(([familia, itens]) => ({ familia, itens }));
}

/** Como a entrada sem cadastro aparece na lista: "Candidato · tocando Clarinete". */
export function descreverAvulsa(entrada: {
  linha_rotulo: string;
  toca: boolean | null;
  instrumento: string | null;
}): string {
  if (entrada.toca === false) return `${entrada.linha_rotulo} · não vai tocar`;
  if (entrada.instrumento) return `${entrada.linha_rotulo} · ${entrada.instrumento}`;
  return entrada.linha_rotulo;
}
