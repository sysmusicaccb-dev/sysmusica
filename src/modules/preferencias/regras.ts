/**
 * Sysmusica — Regras puras das preferências de aparência (sem banco nem navegador).
 * Testadas em regras.test.ts. Os mesmos valores existem no banco (migração 0019) e no estilo (tema.css).
 */
import type { CorId, FonteId, Preferencias, TemaId } from "./tipos";

export const PREFERENCIAS_PADRAO: Preferencias = { tema: "claro", cor: "indigo", fonte: "normal" };

export const TEMAS: { id: TemaId; rotulo: string; descricao: string }[] = [
  { id: "claro", rotulo: "Claro", descricao: "Fundo branco (padrão)" },
  { id: "escuro", rotulo: "Escuro", descricao: "Fundo escuro, mais confortável à noite" },
  { id: "sistema", rotulo: "Automático", descricao: "Segue o modo do aparelho" },
];

/** "amostra" é só a bolinha mostrada no painel; as cores de verdade ficam em tema.css. */
export const CORES: { id: CorId; rotulo: string; amostra: string }[] = [
  { id: "indigo", rotulo: "Índigo", amostra: "#4f46e5" },
  { id: "azul", rotulo: "Azul", amostra: "#2563eb" },
  { id: "verde", rotulo: "Verde", amostra: "#059669" },
  { id: "vinho", rotulo: "Vinho", amostra: "#b02a4e" },
  { id: "grafite", rotulo: "Grafite", amostra: "#475569" },
];

export const FONTES: { id: FonteId; rotulo: string; descricao: string }[] = [
  { id: "normal", rotulo: "Normal", descricao: "Tamanho padrão" },
  { id: "media", rotulo: "Média", descricao: "12% maior" },
  { id: "grande", rotulo: "Grande", descricao: "25% maior" },
];

const IDS_TEMA = TEMAS.map((item) => item.id);
const IDS_COR = CORES.map((item) => item.id);
const IDS_FONTE = FONTES.map((item) => item.id);

// Devolve o valor se ele for um dos permitidos; senão, o padrão
function escolher<T extends string>(valor: unknown, validos: readonly T[], padrao: T): T {
  return typeof valor === "string" && (validos as readonly string[]).includes(valor) ? (valor as T) : padrao;
}

/** Lê as preferências de qualquer origem (banco, aparelho): campo inválido ou ausente volta ao padrão. */
export function lerPreferencias(valor: unknown): Preferencias {
  const base = valor !== null && typeof valor === "object" && !Array.isArray(valor) ? (valor as Record<string, unknown>) : {};
  return {
    tema: escolher(base.tema, IDS_TEMA, PREFERENCIAS_PADRAO.tema),
    cor: escolher(base.cor, IDS_COR, PREFERENCIAS_PADRAO.cor),
    fonte: escolher(base.fonte, IDS_FONTE, PREFERENCIAS_PADRAO.fonte),
  };
}

/** O modo que de fato vale: "Automático" segue o aparelho. */
export function temaEfetivo(tema: TemaId, aparelhoEscuro: boolean): "claro" | "escuro" {
  if (tema === "sistema") return aparelhoEscuro ? "escuro" : "claro";
  return tema;
}

/** Os valores que vão para os atributos data-tema, data-cor e data-fonte da página. */
export function atributosDoTema(
  preferencias: Preferencias,
  aparelhoEscuro: boolean
): { tema: "claro" | "escuro"; cor: CorId; fonte: FonteId } {
  return {
    tema: temaEfetivo(preferencias.tema, aparelhoEscuro),
    cor: preferencias.cor,
    fonte: preferencias.fonte,
  };
}
