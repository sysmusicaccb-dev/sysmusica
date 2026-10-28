import { describe, expect, it } from "vitest";
import { abasDeEventos } from "@/components/layout/abasEventos";
import type { CodigoPermissao } from "@/lib/permissoes";

const criarPode = (permitidas: CodigoPermissao[]) => (permissao: CodigoPermissao) => permitidas.includes(permissao);

describe("aba Configurações de Eventos", () => {
  it("aparece para quem tem eventos.configurar, por último", () => {
    const rotulos = abasDeEventos(criarPode(["eventos.visualizar", "tipoevento.visualizar", "eventos.configurar"])).map((a) => a.rotulo);
    expect(rotulos).toEqual(["Eventos", "Tipo do Evento", "Configurações"]);
  });

  it("não aparece sem a permissão", () => {
    const rotulos = abasDeEventos(criarPode(["eventos.visualizar", "tipoevento.visualizar"])).map((a) => a.rotulo);
    expect(rotulos).not.toContain("Configurações");
  });
});
