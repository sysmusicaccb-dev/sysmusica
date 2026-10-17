import { afterEach, describe, expect, it, vi } from "vitest";
import { mensagemDoErro } from "@/lib/erros";

describe("mensagemDoErro", () => {
  afterEach(() => vi.restoreAllMocks());

  it("registro repetido (23505) usa a mensagem de duplicado", () => {
    expect(mensagemDoErro({ code: "23505", message: "x" }, "padrão", "Já existe.")).toBe("Já existe.");
  });

  it("regras de negócio, permissão e validação mostram a mensagem do banco", () => {
    expect(mensagemDoErro({ code: "P0001", message: "Em uso." }, "padrão")).toBe("Em uso.");
    expect(mensagemDoErro({ code: "42501", message: "Sem permissão." }, "padrão")).toBe("Sem permissão.");
    expect(mensagemDoErro({ code: "23514", message: "Inválido." }, "padrão")).toBe("Inválido.");
  });

  it("erro desconhecido vira a mensagem padrão e o detalhe vai para o console", () => {
    const console_ = vi.spyOn(console, "error").mockImplementation(() => {});
    expect(mensagemDoErro({ code: "XX000", message: "detalhe técnico" }, "Mensagem padrão.")).toBe(
      "Mensagem padrão."
    );
    expect(console_).toHaveBeenCalled();
  });
});
