import { describe, expect, it } from "vitest";
import { abasDeAdministracao } from "@/components/layout/abasAdministracao";
import { GRUPOS_MENU, filtrarMenu, itemMenuAtivo } from "@/components/layout/navegacao";
import type { CodigoPermissao } from "@/lib/permissoes";

const criarPode = (permitidas: CodigoPermissao[]) => (permissao: CodigoPermissao) => permitidas.includes(permissao);
const rotulos = (permitidas: CodigoPermissao[]) => abasDeAdministracao(criarPode(permitidas)).map((aba) => aba.rotulo);

describe("abas da Administração (Usuários | Grupos e Permissões)", () => {
  it("quem vê Usuários e Grupos vê as duas abas", () => {
    expect(rotulos(["usuarios.visualizar", "grupos.visualizar"])).toEqual(["Usuários", "Grupos e Permissões"]);
  });

  it("uma aba só não mostra a barra", () => {
    expect(rotulos(["usuarios.visualizar"])).toEqual([]);
    expect(rotulos(["grupos.visualizar"])).toEqual([]);
  });

  it("sem permissões, nenhuma aba", () => {
    expect(rotulos([])).toEqual([]);
  });
});

describe("menu: Usuários e Grupos e Permissões em um item só", () => {
  const hrefsDe = (permitidas: CodigoPermissao[]) =>
    filtrarMenu(GRUPOS_MENU, criarPode(permitidas)).flatMap((grupo) => grupo.itens.map((item) => item.href));

  it("quem vê os dois tem um único item no menu", () => {
    expect(hrefsDe(["usuarios.visualizar", "grupos.visualizar"])).toEqual(["/administracao/usuarios"]);
  });

  it("quem só tem Grupos continua vendo o item Grupos e Permissões", () => {
    expect(hrefsDe(["grupos.visualizar"])).toEqual(["/administracao/grupos"]);
  });

  it("o item Usuários fica marcado também na tela de Grupos e Permissões", () => {
    const usuarios = GRUPOS_MENU.flatMap((grupo) => grupo.itens).find((item) => item.href === "/administracao/usuarios");
    expect(usuarios).toBeDefined();
    if (!usuarios) return;
    expect(itemMenuAtivo(usuarios, "/administracao/grupos")).toBe(true);
    expect(itemMenuAtivo(usuarios, "/administracao/auditoria")).toBe(false);
  });
});
