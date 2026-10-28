/**
 * Sysmusica — Regras puras do Perfil do Evento (sem banco). Testadas em regras.test.ts.
 *
 * O perfil define o comportamento da tela "Dados do Ensaio" dos tipos de evento ligados a ele. Nesta etapa o perfil
 * tem nome, descrição, comportamento base (Local ou Regional) e status. As mesmas regras valem no banco (migração 0079).
 */
import { normalizarTexto } from "@/lib/texto";
import { DESCRICAO_MAXIMA, NOME_MAXIMO, NOME_MINIMO, formatarNomeTipo, type ModeloEnsaio } from "@/modules/tiposEvento/regras";

/** Um perfil como a função listar_perfis_evento devolve. */
export interface PerfilEvento {
  id: string;
  nome: string;
  descricao: string | null;
  modelo_base: ModeloEnsaio;
  ativo: boolean;
  em_uso: number; // quantos tipos de evento usam o perfil (perfil em uso não pode ser excluído)
}

/** Confere o formulário; devolve a mensagem de erro ou null quando está tudo certo. */
export function validarPerfil(
  dados: { nome: string; descricao: string },
  existentes: Pick<PerfilEvento, "id" | "nome">[],
  idEmEdicao?: string
): string | null {
  const nome = formatarNomeTipo(dados.nome);
  if (nome.length < NOME_MINIMO) return `Informe o nome do perfil (mínimo de ${NOME_MINIMO} caracteres).`;
  if (nome.length > NOME_MAXIMO) return `O nome pode ter no máximo ${NOME_MAXIMO} caracteres.`;
  if (dados.descricao.trim().length > DESCRICAO_MAXIMA) {
    return `A descrição pode ter no máximo ${DESCRICAO_MAXIMA} caracteres.`;
  }
  const chave = normalizarTexto(nome);
  if (existentes.some((p) => p.id !== idEmEdicao && normalizarTexto(p.nome) === chave)) {
    return "Já existe um perfil com este nome.";
  }
  return null;
}

/** Texto do botão de excluir quando o perfil está em uso. */
export function motivoNaoExcluir(perfil: Pick<PerfilEvento, "nome" | "em_uso">): string | null {
  return perfil.em_uso > 0
    ? `${perfil.nome} é usado por ${perfil.em_uso} tipo(s) de evento e não pode ser excluído: troque o perfil desses tipos`
    : null;
}
