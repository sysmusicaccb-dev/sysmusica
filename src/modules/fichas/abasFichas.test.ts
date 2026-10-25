import { describe, expect, it } from "vitest";
import { GUIAS, acharGuia, acharSubguia, tiposDaSubguia } from "@/modules/fichas/abasFichas";
import { FICHAS } from "@/modules/fichas/regras";

describe("guias de Fichas Musicais", () => {
  it("seguem a ordem Músicos, Organistas, GEM, Outros", () => {
    expect(GUIAS.map((g) => g.rotulo)).toEqual(["Músicos", "Organistas", "GEM", "Outros"]);
  });

  it("Músicos e Organistas têm Oficialização, Culto Oficial e RJM; GEM tem Músicos e Organistas", () => {
    const rotulos = (id: string) => acharGuia(id).subguias.map((s) => s.rotulo);
    expect(rotulos("musicos")).toEqual(["Oficialização", "Culto Oficial", "RJM"]);
    expect(rotulos("organistas")).toEqual(["Oficialização", "Culto Oficial", "RJM"]);
    expect(rotulos("gem")).toEqual(["Músicos", "Organistas"]);
  });

  it("toda ficha do catálogo aparece em alguma guia (nenhuma fica escondida)", () => {
    const naGuia = new Set(GUIAS.flatMap((g) => g.subguias.flatMap((s) => s.itens.map((i) => i.tipo))));
    for (const ficha of FICHAS) expect(naGuia.has(ficha.tipo)).toBe(true);
  });

  it("M03 é de músico na Oficialização e M02 no Culto Oficial", () => {
    expect(tiposDaSubguia("musicos", "oficializacao")).toEqual(["M03"]);
    expect(tiposDaSubguia("musicos", "culto-oficial")).toEqual(["M02"]);
  });

  it("a M05 de cada etapa das organistas já vem com o destino marcado", () => {
    const destino = (sub: string) => acharSubguia("organistas", sub).itens.find((i) => i.tipo === "M05")?.para;
    expect(destino("oficializacao")).toBe("OFICIALIZADO");
    expect(destino("culto-oficial")).toBe("CULTO_OFICIAL");
    expect(destino("rjm")).toBe("RJM");
  });

  it("id desconhecido cai na primeira guia/sub-guia", () => {
    expect(acharGuia("xx").id).toBe("musicos");
    expect(acharSubguia("gem", "xx").id).toBe("musicos");
  });
});
