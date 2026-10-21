import { describe, expect, it } from "vitest";
import { CADASTRO_VAZIO, type CadastroMusical } from "@/modules/membros/cadastroMusical";
import { cpfValido, formatarCpfParcial } from "./cpf";
import { VERSAO_AVISO, itensDoAviso } from "./aviso";
import {
  cargosDoFormularioPublico,
  dataIsoValida,
  ehMenorDeIdade,
  formularioVazio,
  idadeEm,
  montarCargaPublica,
  validarEnvioPublico,
  type CargoPublico,
  type DadosFormularioPublico,
} from "./regras";

const HOJE = "2026-10-21";
const musico: CargoPublico = { id: "c1", nome: "Músico", permite_instrumento: true, exige_instrumento: true, exige_cartao: false };
const encarregado: CargoPublico = { id: "c2", nome: "Encarregado Local", permite_instrumento: true, exige_instrumento: false, exige_cartao: true };
const ctx = (cargo: CargoPublico | undefined = musico) => ({ cargo, temFoto: true, temDocumentoFrente: true, temDocumentoVerso: true, hoje: HOJE });

const cadastroOk: CadastroMusical = {
  ...CADASTRO_VAZIO,
  estado_civil: "Solteiro (a)", sexo: "Masculino", batizado: "nao", selado: "nao",
  ddd: "11", telefone: "987654321", tem_whatsapp: "sim",
  cep: "01001000", endereco: "Praça da Sé", numero: "1", uf: "SP",
};
function base(extra: Partial<DadosFormularioPublico> = {}): DadosFormularioPublico {
  return {
    ...formularioVazio(CADASTRO_VAZIO),
    nome: "João da Silva", casaOracaoId: "casa1", cargoId: "c1", instrumentoId: "i1", categoria: "OFICIALIZADO",
    cpf: "529.982.247-25", dataNascimento: "1990-05-10", cidade: "São Paulo", bairro: "Sé",
    cadastro: cadastroOk, aceitePrivacidade: true, ...extra,
  };
}

describe("cpf", () => {
  it("aceita válido, recusa inválido e repetido", () => {
    expect(cpfValido("529.982.247-25")).toBe(true);
    expect(cpfValido("52998224725")).toBe(true);
    expect(cpfValido("529.982.247-24")).toBe(false);
    expect(cpfValido("111.111.111-11")).toBe(false);
    expect(cpfValido("123")).toBe(false);
  });
  it("formata parcial", () => {
    expect(formatarCpfParcial("5299822")).toBe("529.982.2");
    expect(formatarCpfParcial("52998224725999")).toBe("529.982.247-25");
  });
});

describe("datas e idade", () => {
  it("valida datas existentes", () => {
    expect(dataIsoValida("2024-02-29")).toBe(true);
    expect(dataIsoValida("2026-02-29")).toBe(false);
    expect(dataIsoValida("10/05/1990")).toBe(false);
  });
  it("calcula a idade no aniversário", () => {
    expect(idadeEm("2008-10-21", HOJE)).toBe(18);
    expect(idadeEm("2008-10-22", HOJE)).toBe(17);
    expect(ehMenorDeIdade("2008-10-22", HOJE)).toBe(true);
    expect(ehMenorDeIdade("2008-10-21", HOJE)).toBe(false);
    expect(ehMenorDeIdade("lixo", HOJE)).toBe(false);
  });
});

describe("validarEnvioPublico", () => {
  it("aceita um cadastro completo", () => expect(validarEnvioPublico(base(), ctx())).toBeNull());
  it("barra o robô (campo-armadilha) sem explicar", () =>
    expect(validarEnvioPublico(base({ site: "x" }), ctx())).toMatch(/Não foi possível/));
  it("exige foto, documento, aceite", () => {
    expect(validarEnvioPublico(base(), { ...ctx(), temFoto: false })).toMatch(/fotografia/);
    expect(validarEnvioPublico(base(), { ...ctx(), temDocumentoVerso: false })).toMatch(/verso/);
    expect(validarEnvioPublico(base({ aceitePrivacidade: false }), ctx())).toMatch(/privacidade/);
  });
  it("confere nome, CPF, nascimento, casa, cargo", () => {
    expect(validarEnvioPublico(base({ nome: "João" }), ctx())).toMatch(/completo/);
    expect(validarEnvioPublico(base({ cpf: "" }), ctx())).toMatch(/Informe o CPF/);
    expect(validarEnvioPublico(base({ cpf: "111.111.111-11" }), ctx())).toMatch(/inválido/);
    expect(validarEnvioPublico(base({ dataNascimento: "2030-01-01" }), ctx())).toMatch(/futuro/);
    expect(validarEnvioPublico(base({ casaOracaoId: "" }), ctx())).toMatch(/Casa de Oração/);
    expect(validarEnvioPublico(base({ cargoId: "" }), ctx(undefined))).toMatch(/cargo/);
  });
  it("recusa cargo sem cadastro musical", () =>
    expect(validarEnvioPublico(base(), ctx({ ...musico, nome: "Ancião" }))).toMatch(/secretaria/));
  it("exige categoria e instrumento do músico", () => {
    expect(validarEnvioPublico(base({ categoria: "" }), ctx())).toMatch(/categoria/);
    expect(validarEnvioPublico(base({ instrumentoId: "" }), ctx())).toMatch(/instrumento/i);
  });
  it("exige cartão no cargo que pede", () => {
    const d = base({ cargoId: "c2", categoria: "" });
    expect(validarEnvioPublico(d, ctx(encarregado))).toMatch(/cartão/);
  });
  it("menor: pede responsável, telefone e aceite", () => {
    const m = { dataNascimento: "2012-01-01" };
    expect(validarEnvioPublico(base(m), ctx())).toMatch(/nome do responsável/);
    expect(validarEnvioPublico(base({ ...m, responsavelNome: "Maria Silva" }), ctx())).toMatch(/telefone do responsável/);
    expect(validarEnvioPublico(base({ ...m, responsavelNome: "Maria Silva", responsavelTelefone: "11987654321" }), ctx())).toMatch(/concordar/);
    expect(validarEnvioPublico(base({ ...m, responsavelNome: "Maria Silva", responsavelTelefone: "(11) 98765-4321", aceiteResponsavel: true }), ctx())).toBeNull();
  });
  it("maior ignora responsável", () => expect(validarEnvioPublico(base(), ctx())).toBeNull());
});

describe("montarCargaPublica", () => {
  it("normaliza e não leva campos internos", () => {
    const c = montarCargaPublica(base({ nome: "  João   da Silva ", cadastro: { ...cadastroOk, observacao: "x", apresentado_por: "y" } }), ctx());
    expect(c.nome).toBe("João da Silva");
    expect(c.cpf).toBe("52998224725");
    expect(c.cadastro.observacao).toBeNull();
    expect(c.cadastro.apresentado_por).toBeNull();
    expect("documento_frente_path" in c.cadastro).toBe(false);
    expect(c.responsavel_nome).toBeNull();
    expect(c.aviso_versao).toBe(VERSAO_AVISO);
  });
  it("menor leva o responsável só com números no telefone", () => {
    const c = montarCargaPublica(base({ dataNascimento: "2012-01-01", responsavelNome: "Maria  Silva", responsavelTelefone: "(11) 98765-4321", aceiteResponsavel: true }), ctx());
    expect(c.responsavel_nome).toBe("Maria Silva");
    expect(c.responsavel_telefone).toBe("11987654321");
    expect(c.aceite_responsavel).toBe(true);
  });
});

describe("cargos e aviso", () => {
  it("lista só cargos com cadastro", () => {
    const r = cargosDoFormularioPublico([musico, encarregado, { ...musico, id: "x", nome: "Ancião" }]);
    expect(r.map((c) => c.nome)).toEqual(["Músico", "Encarregado Local"]);
  });
  it("aviso usa o contato ou o texto alternativo", () => {
    expect(JSON.stringify(itensDoAviso("lgpd@x.org"))).toContain("lgpd@x.org");
    expect(JSON.stringify(itensDoAviso(""))).toContain("secretaria da sua Casa de Oração");
  });
});
