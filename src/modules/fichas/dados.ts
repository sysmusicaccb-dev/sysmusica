/**
 * Sysmusica — Dados e regras puras dos formulários M02, M03 e M05 (pedido de avaliação de músico/organista).
 * Sem banco e sem tela: testado em dados.test.ts. Os dados da ficha ficam guardados em jsonb (coluna "dados").
 */
import type { TipoFicha } from "./tipos";

/** Para qual categoria a organista pede avaliação (M05). Vale o mesmo código da categoria do cadastro. */
export type DestinoOrganista = "" | "RJM" | "CULTO_OFICIAL" | "OFICIALIZADO";

export const DESTINOS_M05: { valor: Exclude<DestinoOrganista, "">; rotulo: string }[] = [
  { valor: "RJM", rotulo: "Reunião de jovens" },
  { valor: "CULTO_OFICIAL", rotulo: "Culto oficial" },
  { valor: "OFICIALIZADO", rotulo: "Oficialização" },
];

/** Tipos que já têm formulário pronto nesta versão. */
export const TIPOS_COM_FORMULARIO: TipoFicha[] = ["M02", "M03", "M05"];

/** O que a ficha guarda (tudo texto, para caber direto no papel). */
export interface DadosFicha {
  nome: string; // nome completo, sem abreviações
  comum: string; // Comum Congregação
  instrumento: string; // "instrumento e tonalidade" (M02/M03)
  local: string; // cidade onde o pedido é assinado
  data: string; // AAAA-MM-DD
  para: DestinoOrganista; // só M05
  professora_nome: string; // só M05
  professora_comum: string; // só M05
}

/** Dia de hoje em Salvador (AAAA-MM-DD), independente do fuso do computador. */
export function hojeEmSalvador(): string {
  return new Date().toLocaleDateString("sv-SE", { timeZone: "America/Bahia" });
}

export function dadosIniciais(hoje: string = hojeEmSalvador()): DadosFicha {
  return { nome: "", comum: "", instrumento: "", local: "", data: hoje, para: "", professora_nome: "", professora_comum: "" };
}

/** Lê o jsonb vindo do banco de forma tolerante (campo que faltar vira texto vazio). */
export function lerDados(bruto: unknown): DadosFicha {
  const base = dadosIniciais("");
  if (!bruto || typeof bruto !== "object") return base;
  const o = bruto as Record<string, unknown>;
  const t = (chave: string): string => (typeof o[chave] === "string" ? (o[chave] as string) : "");
  const para = t("para");
  return {
    nome: t("nome"),
    comum: t("comum"),
    instrumento: t("instrumento"),
    local: t("local"),
    data: t("data"),
    para: para === "RJM" || para === "CULTO_OFICIAL" || para === "OFICIALIZADO" ? para : "",
    professora_nome: t("professora_nome"),
    professora_comum: t("professora_comum"),
  };
}

/** Confere o preenchimento antes de salvar. Devolve a mensagem do problema, ou nulo se está tudo certo. */
export function validarFicha(tipo: TipoFicha, membroId: string | null, d: DadosFicha): string | null {
  if (!membroId) return "Busque e escolha a pessoa no cadastro.";
  if (d.nome.trim() === "") return "Informe o nome completo.";
  if (d.comum.trim() === "") return "Informe a Comum Congregação.";
  if (d.local.trim() === "") return "Informe a cidade (localidade) do pedido.";
  if (!/^\d{4}-\d{2}-\d{2}$/.test(d.data)) return "Informe a data do pedido.";
  if (tipo === "M05" && d.para === "") return "Marque para qual avaliação o pedido é feito (reunião de jovens, culto oficial ou oficialização).";
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
