import { describe, expect, it } from "vitest";
import { abasDeEventos } from "@/components/layout/abasEventos";
import type { CodigoPermissao } from "@/lib/permissoes";

const criarPode = (permitidas: CodigoPermissao[]) => (permissao: CodigoPermissao) => permitidas.includes(permissao);
const rotulos = (permitidas: CodigoPermissao[]) => abasDeEventos(criarPode(permitidas)).map((aba) => aba.rotulo);

describe("abasDeEventos", () => {
  it("quem tem tudo vê as três abas, na ordem Eventos, Gestão de portarias, Portaria", () => {
    expect(rotulos(["eventos.visualizar", "portarias.visualizar", "portaria.visualizar"])).toEqual([
      "Eventos",
      "Gestão de portarias",
      "Portaria",
    ]);
  });

  it("a aba de Gestão de portarias aparece para quem só cria ou só aprova", () => {
    expect(rotulos(["eventos.visualizar", "portarias.criar"])).toEqual(["Eventos", "Gestão de portarias"]);
    expect(rotulos(["eventos.visualizar", "portarias.aprovar"])).toEqual(["Eventos", "Gestão de portarias"]);
  });

  it("só Eventos + Portaria mostra duas abas", () => {
    expect(rotulos(["eventos.visualizar", "portaria.visualizar"])).toEqual(["Eventos", "Portaria"]);
  });

  it("uma aba só não mostra barra", () => {
    expect(rotulos(["eventos.visualizar"])).toEqual([]);
  });

  it("Tipo do Evento é a segunda aba, logo depois de Eventos", () => {
    expect(rotulos(["eventos.visualizar", "tipoevento.visualizar"])).toEqual(["Eventos", "Tipo do Evento"]);
    expect(
      rotulos(["eventos.visualizar", "tipoevento.visualizar", "portarias.visualizar", "portaria.visualizar"])
    ).toEqual(["Eventos", "Tipo do Evento", "Gestão de portarias", "Portaria"]);
  });

  it("sem a permissão de Tipo do Evento a aba não aparece; sem Eventos não há barra", () => {
    expect(rotulos(["eventos.visualizar", "portaria.visualizar"])).not.toContain("Tipo do Evento");
    expect(rotulos(["tipoevento.visualizar"])).toEqual([]);
  });

  it("quem não tem Eventos não vê barra (o grupo Portaria continua só com o item Portaria)", () => {
    expect(rotulos(["portaria.visualizar", "portaria.registrar"])).toEqual([]);
    expect(rotulos(["portarias.visualizar", "portaria.visualizar"])).toEqual([]);
  });
});
