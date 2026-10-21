import { describe, expect, it } from "vitest";
import {
  CADASTRO_VAZIO,
  cargoEntraNoCadastro,
  cargoExigeCartao,
  cargosDoCadastro,
  deRetornoDoBanco,
  emailValido,
  formatarCep,
  formatarTelefone,
  formatarWhatsapp,
  paraEnvioAoBanco,
  somenteDigitos,
  temAlgumDado,
  validarCadastro,
  type CadastroMusical,
} from "./cadastroMusical";

const completoOk: CadastroMusical = {
  ...CADASTRO_VAZIO,
  selado: "sim",
  ddd: "71",
  telefone: "999998888",
  tem_whatsapp: "sim",
  cep: "40000000",
  endereco: "Rua das Flores",
  numero: "10",
  uf: "BA",
};
const base = { completo: true, exigeCartao: false, cidade: "Salvador", bairro: "Itinga" };

describe("cargos do cadastro", () => {
  it("aceita os cargos do formulário (com ou sem acento, com (a))", () => {
    for (const nome of ["Encarregado Regional", "Encarregado Local", "Examinadora", "Instrutor (a)", "Músico", "Organista"]) {
      expect(cargoEntraNoCadastro(nome), nome).toBe(true);
    }
  });

  it("não aceita os cargos que só entram nas contagens", () => {
    for (const nome of ["Ancião", "Diácono", "Cooperador do Ofício Ministerial", "Secretário da Música", "Candidato (a)"]) {
      expect(cargoEntraNoCadastro(nome), nome).toBe(false);
    }
  });

  it("na edição mantém o cargo atual do membro, mesmo antigo", () => {
    const cargos = [
      { id: "1", nome: "Músico" },
      { id: "2", nome: "Ancião" },
      { id: "3", nome: "Diácono" },
    ];
    expect(cargosDoCadastro(cargos).map((c) => c.id)).toEqual(["1"]);
    expect(cargosDoCadastro(cargos, "2").map((c) => c.id)).toEqual(["1", "2"]);
  });

  it("exige o cartão: usa a coluna do banco; sem ela, a lista padrão", () => {
    expect(cargoExigeCartao({ id: "1", nome: "Músico", exige_cartao: true })).toBe(true);
    expect(cargoExigeCartao({ id: "1", nome: "Examinadora", exige_cartao: false })).toBe(false);
    expect(cargoExigeCartao({ id: "1", nome: "Encarregado Local" })).toBe(true);
    expect(cargoExigeCartao({ id: "1", nome: "Examinadora", exige_cartao: null })).toBe(true);
    expect(cargoExigeCartao({ id: "1", nome: "Organista" })).toBe(false);
    expect(cargoExigeCartao(undefined)).toBe(false);
  });
});

describe("formatos de digitação", () => {
  it("só dígitos", () => {
    expect(somenteDigitos("(71) 9 9999-8888")).toBe("71999998888");
    expect(somenteDigitos("abc123456", 4)).toBe("1234");
  });
  it("CEP", () => {
    expect(formatarCep("40000")).toBe("40000");
    expect(formatarCep("40000000")).toBe("40000-000");
    expect(formatarCep("40.000-000999")).toBe("40000-000");
  });
  it("telefone", () => {
    expect(formatarTelefone("9999")).toBe("9999");
    expect(formatarTelefone("99998888")).toBe("9999-8888");
    expect(formatarTelefone("999998888")).toBe("99999-8888");
  });
  it("WhatsApp", () => {
    expect(formatarWhatsapp("")).toBe("");
    expect(formatarWhatsapp("7")).toBe("(7");
    expect(formatarWhatsapp("71")).toBe("(71");
    expect(formatarWhatsapp("719999")).toBe("(71) 9999");
    expect(formatarWhatsapp("7199998888")).toBe("(71) 9999-8888");
    expect(formatarWhatsapp("71999998888")).toBe("(71) 99999-8888");
  });
});

describe("validarCadastro", () => {
  it("cadastro completo e correto passa", () => {
    expect(validarCadastro(completoOk, base)).toBeNull();
  });

  it("exige cada campo obrigatório quando completo", () => {
    const casos: [Partial<CadastroMusical>, string][] = [
      [{ selado: "" }, "selada"],
      [{ ddd: "" }, "DDD"],
      [{ telefone: "" }, "telefone"],
      [{ tem_whatsapp: "" }, "WhatsApp"],
      [{ cep: "" }, "CEP"],
      [{ endereco: " " }, "endereço"],
      [{ numero: "" }, "número"],
      [{ uf: "" }, "UF"],
    ];
    for (const [troca, trecho] of casos) {
      const erro = validarCadastro({ ...completoOk, ...troca }, base);
      expect(erro, trecho).toContain(trecho);
    }
    expect(validarCadastro(completoOk, { ...base, cidade: "" })).toContain("cidade");
    expect(validarCadastro(completoOk, { ...base, bairro: " " })).toContain("bairro");
  });

  it("sem exigir completo, aceita vazio mas confere o formato do que foi preenchido", () => {
    const solto = { ...base, completo: false };
    expect(validarCadastro(CADASTRO_VAZIO, solto)).toBeNull();
    expect(validarCadastro({ ...CADASTRO_VAZIO, ddd: "7" }, solto)).toContain("DDD");
    expect(validarCadastro({ ...CADASTRO_VAZIO, telefone: "123" }, solto)).toContain("telefone");
    expect(validarCadastro({ ...CADASTRO_VAZIO, cep: "123" }, solto)).toContain("CEP");
    expect(validarCadastro({ ...CADASTRO_VAZIO, uf: "XX" }, solto)).toContain("UF");
    expect(validarCadastro({ ...CADASTRO_VAZIO, email: "sem-arroba" }, solto)).toContain("e-mail");
    expect(
      validarCadastro({ ...CADASTRO_VAZIO, tem_whatsapp: "sim", whatsapp: "123" }, solto)
    ).toContain("WhatsApp");
  });

  it("cartão de identificação: número e validade obrigatórios quando o cargo exige", () => {
    const comCartao = { ...base, exigeCartao: true };
    expect(validarCadastro(completoOk, comCartao)).toContain("número do cartão");
    expect(validarCadastro({ ...completoOk, cartao_numero: "123" }, comCartao)).toContain("validade");
    expect(
      validarCadastro({ ...completoOk, cartao_numero: "123", cartao_validade: "2030-01-01" }, comCartao)
    ).toBeNull();
  });

  it("validade não pode ser anterior à emissão", () => {
    const erro = validarCadastro(
      { ...completoOk, cartao_emissao: "2025-05-01", cartao_validade: "2025-01-01" },
      base
    );
    expect(erro).toContain("anterior");
  });
});

describe("e-mail e dados preenchidos", () => {
  it("e-mail", () => {
    expect(emailValido("a@b.com")).toBe(true);
    expect(emailValido("a@b")).toBe(false);
    expect(emailValido("a b@c.com")).toBe(false);
  });
  it("detecta se há algum dado", () => {
    expect(temAlgumDado(CADASTRO_VAZIO)).toBe(false);
    expect(temAlgumDado({ ...CADASTRO_VAZIO, observacao: "x" })).toBe(true);
    expect(temAlgumDado({ ...CADASTRO_VAZIO, selado: "nao" })).toBe(true);
  });
});

describe("conversão com o banco", () => {
  it("envio: vazio vira null e booleanos viram true/false", () => {
    const envio = paraEnvioAoBanco({ ...completoOk, selado: "nao", complemento: "  " });
    expect(envio.selado).toBe(false);
    expect(envio.tem_whatsapp).toBe(true);
    expect(envio.complemento).toBeNull();
    expect(envio.email).toBeNull();
    expect(envio.uf).toBe("BA");
  });

  it("WhatsApp: vazio com 'sim' copia o telefone; com 'não' não guarda", () => {
    expect(paraEnvioAoBanco({ ...completoOk, whatsapp: "" }).whatsapp).toBe("71999998888");
    expect(paraEnvioAoBanco({ ...completoOk, whatsapp: "(71) 98888-7777" }).whatsapp).toBe("71988887777");
    expect(paraEnvioAoBanco({ ...completoOk, tem_whatsapp: "nao", whatsapp: "71999998888" }).whatsapp).toBeNull();
  });

  it("retorno do banco: aceita nulos e lixo sem quebrar", () => {
    expect(deRetornoDoBanco(null)).toEqual(CADASTRO_VAZIO);
    const lido = deRetornoDoBanco({ selado: true, tem_whatsapp: false, uf: "BA", ddd: null, numero: 5 });
    expect(lido.selado).toBe("sim");
    expect(lido.tem_whatsapp).toBe("nao");
    expect(lido.uf).toBe("BA");
    expect(lido.ddd).toBe("");
    expect(lido.numero).toBe("");
  });

  it("ida e volta mantém os dados", () => {
    const volta = deRetornoDoBanco(paraEnvioAoBanco(completoOk));
    expect(volta).toEqual({ ...completoOk, whatsapp: "71999998888" });
  });
});
