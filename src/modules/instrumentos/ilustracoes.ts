/**
 * Sysmusica — Qual ilustração usar para cada instrumento (regras puras, sem banco). Testadas em ilustracoes.test.ts.
 *
 * A escolha é feita pelo NOME do instrumento (sem acento/maiúsculas). Instrumento sem desenho próprio usa o
 * desenho genérico da FAMÍLIA (Cordas, Madeiras, Metais, Teclas); sem família conhecida, uma nota musical.
 * Para incluir um instrumento novo: acrescente uma regra em REGRAS (a primeira que combinar vale) e, se
 * precisar de um desenho novo, em IlustracaoInstrumento.tsx.
 */

export type ChaveDesenho =
  | "clarinete"
  | "clarone"
  | "flauta"
  | "oboe"
  | "sax"
  | "sax_reto"
  | "sax_curvo"
  | "trompete"
  | "flugelhorn"
  | "bombardino"
  | "trombone"
  | "tuba"
  | "acordeon"
  | "orgao"
  | "violino"
  | "nota";

function semAcento(texto: string): string {
  return texto
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .toLowerCase()
    .replace(/\s+/g, " ")
    .trim();
}

/** Regras em ordem: a primeira cujas palavras TODAS aparecem no nome vence (as mais específicas vêm antes). */
const REGRAS: { palavras: string[]; desenho: ChaveDesenho }[] = [
  { palavras: ["clarone"], desenho: "clarone" },
  { palavras: ["clarinete", "alto"], desenho: "clarone" },
  { palavras: ["clarinete", "baixo"], desenho: "clarone" },
  { palavras: ["clarinete"], desenho: "clarinete" },
  { palavras: ["flauta"], desenho: "flauta" },
  { palavras: ["flautim"], desenho: "flauta" },
  { palavras: ["obo"], desenho: "oboe" },
  { palavras: ["sax", "curvo"], desenho: "sax_curvo" },
  { palavras: ["sax", "reto"], desenho: "sax_reto" },
  { palavras: ["sax"], desenho: "sax" },
  { palavras: ["flugel"], desenho: "flugelhorn" },
  { palavras: ["trompete"], desenho: "trompete" },
  { palavras: ["cornet"], desenho: "trompete" },
  { palavras: ["bombardino"], desenho: "bombardino" },
  { palavras: ["eufonio"], desenho: "bombardino" },
  { palavras: ["trombone"], desenho: "trombone" },
  { palavras: ["tuba"], desenho: "tuba" },
  { palavras: ["sousafone"], desenho: "tuba" },
  { palavras: ["acordeon"], desenho: "acordeon" },
  { palavras: ["acordeao"], desenho: "acordeon" },
  { palavras: ["sanfona"], desenho: "acordeon" },
  { palavras: ["orgao"], desenho: "orgao" },
  { palavras: ["teclado"], desenho: "orgao" },
  { palavras: ["violino"], desenho: "violino" },
  { palavras: ["viola"], desenho: "violino" },
  { palavras: ["violoncelo"], desenho: "violino" },
  { palavras: ["contrabaixo"], desenho: "violino" },
];

/** Desenho genérico de cada família (palavra que aparece no nome da família; "metai" cobre Metais). */
const DESENHO_DA_FAMILIA: { palavra: string; desenho: ChaveDesenho }[] = [
  { palavra: "corda", desenho: "violino" },
  { palavra: "madeira", desenho: "clarinete" },
  { palavra: "metai", desenho: "trompete" },
  { palavra: "tecla", desenho: "orgao" },
];

/** Desenho do instrumento: pelo nome; se não houver, pela família; se não houver, a nota musical. */
export function escolherDesenho(nomeInstrumento: string, nomeFamilia?: string | null): ChaveDesenho {
  const nome = semAcento(nomeInstrumento);
  const achada = REGRAS.find((regra) => regra.palavras.every((palavra) => nome.includes(palavra)));
  if (achada) return achada.desenho;

  const familia = semAcento(nomeFamilia ?? "");
  return DESENHO_DA_FAMILIA.find((item) => familia.includes(item.palavra))?.desenho ?? "nota";
}
