#!/usr/bin/env bash
# =============================================================================
# SysMúsica — PARTE 6: ilustração de cada instrumento (SEM SQL)
#
#  - Desenho simples e original (SVG) para cada instrumento, escolhido pelo NOME do instrumento
#  - Instrumento sem desenho próprio usa o desenho genérico da família (Cordas, Madeiras, Metais, Teclas)
#  - Aparece em: Instrumentos e famílias (tabela e formulário) e na lista de Músicos / Organistas
#  - Sem banco e sem SQL
#
# Segurança: confere cada trecho (exatamente 1 vez), faz backup em /tmp/bkp-parte6-*, aplica,
# roda tsc, vitest, eslint e build; se algo falhar, DESFAZ tudo sozinho (inclusive os arquivos novos).
#
# Uso:  cd /workspaces/sysmusica/sysmusica && bash instalar-parte6-ilustracoes.sh
# Log:  /tmp/instalar-parte6.log
# =============================================================================

LOG=/tmp/instalar-parte6.log
BKP=/tmp/bkp-parte6-$(date +%Y%m%d-%H%M%S)
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
    ("src/modules/instrumentos/components/TabelaInstrumentos.tsx",
     r'''import Badge from "@/components/ui/Badge";''',
     r'''import Badge from "@/components/ui/Badge";
import IlustracaoInstrumento from "./IlustracaoInstrumento";'''),
    ("src/modules/instrumentos/components/TabelaInstrumentos.tsx",
     r'''                    <td className="px-4 py-3 font-medium text-slate-900">{instrumento.nome}</td>''',
     r'''                    <td className="px-4 py-3 font-medium text-slate-900">
                      <div className="flex items-center gap-3">
                        {/* Ilustração pelo nome do instrumento (genérica da família quando não há desenho próprio) */}
                        <IlustracaoInstrumento nome={instrumento.nome} familia={familia?.nome} />
                        {instrumento.nome}
                      </div>
                    </td>'''),
    ("src/modules/instrumentos/components/FormularioInstrumento.tsx",
     r'''import { atualizarInstrumento, criarInstrumento } from "../services/instrumentos";''',
     r'''import { atualizarInstrumento, criarInstrumento } from "../services/instrumentos";
import IlustracaoInstrumento from "./IlustracaoInstrumento";'''),
    ("src/modules/instrumentos/components/FormularioInstrumento.tsx",
     r'''          placeholder="Ex: Clarinete"
          className={classeInput}
        />
      </div>''',
     r'''          placeholder="Ex: Clarinete"
          className={classeInput}
        />
      </div>

      {/* Prévia da ilustração: muda conforme o nome e a família (instrumento sem desenho usa o da família) */}
      {nome.trim() !== "" && (
        <div className="flex items-center gap-3 rounded-lg bg-slate-50 px-3 py-2">
          <IlustracaoInstrumento nome={nome} familia={familiaAtual?.nome} tamanho="grande" />
          <p className="text-xs text-slate-600">
            Ilustração que aparece nas listas. Se o instrumento não tiver desenho próprio, aparece o da família.
          </p>
        </div>
      )}'''),
    ("src/components/ListaMembros.tsx",
     r'''import { cargoUsaCategoria, rotuloDaCategoria } from "@/modules/painel/regras";''',
     r'''import IlustracaoInstrumento from "@/modules/instrumentos/components/IlustracaoInstrumento";
import { cargoUsaCategoria, rotuloDaCategoria } from "@/modules/painel/regras";'''),
    ("src/components/ListaMembros.tsx",
     r'''                    <td className="hidden px-4 py-3 text-slate-700 md:table-cell">
                      {nomeInstrumento ?? "—"}
                    </td>''',
     r'''                    <td className="hidden px-4 py-3 text-slate-700 md:table-cell">
                      {nomeInstrumento ? (
                        <div className="flex items-center gap-2">
                          <IlustracaoInstrumento nome={nomeInstrumento} familia={nomeFamilia} />
                          {nomeInstrumento}
                        </div>
                      ) : (
                        "—"
                      )}
                    </td>'''),
]


# Arquivos NOVOS (o instalador recusa se algum já existir)
NOVOS = {
    "src/modules/instrumentos/ilustracoes.ts": r'''/**
 * SysMúsica — Qual ilustração usar para cada instrumento (regras puras, sem banco). Testadas em ilustracoes.test.ts.
 *
 * A escolha é feita pelo NOME do instrumento (sem acento/maiúsculas). Instrumento sem desenho próprio usa o
 * desenho genérico da FAMÍLIA (Cordas, Madeiras, Metais, Teclas); sem família conhecida, uma nota musical.
 * Para incluir um instrumento novo: acrescente uma regra em REGRAS (a primeira que combinar vale) e, se
 * precisar de um desenho novo, em IlustracaoInstrumento.tsx.
 */

export type ChaveDesenho =
  | "clarinete"
  | "clarone"
  | "flauta"
  | "oboe"
  | "sax"
  | "sax_reto"
  | "sax_curvo"
  | "trompete"
  | "flugelhorn"
  | "bombardino"
  | "trombone"
  | "tuba"
  | "acordeon"
  | "orgao"
  | "violino"
  | "nota";

function semAcento(texto: string): string {
  return texto
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .toLowerCase()
    .replace(/\s+/g, " ")
    .trim();
}

/** Regras em ordem: a primeira cujas palavras TODAS aparecem no nome vence (as mais específicas vêm antes). */
const REGRAS: { palavras: string[]; desenho: ChaveDesenho }[] = [
  { palavras: ["clarone"], desenho: "clarone" },
  { palavras: ["clarinete", "alto"], desenho: "clarone" },
  { palavras: ["clarinete", "baixo"], desenho: "clarone" },
  { palavras: ["clarinete"], desenho: "clarinete" },
  { palavras: ["flauta"], desenho: "flauta" },
  { palavras: ["flautim"], desenho: "flauta" },
  { palavras: ["obo"], desenho: "oboe" },
  { palavras: ["sax", "curvo"], desenho: "sax_curvo" },
  { palavras: ["sax", "reto"], desenho: "sax_reto" },
  { palavras: ["sax"], desenho: "sax" },
  { palavras: ["flugel"], desenho: "flugelhorn" },
  { palavras: ["trompete"], desenho: "trompete" },
  { palavras: ["cornet"], desenho: "trompete" },
  { palavras: ["bombardino"], desenho: "bombardino" },
  { palavras: ["eufonio"], desenho: "bombardino" },
  { palavras: ["trombone"], desenho: "trombone" },
  { palavras: ["tuba"], desenho: "tuba" },
  { palavras: ["sousafone"], desenho: "tuba" },
  { palavras: ["acordeon"], desenho: "acordeon" },
  { palavras: ["acordeao"], desenho: "acordeon" },
  { palavras: ["sanfona"], desenho: "acordeon" },
  { palavras: ["orgao"], desenho: "orgao" },
  { palavras: ["teclado"], desenho: "orgao" },
  { palavras: ["violino"], desenho: "violino" },
  { palavras: ["viola"], desenho: "violino" },
  { palavras: ["violoncelo"], desenho: "violino" },
  { palavras: ["contrabaixo"], desenho: "violino" },
];

/** Desenho genérico de cada família (palavra que aparece no nome da família; "metai" cobre Metais). */
const DESENHO_DA_FAMILIA: { palavra: string; desenho: ChaveDesenho }[] = [
  { palavra: "corda", desenho: "violino" },
  { palavra: "madeira", desenho: "clarinete" },
  { palavra: "metai", desenho: "trompete" },
  { palavra: "tecla", desenho: "orgao" },
];

/** Desenho do instrumento: pelo nome; se não houver, pela família; se não houver, a nota musical. */
export function escolherDesenho(nomeInstrumento: string, nomeFamilia?: string | null): ChaveDesenho {
  const nome = semAcento(nomeInstrumento);
  const achada = REGRAS.find((regra) => regra.palavras.every((palavra) => nome.includes(palavra)));
  if (achada) return achada.desenho;

  const familia = semAcento(nomeFamilia ?? "");
  return DESENHO_DA_FAMILIA.find((item) => familia.includes(item.palavra))?.desenho ?? "nota";
}
''',
    "src/modules/instrumentos/ilustracoes.test.ts": r'''import { describe, expect, it } from "vitest";
import { escolherDesenho } from "./ilustracoes";

describe("ilustração do instrumento", () => {
  it("escolhe o desenho pelo nome (instrumentos da CCB)", () => {
    const casos: [string, string][] = [
      ["Clarinete", "clarinete"],
      ["Clarinete Alto (Clarone)", "clarone"],
      ["Clarinete Baixo (Clarone)", "clarone"],
      ["Flauta Transversal", "flauta"],
      ["Oboé", "oboe"],
      ["Saxofone Alto", "sax"],
      ["Saxofone Tenor", "sax"],
      ["Saxofone Barítono", "sax"],
      ["Saxofone Soprano Curvo", "sax_curvo"],
      ["Saxofone Soprano Reto", "sax_reto"],
      ["Bombardino", "bombardino"],
      ["Flugelhorn", "flugelhorn"],
      ["Trombone", "trombone"],
      ["Trompete", "trompete"],
      ["Tuba Sinfônica", "tuba"],
      ["Acordeon", "acordeon"],
      ["Orgão Eletrônico", "orgao"],
    ];
    for (const [nome, esperado] of casos) expect(escolherDesenho(nome), nome).toBe(esperado);
  });

  it("ignora acento, maiúsculas e espaços extras", () => {
    expect(escolherDesenho("  ORGÃO   eletrônico ")).toBe("orgao");
    expect(escolherDesenho("OBOE")).toBe("oboe");
    expect(escolherDesenho("acordeão")).toBe("acordeon");
  });

  it("instrumento sem desenho próprio usa o da família", () => {
    expect(escolherDesenho("Fagote", "Madeiras")).toBe("clarinete");
    expect(escolherDesenho("Trompa", "Metais")).toBe("trompete");
    expect(escolherDesenho("Harpa", "Cordas")).toBe("violino");
    expect(escolherDesenho("Melódica", "Teclas")).toBe("orgao");
  });

  it("sem nome conhecido e sem família, usa a nota musical", () => {
    expect(escolherDesenho("Pandeiro")).toBe("nota");
    expect(escolherDesenho("Pandeiro", null)).toBe("nota");
    expect(escolherDesenho("", "")).toBe("nota");
  });
});
''',
    "src/modules/instrumentos/components/IlustracaoInstrumento.tsx": r'''/**
 * SysMúsica — Ilustração simples do instrumento (ícone desenhado em SVG, original do SysMúsica).
 * O desenho vem do NOME do instrumento; sem desenho próprio, usa o da família (regras em ../ilustracoes.ts).
 * A cor acompanha o texto (currentColor); o desenho é decorativo e o nome do instrumento fica ao lado.
 */
import type { ReactNode } from "react";
import { escolherDesenho, type ChaveDesenho } from "../ilustracoes";

interface IlustracaoInstrumentoProps {
  nome: string; // nome do instrumento
  familia?: string | null; // nome da família (desenho genérico quando o instrumento não tem desenho próprio)
  tamanho?: "pequeno" | "grande";
}

/** Traços de cada desenho (caixa 48 x 48). */
function tracos(chave: ChaveDesenho): ReactNode {
  switch (chave) {
    case "clarinete":
      return (
        <>
          <path d="M21.5 4h5l-1 6h-3z" />
          <path d="M22.5 10v25M25.5 10v25" />
          <path d="M22.5 35l-4 8.5h11l-4-8.5" />
          <circle cx="24" cy="16" r="1.2" fill="currentColor" /><circle cx="24" cy="22" r="1.2" fill="currentColor" /><circle cx="24" cy="28" r="1.2" fill="currentColor" />
        </>
      );
    case "clarone":
      return (
        <>
          <path d="M10 7c7-3 14-2 14 7" />
          <path d="M22.5 13v22M25.5 13v22" />
          <path d="M22.5 35c0 6 4 8 9 8 5 0 7-3 7-8l3-5" />
          <path d="M25.5 35c0 2 2 3 4 3s3-1 3-3" />
          <circle cx="24" cy="19" r="1.2" fill="currentColor" /><circle cx="24" cy="25" r="1.2" fill="currentColor" /><circle cx="24" cy="31" r="1.2" fill="currentColor" />
        </>
      );
    case "flauta":
      return (
        <>
          <g transform="rotate(-28 24 24)">
          <rect x="3" y="21" width="42" height="6" rx="3" />
          <ellipse cx="10" cy="24" rx="1.6" ry="1.2" />
          <circle cx="19" cy="24" r="1.2" fill="currentColor" /><circle cx="25" cy="24" r="1.2" fill="currentColor" /><circle cx="31" cy="24" r="1.2" fill="currentColor" /><circle cx="37" cy="24" r="1.2" fill="currentColor" />
          </g>
        </>
      );
    case "oboe":
      return (
        <>
          <path d="M23 3v6M25 3v6" />
          <path d="M22.5 9l-.5 26M25.5 9l.5 26" />
          <path d="M22 35l-2.5 6h9l-2.5-6" />
          <circle cx="24" cy="16" r="1.1" fill="currentColor" /><circle cx="24" cy="22" r="1.1" fill="currentColor" /><circle cx="24" cy="28" r="1.1" fill="currentColor" />
        </>
      );
    case "sax":
      return (
        <>
          <path d="M10 6c6-2 12 0 12 8" />
          <path d="M21 14v18c0 8 5 11 11 11 6 0 8-4 8-9l2-6" />
          <path d="M27 14v18c0 2 1 3 3 3s3-1 3-3l-1-3" />
          <path d="M36 28h8" />
          <circle cx="24" cy="19" r="1.2" fill="currentColor" /><circle cx="24" cy="25" r="1.2" fill="currentColor" /><circle cx="24" cy="31" r="1.2" fill="currentColor" />
        </>
      );
    case "sax_reto":
      return (
        <>
          <path d="M21 4h4l2 5h-6z" />
          <path d="M22 9v28M26 9v28" />
          <path d="M22 37c-1 4-1 6 1 6h5" />
          <path d="M26 37l5 2 3-3" />
          <circle cx="24" cy="16" r="1.2" fill="currentColor" /><circle cx="24" cy="23" r="1.2" fill="currentColor" /><circle cx="24" cy="30" r="1.2" fill="currentColor" />
        </>
      );
    case "sax_curvo":
      return (
        <>
          <path d="M21 4h4l2 5h-6z" />
          <path d="M22 9v26M26 9v26" />
          <path d="M22 35c0 6 3 8 8 8 5 0 8-3 8-8" />
          <path d="M26 35c0 2 2 3 4 3" />
          <circle cx="24" cy="16" r="1.2" fill="currentColor" /><circle cx="24" cy="23" r="1.2" fill="currentColor" /><circle cx="24" cy="30" r="1.2" fill="currentColor" />
        </>
      );
    case "trompete":
      return (
        <>
          <path d="M30 19l14-8v26l-14-8" />
          <path d="M8 19h22M8 29h22" />
          <path d="M8 19c-6 0-6 10 0 10" />
          <path d="M15 19v-6M21 19v-6M27 19v-6" />
          <path d="M13 13h4M19 13h4M25 13h4" />
        </>
      );
    case "flugelhorn":
      return (
        <>
          <path d="M28 18l16-10v32l-16-10" />
          <path d="M8 18h20M8 30h20" />
          <path d="M8 18c-6 0-6 12 0 12" />
          <path d="M14 18v-6M20 18v-6M26 18v-5" />
          <path d="M12 12h4M18 12h4M24 12h4" />
        </>
      );
    case "bombardino":
      return (
        <>
          <path d="M27 4h16l-4 18" />
          <path d="M27 4l4 18" />
          <circle cx="22" cy="32" r="12" />
          <circle cx="22" cy="32" r="6" />
          <path d="M31 24l8-2" />
          <path d="M10 28H4M10 36H5" />
        </>
      );
    case "trombone":
      return (
        <>
          <path d="M6 18h28M6 25h28" />
          <path d="M6 18v7" />
          <path d="M34 18l10-8v30l-10-8z" />
          <path d="M6 32h30" />
          <path d="M6 32v6h30v-6" />
        </>
      );
    case "tuba":
      return (
        <>
          <path d="M12 4h24l-4 14H16z" />
          <path d="M16 18c-8 2-10 10-10 16 0 7 6 10 14 10 8 0 14-4 14-12 0-6-4-12-12-14" />
          <path d="M20 34c0-4 2-6 6-6" />
          <path d="M32 20l8 4" />
        </>
      );
    case "acordeon":
      return (
        <>
          <rect x="3" y="11" width="9" height="26" rx="2" />
          <rect x="36" y="11" width="9" height="26" rx="2" />
          <path d="M12 13l4 22 4-22 4 22 4-22 4 22 4-22" />
          <circle cx="7.5" cy="19" r="1.3" fill="currentColor" /><circle cx="7.5" cy="25" r="1.3" fill="currentColor" /><circle cx="7.5" cy="31" r="1.3" fill="currentColor" />
          <path d="M40.5 17v14M40.5 17h0" />
        </>
      );
    case "orgao":
      return (
        <>
          <rect x="3" y="12" width="42" height="26" rx="3" />
          <path d="M3 24h42" />
          <path d="M10 24v14M17 24v14M24 24v14M31 24v14M38 24v14" />
          <rect x="8" y="24" width="4" height="8" fill="currentColor" /><rect x="15" y="24" width="4" height="8" fill="currentColor" /><rect x="29" y="24" width="4" height="8" fill="currentColor" /><rect x="36" y="24" width="4" height="8" fill="currentColor" />
          <circle cx="9" cy="18" r="1.3" fill="currentColor" /><circle cx="15" cy="18" r="1.3" fill="currentColor" /><path d="M24 18h16" />
        </>
      );
    case "violino":
      return (
        <>
          <path d="M24 14V4" />
          <circle cx="24" cy="3.5" r="1.6" />
          <path d="M24 14c-4 0-6 2-6 5 0 2 1 3 2 4-3 1-5 3-5 7 0 6 4 10 9 10s9-4 9-10c0-4-2-6-5-7 1-1 2-2 2-4 0-3-2-5-6-5z" />
          <path d="M21 28c-1 3-1 5 0 7M27 28c1 3 1 5 0 7" />
          <path d="M24 22v17M20 40h8" />
        </>
      );
    case "nota":
      return (
        <>
          <path d="M18 36V10l18-4v26" />
          <circle cx="13" cy="36" r="5" />
          <circle cx="31" cy="32" r="5" />
        </>
      );
  }
}

export default function IlustracaoInstrumento({ nome, familia, tamanho = "pequeno" }: IlustracaoInstrumentoProps) {
  const chave = escolherDesenho(nome, familia);
  const medidas = tamanho === "grande" ? "h-14 w-14 p-2" : "h-8 w-8 p-1";

  return (
    <span
      aria-hidden="true"
      className={"inline-flex shrink-0 items-center justify-center rounded-lg bg-indigo-50 text-indigo-700 " + medidas}
    >
      <svg
        viewBox="0 0 48 48"
        fill="none"
        stroke="currentColor"
        strokeWidth={2.2}
        strokeLinecap="round"
        strokeLinejoin="round"
        className="h-full w-full"
      >
        {tracos(chave)}
      </svg>
    </span>
  );
}
''',
}


# Arquivos a REMOVER: só são apagados se o conteúdo for idêntico ao esperado (cópia fica no backup)
REMOVER = {
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

for arq, esperado in REMOVER.items():
    caminho = os.path.join(RAIZ, arq)
    if not os.path.isfile(caminho):
        problemas.append(f"PARA REMOVER, NÃO ENCONTRADO: {arq}")
    elif ler(caminho).replace("\r\n", "\n").strip() != esperado.replace("\r\n", "\n").strip():
        problemas.append(f"PARA REMOVER, CONTEÚDO DIFERENTE DO ESPERADO (não vou apagar): {arq}")

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
    f.write("\n".join(a for a in alterados + criados if a.endswith((".ts", ".tsx"))) + "\n")
with open(os.path.join(BKP, ".novos"), "w", encoding="utf-8") as f:
    f.write("\n".join(criados) + "\n")
print(f"OK: {len(EDITS)} trocas em {len(alterados)} arquivos + {len(criados)} arquivos novos + {len(removidos)} removidos. Backup em {BKP}")
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
  if "$@" > /tmp/p6-passo.out 2>&1; then
    echo "  ok"
  else
    echo "  FALHOU: $nome"; tail -40 /tmp/p6-passo.out
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
echo "Não há SQL nesta parte."
echo "Depois confira as telas (passo a passo na conversa) e, se estiver tudo certo, faça o git push."
) 2>&1 | tee "$LOG"
