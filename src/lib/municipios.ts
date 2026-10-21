/**
 * SysMúsica — Municípios do Brasil (lista oficial do IBGE) e texto da localidade de origem.
 *
 * Usado onde a pessoa informa uma cidade que não está cadastrada no sistema (ex.: Portaria > Entrada sem
 * cadastro; futuramente, encarregados do ensaio). A lista vem do serviço público do IBGE, por estado, e fica
 * guardada na memória do navegador enquanto a página está aberta. Se o serviço estiver fora do ar, a tela
 * deixa digitar a cidade à mão (as funções puras abaixo continuam valendo).
 * Funções puras testadas em municipios.test.ts.
 */

export const UFS_BRASIL = [
  "AC", "AL", "AP", "AM", "BA", "CE", "DF", "ES", "GO", "MA", "MT", "MS", "MG", "PA",
  "PB", "PR", "PE", "PI", "RJ", "RN", "RS", "RO", "RR", "SC", "SP", "SE", "TO",
] as const;

/** Tamanho máximo do nome da casa de oração digitada (o texto final cabe em 120 caracteres). */
export const MAXIMO_NOME_CASA = 70;

function semAcento(texto: string): string {
  return texto
    .normalize("NFD")
    .replace(/[̀-ͯ]/g, "")
    .toLowerCase()
    .replace(/\s+/g, " ")
    .trim();
}

/** Nomes dos municípios na resposta do IBGE (ordem alfabética; ignora itens fora do formato). */
export function extrairNomesDeMunicipios(json: unknown): string[] {
  if (!Array.isArray(json)) return [];
  const nomes = json
    .map((item) => (item && typeof item === "object" ? (item as { nome?: unknown }).nome : undefined))
    .filter((nome): nome is string => typeof nome === "string" && nome.trim() !== "");
  return [...new Set(nomes)].sort((a, b) => a.localeCompare(b, "pt-BR"));
}

/** Nome oficial do município que corresponde ao texto digitado (sem acento/maiúsculas), ou null. */
export function acharMunicipio(lista: string[], texto: string): string | null {
  const alvo = semAcento(texto);
  if (alvo === "") return null;
  return lista.find((nome) => semAcento(nome) === alvo) ?? null;
}

/** "Casa de Oração Centro - Jequié/BA" (vazio se faltar algum dado). */
export function montarLocalidadeTexto(casa: string, cidade: string, uf: string): string {
  const c = casa.trim();
  const m = cidade.trim();
  const u = uf.trim();
  return c && m && u ? `${c} - ${m}/${u}` : "";
}

/** Casa de oração fora da lista: nome, estado e cidade são obrigatórios. Devolve a mensagem ou null. */
export function validarLocalidadeAvulsa(dados: { casa: string; cidade: string; uf: string }): string | null {
  if (dados.casa.trim() === "") return "Informe o nome da casa de oração.";
  if (dados.uf.trim() === "") return "Escolha o estado (UF) da casa de oração.";
  if (dados.cidade.trim() === "") return "Escolha a cidade da casa de oração.";
  return null;
}

// ---------- Busca online (IBGE) ----------

const cache = new Map<string, string[]>();

/** Municípios de um estado (sigla), direto do IBGE. Lança erro se o serviço não responder. */
export async function listarMunicipios(uf: string): Promise<string[]> {
  const guardado = cache.get(uf);
  if (guardado) return guardado;

  const controle = new AbortController();
  const limite = setTimeout(() => controle.abort(), 10_000);
  try {
    const resposta = await fetch(
      `https://servicodados.ibge.gov.br/api/v1/localidades/estados/${encodeURIComponent(uf)}/municipios?orderBy=nome`,
      { signal: controle.signal }
    );
    if (!resposta.ok) throw new Error(`IBGE respondeu ${resposta.status}`);
    const nomes = extrairNomesDeMunicipios(await resposta.json());
    if (nomes.length === 0) throw new Error("Lista de municípios vazia");
    cache.set(uf, nomes);
    return nomes;
  } finally {
    clearTimeout(limite);
  }
}
