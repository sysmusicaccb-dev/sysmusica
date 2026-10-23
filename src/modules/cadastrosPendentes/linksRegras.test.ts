import { describe, expect, it } from "vitest";
import { urlDoLinkDeCadastro } from "./linksRegras";

describe("urlDoLinkDeCadastro", () => {
  it("monta o endereço com o código", () => {
    expect(urlDoLinkDeCadastro("https://sysmusica.vercel.app", "abc123")).toBe("https://sysmusica.vercel.app/cadastro?l=abc123");
  });
  it("protege caracteres especiais do código", () => {
    expect(urlDoLinkDeCadastro("https://x.com", "a b&c")).toBe("https://x.com/cadastro?l=a%20b%26c");
  });
});
