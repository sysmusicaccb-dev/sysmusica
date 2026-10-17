import { describe, expect, it } from "vitest";
import { valoresDistintos } from "@/lib/listas";

describe("valoresDistintos", () => {
  it("remove repetidos ignorando acento, maiúsculas e espaços, mantendo a primeira grafia", () => {
    expect(valoresDistintos(["Salvador", " salvador ", "Lauro de Freitas", "LAURO  DE FREITAS"])).toEqual([
      "Lauro de Freitas",
      "Salvador",
    ]);
  });

  it("ignora vazios e nulos e ordena em ordem alfabética", () => {
    expect(valoresDistintos([null, undefined, "", "  ", "Ítinga", "Boca do Rio"])).toEqual([
      "Boca do Rio",
      "Ítinga",
    ]);
  });
});
