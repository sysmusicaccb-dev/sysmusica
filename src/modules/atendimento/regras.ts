/**
 * Sysmusica — Regras puras do atendimento da portaria (sem banco nem câmera). Testadas em regras.test.ts.
 * As regras de verdade (acesso, duplicidade, aprovação) ficam no banco; aqui há conferências rápidas
 * para dar resposta imediata na tela e textos de erro da câmera.
 */

export const PREFIXO_QR = "SYSMUSICA:";

/** O texto lido parece um QR Code do Sysmusica? (resposta rápida, sem consultar o banco) */
export function pareceQrSysMusica(texto: string): boolean {
  return texto.trim().toUpperCase().startsWith(PREFIXO_QR);
}

/** Tira espaços sobrando do nome digitado. */
export function normalizarNomeBusca(nome: string): string {
  return nome.trim().replace(/\s+/g, " ");
}

/** A busca exige nome e sobrenome (mesma regra do banco: 8+ caracteres e 2+ palavras). */
export function nomeCompletoValido(nome: string): boolean {
  const limpo = normalizarNomeBusca(nome);
  return limpo.length >= 8 && limpo.split(" ").length >= 2;
}

/**
 * Confere os dados do visitante antes de enviar; devolve a mensagem de erro ou null.
 * A origem (igreja) é uma casa de oração escolhida na lista, cadastrada em Organização: nunca texto livre.
 * É só uma resposta rápida da tela: o banco confere tudo de novo (inclusive nome repetido na casa de oração).
 */
export function validarDadosVisitante(dados: {
  nome: string;
  cargoId: string;
  origemCasaOracaoId: string;
}): string | null {
  if (!nomeCompletoValido(dados.nome)) return "Digite o nome completo do visitante (nome e sobrenome).";
  if (!dados.cargoId) return "Escolha o cargo ou ministério do visitante.";
  if (!dados.origemCasaOracaoId) return "Escolha a igreja de origem na lista (estado, região, setor e casa de oração).";
  return null;
}

/** Hora no fuso de Salvador, no formato "18h42". */
export function horaCurta(iso: string): string {
  const hora = new Intl.DateTimeFormat("pt-BR", {
    hour: "2-digit",
    minute: "2-digit",
    timeZone: "America/Sao_Paulo",
  }).format(new Date(iso));
  return hora.replace(":", "h");
}

/** Ordena do evento mais próximo de "agora" para o mais distante (sem data vai para o fim). Não altera a lista original. */
export function ordenarPorProximidade<T extends { evento_data: string | null }>(itens: T[], agoraMs: number): T[] {
  const distancia = (item: T) =>
    item.evento_data ? Math.abs(Date.parse(item.evento_data) - agoraMs) : Number.POSITIVE_INFINITY;
  return [...itens].sort((a, b) => distancia(a) - distancia(b));
}

/** Mensagem amigável para os erros da câmera. */
export function mensagemCamera(erro: unknown): string {
  const texto = erro instanceof Error ? `${erro.name} ${erro.message}` : String(erro);

  if (texto.includes("INSEGURO")) return "A câmera só funciona em conexão segura (https).";
  if (/SEM_CAMERA|NotFoundError|Camera not found/i.test(texto)) {
    return "Nenhuma câmera encontrada neste aparelho. Use a busca pelo nome.";
  }
  if (/NotAllowedError|Permission/i.test(texto)) {
    return "A permissão da câmera foi negada. Libere o acesso à câmera no navegador e tente novamente, ou use a busca pelo nome.";
  }
  if (/NotReadableError/i.test(texto)) return "A câmera está em uso por outro aplicativo.";
  return "Não foi possível iniciar a câmera. Tente novamente ou use a busca pelo nome.";
}
