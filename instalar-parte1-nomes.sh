#!/usr/bin/env bash
# =============================================================================
# SysMúsica — PARTE 1: nomes e padronização (SEM banco, SEM SQL)
#
#  - Menu e título "Membros"  -> "Músicos / Organistas" (a rota /membros não muda)
#  - Todos os botões "Novo ..." -> "Adicionar" (e os textos de tela vazia que os citam)
#  - Coluna e rótulos "Congregação" -> "Casa de Oração"
#
# Como funciona (segurança):
#  1) confere que CADA trecho a trocar existe exatamente 1 vez (senão lista e para, sem alterar nada)
#  2) faz backup em /tmp/bkp-parte1-*
#  3) aplica as trocas (mantém quebras de linha CRLF/LF do arquivo)
#  4) roda tsc, vitest, eslint e build; se algo falhar, DESFAZ tudo sozinho
#
# Uso:  cd /workspaces/sysmusica/sysmusica && bash instalar-parte1-nomes.sh
# Log:  /tmp/instalar-parte1.log
# =============================================================================

LOG=/tmp/instalar-parte1.log
BKP=/tmp/bkp-parte1-$(date +%Y%m%d-%H%M%S)
RAIZ="$(pwd)"

(
[ -f package.json ] && [ -d src ] || { echo "ERRO: rode dentro da pasta sysmusica (onde está o package.json)."; exit 1; }
mkdir -p "$BKP"
export BKP RAIZ

echo "== 1/3  Conferindo e aplicando as trocas de texto =="
python3 - <<'PYSCRIPT'
import os, shutil, sys

RAIZ = os.environ["RAIZ"]
BKP = os.environ["BKP"]

# (arquivo, trecho antigo, trecho novo) — cada "antigo" precisa existir EXATAMENTE 1 vez no arquivo.
# Os trechos são de uma linha só (sem quebra), então não dependem de CRLF/LF.
EDITS = [
    # ---- Menu e título da tela Membros -> Músicos / Organistas (rota /membros fica igual) ----
    ("src/components/layout/navegacao.ts",
     'rotulo: "Membros", icone: Users',
     'rotulo: "Músicos / Organistas", icone: Users'),
    ("src/components/layout/navegacao.test.ts",
     '{ rotulo: "Membros" }',
     '{ rotulo: "Músicos / Organistas" }'),
    ("src/app/(painel)/membros/page.tsx",
     'titulo="Membros"',
     'titulo="Músicos / Organistas"'),
    ("src/modules/dashboard/components/AtalhosRapidos.tsx",
     'rotulo: "Cadastrar membro", descricao: "Novo membro, cargo e instrumento"',
     'rotulo: "Cadastrar músico / organista", descricao: "Cargo, instrumento e Casa de Oração"'),

    # ---- Botões "Novo ..." -> "Adicionar" (o ícone + continua; troca só o texto) ----
    ("src/app/(painel)/membros/page.tsx",
     '  Novo membro',
     '  Adicionar'),
    ("src/components/ListaMembros.tsx",
     'Clique em “Novo membro” para cadastrar o primeiro.',
     'Clique em “Adicionar” para cadastrar o primeiro.'),

    ("src/app/(painel)/eventos/page.tsx",
     '  Novo evento',
     '  Adicionar'),
    ("src/app/(painel)/eventos/page.tsx",
     'Clique em “Novo evento” para cadastrar o próximo.',
     'Clique em “Adicionar” para cadastrar o próximo.'),
    ("src/components/ListaEventos.tsx",
     'Clique em “Novo evento” para cadastrar o primeiro.',
     'Clique em “Adicionar” para cadastrar o primeiro.'),

    ("src/app/(painel)/instrumentos/page.tsx",
     '  Novo instrumento',
     '  Adicionar'),
    ("src/app/(painel)/instrumentos/page.tsx",
     'Clique em “Novo instrumento” ou cadastre um membro com instrumento.',
     'Clique em “Adicionar” ou cadastre um músico ou organista com instrumento.'),

    ("src/app/(painel)/administracao/organizacao/page.tsx",
     '  Novo estado',
     '  Adicionar'),
    ("src/app/(painel)/administracao/organizacao/page.tsx",
     'Clique em “Novo estado” para começar.',
     'Clique em “Adicionar” para começar.'),

    ("src/app/(painel)/administracao/usuarios/page.tsx",
     '  Novo usuário',
     '  Adicionar'),
    ("src/app/(painel)/administracao/usuarios/page.tsx",
     'Clique em “Novo usuário” para criar o primeiro.',
     'Clique em “Adicionar” para criar o primeiro.'),

    ("src/app/(painel)/administracao/grupos/page.tsx",
     '  Novo grupo',
     '  Adicionar'),
    ("src/app/(painel)/administracao/grupos/page.tsx",
     'Clique em “Novo grupo” para criar o primeiro.',
     'Clique em “Adicionar” para criar o primeiro.'),

    ("src/app/(painel)/portarias/page.tsx",
     '  Nova portaria',
     '  Adicionar'),
    ("src/app/(painel)/portarias/page.tsx",
     'Clique em “Nova portaria” para solicitar a portaria de um evento.',
     'Clique em “Adicionar” para solicitar a portaria de um evento.'),

    # ---- "Congregação" -> "Casa de Oração" (o dado interno continua o mesmo) ----
    ("src/components/ListaMembros.tsx",
     'Família, Congregação e Status;',
     'Família, Casa de Oração e Status;'),
    ("src/components/ListaMembros.tsx",
     '  Congregação',          # cabeçalho da coluna (2+ espaços de indentação; o comentário tem só 1)
     '  Casa de Oração'),
    ("src/modules/atendimento/components/CartaoConferencia.tsx",
     '{ rotulo: "Congregação", valor: membro.congregacao },',
     '{ rotulo: "Casa de Oração", valor: membro.congregacao },'),
    ("src/modules/relatorios/catalogo.ts",
     'rotulo: "Congregação do membro"',
     'rotulo: "Casa de Oração do membro"'),
    ("src/modules/auditoria/regras.ts",
     'congregacao: "Congregação",',
     'congregacao: "Casa de Oração",'),
    ("src/modules/dashboard/components/PainelGraficos.tsx",
     'titulo="Membros por congregação" descricao="As congregações com mais membros."',
     'titulo="Membros por Casa de Oração" descricao="As Casas de Oração com mais membros."'),
]

# 1) leitura (newline="" preserva CRLF/LF exatamente como está no arquivo)
conteudo = {}
problemas = []
for arq, antigo, novo in EDITS:
    caminho = os.path.join(RAIZ, arq)
    if arq not in conteudo:
        if not os.path.isfile(caminho):
            problemas.append(f"ARQUIVO NÃO ENCONTRADO: {arq}")
            conteudo[arq] = None
            continue
        with open(caminho, "r", encoding="utf-8", newline="") as f:
            conteudo[arq] = f.read()
    if conteudo[arq] is None:
        continue

# 2) cada trecho antigo deve existir exatamente 1 vez (conta sobre o texto ORIGINAL)
for arq, antigo, novo in EDITS:
    txt = conteudo.get(arq)
    if txt is None:
        continue
    n = txt.count(antigo)
    if n != 1:
        problemas.append(f"{arq}: trecho {antigo!r} aparece {n} vez(es) (esperado 1)")

if problemas:
    print("NADA FOI ALTERADO. Divergências encontradas:")
    for p in problemas:
        print("  -", p)
    print("Se a mensagem diz 0 vez(es) em TODOS os itens, esta parte provavelmente já foi aplicada.")
    sys.exit(2)

# 3) backup + gravação
alterados = []
for arq in dict.fromkeys(a for a, _, _ in EDITS):
    origem = os.path.join(RAIZ, arq)
    destino = os.path.join(BKP, arq)
    os.makedirs(os.path.dirname(destino), exist_ok=True)
    shutil.copy2(origem, destino)
    txt = conteudo[arq]
    for a, antigo, novo in EDITS:
        if a == arq:
            if txt.count(antigo) != 1:   # reconfere após as trocas anteriores do mesmo arquivo
                print(f"ERRO: {arq}: {antigo!r} mudou durante a aplicação. Nada foi gravado.")
                sys.exit(2)
            txt = txt.replace(antigo, novo, 1)
    with open(origem, "w", encoding="utf-8", newline="") as f:
        f.write(txt)
    alterados.append(arq)

with open(os.path.join(BKP, ".arquivos"), "w", encoding="utf-8") as f:
    f.write("\n".join(alterados) + "\n")
print(f"OK: {len(EDITS)} trocas em {len(alterados)} arquivos. Backup em {BKP}")
PYSCRIPT
rc=$?
[ $rc -eq 0 ] || { echo "Nada foi alterado (veja acima)."; exit 1; }

reverter() {
  echo "↩ Desfazendo as alterações a partir de $BKP ..."
  ( cd "$BKP" && find . -type f ! -name .arquivos -print0 | while IFS= read -r -d '' f; do cp "$f" "$RAIZ/$f"; done )
}

passo() {
  nome="$1"; shift
  echo "▶ $nome"
  if "$@" > /tmp/p1-passo.out 2>&1; then
    echo "  ok"
  else
    echo "  FALHOU: $nome"; tail -40 /tmp/p1-passo.out
    reverter; echo "Alterações desfeitas. Me envie o log: $LOG"
    exit 1
  fi
}

echo; echo "== 2/3  Verificações =="
mapfile -t ARQ < "$BKP/.arquivos"
passo "tipos (tsc)"      npx tsc --noEmit
passo "testes (vitest)"  npx vitest run
passo "lint (eslint)"    npx eslint "${ARQ[@]}"
passo "build"            npm run build

echo; echo "== 3/3  PRONTO =="
echo "Arquivos alterados: ${#ARQ[@]} (backup: $BKP)"
echo "Agora confira as telas (passo a passo na conversa) e, se estiver tudo certo, faça o git push."
) 2>&1 | tee "$LOG"
