import { describe, expect, it } from "vitest";
import { abasDeEventos } from "@/components/layout/abasEventos";
import type { CodigoPermissao } from "@/lib/permissoes";

const criarPode = (permitidas: CodigoPermissao[]) => (permissao: CodigoPermissao) => permitidas.includes(permissao);
const rotulos = (permitidas: CodigoPermissao[]) => abasDeEventos(criarPode(permitidas)).map((a) => a.rotulo);

describe("aba Perfil do Evento", () => {
  it("aparece para quem edita tipos de evento, entre Gestão de Portarias e Configurações", () => {
    expect(
      rotulos(["eventos.visualizar", "tipoevento.visualizar", "tipoevento.editar", "portarias.visualizar", "eventos.configurar"])
    ).toEqual(["Eventos", "Tipo do Evento", "Gestão de Portarias", "Perfil do Evento", "Configurações"]);
  });

  it("não aparece para quem só visualiza os tipos", () => {
    expect(rotulos(["eventos.visualizar", "tipoevento.visualizar"])).not.toContain("Perfil do Evento");
  });
});
