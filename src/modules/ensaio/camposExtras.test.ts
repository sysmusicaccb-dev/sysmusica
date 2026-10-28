import { describe, expect, it } from "vitest";
import { montarImpressaoEnsaio } from "./impressao";
import {
  configPadrao,
  descreverConfig,
  normalizarCamposExtras,
  normalizarConfig,
  novoIdCampoExtra,
  validarCamposExtras,
  valorExtraTexto,
  type CampoExtra,
} from "./perfilConfig";
import { estadoDosDadosCfg, estadoVazioCfg, montarCargaCfg, validarEnsaioCfg } from "./regrasPerfil";
import type { DadosSalvos } from "./tipos";

const campo = (parte: Partial<CampoExtra> & Pick<CampoExtra, "id" | "nome" | "tipo">): CampoExtra => ({
  obrigatorio: false,
  ativo: true,
  opcoes: [],
  ...parte,
});

function configCom(campos: CampoExtra[]) {
  return { ...configPadrao("LOCAL"), campos_extras: campos };
}

function ensaioBase(config: ReturnType<typeof configCom>) {
  const e = estadoVazioCfg(config);
  e.atendeCargo = "ANCIAO";
  e.atendeNome = "Fulano de Tal";
  e.houveAbertura = "NAO";
  e.encarregados = [{ nome: "Beltrano Silva", cidadeUf: "São Paulo-SP", cargo: "LOCAL" }];
  return e;
}

describe("normalizarCamposExtras", () => {
  it("lixo vira lista vazia", () => {
    expect(normalizarCamposExtras(null)).toEqual([]);
    expect(normalizarCamposExtras("x")).toEqual([]);
  });

  it("descarta id repetido, nome repetido, tipo inválido e lista com menos de 2 opções", () => {
    const r = normalizarCamposExtras([
      { id: "a1", nome: "Obs", tipo: "texto_longo" },
      { id: "a1", nome: "Outro", tipo: "numero" },
      { id: "a2", nome: "obs", tipo: "numero" },
      { id: "a3", nome: "Estranho", tipo: "cor" },
      { id: "a4", nome: "Lista curta", tipo: "lista", opcoes: ["x"] },
      { id: "A5", nome: "Lista boa", tipo: "lista", opcoes: ["x", "y", "x", ""] },
    ]);
    expect(r.map((c) => c.id)).toEqual(["a1", "a5"]);
    expect(r[1].opcoes).toEqual(["x", "y"]);
  });

  it("aceita no máximo 10 campos", () => {
    const muitos = Array.from({ length: 15 }, (_, i) => ({ id: `c${i}`, nome: `Campo ${i}`, tipo: "texto_curto" }));
    expect(normalizarCamposExtras(muitos)).toHaveLength(10);
  });

  it("a configuração do perfil leva os campos extras", () => {
    const c = normalizarConfig({ campos_extras: [{ id: "c1", nome: "Obs", tipo: "sim_nao" }] }, "LOCAL");
    expect(c.campos_extras[0]).toMatchObject({ id: "c1", tipo: "sim_nao", obrigatorio: false, ativo: true });
    expect(descreverConfig(c).join(" ")).toMatch(/1 campo extra/);
  });
});

describe("validarCamposExtras e novoIdCampoExtra", () => {
  it("exige nome, nomes diferentes e 2 opções na lista", () => {
    expect(validarCamposExtras([campo({ id: "a", nome: "", tipo: "texto_curto" })])).toMatch(/nome/);
    expect(validarCamposExtras([campo({ id: "a", nome: "Obs", tipo: "texto_curto" }), campo({ id: "b", nome: "obs", tipo: "numero" })])).toMatch(/repetido/);
    expect(validarCamposExtras([campo({ id: "a", nome: "Lista", tipo: "lista", opcoes: ["x", ""] })])).toMatch(/2 opções/);
    expect(validarCamposExtras([campo({ id: "a", nome: "Lista", tipo: "lista", opcoes: ["x", "y"] })])).toBeNull();
  });

  it("gera ids únicos no formato aceito pelo banco", () => {
    const usados = ["c1"];
    const id = novoIdCampoExtra(usados);
    expect(id).toMatch(/^[a-z0-9_]{1,24}$/);
    expect(usados).not.toContain(id);
  });
});

describe("valores dos campos extras no ensaio", () => {
  const campos = [
    campo({ id: "obs", nome: "Observações", tipo: "texto_longo", obrigatorio: true }),
    campo({ id: "qtd", nome: "Quantidade", tipo: "numero" }),
    campo({ id: "ok", nome: "Houve visita?", tipo: "sim_nao" }),
    campo({ id: "lst", nome: "Sala", tipo: "lista", opcoes: ["A", "B"] }),
  ];
  const config = configCom(campos);

  it("campo obrigatório vazio é recusado", () => {
    const e = ensaioBase(config);
    expect(validarEnsaioCfg(e, config).map((x) => x.campo)).toEqual(["extra_obs"]);
  });

  it("confere número e opção da lista", () => {
    const e = ensaioBase(config);
    e.extras = { obs: "ok", qtd: "abc", lst: "Z" };
    expect(validarEnsaioCfg(e, config).map((x) => x.campo).sort()).toEqual(["extra_lst", "extra_qtd"]);
  });

  it("campo desativado não é cobrado nem enviado", () => {
    const desligado = configCom([campo({ id: "obs", nome: "Obs", tipo: "texto_curto", obrigatorio: true, ativo: false })]);
    const e = ensaioBase(desligado);
    e.extras = { obs: "texto" };
    expect(validarEnsaioCfg(e, desligado)).toEqual([]);
    expect(montarCargaCfg(e, desligado).extras).toEqual({});
  });

  it("monta os valores com o tipo certo e ignora os vazios", () => {
    const e = ensaioBase(config);
    e.extras = { obs: "  Tudo certo  ", qtd: "3,5", ok: "SIM", lst: "" };
    expect(validarEnsaioCfg(e, config)).toEqual([]);
    expect(montarCargaCfg(e, config).extras).toEqual({ obs: "Tudo certo", qtd: 3.5, ok: true });
  });

  it("volta do banco para o formulário e para o texto de impressão", () => {
    const dados: DadosSalvos = {
      atende_cargo: "ANCIAO",
      atende_nome: "Fulano de Tal",
      palavra: null,
      hino_abertura_id: null,
      atualizado_em: "2026-10-01T00:00:00Z",
      encarregados: [{ ordem: 1, nome: "Beltrano Silva", cidade_uf: "São Paulo-SP", cargo: "LOCAL" }],
      hinos: [],
      extras: { obs: "Texto", qtd: 4, ok: false },
    };
    const e = estadoDosDadosCfg(dados, config);
    expect(e.extras).toEqual({ obs: "Texto", qtd: "4", ok: "NAO" });
    expect(valorExtraTexto(campos[2], false)).toBe("Não");
    expect(valorExtraTexto(campos[2], "SIM")).toBe("Sim");
    expect(valorExtraTexto(campos[1], 4)).toBe("4");
    expect(valorExtraTexto(campos[0], undefined)).toBe("");
  });
});

describe("campos extras na impressão", () => {
  it("entram depois da palavra, em linha inteira", () => {
    const op = montarImpressaoEnsaio({
      tipoEvento: "Ensaio Local",
      quando: "17/10/2026 às 19h30",
      local: "Casa",
      atende: "Fulano — Ancião",
      rotuloEncarregados: "Encarregado Local",
      encarregados: ["Beltrano"],
      hinoAbertura: "",
      palavra: "",
      extras: [{ rotulo: "Observações", valor: "Tudo certo" }],
      hinosExecutados: [],
      emitidoPor: "x",
      geradoEm: "agora",
    });
    const i = op.informacoes?.findIndex((x) => x.rotulo === "Observações") ?? -1;
    expect(i).toBeGreaterThan(0);
    expect(op.informacoes?.[i - 1].rotulo).toBe("Palavra");
    expect(op.informacoes?.[i].largo).toBe(true);
  });
});
