/**
 * Sysmusica — Regras automáticas por cargo no Cadastro Musical (sem banco, sem tela). Testadas em regrasCargo.test.ts.
 *
 * Regra da CCB (confirmada pelo administrador): alguns cargos já "carregam" o batismo, o selamento e o estado civil.
 * Ao escolher o cargo, a tela preenche e trava esses campos; nos demais cargos a pessoa informa.
 *
 *  - Batizado = Sim: Ancião, Diácono, Cooperadores, Encarregados (Local e Regional), Instrutor(a), Secretário da
 *    Música, Examinadora, e Músico/Organista oficializado(a) ou de Culto Oficial. (Candidato(a) e RJM: livre.)
 *  - Casado(a): Ancião, Diácono, Cooperadores, Encarregado Regional e Examinadora.
 *  - Selado = Sim: Ancião e Diácono.
 *
 * PARA MUDAR AS REGRAS: edite só a função regrasDoCargo abaixo (e a função regra_cargo_cadastro do banco, migração 0050,
 * que confere os envios do formulário público).
 */
import type { CadastroMusical } from "./cadastroMusical";

/** Estado civil que as regras impõem (o mesmo texto aceito pelo banco). */
export const ESTADO_CIVIL_CASADO = "Casado (a)";

/** Idade abaixo da qual o batismo depende de autorização dos pais. */
export const IDADE_BATISMO_COM_AUTORIZACAO = 12;

export const AVISO_BATISMO_MENOR =
  "Menor de 12 anos: o batismo só é possível com a autorização dos pais. Responda conforme a situação real.";

/** O que o cargo decide sozinho (true = o campo é preenchido pelo sistema e travado). */
export interface RegrasDoCargo {
  batizado: boolean; // Batizado = Sim
  casado: boolean; // Estado civil = Casado (a)
  selado: boolean; // Selado = Sim
}

export const SEM_REGRAS: RegrasDoCargo = { batizado: false, casado: false, selado: false };

function semAcento(texto: string): string {
  return texto
    .normalize("NFD")
    .replace(/[̀-ͯ]/g, "")
    .toLowerCase()
    .trim();
}

/** Regras do cargo (pelo início do nome, sem acento). `categoria`: OFICIALIZADO, CULTO_OFICIAL, RJM ou "" (Músico/Organista). */
export function regrasDoCargo(nomeCargo: string | null | undefined, categoria: string | null | undefined): RegrasDoCargo {
  if (!nomeCargo) return SEM_REGRAS;
  const nome = semAcento(nomeCargo);

  if (nome.startsWith("anciao") || nome.startsWith("diacono")) return { batizado: true, casado: true, selado: true };
  if (nome.startsWith("cooperador")) return { batizado: true, casado: true, selado: false };
  if (nome.startsWith("encarregado regional") || nome.startsWith("examinadora")) {
    return { batizado: true, casado: true, selado: false };
  }
  if (nome.startsWith("encarregado local") || nome.startsWith("instrutor") || nome.startsWith("secretario")) {
    return { batizado: true, casado: false, selado: false };
  }
  if (nome.startsWith("musico") || nome.startsWith("organista")) {
    const jaToca = categoria === "OFICIALIZADO" || categoria === "CULTO_OFICIAL";
    return { batizado: jaToca, casado: false, selado: false };
  }
  return SEM_REGRAS;
}

/** Devolve o cadastro com os campos que o cargo decide já preenchidos (o mesmo objeto se nada muda). */
export function aplicarRegrasDoCargo(cadastro: CadastroMusical, regras: RegrasDoCargo): CadastroMusical {
  const precisaMudar =
    (regras.batizado && cadastro.batizado !== "sim") ||
    (regras.casado && cadastro.estado_civil !== ESTADO_CIVIL_CASADO) ||
    (regras.selado && cadastro.selado !== "sim");
  if (!precisaMudar) return cadastro;
  return {
    ...cadastro,
    batizado: regras.batizado ? "sim" : cadastro.batizado,
    estado_civil: regras.casado ? ESTADO_CIVIL_CASADO : cadastro.estado_civil,
    selado: regras.selado ? "sim" : cadastro.selado,
  };
}

/** Idade em anos completos em `hoje` (AAAA-MM-DD); null se alguma data for inválida ou estiver vazia. */
export function idadeEmAnos(dataNascimento: string, hoje: string): number | null {
  const lerData = (texto: string): [number, number, number] | null => {
    if (!/^\d{4}-\d{2}-\d{2}$/.test(texto)) return null;
    const [a, m, d] = texto.split("-").map(Number);
    const data = new Date(Date.UTC(a, m - 1, d));
    return data.getUTCFullYear() === a && data.getUTCMonth() === m - 1 && data.getUTCDate() === d ? [a, m, d] : null;
  };
  const nasc = lerData(dataNascimento);
  const agora = lerData(hoje);
  if (!nasc || !agora) return null;
  let idade = agora[0] - nasc[0];
  if (agora[1] < nasc[1] || (agora[1] === nasc[1] && agora[2] < nasc[2])) idade -= 1;
  return idade;
}

/** Mostrar o aviso do batismo de menor? (cargo sem regra de batismo e pessoa com menos de 12 anos) */
export function avisoBatismoDeMenor(regras: RegrasDoCargo, dataNascimento: string, hoje: string): string | null {
  if (regras.batizado) return null;
  const idade = idadeEmAnos(dataNascimento, hoje);
  return idade !== null && idade < IDADE_BATISMO_COM_AUTORIZACAO ? AVISO_BATISMO_MENOR : null;
}
