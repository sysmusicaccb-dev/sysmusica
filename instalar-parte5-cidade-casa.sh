#!/usr/bin/env bash
# =============================================================================
# SysMúsica — PARTE 5: Portaria > Entrada sem cadastro: Casa de Oração + Cidade (SEM SQL)
#
#  - "Localidade de origem (opcional)" passa a se chamar "Casa de Oração (opcional)"
#  - Casa cadastrada: busca como antes (avisa quando há casas com o mesmo nome em lugares diferentes)
#  - Casa fora da lista: nome + Estado (UF) + Cidade, com a lista oficial de municípios do IBGE (busca online)
#  - Sem banco e sem SQL: o texto vai como "Casa - Cidade/UF" no campo de localidade que já existia
#
# Segurança: confere cada trecho (exatamente 1 vez), faz backup em /tmp/bkp-parte5-*, aplica,
# roda tsc, vitest, eslint e build; se algo falhar, DESFAZ tudo sozinho (inclusive os arquivos novos).
#
# Uso:  cd /workspaces/sysmusica/sysmusica && bash instalar-parte5-cidade-casa.sh
# Log:  /tmp/instalar-parte5.log
# =============================================================================

LOG=/tmp/instalar-parte5.log
BKP=/tmp/bkp-parte5-$(date +%Y%m%d-%H%M%S)
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
    ("src/modules/atendimento/components/BuscaLocalidade.tsx",
     r''' * SysMúsica — Localidade de origem (opcional) de quem entra sem cadastro.
 * Busca pelas primeiras letras do nome da casa de oração (a partir de 2 letras) ou, se não estiver na lista,
 * "Outra localidade" com texto livre. Sem escolher nada também é permitido.''',
     r''' * SysMúsica — Casa de Oração de origem (opcional) de quem entra sem cadastro.
 * Busca pelas primeiras letras do nome da casa de oração (a partir de 2 letras). Se houver casas com o mesmo
 * nome em lugares diferentes, a lista mostra o caminho (estado, região, setor) de cada uma para a pessoa escolher.
 * Se a casa não estiver na lista: nome digitado + Estado (UF) + Cidade, com a lista de municípios do IBGE.
 * Sem escolher nada também é permitido.'''),
    ("src/modules/atendimento/components/BuscaLocalidade.tsx",
     r'''import { buscarLocalidades } from "../services/entrada";''',
     r'''import { buscarLocalidades } from "../services/entrada";
import CampoCidadeUf from "./CampoCidadeUf";'''),
    ("src/modules/atendimento/components/BuscaLocalidade.tsx",
     r'''  texto: string;
  onTexto: (valor: string) => void;
  desabilitado?: boolean;
}''',
     r'''  texto: string; // nome da casa de oração digitada (fora da lista)
  onTexto: (valor: string) => void;
  uf: string; // estado da casa fora da lista
  onUf: (valor: string) => void;
  cidade: string; // cidade da casa fora da lista (lista oficial do IBGE)
  onCidade: (valor: string) => void;
  desabilitado?: boolean;
}'''),
    ("src/modules/atendimento/components/BuscaLocalidade.tsx",
     r'''  texto,
  onTexto,
  desabilitado = false,
}: BuscaLocalidadeProps) {''',
     r'''  texto,
  onTexto,
  uf,
  onUf,
  cidade,
  onCidade,
  desabilitado = false,
}: BuscaLocalidadeProps) {'''),
    ("src/modules/atendimento/components/BuscaLocalidade.tsx",
     r'''  return (
    <fieldset className="space-y-3" disabled={desabilitado}>''',
     r'''  // Casas com o mesmo nome (ex.: "Centro" em cidades diferentes): avisa para conferir o caminho antes de escolher
  const nomes = resultados.map((item) => item.nome.trim().toLowerCase());
  const haNomeRepetido = nomes.some((nome, indice) => nomes.indexOf(nome) !== indice);

  return (
    <fieldset className="space-y-3" disabled={desabilitado}>'''),
    ("src/modules/atendimento/components/BuscaLocalidade.tsx",
     r'''Localidade de origem <span className="font-normal text-slate-500">(opcional)</span>''',
     r'''Casa de Oração <span className="font-normal text-slate-500">(opcional)</span>'''),
    ("src/modules/atendimento/components/BuscaLocalidade.tsx",
     r'''Nenhuma casa de oração encontrada. Use &quot;Outra localidade&quot;.''',
     r'''Nenhuma casa de oração encontrada. Use &quot;A casa de oração não está na lista&quot;.'''),
    ("src/modules/atendimento/components/BuscaLocalidade.tsx",
     r'''            {resultados.length > 0 && (
''',
     r'''            {haNomeRepetido && (
              <p className="rounded-lg bg-amber-50 px-3 py-2 text-xs text-amber-800">
                Há casas de oração com o mesmo nome em lugares diferentes. Confira o caminho (estado, região e setor)
                abaixo de cada nome antes de escolher.
              </p>
            )}
            {resultados.length > 0 && (
'''),
    ("src/modules/atendimento/components/BuscaLocalidade.tsx",
     r'''          Outra localidade (não está na lista)''',
     r'''          A casa de oração não está na lista'''),
    ("src/modules/atendimento/components/BuscaLocalidade.tsx",
     r'''        <div className="space-y-1.5">
          <label htmlFor="localidade-outra" className="sr-only">
            Nome da localidade
          </label>
          <input
            id="localidade-outra"
            type="text"
            maxLength={120}
            value={texto}
            onChange={(e) => onTexto(e.target.value)}
            placeholder="Ex.: Itaju do Colônia - BA"
            className={classeInput}
          />
        </div>''',
     r'''        <div className="space-y-3">
          <div className="space-y-1.5">
            <label htmlFor="localidade-outra" className="text-xs font-medium text-slate-600">
              Nome da Casa de Oração
            </label>
            <input
              id="localidade-outra"
              type="text"
              maxLength={70}
              value={texto}
              onChange={(e) => onTexto(e.target.value)}
              placeholder="Ex.: Centro"
              className={classeInput}
            />
          </div>
          {/* Estado e cidade: a lista de cidades vem do IBGE (busca online) */}
          <CampoCidadeUf idBase="localidade-outra" uf={uf} onUf={onUf} cidade={cidade} onCidade={onCidade} />
        </div>'''),
    ("src/modules/atendimento/components/EntradaSemCadastro.tsx",
     r''' * se vai tocar, o instrumento e a localidade de origem (opcional). A entrada entra na contagem do painel ao vivo.''',
     r''' * se vai tocar, o instrumento e a Casa de Oração de origem (opcional). A entrada entra na contagem do painel ao vivo.
 * Casa fora da lista: o texto gravado é "Casa - Cidade/UF" (cidade da lista do IBGE), no campo que já existia.'''),
    ("src/modules/atendimento/components/EntradaSemCadastro.tsx",
     r'''import { registrarEntradaAvulsa } from "../services/entrada";''',
     r'''import { montarLocalidadeTexto, validarLocalidadeAvulsa } from "@/lib/municipios";
import { registrarEntradaAvulsa } from "../services/entrada";'''),
    ("src/modules/atendimento/components/EntradaSemCadastro.tsx",
     r'''  const [texto, setTexto] = useState("");''',
     r'''  const [texto, setTexto] = useState(""); // nome da casa de oração fora da lista
  const [uf, setUf] = useState(""); // estado da casa fora da lista
  const [cidade, setCidade] = useState(""); // cidade da casa fora da lista (IBGE)'''),
    ("src/modules/atendimento/components/EntradaSemCadastro.tsx",
     r'''    const mensagem = validarEntradaAvulsa({ linha, toca, instrumentoId, outraLocalidade: outra, localidadeTexto: texto });
    if (mensagem) return setErro(mensagem);''',
     r'''    // Casa fora da lista: nome, estado e cidade; o texto final é "Casa - Cidade/UF"
    const foraDaLista = outra && !localidade;
    if (foraDaLista) {
      const erroLocal = validarLocalidadeAvulsa({ casa: texto, cidade, uf });
      if (erroLocal) return setErro(erroLocal);
    }
    const textoOutra = foraDaLista ? montarLocalidadeTexto(texto, cidade, uf) : "";

    const mensagem = validarEntradaAvulsa({ linha, toca, instrumentoId, outraLocalidade: outra, localidadeTexto: textoOutra });
    if (mensagem) return setErro(mensagem);'''),
    ("src/modules/atendimento/components/EntradaSemCadastro.tsx",
     r'''origemTexto: localidade ? null : textoDaLocalidade(outra, texto),''',
     r'''origemTexto: localidade ? null : textoDaLocalidade(outra, textoOutra),'''),
    ("src/modules/atendimento/components/EntradaSemCadastro.tsx",
     r'''        texto={texto}
        onTexto={setTexto}
        desabilitado={salvando}
      />''',
     r'''        texto={texto}
        onTexto={setTexto}
        uf={uf}
        onUf={setUf}
        cidade={cidade}
        onCidade={setCidade}
        desabilitado={salvando}
      />'''),
]


# Arquivos NOVOS (o instalador recusa se algum já existir)
NOVOS = {
    "src/lib/municipios.ts": r'''/**
 * SysMúsica — Municípios do Brasil (lista oficial do IBGE) e texto da localidade de origem.
 *
 * Usado onde a pessoa informa uma cidade que não está cadastrada no sistema (ex.: Portaria > Entrada sem
 * cadastro; futuramente, encarregados do ensaio). A lista vem do serviço público do IBGE, por estado, e fica
 * guardada na memória do navegador enquanto a página está aberta. Se o serviço estiver fora do ar, a tela
 * deixa digitar a cidade à mão (as funções puras abaixo continuam valendo).
 * Funções puras testadas em municipios.test.ts.
 */

export const UFS_BRASIL = [
  "AC", "AL", "AP", "AM", "BA", "CE", "DF", "ES", "GO", "MA", "MT", "MS", "MG", "PA",
  "PB", "PR", "PE", "PI", "RJ", "RN", "RS", "RO", "RR", "SC", "SP", "SE", "TO",
] as const;

/** Tamanho máximo do nome da casa de oração digitada (o texto final cabe em 120 caracteres). */
export const MAXIMO_NOME_CASA = 70;

function semAcento(texto: string): string {
  return texto
    .normalize("NFD")
    .replace(/[̀-ͯ]/g, "")
    .toLowerCase()
    .replace(/\s+/g, " ")
    .trim();
}

/** Nomes dos municípios na resposta do IBGE (ordem alfabética; ignora itens fora do formato). */
export function extrairNomesDeMunicipios(json: unknown): string[] {
  if (!Array.isArray(json)) return [];
  const nomes = json
    .map((item) => (item && typeof item === "object" ? (item as { nome?: unknown }).nome : undefined))
    .filter((nome): nome is string => typeof nome === "string" && nome.trim() !== "");
  return [...new Set(nomes)].sort((a, b) => a.localeCompare(b, "pt-BR"));
}

/** Nome oficial do município que corresponde ao texto digitado (sem acento/maiúsculas), ou null. */
export function acharMunicipio(lista: string[], texto: string): string | null {
  const alvo = semAcento(texto);
  if (alvo === "") return null;
  return lista.find((nome) => semAcento(nome) === alvo) ?? null;
}

/** "Casa de Oração Centro - Jequié/BA" (vazio se faltar algum dado). */
export function montarLocalidadeTexto(casa: string, cidade: string, uf: string): string {
  const c = casa.trim();
  const m = cidade.trim();
  const u = uf.trim();
  return c && m && u ? `${c} - ${m}/${u}` : "";
}

/** Casa de oração fora da lista: nome, estado e cidade são obrigatórios. Devolve a mensagem ou null. */
export function validarLocalidadeAvulsa(dados: { casa: string; cidade: string; uf: string }): string | null {
  if (dados.casa.trim() === "") return "Informe o nome da casa de oração.";
  if (dados.uf.trim() === "") return "Escolha o estado (UF) da casa de oração.";
  if (dados.cidade.trim() === "") return "Escolha a cidade da casa de oração.";
  return null;
}

// ---------- Busca online (IBGE) ----------

const cache = new Map<string, string[]>();

/** Municípios de um estado (sigla), direto do IBGE. Lança erro se o serviço não responder. */
export async function listarMunicipios(uf: string): Promise<string[]> {
  const guardado = cache.get(uf);
  if (guardado) return guardado;

  const controle = new AbortController();
  const limite = setTimeout(() => controle.abort(), 10_000);
  try {
    const resposta = await fetch(
      `https://servicodados.ibge.gov.br/api/v1/localidades/estados/${encodeURIComponent(uf)}/municipios?orderBy=nome`,
      { signal: controle.signal }
    );
    if (!resposta.ok) throw new Error(`IBGE respondeu ${resposta.status}`);
    const nomes = extrairNomesDeMunicipios(await resposta.json());
    if (nomes.length === 0) throw new Error("Lista de municípios vazia");
    cache.set(uf, nomes);
    return nomes;
  } finally {
    clearTimeout(limite);
  }
}
''',
    "src/lib/municipios.test.ts": r'''import { describe, expect, it } from "vitest";
import {
  UFS_BRASIL,
  acharMunicipio,
  extrairNomesDeMunicipios,
  montarLocalidadeTexto,
  validarLocalidadeAvulsa,
} from "./municipios";

describe("municípios do IBGE", () => {
  it("extrai e ordena os nomes, ignorando itens inválidos e repetidos", () => {
    const json = [{ nome: "Salvador" }, { nome: "Abaíra" }, { nome: "Salvador" }, { nome: 3 }, null, {}];
    expect(extrairNomesDeMunicipios(json)).toEqual(["Abaíra", "Salvador"]);
    expect(extrairNomesDeMunicipios({ erro: true })).toEqual([]);
  });

  it("acha o nome oficial ignorando acento e maiúsculas", () => {
    const lista = ["Itaju do Colônia", "Jequié", "São Paulo"];
    expect(acharMunicipio(lista, "  jequie ")).toBe("Jequié");
    expect(acharMunicipio(lista, "SAO PAULO")).toBe("São Paulo");
    expect(acharMunicipio(lista, "Jequ")).toBeNull();
    expect(acharMunicipio(lista, "")).toBeNull();
  });

  it("tem as 27 UFs", () => {
    expect(UFS_BRASIL).toHaveLength(27);
    expect(UFS_BRASIL).toContain("BA");
  });
});

describe("texto da localidade", () => {
  it("monta 'Casa - Cidade/UF' e fica vazio se faltar dado", () => {
    expect(montarLocalidadeTexto(" Centro ", "Jequié", "BA")).toBe("Centro - Jequié/BA");
    expect(montarLocalidadeTexto("Centro", "", "BA")).toBe("");
    expect(montarLocalidadeTexto("Centro", "Jequié", "")).toBe("");
  });

  it("cabe em 120 caracteres no pior caso", () => {
    const texto = montarLocalidadeTexto("x".repeat(70), "Santa Terezinha de Goiás de Tal", "BA");
    expect(texto.length).toBeLessThanOrEqual(120);
  });

  it("valida nome, estado e cidade", () => {
    expect(validarLocalidadeAvulsa({ casa: "", cidade: "A", uf: "BA" })).toContain("nome");
    expect(validarLocalidadeAvulsa({ casa: "X", cidade: "A", uf: "" })).toContain("estado");
    expect(validarLocalidadeAvulsa({ casa: "X", cidade: " ", uf: "BA" })).toContain("cidade");
    expect(validarLocalidadeAvulsa({ casa: "X", cidade: "A", uf: "BA" })).toBeNull();
  });
});
''',
    "src/modules/atendimento/components/CampoCidadeUf.tsx": r'''"use client";

/**
 * SysMúsica — Estado (UF) + Cidade com busca online na lista de municípios do IBGE.
 * Escolhida a UF, a lista de cidades do estado é buscada no IBGE e a cidade é digitada com sugestões.
 * Ao sair do campo, o nome vira o nome OFICIAL do município (sem erro de acento); se não existir na lista,
 * o campo é limpo. Se o IBGE estiver fora do ar, a cidade pode ser digitada à mão (com aviso).
 * Reutilizável (ex.: encarregados do ensaio).
 */
import { useRef, useState } from "react";
import { UFS_BRASIL, acharMunicipio, listarMunicipios } from "@/lib/municipios";

interface CampoCidadeUfProps {
  idBase: string; // prefixo dos ids dos campos
  uf: string;
  onUf: (valor: string) => void;
  cidade: string;
  onCidade: (valor: string) => void;
  desabilitado?: boolean;
}

const classeInput =
  "w-full rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 shadow-sm placeholder:text-slate-400 focus:border-brand-500 focus:outline-none focus:ring-2 focus:ring-brand-200 disabled:opacity-60";

type Situacao = "sem-uf" | "carregando" | "pronta" | "indisponivel";

export default function CampoCidadeUf({ idBase, uf, onUf, cidade, onCidade, desabilitado = false }: CampoCidadeUfProps) {
  const [municipios, setMunicipios] = useState<string[]>([]);
  const [situacao, setSituacao] = useState<Situacao>(uf ? "indisponivel" : "sem-uf");
  const pedido = useRef(0); // ignora respostas de um estado que a pessoa já trocou

  // A lista é buscada no momento em que a UF muda (evento do usuário, não efeito)
  async function trocarUf(sigla: string) {
    onUf(sigla);
    onCidade("");
    setMunicipios([]);
    const atual = ++pedido.current;
    if (!sigla) return setSituacao("sem-uf");
    setSituacao("carregando");
    try {
      const lista = await listarMunicipios(sigla);
      if (atual !== pedido.current) return;
      setMunicipios(lista);
      setSituacao("pronta");
    } catch {
      if (atual === pedido.current) setSituacao("indisponivel");
    }
  }

  // Ao sair do campo: usa o nome oficial; se não existir na lista, limpa
  function conferirCidade() {
    if (situacao !== "pronta" || cidade.trim() === "") return;
    onCidade(acharMunicipio(municipios, cidade) ?? "");
  }

  const listaId = `${idBase}-municipios`;

  return (
    <div className="grid grid-cols-3 gap-3">
      <div className="space-y-1.5">
        <label htmlFor={`${idBase}-uf`} className="text-xs font-medium text-slate-600">
          Estado
        </label>
        <select
          id={`${idBase}-uf`}
          value={uf}
          onChange={(e) => void trocarUf(e.target.value)}
          disabled={desabilitado}
          className={classeInput}
        >
          <option value="">UF</option>
          {UFS_BRASIL.map((sigla) => (
            <option key={sigla} value={sigla}>
              {sigla}
            </option>
          ))}
        </select>
      </div>

      <div className="col-span-2 space-y-1.5">
        <label htmlFor={`${idBase}-cidade`} className="text-xs font-medium text-slate-600">
          Cidade
        </label>
        <input
          id={`${idBase}-cidade`}
          type="text"
          list={listaId}
          autoComplete="off"
          maxLength={60}
          value={cidade}
          onChange={(e) => onCidade(e.target.value)}
          onBlur={conferirCidade}
          disabled={desabilitado || situacao === "sem-uf" || situacao === "carregando"}
          placeholder={
            situacao === "sem-uf" ? "Escolha o estado primeiro" : situacao === "carregando" ? "Buscando cidades..." : "Digite a cidade"
          }
          className={classeInput}
        />
        <datalist id={listaId}>
          {municipios.map((nome) => (
            <option key={nome} value={nome} />
          ))}
        </datalist>
      </div>

      {situacao === "indisponivel" && uf && (
        <p className="col-span-3 rounded-lg bg-amber-50 px-3 py-2 text-xs text-amber-800">
          Não foi possível buscar a lista de cidades online agora. Digite o nome da cidade.
        </p>
      )}
    </div>
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
  if "$@" > /tmp/p5-passo.out 2>&1; then
    echo "  ok"
  else
    echo "  FALHOU: $nome"; tail -40 /tmp/p5-passo.out
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
