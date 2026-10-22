/**
 * Sysmusica — Busca de cidade (regra pura) para o campo Cidade-UF dos encarregados.
 * A lista de municípios vem do IBGE (services/cidades.ts); aqui ficam a leitura da resposta e a busca.
 */
import { SIGLAS_UF } from "./regras";

export interface Cidade {
  nome: string;
  uf: string;
}

/** Texto gravado: "São Paulo-SP". */
export function rotuloDaCidade(cidade: Cidade): string {
  return `${cidade.nome}-${cidade.uf}`;
}

function semAcento(texto: string): string {
  return texto.normalize("NFD").replace(/[̀-ͯ]/g, "").toLowerCase().replace(/\s+/g, " ").trim();
}

/**
 * Lê a resposta da API de municípios do IBGE. Aceita as duas formas em que o estado vem
 * (microrregiao > mesorregiao > UF, ou regiao-imediata > regiao-intermediaria > UF) e ignora o que não for válido.
 */
export function lerMunicipiosDoIbge(resposta: unknown): Cidade[] {
  if (!Array.isArray(resposta)) return [];
  const cidades: Cidade[] = [];
  for (const item of resposta) {
    if (typeof item !== "object" || item === null) continue;
    const registro = item as Record<string, unknown>;
    const nome = typeof registro.nome === "string" ? registro.nome.trim() : "";
    const uf = siglaDoEstado(registro);
    if (nome !== "" && uf !== null) cidades.push({ nome, uf });
  }
  return cidades;
}

function pegar(objeto: unknown, ...caminho: string[]): unknown {
  let atual: unknown = objeto;
  for (const chave of caminho) {
    if (typeof atual !== "object" || atual === null) return undefined;
    atual = (atual as Record<string, unknown>)[chave];
  }
  return atual;
}

function siglaDoEstado(registro: Record<string, unknown>): string | null {
  const candidatos = [
    pegar(registro, "microrregiao", "mesorregiao", "UF", "sigla"),
    pegar(registro, "regiao-imediata", "regiao-intermediaria", "UF", "sigla"),
  ];
  for (const candidato of candidatos) {
    if (typeof candidato === "string" && /^[A-Z]{2}$/.test(candidato)) return candidato;
  }
  return null;
}

/**
 * Sugestões para o que a pessoa digitou. Aceita "são pau" e "sao paulo-sp".
 * Quem COMEÇA com o texto vem primeiro; depois quem apenas contém. No máximo `limite` sugestões.
 */
export function buscarCidades(lista: Cidade[], digitado: string, limite = 8): Cidade[] {
  let termo = semAcento(digitado);
  if (termo.length < 2) return [];

  // "cidade-uf": separa a sigla do estado (só depois de um hífen e se for uma sigla de verdade) para filtrar por ela
  let ufFiltro: string | null = null;
  const comSigla = /^(.*?)\s*-\s*([a-z]{2})$/.exec(termo);
  if (comSigla && comSigla[1].length >= 2 && SIGLAS_UF.includes(comSigla[2].toUpperCase())) {
    ufFiltro = comSigla[2].toUpperCase();
    termo = comSigla[1];
  }

  const comecam: Cidade[] = [];
  const contem: Cidade[] = [];
  for (const cidade of lista) {
    if (ufFiltro && cidade.uf !== ufFiltro) continue;
    const nome = semAcento(cidade.nome);
    if (nome.startsWith(termo)) comecam.push(cidade);
    else if (nome.includes(termo)) contem.push(cidade);
  }
  const porNome = (a: Cidade, b: Cidade) => a.nome.localeCompare(b.nome, "pt-BR") || a.uf.localeCompare(b.uf);
  return [...comecam.sort(porNome), ...contem.sort(porNome)].slice(0, limite);
}
