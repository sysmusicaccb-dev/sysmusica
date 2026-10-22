/**
 * Sysmusica — Consulta de endereço pelo CEP (ViaCEP, serviço público e gratuito).
 * A consulta sai do navegador de quem está cadastrando e leva só o CEP (8 números); nenhum outro dado da pessoa.
 * Se o serviço estiver fora do ar ou sem internet, o formulário continua funcionando: a pessoa digita o endereço.
 * A conversão da resposta fica em cadastroMusical.ts (enderecoDoViaCep), onde é testada.
 */
import { enderecoDoViaCep, type EnderecoDoCep } from "../cadastroMusical";

export type ResultadoCep =
  | { tipo: "ok"; endereco: EnderecoDoCep }
  | { tipo: "nao_encontrado" } // o CEP não existe
  | { tipo: "indisponivel" }; // sem internet, serviço fora do ar ou demorou demais

const TEMPO_MAXIMO_MS = 8000;

/** Busca o endereço de um CEP de 8 números. Nunca lança erro: devolve "indisponivel" se algo falhar. */
export async function buscarEnderecoPorCep(cep: string): Promise<ResultadoCep> {
  if (!/^\d{8}$/.test(cep)) return { tipo: "nao_encontrado" };
  const controle = new AbortController();
  const relogio = setTimeout(() => controle.abort(), TEMPO_MAXIMO_MS);
  try {
    const resposta = await fetch(`https://viacep.com.br/ws/${cep}/json/`, { signal: controle.signal });
    if (resposta.status === 400 || resposta.status === 404) return { tipo: "nao_encontrado" };
    if (!resposta.ok) return { tipo: "indisponivel" };
    const endereco = enderecoDoViaCep(await resposta.json());
    return endereco ? { tipo: "ok", endereco } : { tipo: "nao_encontrado" };
  } catch {
    return { tipo: "indisponivel" };
  } finally {
    clearTimeout(relogio);
  }
}
