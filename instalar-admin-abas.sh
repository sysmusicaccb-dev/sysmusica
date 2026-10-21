#!/usr/bin/env bash
# =============================================================================
# SysMúsica — AJUSTE: Usuários e Grupos e Permissões em um item só do menu (com abas) + títulos das telas com a primeira letra maiúscula
#
#  Não precisa de SQL. Cria a barra de abas Usuários | Grupos e Permissões e acerta os títulos das telas.
#
# Segurança: confere cada trecho (exatamente 1 vez), faz backup em /tmp/bkp-admin-abas-*, aplica,
# roda tsc, vitest, eslint e build; se algo falhar, DESFAZ tudo sozinho (inclusive os arquivos novos).
#
# Uso:  cd /workspaces/sysmusica/sysmusica && rm -rf .next && bash instalar-admin-abas.sh
# Log:  /tmp/instalar-admin-abas.log
# =============================================================================

LOG=/tmp/instalar-admin-abas.log
BKP=/tmp/bkp-admin-abas-$(date +%Y%m%d-%H%M%S)
RAIZ="$(pwd)"

(
[ -f package.json ] && [ -d src ] || { echo "ERRO: rode dentro da pasta sysmusica (onde está o package.json)."; exit 1; }
mkdir -p "$BKP"
export BKP RAIZ

echo "== 1/3  Conferindo e aplicando as alterações =="
# (ajuste simples: sem SQL)
python3 - <<'PYSCRIPT'
import os, shutil, sys, hashlib

RAIZ = os.environ["RAIZ"]
BKP = os.environ["BKP"]

# (arquivo, trecho antigo, trecho novo) — cada "antigo" precisa existir EXATAMENTE 1 vez no arquivo.
# Os trechos usam \n; o instalador converte para o fim de linha do próprio arquivo (CRLF ou LF).
EDITS = [
    ('src/components/layout/navegacao.ts',
     r'''        rotulo: "Usuários",
        icone: KeyRound,
        permissao: "usuarios.visualizar",
''',
     r'''        rotulo: "Usuários",
        icone: KeyRound,
        permissao: "usuarios.visualizar",
        // Grupos e Permissões é ABA dentro de Usuários: o item continua marcado nessa tela
        tambemAtivoEm: ["/administracao/grupos"],
'''),
    ('src/components/layout/navegacao.ts',
     r'''        permissao: "grupos.visualizar",
''',
     r'''        permissao: "grupos.visualizar",
        ocultoSe: "usuarios.visualizar", // quem vê Usuários acessa por aba; quem só tem Grupos continua vendo o item
'''),
    ('src/components/layout/navegacao.test.ts',
     r'''describe("migalhasVisiveis", () => {''',
     r'''describe("Grupos e Permissões como aba de Usuários", () => {
  it("quem vê os dois tem um único item (Usuários) no menu de Administração", () => {
    const menu = filtrarMenu(GRUPOS_MENU, criarPode(["usuarios.visualizar", "grupos.visualizar"]));
    const administracao = menu.find((grupo) => grupo.titulo === "Administração");
    expect(administracao?.itens.map((item) => item.rotulo)).toEqual(["Usuários"]);
  });

  it("quem só tem Grupos vê o item Grupos e Permissões", () => {
    const menu = filtrarMenu(GRUPOS_MENU, criarPode(["grupos.visualizar"]));
    expect(menu.flatMap((grupo) => grupo.itens.map((item) => item.rotulo))).toEqual(["Grupos e Permissões"]);
  });
});

describe("migalhasVisiveis", () => {'''),
    ('src/app/(painel)/administracao/usuarios/layout.tsx',
     r'''import RequerPermissao from "@/modules/autenticacao/components/RequerPermissao";
''',
     r'''import RequerPermissao from "@/modules/autenticacao/components/RequerPermissao";
import AbasDeAdministracao from "@/components/layout/AbasDeAdministracao";
'''),
    ('src/app/(painel)/administracao/usuarios/layout.tsx',
     r'''  return <RequerPermissao permissao="usuarios.visualizar">{children}</RequerPermissao>;''',
     r'''  return (
    <RequerPermissao permissao="usuarios.visualizar">
      {/* Abas Usuários | Grupos e Permissões (só aparecem para quem tem acesso às duas) */}
      <AbasDeAdministracao />
      {children}
    </RequerPermissao>
  );'''),
    ('src/app/(painel)/administracao/grupos/layout.tsx',
     r'''import RequerPermissao from "@/modules/autenticacao/components/RequerPermissao";
''',
     r'''import RequerPermissao from "@/modules/autenticacao/components/RequerPermissao";
import AbasDeAdministracao from "@/components/layout/AbasDeAdministracao";
'''),
    ('src/app/(painel)/administracao/grupos/layout.tsx',
     r'''  return <RequerPermissao permissao="grupos.visualizar">{children}</RequerPermissao>;''',
     r'''  return (
    <RequerPermissao permissao="grupos.visualizar">
      {/* Abas Usuários | Grupos e Permissões (só aparecem para quem tem acesso às duas) */}
      <AbasDeAdministracao />
      {children}
    </RequerPermissao>
  );'''),
    ('src/app/(painel)/administracao/grupos/page.tsx',
     r'''titulo="Grupos e permissões"''',
     r'''titulo="Grupos e Permissões"'''),
    ('src/app/(painel)/administracao/grupos/page.tsx',
     r'''Administração > Grupos e permissões:''',
     r'''Administração > Grupos e Permissões:'''),
    ('src/app/(painel)/instrumentos/page.tsx',
     r'''titulo="Instrumentos e famílias"''',
     r'''titulo="Instrumentos e Famílias"'''),
    ('src/app/(painel)/cadastros-pendentes/page.tsx',
     r'''titulo="Cadastros pendentes"''',
     r'''titulo="Cadastros Pendentes"'''),
    ('src/app/(painel)/painel-ao-vivo/page.tsx',
     r'''titulo="Painel ao vivo"''',
     r'''titulo="Painel ao Vivo"'''),
    ('src/app/(painel)/membros/page.tsx',
     r'''titulo="Músicos / Organistas"''',
     r'''titulo="Músicos e Organistas"'''),
]


# Arquivos NOVOS (o instalador recusa se algum já existir)
NOVOS = {
    'src/components/layout/abasAdministracao.ts': r'''/**
 * SysMúsica — Abas da Administração de acesso (regra pura): Usuários | Grupos e Permissões.
 * Cada aba é uma tela que já existe (mesma rota e mesma permissão); aqui só se decide QUAIS abas a pessoa vê.
 * As abas existem para quem tem a permissão de Usuários e acesso também a Grupos: quem só tem Grupos
 * continua com o item "Grupos e Permissões" no menu (ver ocultoSe em navegacao.ts) e não vê barra de abas.
 */
import type { CodigoPermissao } from "@/lib/permissoes";

export interface AbaAdministracao {
  href: string;
  rotulo: string;
}

export function abasDeAdministracao(pode: (permissao: CodigoPermissao) => boolean): AbaAdministracao[] {
  if (!pode("usuarios.visualizar")) return [];

  const abas: AbaAdministracao[] = [{ href: "/administracao/usuarios", rotulo: "Usuários" }];
  if (pode("grupos.visualizar")) abas.push({ href: "/administracao/grupos", rotulo: "Grupos e Permissões" });

  // Uma aba só não precisa de barra
  return abas.length > 1 ? abas : [];
}
''',
    'src/components/layout/abasAdministracao.test.ts': r'''import { describe, expect, it } from "vitest";
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
''',
    'src/components/layout/AbasDeAdministracao.tsx': r'''"use client";

/**
 * SysMúsica — Barra de abas da Administração de acesso: Usuários | Grupos e Permissões.
 * Cada aba leva para a tela que já existe (mesma rota e mesma permissão). A barra é exibida pelos layouts
 * dessas duas telas e só aparece para quem vê as duas abas (regra em ./abasAdministracao.ts).
 */
import Link from "next/link";
import { usePathname } from "next/navigation";
import { cn } from "@/lib/cn";
import { useSessao } from "@/modules/autenticacao/SessaoProvider";
import { abasDeAdministracao } from "./abasAdministracao";
import { itemAtivo } from "./navegacao";

export default function AbasDeAdministracao() {
  const caminho = usePathname() ?? "";
  const { pode } = useSessao();
  const abas = abasDeAdministracao(pode);

  if (abas.length === 0) return null;

  return (
    // Mesma largura do conteúdo das telas de Usuários e Grupos (max-w-7xl); não sai na impressão
    <div className="mx-auto max-w-7xl px-4 pt-6 sm:px-6 lg:px-8 print:hidden">
      <nav aria-label="Seções de Usuários e Grupos" className="flex gap-1 overflow-x-auto border-b border-slate-200">
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


# Arquivos a REMOVER: só são apagados se o conteúdo for idêntico ao esperado (cópia fica no backup)
REMOVER = {}


# Arquivos SUBSTITUÍDOS por inteiro: só troca se o original tiver o hash (sha256, fim de linha normalizado) esperado
SUBST = {}


def ler(caminho):
    with open(caminho, "r", encoding="utf-8", newline="") as f:
        return f.read()

def eol_de(txt):
    return "\r\n" if "\r\n" in txt else "\n"

def adaptar(trecho, eol):
    return trecho.replace("\n", eol) if eol != "\n" else trecho

def norm(t):
    return t.replace("\r\n", "\n").rstrip("\n")

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

for arq in list(NOVOS):
    p = os.path.join(RAIZ, arq)
    if os.path.exists(p):
        if norm(ler(p)) == norm(NOVOS[arq]):
            print(f"já existe, idêntico (mantido): {arq}")
            del NOVOS[arq]
        else:
            problemas.append(f"JÁ EXISTE E É DIFERENTE (não vou sobrescrever): {arq}")

for arq, esperado in REMOVER.items():
    caminho = os.path.join(RAIZ, arq)
    if not os.path.isfile(caminho):
        problemas.append(f"PARA REMOVER, NÃO ENCONTRADO: {arq}")
    elif ler(caminho).replace("\r\n", "\n").strip() != esperado.replace("\r\n", "\n").strip():
        problemas.append(f"PARA REMOVER, CONTEÚDO DIFERENTE DO ESPERADO (não vou apagar): {arq}")

for arq, info in SUBST.items():
    caminho = os.path.join(RAIZ, arq)
    if not os.path.isfile(caminho):
        problemas.append(f"PARA SUBSTITUIR, NÃO ENCONTRADO: {arq}")
    elif hashlib.sha256(norm(ler(caminho)).encode("utf-8")).hexdigest() != info["sha"]:
        problemas.append(f"PARA SUBSTITUIR, O ARQUIVO É DIFERENTE DO ESPERADO (não vou sobrescrever): {arq}")

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

substituidos = []
for arq, info in SUBST.items():
    origem = os.path.join(RAIZ, arq)
    destino = os.path.join(BKP, arq)
    os.makedirs(os.path.dirname(destino), exist_ok=True)
    shutil.copy2(origem, destino)
    eol = eol_de(ler(origem))
    with open(origem, "w", encoding="utf-8", newline="") as f:
        f.write(adaptar(info["novo"].rstrip("\n") + "\n", eol))
    substituidos.append(arq)

removidos = []
for arq in REMOVER:
    origem = os.path.join(RAIZ, arq)
    destino = os.path.join(BKP, arq)
    os.makedirs(os.path.dirname(destino), exist_ok=True)
    shutil.copy2(origem, destino)
    os.remove(origem)
    removidos.append(arq)

for arq, cont in NOVOS.items():
    destino = os.path.join(RAIZ, arq)
    os.makedirs(os.path.dirname(destino), exist_ok=True)
    with open(destino, "w", encoding="utf-8", newline="") as f:
        f.write(cont)
    criados.append(arq)

with open(os.path.join(BKP, ".arquivos"), "w", encoding="utf-8") as f:
    f.write("\n".join(a for a in alterados + substituidos + criados if a.endswith((".ts", ".tsx"))) + "\n")
with open(os.path.join(BKP, ".novos"), "w", encoding="utf-8") as f:
    f.write("\n".join(criados) + "\n")
print(f"OK: {len(EDITS)} trocas em {len(alterados)} arquivos + {len(substituidos)} substituídos + {len(criados)} arquivos novos + {len(removidos)} removidos. Backup em {BKP}")
PYSCRIPT
rc=$?
[ $rc -eq 0 ] || { echo "Nada foi alterado (veja acima)."; exit 1; }

reverter() {
  echo "↩ Desfazendo as alterações a partir de $BKP ..."
  ( cd "$BKP" && find . -type f ! -name .arquivos ! -name .novos -print0 | while IFS= read -r -d '' f; do cp "$f" "$RAIZ/$f"; done )
  while IFS= read -r n; do [ -n "$n" ] && { rm -f "$RAIZ/$n"; rmdir -p "$(dirname "$RAIZ/$n")" 2>/dev/null; }; done < "$BKP/.novos"
  true
}

passo() {
  nome="$1"; shift
  echo "▶ $nome"
  if "$@" > /tmp/adminabas-passo.out 2>&1; then
    echo "  ok"
  else
    echo "  FALHOU: $nome"; tail -40 /tmp/adminabas-passo.out
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
echo "Pronto: recarregue o sistema e confira Administração > Usuários."
echo "Depois confira as telas (passo a passo na conversa) e, se estiver tudo certo, faça o git push."
) 2>&1 | tee "$LOG"
