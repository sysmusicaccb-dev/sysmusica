/**
 * Sysmusica — Lista de municípios do IBGE para o campo Cidade-UF.
 * Baixada uma vez por visita e guardada em memória. Nunca lança erro: se o IBGE estiver fora do ar, devolve
 * lista vazia e a tela deixa a pessoa digitar "Cidade-UF" à mão (o banco confere o formato).
 */
import { lerMunicipiosDoIbge, type Cidade } from "../cidades";

const URL_MUNICIPIOS = "https://servicodados.ibge.gov.br/api/v1/localidades/municipios?orderBy=nome";
const TEMPO_LIMITE_MS = 10_000;

let guardada: Promise<Cidade[]> | null = null;

export function carregarCidades(): Promise<Cidade[]> {
  if (guardada) return guardada;
  guardada = (async () => {
    const controle = new AbortController();
    const relogio = setTimeout(() => controle.abort(), TEMPO_LIMITE_MS);
    try {
      const resposta = await fetch(URL_MUNICIPIOS, { signal: controle.signal });
      if (!resposta.ok) throw new Error(String(resposta.status));
      const lista = lerMunicipiosDoIbge(await resposta.json());
      if (lista.length === 0) throw new Error("vazia");
      return lista;
    } catch {
      guardada = null; // falhou: na próxima vez tenta de novo
      return [];
    } finally {
      clearTimeout(relogio);
    }
  })();
  return guardada;
}
