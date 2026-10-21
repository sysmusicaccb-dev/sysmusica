#!/usr/bin/env bash
# =============================================================================
# SysMúsica — PARTE 3: abas dentro de EVENTOS (SEM banco, SEM SQL)
#
#  - A tela Eventos ganha uma barra de abas:  Eventos | Gestão de portarias | Portaria
#    (cada aba é a mesma tela de antes, com a mesma rota e a mesma permissão)
#  - No menu lateral sobra só "Eventos": "Gestão de portarias" e "Portaria" saem do menu de quem vê Eventos
#  - Quem NÃO tem a permissão de Eventos (ex.: grupo Portaria) continua com os itens próprios no menu,
#    sem barra de abas: o usuário só da Portaria continua vendo apenas "Portaria"
#  - O item "Eventos" fica marcado no menu enquanto você está em qualquer uma das três abas
#
# Segurança: confere cada trecho (exatamente 1 vez), faz backup em /tmp/bkp-parte3-*, aplica,
# roda tsc, vitest, eslint e build; se algo falhar, DESFAZ tudo sozinho (inclusive os arquivos novos).
#
# Uso:  cd /workspaces/sysmusica/sysmusica && bash instalar-parte3-abas-eventos.sh
# Log:  /tmp/instalar-parte3.log
# =============================================================================

LOG=/tmp/instalar-parte3.log
BKP=/tmp/bkp-parte3-$(date +%Y%m%d-%H%M%S)
RAIZ="$(pwd)"

(
[ -f package.json ] && [ -d src ] || { echo "ERRO: rode dentro da pasta sysmusica (onde está o package.json)."; exit 1; }
mkdir -p "$BKP"
export BKP RAIZ

echo "== 1/3  Conferindo e aplicando as alterações =="
python3 - <<'PYSCRIPT'
import os, shutil, sys

RAIZ = os.environ["RAIZ"]
BKP = os.environ["BKP"]

# (arquivo, trecho antigo, trecho novo) — cada "antigo" precisa existir EXATAMENTE 1 vez no arquivo.
# Os trechos usam \n; o instalador converte para o fim de linha do próprio arquivo (CRLF ou LF).
EDITS = [
    ("src/components/layout/navegacao.ts",
     r'''  qualquer?: CodigoPermissao[]; // ...a não ser que tenha QUALQUER uma destas
}''',
     r'''  qualquer?: CodigoPermissao[]; // ...a não ser que tenha QUALQUER uma destas
  ocultoSe?: CodigoPermissao; // o item SOME do menu para quem tem esta permissão (acessa por aba de outro item)
  tambemAtivoEm?: string[]; // rotas que também deixam este item marcado no menu (ex.: abas de Eventos)
}'''),
    ("src/components/layout/navegacao.ts",
     r'''      { href: "/eventos", rotulo: "Eventos", icone: CalendarDays, permissao: "eventos.visualizar" },''',
     r'''      {
        href: "/eventos",
        rotulo: "Eventos",
        icone: CalendarDays,
        permissao: "eventos.visualizar",
        // Gestão de portarias e Portaria são ABAS dentro de Eventos: o item continua marcado nessas telas
        tambemAtivoEm: ["/portarias", "/portaria"],
      },'''),
    ("src/components/layout/navegacao.ts",
     r'''        qualquer: ["portarias.criar", "portarias.aprovar"],''',
     r'''        qualquer: ["portarias.criar", "portarias.aprovar"],
        ocultoSe: "eventos.visualizar", // quem vê Eventos acessa por aba; os demais mantêm o item'''),
    ("src/components/layout/navegacao.ts",
     r'''      { href: "/portaria", rotulo: "Portaria", icone: DoorOpen, permissao: "portaria.visualizar" },''',
     r'''      {
        href: "/portaria",
        rotulo: "Portaria",
        icone: DoorOpen,
        permissao: "portaria.visualizar",
        ocultoSe: "eventos.visualizar", // quem vê Eventos acessa por aba; quem só tem Portaria continua vendo só este item
      },'''),
    ("src/components/layout/navegacao.ts",
     r'''  return pode(item.permissao) || (item.qualquer ?? []).some((permissao) => pode(permissao));''',
     r'''  // Itens que viraram aba de outro item somem do menu de quem já tem esse outro item
  if (item.ocultoSe && pode(item.ocultoSe)) return false;
  return pode(item.permissao) || (item.qualquer ?? []).some((permissao) => pode(permissao));'''),
    ("src/components/layout/navegacao.ts",
     r'''  return caminho === href || caminho.startsWith(`${href}/`);
}''',
     r'''  return caminho === href || caminho.startsWith(`${href}/`);
}

/** O item do menu está ativo? Vale a rota dele e as rotas das suas abas (ex.: Eventos > Portaria). */
export function itemMenuAtivo(item: ItemMenu, caminho: string): boolean {
  return itemAtivo(item.href, caminho) || (item.tambemAtivoEm ?? []).some((rota) => itemAtivo(rota, caminho));
}'''),
    ("src/components/layout/Sidebar.tsx",
     r'''import { GRUPOS_MENU, filtrarMenu, itemAtivo } from "./navegacao";''',
     r'''import { GRUPOS_MENU, filtrarMenu, itemMenuAtivo } from "./navegacao";'''),
    ("src/components/layout/Sidebar.tsx",
     r'''const ativo = itemAtivo(item.href, caminho);''',
     r'''const ativo = itemMenuAtivo(item, caminho);'''),
    ("src/app/(painel)/eventos/layout.tsx",
     r'''import RequerPermissao from "@/modules/autenticacao/components/RequerPermissao";''',
     r'''import RequerPermissao from "@/modules/autenticacao/components/RequerPermissao";
import AbasDeEventos from "@/components/layout/AbasDeEventos";'''),
    ("src/app/(painel)/eventos/layout.tsx",
     r'''  return <RequerPermissao permissao="eventos.visualizar">{children}</RequerPermissao>;''',
     r'''  return (
    <RequerPermissao permissao="eventos.visualizar">
      {/* Abas Eventos | Gestão de portarias | Portaria (só aparecem para quem tem acesso a mais de uma) */}
      <AbasDeEventos />
      {children}
    </RequerPermissao>
  );'''),
    ("src/app/(painel)/portarias/layout.tsx",
     r'''import RequerPermissao from "@/modules/autenticacao/components/RequerPermissao";''',
     r'''import RequerPermissao from "@/modules/autenticacao/components/RequerPermissao";
import AbasDeEventos from "@/components/layout/AbasDeEventos";'''),
    ("src/app/(painel)/portarias/layout.tsx",
     r'''    <RequerPermissao permissao="portarias.visualizar" ou={["portarias.criar", "portarias.aprovar"]}>
      {children}''',
     r'''    <RequerPermissao permissao="portarias.visualizar" ou={["portarias.criar", "portarias.aprovar"]}>
      <AbasDeEventos />
      {children}'''),
    ("src/app/(painel)/portaria/layout.tsx",
     r'''import RequerPermissao from "@/modules/autenticacao/components/RequerPermissao";''',
     r'''import RequerPermissao from "@/modules/autenticacao/components/RequerPermissao";
import AbasDeEventos from "@/components/layout/AbasDeEventos";'''),
    ("src/app/(painel)/portaria/layout.tsx",
     r'''  return <RequerPermissao permissao="portaria.visualizar">{children}</RequerPermissao>;''',
     r'''  return (
    <RequerPermissao permissao="portaria.visualizar">
      <AbasDeEventos />
      {children}
    </RequerPermissao>
  );'''),
    ("src/components/layout/navegacao.test.ts",
     r'''  itemAtivo,
  migalhasVisiveis,''',
     r'''  itemAtivo,
  itemMenuAtivo,
  migalhasVisiveis,'''),
    ("src/components/layout/navegacao.test.ts",
     r'''    expect(hrefs(["backup.visualizar"])).toEqual(["/administracao/backup"]);
  });
});''',
     r'''    expect(hrefs(["backup.visualizar"])).toEqual(["/administracao/backup"]);
  });
});

describe("Gestão de portarias e Portaria como abas de Eventos", () => {
  const hrefsDe = (pode: ReturnType<typeof criarPode>) =>
    filtrarMenu(GRUPOS_MENU, pode).flatMap((grupo) => grupo.itens.map((item) => item.href));

  it("quem vê Eventos acessa Gestão de portarias e Portaria pelas abas, sem itens soltos no menu", () => {
    const pode = criarPode(["eventos.visualizar", "portarias.visualizar", "portaria.visualizar"]);
    expect(hrefsDe(pode)).toEqual(["/eventos"]);
  });

  it("quem NÃO vê Eventos continua com os itens próprios no menu", () => {
    expect(hrefsDe(criarPode(["portarias.visualizar", "portaria.visualizar"]))).toEqual(["/portarias", "/portaria"]);
    expect(hrefsDe(criarPode(["portaria.visualizar", "portaria.registrar"]))).toEqual(["/portaria"]);
  });

  it("o item Eventos fica marcado nas telas das abas e não nas demais", () => {
    const eventos = GRUPOS_MENU.flatMap((grupo) => grupo.itens).find((item) => item.href === "/eventos");
    expect(eventos).toBeDefined();
    if (!eventos) return;
    for (const caminho of ["/eventos", "/portarias", "/portaria", "/portaria/registros"]) {
      expect(itemMenuAtivo(eventos, caminho), caminho).toBe(true);
    }
    expect(itemMenuAtivo(eventos, "/membros")).toBe(false);
  });

  it("a primeira tela de quem vê Eventos e Portaria continua sendo Eventos", () => {
    expect(primeiraRotaPermitida(criarPode(["eventos.visualizar", "portaria.visualizar"]))).toBe("/eventos");
  });
});'''),
]


# Arquivos NOVOS (o instalador recusa se algum já existir)
NOVOS = {
    "src/components/layout/abasEventos.ts": r'''/**
 * SysMúsica — Abas da tela de Eventos (regra pura): Eventos | Gestão de portarias | Portaria.
 * Cada aba é uma tela que já existe (mesma rota e mesma permissão); aqui só se decide QUAIS abas a pessoa vê.
 * As abas existem só para quem tem a permissão de Eventos e acesso a pelo menos mais uma tela: quem não tem
 * Eventos (ex.: grupo Portaria) continua com os itens próprios no menu e não vê barra de abas.
 */
import type { CodigoPermissao } from "@/lib/permissoes";

export interface AbaEvento {
  href: string;
  rotulo: string;
}

export function abasDeEventos(pode: (permissao: CodigoPermissao) => boolean): AbaEvento[] {
  if (!pode("eventos.visualizar")) return [];

  const abas: AbaEvento[] = [{ href: "/eventos", rotulo: "Eventos" }];
  // Mesma regra do layout de /portarias: visualiza, cria ou aprova
  if (pode("portarias.visualizar") || pode("portarias.criar") || pode("portarias.aprovar")) {
    abas.push({ href: "/portarias", rotulo: "Gestão de portarias" });
  }
  if (pode("portaria.visualizar")) abas.push({ href: "/portaria", rotulo: "Portaria" });

  // Uma aba só não precisa de barra
  return abas.length > 1 ? abas : [];
}
''',
    "src/components/layout/abasEventos.test.ts": r'''import { describe, expect, it } from "vitest";
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

  it("quem não tem Eventos não vê barra (o grupo Portaria continua só com o item Portaria)", () => {
    expect(rotulos(["portaria.visualizar", "portaria.registrar"])).toEqual([]);
    expect(rotulos(["portarias.visualizar", "portaria.visualizar"])).toEqual([]);
  });
});
''',
    "src/components/layout/AbasDeEventos.tsx": r'''"use client";

/**
 * SysMúsica — Barra de abas da tela de Eventos: Eventos | Gestão de portarias | Portaria.
 * Cada aba leva para a tela que já existe (mesma rota e mesma permissão). A barra é exibida pelos layouts
 * dessas três telas e só aparece para quem vê mais de uma aba (regra em ./abasEventos.ts).
 */
import Link from "next/link";
import { usePathname } from "next/navigation";
import { cn } from "@/lib/cn";
import { useSessao } from "@/modules/autenticacao/SessaoProvider";
import { abasDeEventos } from "./abasEventos";
import { itemAtivo } from "./navegacao";

export default function AbasDeEventos() {
  const caminho = usePathname() ?? "";
  const { pode } = useSessao();
  const abas = abasDeEventos(pode);

  if (abas.length === 0) return null;

  return (
    // Mesma largura do conteúdo das telas (max-w-6xl); não sai na impressão
    <div className="mx-auto max-w-6xl px-4 pt-6 sm:px-6 lg:px-8 print:hidden">
      <nav aria-label="Seções de Eventos" className="flex gap-1 overflow-x-auto border-b border-slate-200">
        {abas.map((aba) => {
          const ativa = itemAtivo(aba.href, caminho);
          return (
            <Link
              key={aba.href}
              href={aba.href}
              aria-current={ativa ? "page" : undefined}
              className={cn(
                "-mb-px shrink-0 border-b-2 px-4 py-2.5 text-sm font-medium transition focus:outline-none focus-visible:ring-2 focus-visible:ring-brand-300",
                ativa
                  ? "border-brand-600 text-brand-700"
                  : "border-transparent text-slate-500 hover:border-slate-300 hover:text-slate-700"
              )}
            >
              {aba.rotulo}
            </Link>
          );
        })}
      </nav>
    </div>
  );
}
''',
}


def ler(caminho):
    with open(caminho, "r", encoding="utf-8", newline="") as f:
        return f.read()

def eol_de(txt):
    return "\r\n" if "\r\n" in txt else "\n"

def adaptar(trecho, eol):
    return trecho.replace("\n", eol) if eol != "\n" else trecho

conteudo, problemas = {}, []
for arq, antigo, novo in EDITS:
    if arq in conteudo:
        continue
    caminho = os.path.join(RAIZ, arq)
    if not os.path.isfile(caminho):
        problemas.append(f"ARQUIVO NÃO ENCONTRADO: {arq}")
        conteudo[arq] = None
    else:
        conteudo[arq] = ler(caminho)

for arq, antigo, novo in EDITS:
    txt = conteudo.get(arq)
    if txt is None:
        continue
    n = txt.count(adaptar(antigo, eol_de(txt)))
    if n != 1:
        resumo = antigo.strip().split("\n")[0][:80]
        problemas.append(f"{arq}: trecho «{resumo}…» aparece {n} vez(es) (esperado 1)")

for arq in NOVOS:
    if os.path.exists(os.path.join(RAIZ, arq)):
        problemas.append(f"JÁ EXISTE (não vou sobrescrever): {arq}")

if problemas:
    print("NADA FOI ALTERADO. Divergências encontradas:")
    for p in problemas:
        print("  -", p)
    print("Se TODOS dizem 0 vez(es) / JÁ EXISTE, esta parte provavelmente já foi aplicada.")
    sys.exit(2)

alterados, criados = [], []
for arq in dict.fromkeys(a for a, _, _ in EDITS):
    origem = os.path.join(RAIZ, arq)
    destino = os.path.join(BKP, arq)
    os.makedirs(os.path.dirname(destino), exist_ok=True)
    shutil.copy2(origem, destino)
    txt = conteudo[arq]
    eol = eol_de(txt)
    for a, antigo, novo in EDITS:
        if a != arq:
            continue
        ant = adaptar(antigo, eol)
        if txt.count(ant) != 1:
            print(f"ERRO: {arq}: trecho mudou durante a aplicação. Nada foi gravado.")
            sys.exit(2)
        txt = txt.replace(ant, adaptar(novo, eol), 1)
    with open(origem, "w", encoding="utf-8", newline="") as f:
        f.write(txt)
    alterados.append(arq)

for arq, cont in NOVOS.items():
    destino = os.path.join(RAIZ, arq)
    os.makedirs(os.path.dirname(destino), exist_ok=True)
    with open(destino, "w", encoding="utf-8", newline="") as f:
        f.write(cont)
    criados.append(arq)

with open(os.path.join(BKP, ".arquivos"), "w", encoding="utf-8") as f:
    f.write("\n".join(a for a in alterados + criados if a.endswith((".ts", ".tsx"))) + "\n")
with open(os.path.join(BKP, ".novos"), "w", encoding="utf-8") as f:
    f.write("\n".join(criados) + "\n")
print(f"OK: {len(EDITS)} trocas em {len(alterados)} arquivos + {len(criados)} arquivos novos. Backup em {BKP}")
PYSCRIPT
rc=$?
[ $rc -eq 0 ] || { echo "Nada foi alterado (veja acima)."; exit 1; }

reverter() {
  echo "↩ Desfazendo as alterações a partir de $BKP ..."
  ( cd "$BKP" && find . -type f ! -name .arquivos ! -name .novos -print0 | while IFS= read -r -d '' f; do cp "$f" "$RAIZ/$f"; done )
  while IFS= read -r n; do [ -n "$n" ] && rm -f "$RAIZ/$n"; done < "$BKP/.novos"
}

passo() {
  nome="$1"; shift
  echo "▶ $nome"
  if "$@" > /tmp/p3-passo.out 2>&1; then
    echo "  ok"
  else
    echo "  FALHOU: $nome"; tail -40 /tmp/p3-passo.out
    reverter; echo "Alterações desfeitas. Me envie o log: $LOG"
    exit 1
  fi
}

echo; echo "== 2/3  Verificações =="
mapfile -t ARQ < <(grep -v '^$' "$BKP/.arquivos")
passo "tipos (tsc)"      npx tsc --noEmit
passo "testes (vitest)"  npx vitest run
passo "lint (eslint)"    npx eslint "${ARQ[@]}"
passo "build"            npm run build

echo; echo "== 3/3  PRONTO =="
echo "Backup: $BKP"
echo "Não há SQL nesta parte. Confira as telas (passo a passo na conversa) e, se estiver tudo certo, faça o git push."
) 2>&1 | tee "$LOG"
