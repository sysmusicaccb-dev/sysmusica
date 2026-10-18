import { afterEach, describe, expect, it, vi } from "vitest";
import { guardarPreferenciasLocais } from "@/modules/preferencias/armazenamento";
import { SCRIPT_TEMA_INICIAL } from "@/modules/preferencias/scriptInicial";

const CHAVE = "sysmusica.preferencias";

// Roda o script com um "navegador" de mentira e devolve os atributos que ele colocou na página
function executar(armazem: Record<string, string> | "erro", aparelhoEscuro = false): Record<string, string> {
  const atributos: Record<string, string> = {};
  const document = {
    documentElement: {
      setAttribute: (nome: string, valor: string) => {
        atributos[nome] = valor;
      },
    },
  };
  const localStorage = {
    getItem: (chave: string) => {
      if (armazem === "erro") throw new Error("sem armazenamento");
      return armazem[chave] ?? null;
    },
  };
  const window = { matchMedia: () => ({ matches: aparelhoEscuro }) };

  new Function("localStorage", "document", "window", SCRIPT_TEMA_INICIAL)(localStorage, document, window);
  return atributos;
}

const PADRAO = { "data-tema": "claro", "data-cor": "indigo", "data-fonte": "normal" };

afterEach(() => {
  vi.unstubAllGlobals();
});

describe("SCRIPT_TEMA_INICIAL", () => {
  it("usa o padrão quando não há nada guardado", () => {
    expect(executar({})).toEqual(PADRAO);
  });

  it("aplica o que está guardado neste aparelho", () => {
    const guardado = JSON.stringify({ tema: "escuro", cor: "azul", fonte: "grande" });
    expect(executar({ [CHAVE]: guardado })).toEqual({
      "data-tema": "escuro",
      "data-cor": "azul",
      "data-fonte": "grande",
    });
  });

  it("no modo automático, segue o aparelho", () => {
    const guardado = JSON.stringify({ tema: "sistema", cor: "verde", fonte: "media" });
    expect(executar({ [CHAVE]: guardado }, true)["data-tema"]).toBe("escuro");
    expect(executar({ [CHAVE]: guardado }, false)["data-tema"]).toBe("claro");
  });

  it("troca só o campo inválido pelo padrão", () => {
    const guardado = JSON.stringify({ tema: "roxo", cor: "vinho", fonte: 12 });
    expect(executar({ [CHAVE]: guardado })).toEqual({ ...PADRAO, "data-cor": "vinho" });
  });

  it("não quebra com dado corrompido, valor que não é objeto ou armazenamento indisponível", () => {
    expect(executar({ [CHAVE]: "{quebrado" })).toEqual(PADRAO);
    expect(executar({ [CHAVE]: "7" })).toEqual(PADRAO);
    expect(executar({ [CHAVE]: "null" })).toEqual(PADRAO);
    expect(executar("erro")).toEqual(PADRAO);
  });

  it("lê exatamente o que o sistema grava neste aparelho (mesma chave)", () => {
    const guardado: Record<string, string> = {};
    vi.stubGlobal("window", {
      localStorage: {
        setItem: (chave: string, valor: string) => {
          guardado[chave] = valor;
        },
      },
    });
    guardarPreferenciasLocais({ tema: "escuro", cor: "vinho", fonte: "media" });
    vi.unstubAllGlobals();

    expect(executar(guardado)).toEqual({ "data-tema": "escuro", "data-cor": "vinho", "data-fonte": "media" });
  });

  it("não contém nada que feche a tag de script", () => {
    expect(SCRIPT_TEMA_INICIAL.toLowerCase()).not.toContain("</script");
  });
});
