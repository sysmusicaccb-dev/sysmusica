#!/usr/bin/env bash
# =============================================================================
# SysMúsica — PARTE 9 (ajuste 3): Casa de Oração com busca e lista de sugestões ao digitar
#
#  Não precisa de SQL. Troca só src/modules/cadastroPublico/components/SeletorCasaPublico.tsx
#  (serve tanto para quem já instalou o ajuste 2 quanto para quem não instalou).
#
# Segurança: confere cada trecho (exatamente 1 vez), faz backup em /tmp/bkp-parte9aj3-*, aplica,
# roda tsc, vitest, eslint e build; se algo falhar, DESFAZ tudo sozinho (inclusive os arquivos novos).
#
# Uso:  cd /workspaces/sysmusica/sysmusica && rm -rf .next && bash instalar-parte9-ajuste3.sh
# Log:  /tmp/instalar-parte9aj3.log
# =============================================================================

LOG=/tmp/instalar-parte9aj3.log
BKP=/tmp/bkp-parte9aj3-$(date +%Y%m%d-%H%M%S)
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
EDITS = []


# Arquivos NOVOS (o instalador recusa se algum já existir)
NOVOS = {}


# Arquivos a REMOVER: só são apagados se o conteúdo for idêntico ao esperado (cópia fica no backup)
REMOVER = {}


# Arquivos SUBSTITUÍDOS por inteiro: só troca se o original tiver o hash (sha256, fim de linha normalizado) esperado
SUBST = {
    "src/modules/cadastroPublico/components/SeletorCasaPublico.tsx": {"sha": ["0e69412136ba0ca2cfdf4e53fd96c703272ee15309c6ba6bd03042fca3ba1046", "4f0acb265060fabdd9ac05149b6063e7b5ae1e99756f93dc9df8026f5c86ea6e"], "novo": r'''"use client";

/**
 * SysMúsica — Escolha da Casa de Oração no formulário público (campo com busca e lista de sugestões).
 * A pessoa começa a digitar e aparece, na hora, a lista das Casas de Oração que combinam (por nome ou pelo caminho
 * RRM › RA › ADM › Setor). Clicar numa sugestão (ou usar as setas + Enter) escolhe a casa.
 * A lista inteira vem de uma vez da função pública opcoes_cadastro_publico (só nome e caminho na organização), então
 * a busca é instantânea e não faz uma consulta ao banco a cada letra. Se a pessoa digitar de novo depois de escolher,
 * a escolha é desfeita (para não enviar uma casa diferente da que está escrita).
 */
import { useId, useMemo, useState, type KeyboardEvent } from "react";
import type { CasaPublica } from "../regras";
import { classeInput } from "./Campos";

/** Quantas sugestões aparecem de uma vez (o resto some até a pessoa digitar mais). */
const MAXIMO_SUGESTOES = 30;

function semAcento(texto: string): string {
  return texto.normalize("NFD").replace(/[̀-ͯ]/g, "").toLowerCase();
}

function caminho(casa: CasaPublica): string {
  return [casa.rrm, casa.ra, casa.adm, casa.setor].filter((parte): parte is string => !!parte).join(" › ");
}

interface Props {
  id: string;
  valor: string; // id da casa escolhida ("" = nenhuma)
  onChange: (id: string) => void;
  casas: CasaPublica[];
  disabled?: boolean;
}

export default function SeletorCasaPublico({ id, valor, onChange, casas, disabled }: Props) {
  const idLista = useId();
  const [texto, setTexto] = useState("");
  const [aberto, setAberto] = useState(false);
  const [destaque, setDestaque] = useState(0);

  // Com uma casa já escolhida, ao abrir a lista mostra todas; sem escolha, filtra pelo que foi digitado
  const encontradas = useMemo(() => {
    const termo = valor ? "" : semAcento(texto.trim());
    if (termo === "") return casas;
    return casas.filter((c) => semAcento(`${c.nome} ${caminho(c)}`).includes(termo));
  }, [texto, valor, casas]);
  const sugestoes = encontradas.slice(0, MAXIMO_SUGESTOES);

  function escolher(casa: CasaPublica) {
    setTexto(casa.nome);
    onChange(casa.id);
    setAberto(false);
  }

  function aoDigitar(novo: string) {
    setTexto(novo);
    if (valor) onChange(""); // mudou o texto: a escolha anterior deixa de valer
    setAberto(true);
    setDestaque(0);
  }

  function aoTeclar(e: KeyboardEvent<HTMLInputElement>) {
    if (e.key === "ArrowDown") {
      e.preventDefault();
      setAberto(true);
      setDestaque((d) => Math.min(d + 1, sugestoes.length - 1));
    } else if (e.key === "ArrowUp") {
      e.preventDefault();
      setDestaque((d) => Math.max(d - 1, 0));
    } else if (e.key === "Enter" && aberto && sugestoes[destaque]) {
      e.preventDefault(); // não envia o formulário: só escolhe a casa
      escolher(sugestoes[destaque]);
    } else if (e.key === "Escape") {
      setAberto(false);
    }
  }

  return (
    <div className="relative space-y-1">
      <input
        id={id}
        type="text"
        role="combobox"
        aria-expanded={aberto}
        aria-controls={idLista}
        aria-autocomplete="list"
        autoComplete="off"
        value={texto}
        disabled={disabled}
        placeholder="Comece a digitar o nome da Casa de Oração"
        onChange={(e) => aoDigitar(e.target.value)}
        onFocus={() => setAberto(true)}
        onBlur={() => setAberto(false)}
        onKeyDown={aoTeclar}
        className={classeInput}
      />

      {aberto && (
        <ul
          id={idLista}
          role="listbox"
          className="absolute z-20 mt-1 max-h-64 w-full overflow-y-auto rounded-lg border border-slate-300 bg-white py-1 text-sm shadow-lg"
        >
          {casas.length === 0 && <li className="px-3 py-2 text-slate-500">Nenhuma Casa de Oração disponível. Avise a secretaria.</li>}
          {casas.length > 0 && sugestoes.length === 0 && (
            <li className="px-3 py-2 text-slate-500">Nenhuma Casa de Oração encontrada. Confira o que digitou.</li>
          )}
          {sugestoes.map((casa, i) => (
            <li
              key={casa.id}
              role="option"
              aria-selected={casa.id === valor}
              // mouseDown (e não click): acontece ANTES de o campo perder o foco e fechar a lista
              onMouseDown={(e) => {
                e.preventDefault();
                escolher(casa);
              }}
              onMouseEnter={() => setDestaque(i)}
              className={`cursor-pointer px-3 py-2 ${i === destaque ? "bg-brand-50" : ""} ${casa.id === valor ? "font-semibold" : ""}`}
            >
              <span className="block text-slate-900">{casa.nome}</span>
              {caminho(casa) && <span className="block text-xs text-slate-500">{caminho(casa)}</span>}
            </li>
          ))}
          {encontradas.length > MAXIMO_SUGESTOES && (
            <li className="px-3 py-2 text-xs text-slate-500">Mostrando {MAXIMO_SUGESTOES} de {encontradas.length}. Digite mais letras para refinar.</li>
          )}
        </ul>
      )}

      {valor && <p className="text-xs font-medium text-emerald-700">Casa de Oração escolhida.</p>}
    </div>
  );
}
'''},
}


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
    elif hashlib.sha256(norm(ler(caminho)).encode("utf-8")).hexdigest() not in ([info["sha"]] if isinstance(info["sha"], str) else info["sha"]):
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
  if "$@" > /tmp/p9aj3-passo.out 2>&1; then
    echo "  ok"
  else
    echo "  FALHOU: $nome"; tail -40 /tmp/p9aj3-passo.out
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
echo "Pronto: recarregue /cadastro e digite o nome da Casa de Oração."
echo "Depois confira as telas (passo a passo na conversa) e, se estiver tudo certo, faça o git push."
) 2>&1 | tee "$LOG"
