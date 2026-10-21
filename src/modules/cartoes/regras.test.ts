import { describe, expect, it } from "vitest";
import { GRUPOS_MENU, filtrarMenu, montarMigalhas } from "@/components/layout/navegacao";
import type { CodigoPermissao } from "@/lib/permissoes";
import { contarSituacoes, filtrarCartoes, formatarValidade, textoPrazo } from "./regras";
import type { LinhaCartao } from "./tipos";

function linha(nome: string, situacao: LinhaCartao["situacao"], dias: number | null): LinhaCartao {
  return { membro_id: nome, nome, cargo_nome: null, casa_nome: null, cartao_numero: null, cartao_validade: null, dias, situacao };
}

describe("formatarValidade", () => {
  it("troca AAAA-MM-DD por DD/MM/AAAA", () => {
    expect(formatarValidade("2026-11-05")).toBe("05/11/2026");
  });
  it("sem data mostra um traço", () => {
    expect(formatarValidade(null)).toBe("—");
    expect(formatarValidade("")).toBe("—");
  });
});

describe("textoPrazo", () => {
  it("cartão vencido", () => {
    expect(textoPrazo("VENCIDO", -1)).toBe("venceu ontem");
    expect(textoPrazo("VENCIDO", -5)).toBe("venceu há 5 dias");
  });
  it("cartão a vencer", () => {
    expect(textoPrazo("A_VENCER", 0)).toBe("vence hoje");
    expect(textoPrazo("A_VENCER", 1)).toBe("vence amanhã");
    expect(textoPrazo("A_VENCER", 12)).toBe("vence em 12 dias");
  });
  it("sem validade", () => {
    expect(textoPrazo("SEM_VALIDADE", null)).toBe("validade não informada");
  });
});

describe("filtrarCartoes e contarSituacoes", () => {
  const itens = [linha("A", "VENCIDO", -3), linha("B", "A_VENCER", 4), linha("C", "A_VENCER", 20), linha("D", "SEM_VALIDADE", null)];

  it("TODOS mantém tudo; os demais filtram pela situação", () => {
    expect(filtrarCartoes(itens, "TODOS")).toHaveLength(4);
    expect(filtrarCartoes(itens, "A_VENCER").map((i) => i.nome)).toEqual(["B", "C"]);
    expect(filtrarCartoes(itens, "VENCIDO").map((i) => i.nome)).toEqual(["A"]);
  });

  it("conta cada situação", () => {
    expect(contarSituacoes(itens)).toEqual({ TODOS: 4, VENCIDO: 1, A_VENCER: 2, SEM_VALIDADE: 1 });
  });
});

describe("menu: Cartões a Vencer", () => {
  const hrefsDe = (permitidas: CodigoPermissao[]) =>
    filtrarMenu(GRUPOS_MENU, (p) => permitidas.includes(p)).flatMap((grupo) => grupo.itens.map((item) => item.href));

  it("só aparece para quem tem a permissão cartoes.visualizar", () => {
    expect(hrefsDe(["cartoes.visualizar"])).toEqual(["/cartoes"]);
    expect(hrefsDe(["membros.visualizar"])).not.toContain("/cartoes");
  });

  it("breadcrumbs: Início > Cadastros > Cartões a Vencer", () => {
    expect(montarMigalhas("/cartoes")).toEqual([
      { rotulo: "Início", href: "/" },
      { rotulo: "Cadastros" },
      { rotulo: "Cartões a Vencer" },
    ]);
  });
});
