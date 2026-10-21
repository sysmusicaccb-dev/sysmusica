import { describe, expect, it } from "vitest";
import { GRUPOS_MENU } from "@/components/layout/navegacao";
import { CATALOGO_PERMISSOES } from "@/lib/permissoes";
import { dataDeVencimento, formatarDataCurta, validarPrazo } from "./prazo";

describe("validarPrazo", () => {
  it("aceita números inteiros de 7 a 365 (com espaços ao redor)", () => {
    expect(validarPrazo("60")).toEqual({ ok: true, dias: 60 });
    expect(validarPrazo(" 45 ")).toEqual({ ok: true, dias: 45 });
    expect(validarPrazo("7")).toEqual({ ok: true, dias: 7 });
    expect(validarPrazo("365")).toEqual({ ok: true, dias: 365 });
  });

  it("recusa vazio, texto, decimal e negativo", () => {
    for (const texto of ["", "   ", "abc", "30,5", "30.5", "-10", "1e2"]) {
      expect(validarPrazo(texto).ok, texto).toBe(false);
    }
  });

  it("recusa fora do intervalo, com mensagem clara", () => {
    expect(validarPrazo("6")).toEqual({ ok: false, erro: "O prazo deve ficar entre 7 e 365 dias." });
    expect(validarPrazo("366")).toEqual({ ok: false, erro: "O prazo deve ficar entre 7 e 365 dias." });
    expect(validarPrazo("0").ok).toBe(false);
  });
});

describe("dataDeVencimento e formatarDataCurta", () => {
  // 21/10/2026 16:18 em São Paulo (UTC-3) = 19:18 UTC
  const base = new Date("2026-10-21T19:18:00Z");

  it("soma os dias à data de envio", () => {
    expect(formatarDataCurta(dataDeVencimento(60, base))).toBe("20/12/2026");
    expect(formatarDataCurta(dataDeVencimento(30, base))).toBe("20/11/2026");
  });
});

describe("permissão de configurar o prazo", () => {
  it("existe no catálogo, junto das demais de Cadastros pendentes", () => {
    const codigos = CATALOGO_PERMISSOES.map((permissao) => permissao.codigo as string);
    expect(codigos).toContain("cadastros.configurar");
    expect(codigos).toContain("cadastros.visualizar");
  });

  it("não vira item de menu (é um botão dentro de Cadastros Pendentes)", () => {
    const permissoesDoMenu = GRUPOS_MENU.flatMap((grupo) => grupo.itens.map((item) => item.permissao as string));
    expect(permissoesDoMenu).not.toContain("cadastros.configurar");
  });
});
