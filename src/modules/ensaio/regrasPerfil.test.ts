import { describe, expect, it } from "vitest";
import { configPadrao, normalizarConfig } from "./perfilConfig";
import { ajustarQuantidadeCfg, estadoDosDadosCfg, estadoVazioCfg, escolherAberturaCfg, montarCargaCfg, usaAbertura, validarEnsaioCfg } from "./regrasPerfil";
import type { DadosSalvos } from "./tipos";

const local = configPadrao("LOCAL");
const regional = configPadrao("REGIONAL");

function preenchido(config = local) {
  const e = estadoVazioCfg(config);
  e.atendeCargo = config.quem_atendeu.cargos[0];
  e.atendeNome = "Fulano de Tal";
  e.houveAbertura = "NAO";
  e.encarregados = [{ nome: "Beltrano Silva", cidadeUf: "São Paulo-SP", cargo: "LOCAL" }];
  if (config.palavra.ativo) e.palavra = "Salmo 23";
  return e;
}

describe("estadoVazioCfg", () => {
  it("Regional já vem com Ancião e uma linha de encarregado", () => {
    const e = estadoVazioCfg(regional);
    expect(e.atendeCargo).toBe("ANCIAO");
    expect(e.encarregados).toHaveLength(1);
  });

  it("perfil sem encarregados não tem linhas", () => {
    const c = normalizarConfig({ encarregados: { ativo: false } }, "LOCAL");
    expect(estadoVazioCfg(c).encarregados).toEqual([]);
  });

  it("um cargo só de encarregado já vem escolhido", () => {
    const c = normalizarConfig({ encarregados: { cargos: ["INSTRUTOR"] } }, "LOCAL");
    expect(estadoVazioCfg(c).encarregados[0].cargo).toBe("INSTRUTOR");
  });
});

describe("validarEnsaioCfg", () => {
  it("formulário completo passa", () => {
    expect(validarEnsaioCfg(preenchido(), local)).toEqual([]);
    expect(validarEnsaioCfg(preenchido(regional), regional)).toEqual([]);
  });

  it("pergunta do hino de abertura precisa de resposta; Sim exige escolher o hino", () => {
    const e = preenchido();
    e.houveAbertura = "";
    expect(validarEnsaioCfg(e, local).map((x) => x.campo)).toContain("hino_abertura");
    e.houveAbertura = "SIM";
    expect(validarEnsaioCfg(e, local).map((x) => x.mensagem).join(" ")).toMatch(/Escolha o hino de abertura/);
    e.hinoAberturaId = "h1";
    expect(validarEnsaioCfg(e, local)).toEqual([]);
  });

  it("vários cargos de encarregado: cada um precisa escolher o cargo", () => {
    const e = preenchido();
    e.encarregados[0].cargo = "";
    expect(validarEnsaioCfg(e, local).map((x) => x.campo)).toContain("encarregado_0_cargo");
  });

  it("palavra obrigatória só quando ligada e marcada como obrigatória", () => {
    const e = preenchido(regional);
    e.palavra = "";
    expect(validarEnsaioCfg(e, regional).map((x) => x.campo)).toContain("palavra");
    const opcional = normalizarConfig({ palavra: { ativo: true, obrigatoria: false } }, "REGIONAL");
    expect(validarEnsaioCfg(e, opcional).map((x) => x.campo)).not.toContain("palavra");
  });

  it("campos desligados no perfil não são cobrados", () => {
    const c = normalizarConfig({ quem_atendeu: { ativo: false }, encarregados: { ativo: false }, hino_abertura: { modo: "nao_usa" } }, "LOCAL");
    expect(validarEnsaioCfg(estadoVazioCfg(c), c)).toEqual([]);
  });

  it("sem Cidade-UF no perfil, a cidade não é cobrada", () => {
    const c = normalizarConfig({ encarregados: { cidade_uf: false } }, "LOCAL");
    const e = preenchido(c);
    e.encarregados[0].cidadeUf = "";
    expect(validarEnsaioCfg(e, c)).toEqual([]);
  });

  it("nomes de encarregados repetidos são recusados", () => {
    const e = preenchido();
    e.encarregados = [
      { nome: "Beltrano Silva", cidadeUf: "São Paulo-SP", cargo: "LOCAL" },
      { nome: "beltrano  silva", cidadeUf: "São Paulo-SP", cargo: "LOCAL" },
    ];
    expect(validarEnsaioCfg(e, local).map((x) => x.campo)).toContain("encarregado_1_nome");
  });

  it("respeita o mínimo e o máximo de encarregados", () => {
    const c = normalizarConfig({ encarregados: { minimo: 2, maximo: 2 } }, "LOCAL");
    const e = preenchido(c);
    expect(validarEnsaioCfg(e, c).map((x) => x.campo)).toContain("encarregados");
  });
});

describe("montarCargaCfg", () => {
  it("modo pergunta com Não envia abertura nula", () => {
    const e = preenchido();
    e.hinoAberturaId = "h1";
    e.houveAbertura = "NAO";
    expect(montarCargaCfg(e, local).hino_abertura_id).toBeNull();
    e.houveAbertura = "SIM";
    expect(montarCargaCfg(e, local).hino_abertura_id).toBe("h1");
  });

  it("campos desligados vão vazios", () => {
    const c = normalizarConfig({ quem_atendeu: { ativo: false }, encarregados: { ativo: false }, hinos_executados: { ativo: false } }, "LOCAL");
    const e = preenchido(c);
    e.hinosIds = ["a", "b"];
    const carga = montarCargaCfg(e, c);
    expect(carga.atende_nome).toBeNull();
    expect(carga.encarregados).toEqual([]);
    expect(carga.hinos).toEqual([]);
  });

  it("palavra só vai quando o perfil usa", () => {
    expect(montarCargaCfg(preenchido(), local).palavra).toBeNull();
    expect(montarCargaCfg(preenchido(regional), regional).palavra).toBe("Salmo 23");
  });
});

describe("ajustarQuantidadeCfg", () => {
  it("fica entre o mínimo e o máximo e mantém o que foi digitado", () => {
    const c = normalizarConfig({ encarregados: { minimo: 1, maximo: 2 } }, "LOCAL");
    const base = [{ nome: "A B C", cidadeUf: "", cargo: "" as const }];
    expect(ajustarQuantidadeCfg(base, 5, c)).toHaveLength(2);
    expect(ajustarQuantidadeCfg(base, 5, c)[0].nome).toBe("A B C");
    expect(ajustarQuantidadeCfg(base, 0, c)).toHaveLength(1);
  });
});

describe("estadoDosDadosCfg e escolherAberturaCfg", () => {
  const dados: DadosSalvos = {
    atende_cargo: "ANCIAO",
    atende_nome: "Fulano de Tal",
    palavra: null,
    hino_abertura_id: null,
    atualizado_em: "2026-10-01T00:00:00Z",
    encarregados: [{ ordem: 1, nome: "Beltrano Silva", cidade_uf: "São Paulo-SP", cargo: null }],
    hinos: ["h2"],
  };

  it("abertura gravada como nula volta como resposta Não", () => {
    const e = estadoDosDadosCfg(dados, local);
    expect(e.houveAbertura).toBe("NAO");
    expect(usaAbertura(local, e)).toBe(false);
  });

  it("escolher a abertura tira o hino da lista de executados", () => {
    const e = estadoDosDadosCfg(dados, local);
    const r = escolherAberturaCfg(e, "h2");
    expect(r.saiuDaLista).toBe(true);
    expect(r.estado.hinosIds).toEqual([]);
  });
});
