import { describe, expect, it } from "vitest";
import {
  GRUPOS_MENU,
  filtrarMenu,
  itemAtivo,
  migalhasVisiveis,
  montarMigalhas,
  primeiraRotaPermitida,
} from "@/components/layout/navegacao";
import type { CodigoPermissao } from "@/lib/permissoes";

// Cria a função "pode" a partir de uma lista de permissões (como o contexto de sessão faz)
function criarPode(permitidas: CodigoPermissao[]) {
  return (permissao: CodigoPermissao) => permitidas.includes(permissao);
}

describe("itemAtivo", () => {
  it("a raiz só fica ativa exatamente em '/'", () => {
    expect(itemAtivo("/", "/")).toBe(true);
    expect(itemAtivo("/", "/membros")).toBe(false);
  });

  it("um item fica ativo na própria rota e nas subrotas", () => {
    expect(itemAtivo("/membros", "/membros")).toBe(true);
    expect(itemAtivo("/membros", "/membros/123")).toBe(true);
  });

  it("não confunde rotas com o mesmo prefixo", () => {
    expect(itemAtivo("/membros", "/membrosX")).toBe(false);
  });
});

describe("montarMigalhas", () => {
  it("mostra só 'Dashboard' na raiz", () => {
    expect(montarMigalhas("/")).toEqual([{ rotulo: "Dashboard" }]);
  });

  it("monta Início > Grupo > Página", () => {
    expect(montarMigalhas("/membros")).toEqual([
      { rotulo: "Início", href: "/" },
      { rotulo: "Cadastros" },
      { rotulo: "Membros" },
    ]);
    expect(montarMigalhas("/portaria")).toEqual([
      { rotulo: "Início", href: "/" },
      { rotulo: "Operações" },
      { rotulo: "Portaria" },
    ]);
  });

  it("subrotas usam os mesmos breadcrumbs da página", () => {
    expect(montarMigalhas("/membros/123")).toEqual(montarMigalhas("/membros"));
  });

  it("rota desconhecida volta ao início", () => {
    expect(montarMigalhas("/inexistente")).toEqual([{ rotulo: "Início", href: "/" }]);
  });
});

describe("filtrarMenu", () => {
  it("o grupo Portaria enxerga apenas o item Portaria", () => {
    const menu = filtrarMenu(GRUPOS_MENU, criarPode(["portaria.visualizar", "portaria.registrar"]));
    expect(menu.map((grupo) => grupo.titulo)).toEqual(["Operações"]);
    expect(menu[0].itens.map((item) => item.rotulo)).toEqual(["Portaria"]);
  });

  it("remove os grupos que ficam vazios", () => {
    const menu = filtrarMenu(GRUPOS_MENU, criarPode(["dashboard.visualizar"]));
    expect(menu.map((grupo) => grupo.titulo)).toEqual([null]);
  });

  it("sem permissões, o menu fica vazio", () => {
    expect(filtrarMenu(GRUPOS_MENU, criarPode([]))).toEqual([]);
  });
});

describe("primeiraRotaPermitida", () => {
  it("devolve a primeira tela permitida, ignorando o dashboard", () => {
    expect(primeiraRotaPermitida(criarPode(["portaria.visualizar"]))).toBe("/portaria");
    expect(primeiraRotaPermitida(criarPode(["eventos.visualizar", "portaria.visualizar"]))).toBe(
      "/eventos"
    );
  });

  it("devolve null quando não há nenhuma tela permitida", () => {
    expect(primeiraRotaPermitida(criarPode(["dashboard.visualizar"]))).toBeNull();
  });
});

describe("menu de Administração", () => {
  it("aparece só para quem tem permissão de usuários ou grupos", () => {
    const semAdmin = filtrarMenu(GRUPOS_MENU, criarPode(["portaria.visualizar"]));
    expect(semAdmin.map((grupo) => grupo.titulo)).not.toContain("Administração");

    const comUsuarios = filtrarMenu(GRUPOS_MENU, criarPode(["usuarios.visualizar"]));
    const administracao = comUsuarios.find((grupo) => grupo.titulo === "Administração");
    expect(administracao?.itens.map((item) => item.rotulo)).toEqual(["Usuários"]);
  });

  it("monta os breadcrumbs Início > Administração > Usuários", () => {
    expect(montarMigalhas("/administracao/usuarios")).toEqual([
      { rotulo: "Início", href: "/" },
      { rotulo: "Administração" },
      { rotulo: "Usuários" },
    ]);
  });
});

describe("migalhasVisiveis", () => {
  const caminho = montarMigalhas("/portaria");

  it("quem acessa o dashboard continua vendo o 'Início'", () => {
    const visiveis = migalhasVisiveis(caminho, criarPode(["dashboard.visualizar", "portaria.visualizar"]));
    expect(visiveis.map((migalha) => migalha.rotulo)).toEqual(["Início", "Operações", "Portaria"]);
  });

  it("quem só tem a Portaria não vê o 'Início'", () => {
    const visiveis = migalhasVisiveis(caminho, criarPode(["portaria.visualizar", "portaria.registrar"]));
    expect(visiveis.map((migalha) => migalha.rotulo)).toEqual(["Operações", "Portaria"]);
  });
});

describe("usuário só com acesso à Portaria", () => {
  const pode = criarPode(["portaria.visualizar", "portaria.registrar"]);

  it("vê somente o item Portaria no menu e nenhum outro grupo", () => {
    const menu = filtrarMenu(GRUPOS_MENU, pode);
    const itens = menu.flatMap((grupo) => grupo.itens.map((item) => item.rotulo));
    expect(itens).toEqual(["Portaria"]);
  });

  it("é levado direto para a Portaria ao entrar", () => {
    expect(primeiraRotaPermitida(pode)).toBe("/portaria");
  });

  it("não vê a Gestão de portarias (criar/aprovar é outra responsabilidade)", () => {
    const itens = filtrarMenu(GRUPOS_MENU, pode).flatMap((grupo) => grupo.itens.map((item) => item.href));
    expect(itens).not.toContain("/portarias");
  });
});

describe("Gestão de portarias no menu", () => {
  const podeCom = (permissoes: string[]) => (permissao: string) => permissoes.includes(permissao);
  const hrefs = (permissoes: string[]) =>
    filtrarMenu(GRUPOS_MENU, podeCom(permissoes)).flatMap((grupo) => grupo.itens.map((item) => item.href));

  it("aparece para quem só cria, só aprova ou só visualiza portarias", () => {
    for (const permissao of ["portarias.criar", "portarias.aprovar", "portarias.visualizar"]) {
      expect(hrefs([permissao]), permissao).toContain("/portarias");
    }
  });

  it("quem só cria portarias não vê a Portaria (registro de entrada)", () => {
    expect(hrefs(["portarias.criar"])).toEqual(["/portarias"]);
  });

  it("quem só tem a permissão de fotografia vê apenas Fotografias", () => {
    expect(hrefs(["membros.foto"])).toEqual(["/fotografias"]);
  });

  it("quem só tem a permissão de organização vê apenas Organização", () => {
    expect(hrefs(["organizacao.visualizar"])).toEqual(["/administracao/organizacao"]);
  });

  it("quem só tem a permissão de auditoria vê apenas Auditoria", () => {
    expect(hrefs(["auditoria.visualizar"])).toEqual(["/administracao/auditoria"]);
  });
});
