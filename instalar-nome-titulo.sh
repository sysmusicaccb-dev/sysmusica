#!/usr/bin/env bash
# =============================================================================
# SysMúsica — AJUSTE: nome "Sysmusica" em todo o sistema, título da impressão centralizado e sem a linha "Filtros: Nenhum filtro adicional"
#
#  Não precisa de SQL. Troca SysMúsica -> Sysmusica em todos os textos (telas, impressões, e-mails e avisos de backup, testes).
#  Não mexe em dados: o prefixo do QR Code (SYSMUSICA:1:), chaves em minúsculo e o nome do banco ficam como estão.
#
# Segurança: confere cada trecho (exatamente 1 vez), faz backup em /tmp/bkp-nome-titulo-*, aplica,
# roda tsc, vitest, eslint e build; se algo falhar, DESFAZ tudo sozinho (inclusive os arquivos novos).
#
# Uso:  cd /workspaces/sysmusica/sysmusica && rm -rf .next && bash instalar-nome-titulo.sh
# Log:  /tmp/instalar-nome-titulo.log
# =============================================================================

LOG=/tmp/instalar-nome-titulo.log
BKP=/tmp/bkp-nome-titulo-$(date +%Y%m%d-%H%M%S)
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
    ('src/modules/relatorios/regras.ts',
     r'''    lista.push({
      rotulo: "Filtros",
      valor: textoOutrosFiltros(definicao, filtros, rotulos) || "Nenhum filtro adicional",
      largo: true,
    });
''',
     r'''    // Só mostra a linha quando há filtro de verdade; sem filtro, ela some do cabeçalho
    const outros = textoOutrosFiltros(definicao, filtros, rotulos);
    if (outros) lista.push({ rotulo: "Filtros", valor: outros, largo: true });
'''),
    ('src/modules/relatorios/regras.test.ts',
     r'''    expect(lista).toContain("Filtros: Nenhum filtro adicional");
''',
     r'''    // Sem filtro adicional, a linha "Filtros" não aparece no cabeçalho
    expect(lista.some((linha) => linha.startsWith("Filtros"))).toBe(false);
'''),
    ('src/lib/exportacao.ts',
     r'''.cab { display: flex; align-items: center; gap: 14px;''',
     r'''.cab { display: grid; grid-template-columns: 1fr minmax(0, auto) 1fr; align-items: center; gap: 14px;'''),
    ('src/lib/exportacao.ts',
     r'''.marca { display: flex;''',
     r'''.marca { grid-column: 1; justify-self: start; display: flex;'''),
    ('src/lib/exportacao.ts',
     r'''.tit { min-width: 0; flex: 1; }''',
     r'''.tit { min-width: 0; grid-column: 2; text-align: center; } /* título centralizado na folha */'''),
]


# Arquivos NOVOS (o instalador recusa se algum já existir)
NOVOS = {
    'src/lib/exportacao.titulo.test.ts': r'''/** Sysmusica — Teste do cabeçalho da impressão: o título fica centralizado na folha. */
import { describe, expect, it } from "vitest";
import { montarHtmlImpressao } from "./exportacao";

describe("título da impressão", () => {
  const html = montarHtmlImpressao({ titulo: "Portarias", marca: "Sysmusica", colunas: ["A"], linhas: [["1"]] });

  it("centraliza o título e deixa a marca à esquerda", () => {
    expect(html).toContain("grid-column: 2; text-align: center;");
    expect(html).toContain(".marca { grid-column: 1; justify-self: start;");
    expect(html).toContain("<h1>Portarias</h1>");
  });
});
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

# ---- Troca global do nome: "SysMúsica"/"Sysmúsica" -> "Sysmusica" (só textos; prefixos de dados como SYSMUSICA:1: e nomes em minúsculo NÃO mudam)
import re
PADRAO = re.compile(r"Sys[mM]úsica|\bSysMusica\b")
globais, trocas = [], 0
candidatos = ["vitest.config.ts", ".github/workflows/ci.yml"]
for pasta, _dirs, nomes in os.walk(os.path.join(RAIZ, "src")):
    for nome in nomes:
        if nome.endswith((".ts", ".tsx", ".css", ".mjs")):
            candidatos.append(os.path.relpath(os.path.join(pasta, nome), RAIZ))
for arq in sorted(candidatos):
    caminho = os.path.join(RAIZ, arq)
    if not os.path.isfile(caminho):
        continue
    txt = ler(caminho)
    novo_txt, n = PADRAO.subn("Sysmusica", txt)
    if n == 0:
        continue
    destino = os.path.join(BKP, arq)
    if not os.path.exists(destino):
        os.makedirs(os.path.dirname(destino), exist_ok=True)
        shutil.copy2(caminho, destino)
    with open(caminho, "w", encoding="utf-8", newline="") as f:
        f.write(novo_txt)
    globais.append(arq)
    trocas += n
print(f"Nome: {trocas} trocas para 'Sysmusica' em {len(globais)} arquivos.")
alterados += globais

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
  if "$@" > /tmp/nometitulo-passo.out 2>&1; then
    echo "  ok"
  else
    echo "  FALHOU: $nome"; tail -40 /tmp/nometitulo-passo.out
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
echo "Pronto. Confira o nome, imprima um relatório e faça o git push."
echo "Depois confira as telas (passo a passo na conversa) e, se estiver tudo certo, faça o git push."
) 2>&1 | tee "$LOG"
