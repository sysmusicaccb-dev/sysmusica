/**
 * Sysmusica — Dados e regras puras dos formulários da Comissão Musical que já têm tela:
 * M01 (ingresso no GEM), M02, M03, M05, M07 (troca de instrumento) e Avaliação RJM.
 * Sem banco e sem tela: testado em dados.test.ts. Os dados da ficha ficam em jsonb (coluna "dados").
 */
import type { TipoFicha } from "./tipos";

/** Para qual categoria a organista pede avaliação (M05). Vale o mesmo código da categoria do cadastro. */
export type DestinoOrganista = "" | "RJM" | "CULTO_OFICIAL" | "OFICIALIZADO";

export const DESTINOS_M05: { valor: Exclude<DestinoOrganista, "">; rotulo: string }[] = [
  { valor: "RJM", rotulo: "Reunião de jovens" },
  { valor: "CULTO_OFICIAL", rotulo: "Culto oficial" },
  { valor: "OFICIALIZADO", rotulo: "Oficialização" },
];

/** Motivo da troca de instrumento (M07). */
export type MotivoTroca = "" | "NECESSIDADE_ORQUESTRA" | "SAUDE";
export const MOTIVOS_M07: { valor: Exclude<MotivoTroca, "">; rotulo: string }[] = [
  { valor: "NECESSIDADE_ORQUESTRA", rotulo: "Necessidade da orquestra" },
  { valor: "SAUDE", rotulo: "Saúde ou orientação médica" },
];

/** Tipos que já têm formulário pronto. */
export type TipoComFormulario = "M01" | "M02" | "M03" | "M05" | "M07" | "AVALIACAO_RJM" | "AVALIACAO_CANDIDATO" | "PRE_AVALIACAO_ORGANISTA" | "EXAME_ORGANISTA" | "ACOMPANHAMENTO_GEM" | "NECESSIDADE_INSTRUMENTO";
export const TIPOS_COM_FORMULARIO: TipoFicha[] = [
  "M01", "M02", "M03", "M05", "M07", "AVALIACAO_RJM", "AVALIACAO_CANDIDATO",
  "PRE_AVALIACAO_ORGANISTA", "EXAME_ORGANISTA", "ACOMPANHAMENTO_GEM", "NECESSIDADE_INSTRUMENTO",
];

/** Confere se o tipo tem formulário (e informa isso ao TypeScript). */
export function temFormulario(tipo: string): tipo is TipoComFormulario {
  return (TIPOS_COM_FORMULARIO as string[]).includes(tipo);
}

/** O que a ficha guarda (tudo texto, para caber direto no papel). */
export interface DadosFicha {
  nome: string; // nome completo, sem abreviações
  comum: string; // Comum Congregação (no M01: cidade - bairro)
  instrumento: string; // "instrumento e tonalidade" (M01, M02, M03, RJM)
  local: string; // cidade onde o pedido é assinado
  data: string; // AAAA-MM-DD
  para: DestinoOrganista; // só M05
  professora_nome: string; // só M05
  professora_comum: string; // só M05
  // --- M01 (ingresso no GEM)
  nascimento: string; // AAAA-MM-DD
  estado_civil: string;
  telefone: string;
  inicio_gem: string; // AAAA-MM-DD
  responsavel_nome: string; // só para menores de 18 anos
  parentesco: string;
  // --- M07 (troca de instrumento)
  data_oficializacao: string; // AAAA-MM-DD
  instrumento_atual: string;
  instrumento_novo: string; // nome do instrumento novo (texto para o papel)
  instrumento_novo_id: string; // id do instrumento novo (é o que o "Apto" grava no cadastro)
  motivo: MotivoTroca;
  // --- M10, M11, organistas e necessidade de instrumentos: campos variados (chave -> texto), ver layouts.ts
  notas: Record<string, string>;
}

/** Dia de hoje em Salvador (AAAA-MM-DD), independente do fuso do computador. */
export function hojeEmSalvador(): string {
  return new Date().toLocaleDateString("sv-SE", { timeZone: "America/Bahia" });
}

export function dadosIniciais(hoje: string = hojeEmSalvador()): DadosFicha {
  return {
    nome: "", comum: "", instrumento: "", local: "", data: hoje, para: "", professora_nome: "", professora_comum: "",
    nascimento: "", estado_civil: "", telefone: "", inicio_gem: "", responsavel_nome: "", parentesco: "",
    data_oficializacao: "", instrumento_atual: "", instrumento_novo: "", instrumento_novo_id: "", motivo: "", notas: {},
  };
}

/** Lê o mapa "notas" do jsonb: só entram valores que são texto. */
function lerNotas(bruto: unknown): Record<string, string> {
  const saida: Record<string, string> = {};
  if (bruto && typeof bruto === "object" && !Array.isArray(bruto)) {
    for (const [chave, valor] of Object.entries(bruto as Record<string, unknown>)) {
      if (typeof valor === "string") saida[chave] = valor;
    }
  }
  return saida;
}

/** Lê o jsonb vindo do banco de forma tolerante (campo que faltar vira texto vazio). */
export function lerDados(bruto: unknown): DadosFicha {
  const base = dadosIniciais("");
  if (!bruto || typeof bruto !== "object") return base;
  const o = bruto as Record<string, unknown>;
  const t = (chave: string): string => (typeof o[chave] === "string" ? (o[chave] as string) : "");
  const para = t("para");
  const motivo = t("motivo");
  return {
    nome: t("nome"), comum: t("comum"), instrumento: t("instrumento"), local: t("local"), data: t("data"),
    para: para === "RJM" || para === "CULTO_OFICIAL" || para === "OFICIALIZADO" ? para : "",
    professora_nome: t("professora_nome"), professora_comum: t("professora_comum"),
    nascimento: t("nascimento"), estado_civil: t("estado_civil"), telefone: t("telefone"), inicio_gem: t("inicio_gem"),
    responsavel_nome: t("responsavel_nome"), parentesco: t("parentesco"),
    data_oficializacao: t("data_oficializacao"), instrumento_atual: t("instrumento_atual"),
    instrumento_novo: t("instrumento_novo"), instrumento_novo_id: t("instrumento_novo_id"),
    motivo: motivo === "NECESSIDADE_ORQUESTRA" || motivo === "SAUDE" ? motivo : "",
    notas: lerNotas(o.notas),
  };
}

const ISO = /^\d{4}-\d{2}-\d{2}$/;

/** A pessoa tem menos de 18 anos na data informada? (datas AAAA-MM-DD; data inválida = não) */
export function menorDeIdade(nascimento: string, hoje: string): boolean {
  if (!ISO.test(nascimento) || !ISO.test(hoje)) return false;
  const [an, mn, dn] = nascimento.split("-").map(Number);
  const [ah, mh, dh] = hoje.split("-").map(Number);
  let idade = ah - an;
  if (mh < mn || (mh === mn && dh < dn)) idade -= 1;
  return idade < 18;
}

/** Confere o preenchimento antes de salvar. Devolve a mensagem do problema, ou nulo se está tudo certo. */
export function validarFicha(tipo: TipoFicha, membroId: string | null, d: DadosFicha): string | null {
  if (!membroId) return "Busque e escolha a pessoa no cadastro.";
  if (d.nome.trim() === "") return "Informe o nome completo.";
  if (d.comum.trim() === "") return "Informe a Comum Congregação.";
  if (tipo === "M01") {
    if (!ISO.test(d.nascimento)) return "Informe a data de nascimento.";
    if (!ISO.test(d.inicio_gem)) return "Informe a data de início no GEM.";
    if (menorDeIdade(d.nascimento, d.inicio_gem) && d.responsavel_nome.trim() === "") {
      return "Menor de 18 anos: informe o nome do responsável.";
    }
    return null;
  }
  if (d.local.trim() === "") return "Informe a cidade (localidade) do pedido.";
  if (!ISO.test(d.data)) return "Informe a data do pedido.";
  if (tipo === "M05" && d.para === "") return "Marque para qual avaliação o pedido é feito (reunião de jovens, culto oficial ou oficialização).";
  if (tipo === "M07") {
    if (d.instrumento_novo_id === "") return "Escolha o instrumento que deseja tocar.";
    if (d.motivo === "") return "Marque o motivo da troca.";
  }
  return null;
}

const MESES = ["janeiro", "fevereiro", "março", "abril", "maio", "junho", "julho", "agosto", "setembro", "outubro", "novembro", "dezembro"];

/** "2026-10-25" -> { dia: "25", mes: "outubro", ano: "2026" }. Data inválida volta com campos vazios (linha em branco no papel). */
export function dataPorExtenso(iso: string): { dia: string; mes: string; ano: string } {
  const m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(iso);
  if (!m) return { dia: "", mes: "", ano: "" };
  const mes = MESES[Number(m[2]) - 1];
  if (!mes) return { dia: "", mes: "", ano: "" };
  return { dia: String(Number(m[3])), mes, ano: m[1] };
}

/** "2026-10-25" -> "25/10/2026" (vazio se inválida). */
export function dataBr(iso: string): string {
  const m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(iso);
  return m ? `${m[3]}/${m[2]}/${m[1]}` : "";
}
