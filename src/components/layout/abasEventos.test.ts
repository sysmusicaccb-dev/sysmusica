import { describe, expect, it } from "vitest";
import { abasDeEventos } from "@/components/layout/abasEventos";
import type { CodigoPermissao } from "@/lib/permissoes";

const criarPode = (permitidas: CodigoPermissao[]) => (permissao: CodigoPermissao) => permitidas.includes(permissao);
const rotulos = (permitidas: CodigoPermissao[]) => abasDeEventos(criarPode(permitidas)).map((aba) => aba.rotulo);

describe("abasDeEventos", () => {
  it("quem tem tudo vê as abas Eventos e Gestão de portarias (a aba Portaria não existe mais)", () => {
    expect(rotulos(["eventos.visualizar", "portarias.visualizar", "portaria.visualizar"])).toEqual([
      "Eventos",
      "Gestão de Portarias",
    ]);
  });

  it("a aba de Gestão de portarias aparece para quem só cria ou só aprova", () => {
    expect(rotulos(["eventos.visualizar", "portarias.criar"])).toEqual(["Eventos", "Gestão de Portarias"]);
    expect(rotulos(["eventos.visualizar", "portarias.aprovar"])).toEqual(["Eventos", "Gestão de Portarias"]);
  });

  it("só Eventos + Portaria não mostra barra (Portaria não é mais aba)", () => {
    expect(rotulos(["eventos.visualizar", "portaria.visualizar"])).toEqual([]);
  });

  it("uma aba só não mostra barra", () => {
    expect(rotulos(["eventos.visualizar"])).toEqual([]);
  });

  it("Tipo do Evento é a segunda aba, logo depois de Eventos", () => {
    expect(rotulos(["eventos.visualizar", "tipoevento.visualizar"])).toEqual(["Eventos", "Tipo do Evento"]);
    expect(
      rotulos(["eventos.visualizar", "tipoevento.visualizar", "portarias.visualizar", "portaria.visualizar"])
    ).toEqual(["Eventos", "Tipo do Evento", "Gestão de Portarias"]);
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
