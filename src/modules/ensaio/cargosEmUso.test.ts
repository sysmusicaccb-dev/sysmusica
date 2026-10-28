import { describe, expect, it } from "vitest";
import { configPadrao } from "./perfilConfig";
import { cargosEmUso } from "./regrasPerfil";

describe("cargosEmUso (título do bloco acompanha o cargo escolhido)", () => {
  const config = configPadrao("LOCAL"); // Regional, Local e Instrutor

  it("sem escolha, vale o que o perfil permite", () => {
    expect(cargosEmUso([{ cargo: "" }], config)).toEqual(["REGIONAL", "LOCAL", "INSTRUTOR"]);
  });
  it("com escolha, só o cargo escolhido", () => {
    expect(cargosEmUso([{ cargo: "INSTRUTOR" }, { cargo: "" }], config)).toEqual(["INSTRUTOR"]);
  });
  it("cargos misturados mantêm a ordem do perfil", () => {
    expect(cargosEmUso([{ cargo: "INSTRUTOR" }, { cargo: "REGIONAL" }], config)).toEqual(["REGIONAL", "INSTRUTOR"]);
  });
  it("perfil com um cargo só não muda", () => {
    const so = { ...config, encarregados: { ...config.encarregados, cargos: ["INSTRUTOR" as const] } };
    expect(cargosEmUso([{ cargo: null }], so)).toEqual(["INSTRUTOR"]);
  });
});
