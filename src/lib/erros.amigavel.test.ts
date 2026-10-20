import { describe, expect, it } from "vitest";
import { mensagemDoErro } from "./erros";

describe("mensagemDoErro (textos técnicos do banco)", () => {
  it("troca o texto técnico de permissão por uma mensagem clara", () => {
    const msg = mensagemDoErro({ code: "42501", message: "permission denied for function portaria_encerrada" }, "padrão");
    expect(msg).toContain("não tem permissão");
    expect(msg).not.toContain("portaria_encerrada");
  });
  it("troca o texto de segurança por linha (RLS) também", () => {
    const msg = mensagemDoErro({ code: "42501", message: 'new row violates row-level security policy for table "eventos"' }, "padrão");
    expect(msg).toContain("não tem permissão");
  });
  it("mantém as mensagens que o próprio sistema escreve", () => {
    expect(mensagemDoErro({ code: "42501", message: "Este evento já foi encerrado. Só o Administrador pode alterá-lo." }, "padrão")).toBe(
      "Este evento já foi encerrado. Só o Administrador pode alterá-lo."
    );
    expect(mensagemDoErro({ code: "P0001", message: "Motivo obrigatório." }, "padrão")).toBe("Motivo obrigatório.");
  });
  it("traduz referência inválida e campo obrigatório vazio", () => {
    expect(mensagemDoErro({ code: "23503", message: "violates foreign key constraint" }, "padrão")).toContain("ligado a outros dados");
    expect(mensagemDoErro({ code: "23502", message: "null value in column" }, "padrão")).toContain("campos obrigatórios");
  });
  it("registro repetido e erros desconhecidos seguem como antes", () => {
    expect(mensagemDoErro({ code: "23505", message: "duplicate key" }, "padrão", "Já existe.")).toBe("Já existe.");
    expect(mensagemDoErro({ code: "XX000", message: "algo interno" }, "padrão")).toBe("padrão");
  });
});
