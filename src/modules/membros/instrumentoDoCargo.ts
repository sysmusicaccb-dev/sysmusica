/**
 * Sysmusica — Instrumento automático por cargo (sem banco, sem tela). Testado em instrumentoDoCargo.test.ts.
 *
 * Organista, Examinadora e Instrutora tocam SEMPRE o Órgão: o campo Instrumento já vem preenchido e travado,
 * em qualquer tela. Só quem toca outros instrumentos (os músicos, inclusive Instrutor e Encarregados) escolhe.
 * Vale quando o cargo só aceita Órgão (coluna cargos.somente_orgao) e existe UM único instrumento Órgão cadastrado.
 */
import { instrumentoEOrgao } from "./cadastroMusical";

function semAcento(texto: string): string {
  return texto
    .normalize("NFD")
    .replace(/[̀-ͯ]/g, "")
    .toLowerCase()
    .trim();
}

/** Cargos femininos que só tocam Órgão (usados quando a lista não traz a coluna somente_orgao). */
const CARGOS_ORGAO_PELO_NOME = ["organista", "examinadora", "instrutora"];

export interface CargoParaOrgao {
  nome: string;
  somente_orgao?: boolean | null;
}

/** O cargo só toca Órgão? A coluna do banco decide; sem ela, vale o nome (Instrutor masculino NÃO entra). */
export function cargoTocaSoOrgao(cargo: CargoParaOrgao | null | undefined): boolean {
  if (!cargo) return false;
  if (typeof cargo.somente_orgao === "boolean") return cargo.somente_orgao;
  const nome = semAcento(cargo.nome);
  return CARGOS_ORGAO_PELO_NOME.some((prefixo) => nome.startsWith(prefixo));
}

/** Id do Órgão a preencher sozinho ("" = a pessoa escolhe). Só preenche quando há exatamente um Órgão cadastrado. */
export function orgaoUnicoDoCargo(
  cargo: CargoParaOrgao | null | undefined,
  instrumentos: { id: string; nome: string }[]
): string {
  if (!cargoTocaSoOrgao(cargo)) return "";
  const orgaos = instrumentos.filter((instrumento) => instrumentoEOrgao(instrumento.nome));
  return orgaos.length === 1 ? orgaos[0].id : "";
}
