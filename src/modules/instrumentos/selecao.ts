/**
 * SysMúsica — Regras puras do seletor de instrumento (sem banco). Testadas em selecao.test.ts.
 * O mesmo seletor é usado no cadastro de membro e no cadastro de visitante, para a escolha ser sempre
 * igual: lista suspensa agrupada por família, e a família aparece sozinha pelo instrumento escolhido.
 */

export interface InstrumentoOpcao {
  id: string;
  nome: string;
  familia_id: string | null;
}

export interface FamiliaOpcao {
  id: string;
  nome: string;
}

export interface GrupoInstrumentos {
  familiaId: string | null; // nulo = instrumentos sem família
  rotulo: string;
  instrumentos: InstrumentoOpcao[];
}

const ROTULO_SEM_FAMILIA = "Sem família definida";

// Ordem natural em português
const porNome = (a: { nome: string }, b: { nome: string }) => a.nome.localeCompare(b.nome, "pt-BR", { numeric: true });

/** Agrupa os instrumentos por família (famílias em ordem de nome; os sem família vão para o fim). */
export function agruparInstrumentosPorFamilia(
  instrumentos: InstrumentoOpcao[],
  familias: FamiliaOpcao[]
): GrupoInstrumentos[] {
  const conhecidas = new Set(familias.map((familia) => familia.id));
  const porFamilia = new Map<string, InstrumentoOpcao[]>();
  const semFamilia: InstrumentoOpcao[] = [];

  for (const instrumento of instrumentos) {
    if (instrumento.familia_id && conhecidas.has(instrumento.familia_id)) {
      porFamilia.set(instrumento.familia_id, [...(porFamilia.get(instrumento.familia_id) ?? []), instrumento]);
    } else {
      semFamilia.push(instrumento);
    }
  }

  const grupos: GrupoInstrumentos[] = [...familias]
    .filter((familia) => porFamilia.has(familia.id))
    .sort(porNome)
    .map((familia) => ({
      familiaId: familia.id,
      rotulo: familia.nome,
      instrumentos: [...(porFamilia.get(familia.id) ?? [])].sort(porNome),
    }));

  if (semFamilia.length > 0) {
    grupos.push({ familiaId: null, rotulo: ROTULO_SEM_FAMILIA, instrumentos: [...semFamilia].sort(porNome) });
  }
  return grupos;
}

/** Nome da família do instrumento escolhido; nulo se não houver instrumento ou se ele estiver sem família. */
export function nomeDaFamiliaDoInstrumento(
  instrumentoId: string,
  instrumentos: InstrumentoOpcao[],
  familias: FamiliaOpcao[]
): string | null {
  const instrumento = instrumentos.find((item) => item.id === instrumentoId);
  if (!instrumento?.familia_id) return null;
  return familias.find((familia) => familia.id === instrumento.familia_id)?.nome ?? null;
}

/**
 * Regra do instrumento obrigatório: devolve a mensagem de erro ou null.
 * (O banco confere de novo: a tela é só a resposta rápida.)
 */
export function validarInstrumentoDoCargo(
  exige: boolean,
  instrumentoId: string,
  nomeCargo: string | undefined
): string | null {
  if (exige && !instrumentoId) {
    return `O cargo ${nomeCargo ?? "escolhido"} exige o instrumento. Escolha o instrumento na lista.`;
  }
  return null;
}
