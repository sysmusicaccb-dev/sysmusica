import { describe, expect, it } from "vitest";
import { compararComAtual, diasParaVencer, formatarData, quantosMudaram, simNao, validarMotivo } from "./regras";
import type { DetalheCadastro } from "./tipos";

function detalhe(extra: Partial<DetalheCadastro> = {}): DetalheCadastro {
  return {
    id: "p1", tipo: "NOVO", status: "PENDENTE", membro_id: null, nome: "Maria Souza", data_nascimento: "1990-05-10",
    cidade: "Salvador", bairro: "Centro", cpf: "***.982.***-25", cpf_completo_visivel: false, casa_oracao_id: "c1",
    casa_nome: "Central", cargo_id: "g1", cargo_nome: "Músico", instrumento_id: "i1", instrumento_nome: "Violino",
    categoria: "OFICIALIZADO", dados: { estado_civil: "Solteiro (a)", sexo: "Feminino", batizado: false, selado: false, ddd: "71", telefone: "987654321", cep: "40000000", endereco: "Rua A", numero: "10", uf: "BA" },
    menor: false, responsavel_nome: null, responsavel_telefone: null, aviso_versao: "v1", aceite_em: "2026-10-21T10:00:00Z",
    cpf_conflito: false, criado_em: "2026-10-21T10:00:00Z", expira_em: "2026-12-20T10:00:00Z", decidido_em: null,
    motivo_rejeicao: null, arquivos_disponiveis: true, outros_pendentes: 0, atual: null, ...extra,
  };
}

describe("formatações", () => {
  it("data e sim/não", () => {
    expect(formatarData("2026-10-21")).toBe("21/10/2026");
    expect(formatarData(null)).toBe("—");
    expect(simNao(true)).toBe("Sim");
    expect(simNao(false)).toBe("Não");
    expect(simNao(null)).toBe("—");
  });
  it("dias para vencer nunca fica negativo", () => {
    const agora = new Date("2026-10-21T10:00:00Z");
    expect(diasParaVencer("2026-10-31T10:00:00Z", agora)).toBe(10);
    expect(diasParaVencer("2026-10-01T10:00:00Z", agora)).toBe(0);
  });
});

describe("compararComAtual", () => {
  it("cadastro novo não marca nada como mudado", () => {
    const linhas = compararComAtual(detalhe());
    expect(quantosMudaram(linhas)).toBe(0);
    expect(linhas.find((l) => l.chave === "nome")?.novo).toBe("Maria Souza");
    expect(linhas.find((l) => l.chave === "telefone")?.novo).toBe("(71) 987654321");
  });
  it("atualização destaca só o que mudou", () => {
    const d = detalhe({
      tipo: "ATUALIZACAO", membro_id: "m1",
      atual: {
        nome: "Maria Souza", casa_oracao_id: "c1", casa_nome: "Central", cargo_id: "g1", cargo_nome: "Músico",
        instrumento_id: "i1", instrumento_nome: "Violino", categoria: "OFICIALIZADO", cidade: "Salvador", bairro: "Centro",
        data_nascimento: "1990-05-10",
        cadastro: { estado_civil: "Casado (a)", sexo: "Feminino", batizado: false, selado: false, ddd: "71", telefone: "987654321", cep: "40000000", endereco: "Rua A", numero: "10", uf: "BA" },
      },
    });
    const linhas = compararComAtual(d);
    expect(linhas.filter((l) => l.mudou).map((l) => l.chave)).toEqual(["estado_civil"]);
    const ec = linhas.find((l) => l.chave === "estado_civil");
    expect(ec?.atual).toBe("Casado (a)");
    expect(ec?.novo).toBe("Solteiro (a)");
  });
  it("campo que antes estava vazio e agora foi preenchido conta como mudança", () => {
    const d = detalhe({
      tipo: "ATUALIZACAO", membro_id: "m1",
      atual: { nome: "Maria Souza", casa_oracao_id: "c1", casa_nome: "Central", cargo_id: "g1", cargo_nome: "Músico", instrumento_id: "i1", instrumento_nome: "Violino", categoria: "OFICIALIZADO", cidade: "Salvador", bairro: "Centro", data_nascimento: "1990-05-10", cadastro: null },
    });
    expect(quantosMudaram(compararComAtual(d))).toBeGreaterThan(5);
  });
});

describe("validarMotivo", () => {
  it("exige entre 5 e 300 letras", () => {
    expect(validarMotivo("ok")).toMatch(/pelo menos 5/);
    expect(validarMotivo("   a   b   ")).toMatch(/pelo menos 5/);
    expect(validarMotivo("Documento ilegível")).toBeNull();
    expect(validarMotivo("x".repeat(301))).toMatch(/300/);
  });
});
