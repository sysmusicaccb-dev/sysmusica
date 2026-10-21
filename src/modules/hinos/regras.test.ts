import { describe, expect, it } from "vitest";
import {
  compararHinos,
  filtrarHinos,
  formatarTitulo,
  interpretarLista,
  resumirImportacao,
  rotuloCompleto,
  rotuloHino,
  validarHino,
  type Hino,
} from "./regras";

const h = (categoria: Hino["categoria"], numero: number, nome: string) => ({ categoria, numero, nome });

describe("rotuloHino", () => {
  it("hino do hinário tem 3 dígitos e coro aparece como 'Coro N'", () => {
    expect(rotuloHino("HINO", 2)).toBe("002");
    expect(rotuloHino("HINO", 480)).toBe("480");
    expect(rotuloHino("CORO", 1)).toBe("Coro 1");
    expect(rotuloHino("CORO", 12)).toBe("Coro 12");
  });

  it("monta o rótulo completo com o título", () => {
    expect(rotuloCompleto(h("HINO", 2, "Oh! quão suave é confiar em Jesus"))).toBe("002 – Oh! quão suave é confiar em Jesus");
    expect(rotuloCompleto(h("CORO", 3, "Título"))).toBe("Coro 3 – Título");
  });
});

describe("validarHino", () => {
  it("aceita hino e coro corretos", () => {
    expect(validarHino({ categoria: "HINO", numero: 1, nome: "Saudai o nome de Jesus" })).toBeNull();
    expect(validarHino({ categoria: "CORO", numero: 9999, nome: "Ab" })).toBeNull();
  });

  it("recusa categoria inválida, número fora da faixa e título curto ou longo", () => {
    expect(validarHino({ categoria: "X", numero: 1, nome: "Abc" })).toMatch(/hino ou coro/);
    for (const numero of [0, -1, 10000, 1.5, null]) {
      expect(validarHino({ categoria: "HINO", numero, nome: "Abc" }), String(numero)).toMatch(/número/);
    }
    expect(validarHino({ categoria: "HINO", numero: 1, nome: " a " })).toMatch(/título/);
    expect(validarHino({ categoria: "HINO", numero: 1, nome: "x".repeat(151) })).toMatch(/no máximo/);
  });

  it("conta o título sem os espaços extras", () => {
    expect(formatarTitulo("  Louvor,   honra  e glória ")).toBe("Louvor, honra e glória");
  });
});

describe("compararHinos", () => {
  it("hinos antes dos coros, cada grupo pelo número", () => {
    const lista = [h("CORO", 1, "a"), h("HINO", 10, "b"), h("HINO", 2, "c"), h("CORO", 3, "d")];
    expect([...lista].sort(compararHinos).map((x) => rotuloHino(x.categoria, x.numero))).toEqual(["002", "010", "Coro 1", "Coro 3"]);
  });
});

describe("filtrarHinos", () => {
  const lista = [
    h("HINO", 1, "Saudai o nome de Jesus"),
    h("HINO", 2, "Oh! quão suave é confiar em Jesus"),
    h("HINO", 20, "Firmes nas promessas"),
    h("HINO", 200, "Eis a igreja de Deus"),
    h("CORO", 2, "Coro dois"),
    h("CORO", 3, "Terceiro"),
  ];
  const numeros = (r: typeof lista) => r.map((x) => rotuloHino(x.categoria, x.numero));

  it("sem busca devolve tudo", () => {
    expect(filtrarHinos(lista, "")).toHaveLength(6);
    expect(filtrarHinos(lista, "   ")).toHaveLength(6);
  });

  it("busca pelo número (com ou sem zeros à esquerda)", () => {
    expect(numeros(filtrarHinos(lista, "2"))).toEqual(["002", "020", "200", "Coro 2"]);
    // com zeros à esquerda a busca é de hino do hinário (o coro aparece como "Coro 2")
    expect(numeros(filtrarHinos(lista, "002"))).toEqual(["002", "020", "200"]);
    expect(numeros(filtrarHinos(lista, "20"))).toEqual(["020", "200"]);
  });

  it("busca coro pelo rótulo", () => {
    expect(numeros(filtrarHinos(lista, "coro 3"))).toEqual(["Coro 3"]);
    expect(numeros(filtrarHinos(lista, "coro"))).toEqual(["Coro 2", "Coro 3"]);
  });

  it("busca pelo título sem acento e sem diferenciar maiúsculas", () => {
    expect(numeros(filtrarHinos(lista, "QUAO suave"))).toEqual(["002"]);
    expect(numeros(filtrarHinos(lista, "jesus"))).toEqual(["001", "002"]);
    expect(filtrarHinos(lista, "zzz")).toEqual([]);
  });
});

describe("interpretarLista", () => {
  it("lê os formatos comuns de lista", () => {
    const texto = [
      "001 - Saudai o nome de Jesus",
      "2. Oh! quão suave é confiar em Jesus",
      "3) Louvor, honra e glória",
      "004 – Canta, minha alma, canta",
      "5 Firmes nas promessas",
    ].join("\n");
    const { itens, problemas } = interpretarLista(texto, "HINO");
    expect(problemas).toEqual([]);
    expect(itens.map((i) => [i.categoria, i.numero, i.nome])).toEqual([
      ["HINO", 1, "Saudai o nome de Jesus"],
      ["HINO", 2, "Oh! quão suave é confiar em Jesus"],
      ["HINO", 3, "Louvor, honra e glória"],
      ["HINO", 4, "Canta, minha alma, canta"],
      ["HINO", 5, "Firmes nas promessas"],
    ]);
  });

  it("'Coro N' vira coro e a categoria escolhida vale para as demais linhas", () => {
    const { itens } = interpretarLista("Coro 1 - Primeiro\n2 - Segundo", "HINO");
    expect(itens.map((i) => [i.categoria, i.numero])).toEqual([["CORO", 1], ["HINO", 2]]);
    const todosCoros = interpretarLista("1 - Primeiro\n2 - Segundo", "CORO");
    expect(todosCoros.itens.every((i) => i.categoria === "CORO")).toBe(true);
  });

  it("ignora linhas vazias e guarda o número da linha", () => {
    const { itens } = interpretarLista("\n\n7 - Sete\n   \n8 - Oito", "HINO");
    expect(itens.map((i) => i.linha)).toEqual([3, 5]);
  });

  it("separa as linhas com problema: sem número, título curto, número repetido, número grande demais", () => {
    const { itens, problemas } = interpretarLista(
      ["Saudai o nome", "9 - A", "10 - Dez", "10 - Dez de novo", "123456 - Longo", "0 - Zero"].join("\n"),
      "HINO"
    );
    expect(itens.map((i) => i.numero)).toEqual([10]);
    expect(problemas.map((p) => p.linha)).toEqual([1, 2, 4, 5, 6]);
    expect(problemas[0].motivo).toMatch(/número/);
    expect(problemas[1].motivo).toMatch(/título/);
    expect(problemas[2].motivo).toMatch(/repetido/);
  });

  it("o mesmo número em categorias diferentes não é repetido", () => {
    const { itens, problemas } = interpretarLista("1 - Hino um\nCoro 1 - Coro um", "HINO");
    expect(problemas).toEqual([]);
    expect(itens).toHaveLength(2);
  });

  it("aceita fim de linha do Windows", () => {
    expect(interpretarLista("1 - Um\r\n2 - Dois\r\n", "HINO").itens).toHaveLength(2);
  });
});

describe("resumirImportacao", () => {
  it("conta novos, já existentes e títulos diferentes", () => {
    const { itens } = interpretarLista("1 - Saudai o nome de Jesus\n2 - Título novo\n3 - Terceiro", "HINO");
    const resumo = resumirImportacao(itens, [
      h("HINO", 1, "SAUDAI o nome de Jesus"),
      h("HINO", 2, "Título antigo"),
      h("CORO", 3, "Outro"),
    ]);
    expect(resumo).toEqual({ novos: 1, jaExistem: 2, tituloDiferente: 1 });
  });
});
