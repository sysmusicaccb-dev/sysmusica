import { describe, expect, it } from "vitest";
import {
  alternarGrupo,
  resumoGrupos,
  validarGruposEscolhidos,
} from "@/modules/administracao/gruposDoUsuario";

describe("alternarGrupo", () => {
  it("adiciona um grupo que não estava marcado", () => {
    expect(alternarGrupo(["a"], "b")).toEqual(["a", "b"]);
  });

  it("remove um grupo que estava marcado", () => {
    expect(alternarGrupo(["a", "b"], "a")).toEqual(["b"]);
  });

  it("não altera a lista original", () => {
    const original = ["a"];
    alternarGrupo(original, "b");
    expect(original).toEqual(["a"]);
  });
});

describe("validarGruposEscolhidos", () => {
  it("exige pelo menos um grupo", () => {
    expect(validarGruposEscolhidos([])).toBe("Escolha pelo menos um grupo.");
    expect(validarGruposEscolhidos(["a"])).toBeNull();
    expect(validarGruposEscolhidos(["a", "b", "c"])).toBeNull();
  });
});

describe("resumoGrupos", () => {
  it("junta os nomes e trata a lista vazia", () => {
    expect(resumoGrupos(["Secretaria", "Aprovadores"])).toBe("Secretaria, Aprovadores");
    expect(resumoGrupos([])).toBe("Sem grupo");
  });
});
