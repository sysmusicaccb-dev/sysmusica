import { describe, expect, it } from "vitest";
import { ErroHttp } from "@/modules/administracao/server/erros";
import { erroDoBanco, exigirUuid } from "./erros";

describe("erroDoBanco", () => {
  it("repassa a mensagem dos códigos esperados", () => {
    const e = erroDoBanco({ code: "P0429", message: "Muitas tentativas." });
    expect(e).toBeInstanceOf(ErroHttp);
    expect((e as ErroHttp).status).toBe(429);
    expect((erroDoBanco({ code: "42501", message: "x" }) as ErroHttp).status).toBe(403);
    expect((erroDoBanco({ code: "P0002", message: "x" }) as ErroHttp).status).toBe(404);
    expect((erroDoBanco({ code: "23505", message: "x" }) as ErroHttp).status).toBe(409);
    expect((erroDoBanco({ code: "P0001", message: "CPF inválido." }) as ErroHttp).status).toBe(400);
  });
  it("erro desconhecido NÃO vaza detalhe para a pessoa", () => {
    const e = erroDoBanco({ code: "XX000", message: "segredo interno" });
    expect(e).not.toBeInstanceOf(ErroHttp);
  });
});

describe("exigirUuid", () => {
  it("aceita uuid e recusa o resto", () => {
    expect(exigirUuid("aaaaaaaa-0000-4000-8000-000000000001")).toBe("aaaaaaaa-0000-4000-8000-000000000001");
    expect(() => exigirUuid("../../x")).toThrow();
    expect(() => exigirUuid(undefined)).toThrow();
  });
});
