import { describe, expect, it } from "vitest";
import {
  acharPeloRotulo,
  adicionarHinos,
  ajustarQuantidade,
  cargosDoModelo,
  escolherAbertura,
  estaVazio,
  estadoDosDados,
  estadoVazio,
  hinosDisponiveis,
  moverHino,
  montarCarga,
  montarCidadeUf,
  motivoSemEdicao,
  removerHinos,
  rotuloEncarregado,
  temPalavra,
  validarCidadeUf,
  validarEnsaio,
  type EstadoEnsaio,
} from "./regras";
import type { DadosSalvos } from "./tipos";

const valido = (sobrepor: Partial<EstadoEnsaio> = {}): EstadoEnsaio => ({
  atendeCargo: "ANCIAO",
  atendeNome: "Elias Ramos",
  palavra: "Salmo 150",
  hinoAberturaId: "h1",
  encarregados: [{ nome: "João Ferreira", cidadeUf: "São Paulo-SP" }],
  hinosIds: ["h2", "h5"],
  ...sobrepor,
});
const campos = (e: ReturnType<typeof validarEnsaio>) => e.map((x) => x.campo);

describe("modelo", () => {
  it("Regional: só Ancião, tem palavra, 'Encarregado Regional'", () => {
    expect(cargosDoModelo("REGIONAL")).toEqual(["ANCIAO"]);
    expect(temPalavra("REGIONAL")).toBe(true);
    expect(rotuloEncarregado("REGIONAL")).toBe("Encarregado Regional");
  });
  it("Local: quatro cargos, sem palavra, 'Encarregado Local'", () => {
    expect(cargosDoModelo("LOCAL")).toEqual(["ANCIAO", "DIACONO", "COOPERADOR_OFICIO", "COOPERADOR_RJM"]);
    expect(temPalavra("LOCAL")).toBe(false);
    expect(rotuloEncarregado("LOCAL")).toBe("Encarregado Local");
  });
});

describe("Cidade-UF", () => {
  it("monta e valida", () => {
    expect(montarCidadeUf(" São  Paulo ", "sp")).toBe("São Paulo-SP");
    expect(validarCidadeUf("São Paulo-SP")).toBeNull();
    expect(validarCidadeUf("Palmas-TO")).toBeNull();
    expect(validarCidadeUf("  Rio   Branco-AC ")).toBeNull();
  });
  it("recusa sem UF, UF minúscula, UF que não existe e cidade curta", () => {
    for (const ruim of ["São Paulo", "São Paulo-sp", "São Paulo-XX", "A-SP", "", "-SP", "São Paulo-SPP"]) {
      expect(validarCidadeUf(ruim), ruim).toMatch(/Cidade-UF/);
    }
  });
});

describe("estado do formulário", () => {
  it("em branco: Regional já vem com Ancião; Local sem cargo; 1 encarregado vazio", () => {
    expect(estadoVazio("REGIONAL").atendeCargo).toBe("ANCIAO");
    expect(estadoVazio("LOCAL").atendeCargo).toBe("");
    expect(estadoVazio("LOCAL").encarregados).toHaveLength(1);
  });

  it("monta o estado a partir dos dados gravados (encarregados na ordem)", () => {
    const dados: DadosSalvos = {
      atende_cargo: "DIACONO",
      atende_nome: "Fulano",
      palavra: null,
      hino_abertura_id: "h1",
      atualizado_em: "2026-10-21T00:00:00Z",
      encarregados: [
        { ordem: 2, nome: "B", cidade_uf: "Salvador-BA" },
        { ordem: 1, nome: "A", cidade_uf: "São Paulo-SP" },
      ],
      hinos: ["h2", "h3"],
    };
    const estado = estadoDosDados(dados, "LOCAL");
    expect(estado.encarregados.map((e) => e.nome)).toEqual(["A", "B"]);
    expect(estado.palavra).toBe("");
    expect(estado.hinosIds).toEqual(["h2", "h3"]);
    expect(estadoDosDados(null, "REGIONAL")).toEqual(estadoVazio("REGIONAL"));
  });

  it("ajustar a quantidade mantém o que foi digitado e fica entre 1 e 3", () => {
    const base = [{ nome: "A", cidadeUf: "X-SP" }, { nome: "B", cidadeUf: "Y-BA" }];
    expect(ajustarQuantidade(base, 3).map((e) => e.nome)).toEqual(["A", "B", ""]);
    expect(ajustarQuantidade(base, 1).map((e) => e.nome)).toEqual(["A"]);
    expect(ajustarQuantidade(base, 0)).toHaveLength(1);
    expect(ajustarQuantidade(base, 9)).toHaveLength(3);
    expect(ajustarQuantidade(base, Number.NaN)).toHaveLength(1);
  });

  it("estaVazio", () => {
    expect(estaVazio(estadoVazio("REGIONAL"), "REGIONAL")).toBe(true);
    expect(estaVazio({ ...estadoVazio("REGIONAL"), atendeNome: "x" }, "REGIONAL")).toBe(false);
    expect(estaVazio({ ...estadoVazio("LOCAL"), hinosIds: ["a"] }, "LOCAL")).toBe(false);
  });
});

describe("hinos executados", () => {
  it("adicionar não repete e não aceita o hino de abertura", () => {
    expect(adicionarHinos(["a"], ["a", "b", "c", "b"], "c")).toEqual(["a", "b"]);
  });
  it("respeita o limite de 100", () => {
    const cem = Array.from({ length: 100 }, (_, i) => `h${i}`);
    expect(adicionarHinos(cem, ["novo"], "")).toHaveLength(100);
  });
  it("remover e mover", () => {
    expect(removerHinos(["a", "b", "c"], ["b"])).toEqual(["a", "c"]);
    expect(moverHino(["a", "b", "c"], 1, -1)).toEqual(["b", "a", "c"]);
    expect(moverHino(["a", "b", "c"], 1, 1)).toEqual(["a", "c", "b"]);
    expect(moverHino(["a", "b", "c"], 0, -1)).toEqual(["a", "b", "c"]);
    expect(moverHino(["a", "b", "c"], 2, 1)).toEqual(["a", "b", "c"]);
    expect(moverHino(["a"], 5, 1)).toEqual(["a"]);
  });
  it("disponíveis: ativos, fora da lista e diferentes da abertura", () => {
    const todos = [{ id: "a", ativo: true }, { id: "b", ativo: false }, { id: "c", ativo: true }, { id: "d", ativo: true }];
    expect(hinosDisponiveis(todos, ["c"], "d").map((h) => h.id)).toEqual(["a"]);
  });
  it("escolher a abertura tira o hino da lista de executados e avisa", () => {
    const antes = valido({ hinosIds: ["h2", "h3"] });
    const r = escolherAbertura(antes, "h3");
    expect(r.estado.hinoAberturaId).toBe("h3");
    expect(r.estado.hinosIds).toEqual(["h2"]);
    expect(r.saiuDaLista).toBe(true);
    expect(escolherAbertura(antes, "h9").saiuDaLista).toBe(false);
    expect(escolherAbertura(antes, "").estado.hinoAberturaId).toBe("");
  });
  it("acha o hino pelo texto exato da opção", () => {
    const opcoes = [{ rotulo: "002 – Oh! quão suave", hino: { id: "x" } }, { rotulo: "Coro 1 – Um", hino: { id: "y" } }];
    expect(acharPeloRotulo(opcoes, "  coro 1 –  um ")?.id).toBe("y");
    expect(acharPeloRotulo(opcoes, "002")).toBeNull();
    expect(acharPeloRotulo(opcoes, "")).toBeNull();
  });
});

describe("validarEnsaio", () => {
  it("o ensaio completo passa (Regional e Local)", () => {
    expect(validarEnsaio(valido(), "REGIONAL")).toEqual([]);
    expect(validarEnsaio(valido({ atendeCargo: "DIACONO", palavra: "" }), "LOCAL")).toEqual([]);
  });

  it("zero hinos executados é permitido (preenche-se durante o ensaio)", () => {
    expect(validarEnsaio(valido({ hinosIds: [] }), "REGIONAL")).toEqual([]);
  });

  it("Regional exige Ancião e palavra; Local não exige palavra", () => {
    expect(campos(validarEnsaio(valido({ atendeCargo: "DIACONO" }), "REGIONAL"))).toEqual(["atende_cargo"]);
    expect(campos(validarEnsaio(valido({ palavra: "   " }), "REGIONAL"))).toEqual(["palavra"]);
    expect(campos(validarEnsaio(valido({ palavra: "a".repeat(501) }), "REGIONAL"))).toEqual(["palavra"]);
    expect(validarEnsaio(valido({ atendeCargo: "COOPERADOR_RJM", palavra: "" }), "LOCAL")).toEqual([]);
    expect(campos(validarEnsaio(valido({ atendeCargo: "" }), "LOCAL"))).toEqual(["atende_cargo"]);
  });

  it("nome de quem atende: obrigatório e com limite", () => {
    expect(campos(validarEnsaio(valido({ atendeNome: " ab " }), "REGIONAL"))).toEqual(["atende_nome"]);
    expect(campos(validarEnsaio(valido({ atendeNome: "a".repeat(121) }), "REGIONAL"))).toEqual(["atende_nome"]);
  });

  it("encarregados: nome e cidade obrigatórios, nomes não repetem, no máximo 3", () => {
    const e1 = { nome: "", cidadeUf: "" };
    expect(campos(validarEnsaio(valido({ encarregados: [e1] }), "REGIONAL"))).toEqual(["encarregado_0_nome", "encarregado_0_cidade"]);
    const repetido = validarEnsaio(
      valido({ encarregados: [{ nome: "João Ferreira", cidadeUf: "São Paulo-SP" }, { nome: "joao  ferreira", cidadeUf: "Salvador-BA" }] }),
      "REGIONAL"
    );
    expect(campos(repetido)).toEqual(["encarregado_1_nome"]);
    expect(campos(validarEnsaio(valido({ encarregados: [] }), "REGIONAL"))).toEqual(["encarregados"]);
    const quatro = Array.from({ length: 4 }, (_, i) => ({ nome: `Nome ${i}x`, cidadeUf: "Palmas-TO" }));
    expect(campos(validarEnsaio(valido({ encarregados: quatro }), "REGIONAL"))).toEqual(["encarregados"]);
  });

  it("hino de abertura obrigatório e fora da lista de executados", () => {
    expect(campos(validarEnsaio(valido({ hinoAberturaId: "" }), "REGIONAL"))).toEqual(["hino_abertura"]);
    expect(campos(validarEnsaio(valido({ hinosIds: ["h1", "h2"] }), "REGIONAL"))).toEqual(["hinos"]);
  });

  it("hino repetido na lista", () => {
    expect(campos(validarEnsaio(valido({ hinosIds: ["h2", "h2"] }), "REGIONAL"))).toEqual(["hinos"]);
  });

  it("os erros vêm na ordem da tela", () => {
    const e = validarEnsaio(estadoVazio("REGIONAL"), "REGIONAL");
    expect(campos(e)).toEqual(["atende_nome", "palavra", "encarregado_0_nome", "encarregado_0_cidade", "hino_abertura"]);
  });
});

describe("montarCarga", () => {
  it("limpa os textos; Regional leva a palavra, Local manda nulo", () => {
    const estado = valido({ atendeNome: "  Elias   Ramos ", palavra: " Salmo 150 ", encarregados: [{ nome: " João  Ferreira ", cidadeUf: " São Paulo-SP " }] });
    expect(montarCarga(estado, "REGIONAL")).toEqual({
      atende_cargo: "ANCIAO",
      atende_nome: "Elias Ramos",
      palavra: "Salmo 150",
      hino_abertura_id: "h1",
      encarregados: [{ nome: "João Ferreira", cidade_uf: "São Paulo-SP" }],
      hinos: ["h2", "h5"],
    });
    expect(montarCarga(estado, "LOCAL").palavra).toBeNull();
  });
});

describe("motivoSemEdicao", () => {
  const ev = { cancelado: false, iniciado: true, encerrado: false };
  it("null quando dá para editar", () => {
    expect(motivoSemEdicao(ev, true, true)).toBeNull();
  });
  it("explica cada caso, na ordem", () => {
    expect(motivoSemEdicao({ ...ev, cancelado: true }, false, true)).toMatch(/cancelado/);
    expect(motivoSemEdicao(ev, false, false)).toMatch(/permissão/);
    expect(motivoSemEdicao({ ...ev, iniciado: false }, false, true)).toMatch(/ainda não começou/);
    expect(motivoSemEdicao({ ...ev, encerrado: true }, false, true)).toMatch(/encerrado/);
    expect(motivoSemEdicao(ev, false, true)).toMatch(/Não é possível/);
  });
});
