/**
 * Sysmusica — Texto "Quem pode" de cada ficha (mostrado no cartão do catálogo).
 * É só informação para a tela: quem confere a regra de verdade é o banco (migração 0073, função
 * avaliar_elegibilidade_ficha). Mudou a regra lá, mude o texto aqui.
 */
const QUEM_PODE: Record<string, string> = {
  M01: "Só candidato (quem ainda não toca). Quem já foi liberado para tocar (RJM, Culto Oficial ou Oficializado) não entra no GEM.",
  ACOMPANHAMENTO_GEM: "Só candidato (quem ainda não toca). Quem já foi liberado para tocar não entra no GEM.",
  AVALIACAO_CANDIDATO: "Só candidato. Apto: o cadastro passa para RJM e já pode tocar nas Reuniões de Jovens e Menores.",
  AVALIACAO_RJM: "Só candidato. Apto: o cadastro passa para RJM (liberado para tocar).",
  M02: "Só quem está em RJM.",
  M03: "Só quem está em Culto Oficial.",
  M05: "Só organista. Reunião de jovens: sem etapa; Culto Oficial: quem está em RJM; Oficialização: quem está em Culto Oficial.",
  PRE_AVALIACAO_ORGANISTA: "Só organista que ainda não é Oficializada. Apto de candidata: o cadastro passa para RJM.",
  EXAME_ORGANISTA: "Só organista que ainda não é Oficializada.",
  M07: "Só Oficializado que toca (tem instrumento no cadastro).",
  NECESSIDADE_INSTRUMENTO: "Qualquer pessoa, em qualquer etapa.",
};

/** Texto "Quem pode" da ficha (vazio se o tipo for desconhecido). */
export function quemPode(tipo: string): string {
  return QUEM_PODE[tipo] ?? "";
}
