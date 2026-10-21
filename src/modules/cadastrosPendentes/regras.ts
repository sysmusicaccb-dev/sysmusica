/**
 * SysMúsica — Regras puras da tela "Cadastros pendentes" (sem banco, sem tela). Testadas em regras.test.ts.
 * Aqui fica a COMPARAÇÃO campo a campo entre o pedido de atualização e o cadastro atual do membro.
 */
import { cargoUsaCategoria, rotuloDaCategoria } from "@/modules/painel/regras";
import type { DadosCadastro, DetalheCadastro, StatusCadastro, TipoCadastro } from "./tipos";

export const ROTULO_STATUS: Record<StatusCadastro, string> = {
  PENDENTE: "Pendente",
  APROVADO: "Aprovado",
  REJEITADO: "Recusado",
  EXPIRADO: "Vencido",
  SUBSTITUIDO: "Substituído",
};

export const ROTULO_TIPO: Record<TipoCadastro, string> = {
  NOVO: "Novo cadastro",
  ATUALIZACAO: "Atualização",
};

/** Cor do selo de cada situação (variantes do componente Badge). */
export const VARIANTE_STATUS: Record<StatusCadastro, "alerta" | "sucesso" | "perigo" | "neutro"> = {
  PENDENTE: "alerta",
  APROVADO: "sucesso",
  REJEITADO: "perigo",
  EXPIRADO: "neutro",
  SUBSTITUIDO: "neutro",
};

const VAZIO = "—";

/** "2026-10-21" -> "21/10/2026". Texto que não é data volta como está. */
export function formatarData(iso: string | null | undefined): string {
  if (!iso) return VAZIO;
  const m = /^(\d{4})-(\d{2})-(\d{2})/.exec(iso);
  return m ? `${m[3]}/${m[2]}/${m[1]}` : iso;
}

/** Data e hora de um instante (fuso de Brasília), ex.: "21/10/2026 14:05". */
export function formatarDataHora(iso: string | null | undefined): string {
  if (!iso) return VAZIO;
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return iso;
  return d.toLocaleString("pt-BR", { timeZone: "America/Sao_Paulo", day: "2-digit", month: "2-digit", year: "numeric", hour: "2-digit", minute: "2-digit" });
}

export function simNao(valor: boolean | null | undefined): string {
  return valor === true ? "Sim" : valor === false ? "Não" : VAZIO;
}

/** Dias que faltam para o pedido vencer (0 se já venceu). */
export function diasParaVencer(expiraEm: string, agora: Date = new Date()): number {
  const ms = new Date(expiraEm).getTime() - agora.getTime();
  return Number.isNaN(ms) ? 0 : Math.max(0, Math.ceil(ms / 86_400_000));
}

export interface LinhaComparacao {
  chave: string;
  rotulo: string;
  atual: string; // como está hoje (vazio em cadastro novo)
  novo: string; // como ficará
  mudou: boolean;
}

function texto(v: string | null | undefined): string {
  const t = (v ?? "").trim();
  return t === "" ? VAZIO : t;
}

function telefone(d: DadosCadastro | null | undefined): string {
  if (!d?.telefone) return VAZIO;
  return d.ddd ? `(${d.ddd}) ${d.telefone}` : d.telefone;
}

function endereco(d: DadosCadastro | null | undefined): string {
  if (!d?.endereco) return VAZIO;
  const partes = [d.endereco, d.numero, d.complemento].filter((p): p is string => !!p && p.trim() !== "");
  return partes.join(", ");
}

function cartao(d: DadosCadastro | null | undefined): string {
  if (!d?.cartao_numero) return VAZIO;
  return `${d.cartao_numero}${d.cartao_validade ? ` (validade ${formatarData(d.cartao_validade)})` : ""}`;
}

function categoria(nomeCargo: string | null, valor: string | null): string {
  if (!valor) return VAZIO;
  const tipo = cargoUsaCategoria(nomeCargo);
  return tipo ? rotuloDaCategoria(valor, tipo) : VAZIO;
}

/**
 * Linhas "campo | hoje | pedido". Em cadastro NOVO, a coluna "hoje" fica vazia. Em atualização, `mudou` marca o que
 * o aprovador precisa olhar. CPF e data de nascimento não entram: são o que identifica a pessoa e não mudam.
 */
export function compararComAtual(d: DetalheCadastro): LinhaComparacao[] {
  const a = d.atual;
  const novoDados = d.dados ?? {};
  const atualDados = a?.cadastro ?? null;
  const linha = (chave: string, rotulo: string, atual: string, novo: string): LinhaComparacao => ({
    chave,
    rotulo,
    atual: a ? atual : VAZIO,
    novo,
    mudou: !!a && atual !== novo,
  });
  return [
    linha("nome", "Nome", texto(a?.nome), texto(d.nome)),
    linha("casa", "Casa de Oração", texto(a?.casa_nome), texto(d.casa_nome)),
    linha("cargo", "Cargo", texto(a?.cargo_nome), texto(d.cargo_nome)),
    linha("instrumento", "Instrumento", texto(a?.instrumento_nome), texto(d.instrumento_nome)),
    linha("categoria", "Categoria", categoria(a?.cargo_nome ?? null, a?.categoria ?? null), categoria(d.cargo_nome, d.categoria)),
    linha("estado_civil", "Estado civil", texto(atualDados?.estado_civil), texto(novoDados.estado_civil)),
    linha("sexo", "Sexo", texto(atualDados?.sexo), texto(novoDados.sexo)),
    linha("batizado", "Batizado(a)", simNao(atualDados?.batizado), simNao(novoDados.batizado)),
    linha("data_batismo", "Data do batismo", formatarData(atualDados?.data_batismo), formatarData(novoDados.data_batismo)),
    linha("selado", "Selado(a)", simNao(atualDados?.selado), simNao(novoDados.selado)),
    linha("telefone", "Telefone", telefone(atualDados), telefone(novoDados)),
    linha("whatsapp", "WhatsApp", texto(atualDados?.whatsapp), texto(novoDados.whatsapp)),
    linha("email", "E-mail", texto(atualDados?.email), texto(novoDados.email)),
    linha("cep", "CEP", texto(atualDados?.cep), texto(novoDados.cep)),
    linha("endereco", "Endereço", endereco(atualDados), endereco(novoDados)),
    linha("bairro", "Bairro", texto(a?.bairro), texto(d.bairro)),
    linha("cidade", "Cidade", texto(a?.cidade), texto(d.cidade)),
    linha("uf", "UF", texto(atualDados?.uf), texto(novoDados.uf)),
    linha("cartao", "Cartão de identificação", cartao(atualDados), cartao(novoDados)),
  ];
}

/** Quantos campos mudam num pedido de atualização. */
export function quantosMudaram(linhas: LinhaComparacao[]): number {
  return linhas.filter((l) => l.mudou).length;
}

/** O texto do motivo da recusa é aceito? Devolve a mensagem de erro ou null (o banco confere de novo). */
export function validarMotivo(motivo: string): string | null {
  const m = motivo.trim().replace(/\s+/g, " ");
  if (m.length < 5) return "Informe o motivo da recusa (pelo menos 5 letras).";
  if (m.length > 300) return "O motivo pode ter no máximo 300 caracteres.";
  return null;
}
