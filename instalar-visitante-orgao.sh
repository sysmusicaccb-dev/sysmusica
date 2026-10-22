#!/usr/bin/env bash
# =============================================================================
# SysMúsica — AJUSTE: formulário de visitante da portaria só oferece o instrumento Órgão para Organista, Examinadora e Instrutor(a)
#
#  Não precisa de SQL. O banco já recusava o instrumento errado; agora a tela mostra só os Órgãos e escolhe sozinha.
#
# Segurança: confere cada trecho (exatamente 1 vez), faz backup em /tmp/bkp-visitante-orgao-*, aplica,
# roda tsc, vitest, eslint e build; se algo falhar, DESFAZ tudo sozinho (inclusive os arquivos novos).
#
# Uso:  cd /workspaces/sysmusica/sysmusica && rm -rf .next && bash instalar-visitante-orgao.sh
# Log:  /tmp/instalar-visitante-orgao.log
# =============================================================================

LOG=/tmp/instalar-visitante-orgao.log
BKP=/tmp/bkp-visitante-orgao-$(date +%Y%m%d-%H%M%S)
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
    ('src/modules/atendimento/components/FormularioVisitante.tsx',
     r'''import { validarInstrumentoDoCargo } from "@/modules/instrumentos/selecao";
''',
     r'''import { validarInstrumentoDoCargo } from "@/modules/instrumentos/selecao";
import { cargoSomenteOrgao, instrumentosDoCargo } from "@/modules/membros/cadastroMusical";
'''),
    ('src/modules/atendimento/components/FormularioVisitante.tsx',
     r'''  const exigeInstrumento = cargo?.exige_instrumento === true;
''',
     r'''  const exigeInstrumento = cargo?.exige_instrumento === true;
  // Cargo travado no Órgão (Organista, Examinadora, Instrutor e Instrutora): só os instrumentos Órgão aparecem
  const somenteOrgao = cargoSomenteOrgao(cargo);
  const instrumentosDisponiveis = instrumentosDoCargo(opcoes?.instrumentos ?? [], somenteOrgao);
'''),
    ('src/modules/atendimento/components/FormularioVisitante.tsx',
     r'''    if (!novo?.permite_instrumento) setInstrumentoId("");
''',
     r'''    if (!novo?.permite_instrumento) {
      setInstrumentoId("");
    } else if (cargoSomenteOrgao(novo)) {
      // Cargo travado no Órgão: escolhe o Órgão sozinho (se só houver um) e tira um instrumento que não seja Órgão
      const orgaos = instrumentosDoCargo(opcoes?.instrumentos ?? [], true);
      setInstrumentoId((atual) => (orgaos.some((item) => item.id === atual) ? atual : orgaos.length === 1 ? orgaos[0].id : ""));
    }
'''),
    ('src/modules/atendimento/components/FormularioVisitante.tsx',
     r'''    if (erroInstrumento) return setErro(erroInstrumento);
''',
     r'''    if (erroInstrumento) return setErro(erroInstrumento);
    // Cargo travado no Órgão: o instrumento precisa ser um dos Órgãos (o banco confere de novo)
    if (somenteOrgao && instrumentoId && !instrumentosDisponiveis.some((item) => item.id === instrumentoId)) {
      return setErro(`O cargo ${cargo?.nome ?? "escolhido"} só pode usar o instrumento Órgão.`);
    }
'''),
    ('src/modules/atendimento/components/FormularioVisitante.tsx',
     r'''              instrumentos={opcoes.instrumentos}
              familias={opcoes.familias}
              obrigatorio={exigeInstrumento}
              disabled={salvando}
''',
     r'''              instrumentos={instrumentosDisponiveis}
              familias={opcoes.familias}
              obrigatorio={exigeInstrumento}
              disabled={salvando || (somenteOrgao && instrumentosDisponiveis.length === 1)}
'''),
    ('src/modules/atendimento/components/FormularioVisitante.tsx',
     r'''              className={classeInput}
            />
          </div>

          <FamiliaAutomatica''',
     r'''              className={classeInput}
            />
            {somenteOrgao && (
              <p className="text-xs text-slate-500">
                {instrumentosDisponiveis.length === 0
                  ? "Este cargo só usa o instrumento Órgão, mas nenhum Órgão está cadastrado. Peça a um administrador para cadastrar em Instrumentos e famílias."
                  : "Este cargo só usa o instrumento Órgão (escolhido automaticamente)."}
              </p>
            )}
          </div>

          <FamiliaAutomatica'''),
]


# Arquivos NOVOS (o instalador recusa se algum já existir)
NOVOS = {
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
  if "$@" > /tmp/visitanteorg-passo.out 2>&1; then
    echo "  ok"
  else
    echo "  FALHOU: $nome"; tail -40 /tmp/visitanteorg-passo.out
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
echo "Pronto. Confira o cadastro de visitante na Portaria e faça o git push."
echo "Depois confira as telas (passo a passo na conversa) e, se estiver tudo certo, faça o git push."
) 2>&1 | tee "$LOG"
