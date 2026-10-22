#!/usr/bin/env bash
# =============================================================================
# SysMúsica — NOVO: botão Imprimir no Painel de Totais (Painel ao Vivo) e nos Dados do Ensaio
#
#  Não precisa de SQL. Cria a folha de impressão (mesmo padrão dos Relatórios: logo, cabeçalho, título centralizado).
#
# Segurança: confere cada trecho (exatamente 1 vez), faz backup em /tmp/bkp-impressao-painel-ensaio-*, aplica,
# roda tsc, vitest, eslint e build; se algo falhar, DESFAZ tudo sozinho (inclusive os arquivos novos).
#
# Uso:  cd /workspaces/sysmusica/sysmusica && rm -rf .next && bash instalar-impressao-painel-ensaio.sh
# Log:  /tmp/instalar-impressao-painel-ensaio.log
# =============================================================================

LOG=/tmp/instalar-impressao-painel-ensaio.log
BKP=/tmp/bkp-impressao-painel-ensaio-$(date +%Y%m%d-%H%M%S)
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
    ('src/modules/painel/components/ResumoTempoReal.tsx',
     r'''import { agruparBlocos, montarFamilias } from "../regras";
''',
     r'''import { agruparBlocos, montarFamilias } from "../regras";
import BotaoImprimirPainel from "./BotaoImprimirPainel";
'''),
    ('src/modules/painel/components/ResumoTempoReal.tsx',
     r'''      <h2 className="text-lg font-bold text-slate-900">Resumo em tempo real</h2>
''',
     r'''      <div className="flex items-center justify-between gap-3">
        <h2 className="text-lg font-bold text-slate-900">Resumo em tempo real</h2>
        <BotaoImprimirPainel dados={dados} />
      </div>
'''),
    ('src/app/(painel)/ensaio/page.tsx',
     r'''import FormularioEnsaio from "@/modules/ensaio/components/FormularioEnsaio";
''',
     r'''import FormularioEnsaio from "@/modules/ensaio/components/FormularioEnsaio";
import BotaoImprimirEnsaio from "@/modules/ensaio/components/BotaoImprimirEnsaio";
'''),
    ('src/app/(painel)/ensaio/page.tsx',
     r'''            {resposta && !carregandoEvento && (
              <FormularioEnsaio
''',
     r'''            {resposta?.dados && !carregandoEvento && (
              <BotaoImprimirEnsaio resposta={resposta} hinos={hinos} totais={totais} />
            )}
            {resposta && !carregandoEvento && (
              <FormularioEnsaio
'''),
]


# Arquivos NOVOS (o instalador recusa se algum já existir)
NOVOS = {
    'src/lib/impressaoMarca.ts': r'''/**
 * Sysmusica — Marca usada nas folhas impressas (nome e logomarca), para todas as telas que imprimem.
 * A logomarca precisa de endereço completo (a janela da impressão não tem o endereço do site).
 */
import { MARCA } from "@/lib/marca";

export function opcoesMarca(): { marca: string; logoUrl: string } {
  const https = typeof window !== "undefined" && window.location.protocol === "https:";
  return {
    marca: MARCA.nome,
    logoUrl: https ? `${window.location.origin}${MARCA.logoCaminho}` : MARCA.logoCaminho,
  };
}
''',
    'src/modules/painel/impressao.ts': r'''/**
 * Sysmusica — Impressão do Painel de Totais (Painel ao Vivo). Função pura: recebe os números do painel e devolve
 * o que a folha impressa mostra (quadro do cabeçalho + tabela com Ministério, Músicos, Organistas e Instrumentos).
 * Testada em impressao.test.ts.
 */
import type { ItemInformacao, OpcoesImpressao } from "@/lib/exportacao";
import {
  agruparBlocos,
  formatarDiaDoEvento,
  formatarHoraDaAtualizacao,
  formatarHoraDoEvento,
  montarFamilias,
} from "./regras";
import type { DadosPainel } from "./tipos";

export interface ExtrasImpressaoPainel {
  emitidoPor: string;
  geradoEm: string;
  marca?: string;
  logoUrl?: string;
}

export function montarImpressaoPainel(dados: DadosPainel, extras: ExtrasImpressaoPainel): OpcoesImpressao {
  // Blocos sem nenhuma linha não entram (a faixa do bloco ficaria sozinha)
  const blocos = agruparBlocos(dados.linhas).filter((bloco) => bloco.linhas.length > 0);
  const { total: totalInstrumentos, familias } = montarFamilias(dados.instrumentos);

  const linhas: string[][] = [];
  const agrupamento: { antesDaLinha: number; titulo: string }[] = [];
  for (const bloco of blocos) {
    agrupamento.push({ antesDaLinha: linhas.length, titulo: `${bloco.rotulo} — ${bloco.total}` });
    for (const linha of bloco.linhas) linhas.push([linha.rotulo, String(linha.qtd), ""]);
  }
  // Instrumentos: recorte de quem toca (não soma de novo no total de participantes)
  agrupamento.push({ antesDaLinha: linhas.length, titulo: `Instrumentos — ${totalInstrumentos}` });
  for (const familia of familias) linhas.push([familia.nome, String(familia.qtd), familia.percentual]);

  const evento = dados.evento;
  const local = [evento.casa_oracao ?? evento.local, evento.cidade].filter((parte): parte is string => Boolean(parte));
  const atualizado = new Date(dados.atualizado_em);

  const informacoes: ItemInformacao[] = [
    {
      rotulo: "Evento",
      valor: `${formatarDiaDoEvento(evento.data_evento)} às ${formatarHoraDoEvento(evento.data_evento)} · ${evento.tipo}`,
      largo: true,
    },
    { rotulo: "Local", valor: local.join(" · "), largo: true },
    { rotulo: "Total de participantes", valor: String(dados.total) },
    // Data inválida: o item fica vazio e é ignorado pela impressão
    { rotulo: "Atualizado às", valor: Number.isNaN(atualizado.getTime()) ? "" : formatarHoraDaAtualizacao(atualizado) },
    { rotulo: "Emitido em", valor: extras.geradoEm },
    { rotulo: "Emitido por", valor: extras.emitidoPor },
  ];

  return {
    titulo: "Painel de Totais",
    colunas: ["Item", "Quantidade", "Percentual"],
    linhas,
    agrupamento,
    informacoes,
    orientacao: "retrato",
    colunasCompactas: true,
    paginacao: true,
    marca: extras.marca,
    logoUrl: extras.logoUrl,
    geradoEm: extras.geradoEm,
    // Quem emitiu e quando já estão no cabeçalho: o rodapé leva só o nome do sistema
    rodapeItens: extras.marca ? [extras.marca] : [],
  };
}
''',
    'src/modules/painel/impressao.test.ts': r'''/** Sysmusica — Testes da impressão do Painel de Totais. */
import { describe, expect, it } from "vitest";
import { montarImpressaoPainel } from "./impressao";
import type { DadosPainel, LinhaPainel } from "./tipos";

const linha = (codigo: string, bloco: LinhaPainel["bloco"], rotulo: string, ordem: number, qtd: number): LinhaPainel => ({
  codigo,
  bloco,
  rotulo,
  ordem,
  qtd,
  selecionavel: true,
});

const dados: DadosPainel = {
  evento: {
    id: "e1",
    tipo: "Ensaio Regional",
    local: "Central Itinga",
    data_evento: "2026-10-17T22:30:00Z",
    cidade: "Lauro de Freitas",
    casa_oracao: "Central Itinga",
  },
  total: 10,
  linhas: [
    linha("anciao", "MINISTERIO", "Ancião", 1, 1),
    linha("encarregado_local", "MUSICOS", "Encarregado Local", 1, 2),
    linha("musico", "MUSICOS", "Músico", 2, 5),
    linha("organista", "ORGANISTAS", "Organista", 1, 2),
  ],
  instrumentos: [
    { familia: "Cordas", qtd: 3 },
    { familia: "Metais", qtd: 1 },
  ],
  atualizado_em: "2026-10-17T22:45:12Z",
};
const extras = { emitidoPor: "Levi Alencar", geradoEm: "18/10/2026 01:31", marca: "Sysmusica" };

describe("montarImpressaoPainel", () => {
  const saida = montarImpressaoPainel(dados, extras);

  it("monta a tabela com os blocos e as famílias de instrumentos", () => {
    expect(saida.titulo).toBe("Painel de Totais");
    expect(saida.colunas).toEqual(["Item", "Quantidade", "Percentual"]);
    expect(saida.linhas).toEqual([
      ["Ancião", "1", ""],
      ["Encarregado Local", "2", ""],
      ["Músico", "5", ""],
      ["Organista", "2", ""],
      ["Cordas", "3", "75,0%"],
      ["Madeiras", "0", "0,0%"],
      ["Metais", "1", "25,0%"],
    ]);
  });

  it("põe a faixa de cada bloco antes da sua primeira linha, com o total do bloco", () => {
    expect(saida.agrupamento).toEqual([
      { antesDaLinha: 0, titulo: "Ministério — 1" },
      { antesDaLinha: 1, titulo: "Músicos — 7" },
      { antesDaLinha: 3, titulo: "Organistas — 2" },
      { antesDaLinha: 4, titulo: "Instrumentos — 4" },
    ]);
  });

  it("traz o total de participantes e quem emitiu no cabeçalho, sem repetir no rodapé", () => {
    const itens = Object.fromEntries((saida.informacoes ?? []).map((item) => [item.rotulo, item.valor]));
    expect(itens["Total de participantes"]).toBe("10");
    expect(itens["Emitido por"]).toBe("Levi Alencar");
    expect(itens["Local"]).toBe("Central Itinga · Lauro de Freitas");
    expect(saida.rodapeItens).toEqual(["Sysmusica"]);
  });

  it("não quebra com data de atualização inválida nem com bloco vazio", () => {
    const sem = montarImpressaoPainel(
      { ...dados, atualizado_em: "x", linhas: [linha("musico", "MUSICOS", "Músico", 1, 5)] },
      extras
    );
    const itens = Object.fromEntries((sem.informacoes ?? []).map((item) => [item.rotulo, item.valor]));
    expect(itens["Atualizado às"]).toBe("");
    expect((sem.agrupamento ?? []).map((grupo) => grupo.titulo)).toEqual(["Músicos — 5", "Instrumentos — 4"]);
  });
});
''',
    'src/modules/painel/components/BotaoImprimirPainel.tsx': r'''"use client";

/**
 * Sysmusica — Botão "Imprimir" do Painel de Totais. Abre a folha de impressão em janela própria
 * (sem menu e sem barra lateral) com os números que estão na tela neste momento.
 */
import { useState } from "react";
import { Printer } from "lucide-react";
import { abrirJanelaImpressao, escreverImpressao } from "@/lib/exportacao";
import { opcoesMarca } from "@/lib/impressaoMarca";
import { useSessao } from "@/modules/autenticacao/SessaoProvider";
import { agoraEmSalvador } from "@/modules/relatorios/regras";
import { montarImpressaoPainel } from "../impressao";
import type { DadosPainel } from "../tipos";

export default function BotaoImprimirPainel({ dados }: { dados: DadosPainel }) {
  const { conta } = useSessao();
  const [aviso, setAviso] = useState<string | null>(null);

  function imprimir() {
    // A janela é aberta já no clique, senão o navegador a bloqueia como pop-up
    const janela = abrirJanelaImpressao();
    if (!janela) {
      setAviso("O navegador bloqueou a janela de impressão. Permita pop-ups para este site e tente de novo.");
      return;
    }
    setAviso(null);
    escreverImpressao(
      janela,
      montarImpressaoPainel(dados, {
        emitidoPor: conta?.nome ?? "usuário",
        geradoEm: agoraEmSalvador(),
        ...opcoesMarca(),
      })
    );
  }

  return (
    <div className="flex flex-col items-end gap-1">
      <button
        type="button"
        onClick={imprimir}
        className="inline-flex items-center gap-1.5 rounded-lg border border-slate-300 bg-white px-3 py-1.5 text-sm font-medium text-slate-700 shadow-sm hover:bg-slate-50 focus:outline-none focus:ring-2 focus:ring-brand-200"
      >
        <Printer className="h-4 w-4" aria-hidden="true" />
        Imprimir
      </button>
      {aviso && (
        <p role="alert" className="max-w-xs text-right text-xs text-red-600">
          {aviso}
        </p>
      )}
    </div>
  );
}
''',
    'src/modules/ensaio/impressao.ts': r'''/**
 * Sysmusica — Impressão dos Dados do Ensaio. Função pura: recebe os textos já prontos (quem atendeu, encarregados,
 * hinos...) e devolve o que a folha impressa mostra. Testada em impressao.test.ts.
 */
import type { ItemInformacao, OpcoesImpressao } from "@/lib/exportacao";

export interface EntradaImpressaoEnsaio {
  tipoEvento: string; // "Ensaio Local" ou "Ensaio Regional"
  quando: string; // "17/10/2026 às 19h30"
  local: string; // casa de oração e cidade, já juntas
  atende: string; // "Nome — Ancião"
  rotuloEncarregados: string; // "Encarregado Local" etc.
  encarregados: string[]; // "Nome (Cidade-UF)"
  hinoAbertura: string;
  palavra: string; // vazio no ensaio local
  hinosExecutados: string[]; // rótulos completos, na ordem em que foram cantados
  totalParticipantes?: number; // só quando a pessoa pode ver o painel
  emitidoPor: string;
  geradoEm: string;
  marca?: string;
  logoUrl?: string;
}

export function montarImpressaoEnsaio(entrada: EntradaImpressaoEnsaio): OpcoesImpressao {
  const informacoes: ItemInformacao[] = [
    { rotulo: "Evento", valor: `${entrada.quando} · ${entrada.tipoEvento}`, largo: true },
    { rotulo: "Local", valor: entrada.local, largo: true },
    { rotulo: "Quem atendeu", valor: entrada.atende, largo: true },
    {
      rotulo: `${entrada.rotuloEncarregados} (${entrada.encarregados.length})`,
      valor: entrada.encarregados.join("; "),
      largo: true,
    },
    { rotulo: "Hino de abertura", valor: entrada.hinoAbertura, largo: true },
    { rotulo: "Palavra", valor: entrada.palavra.trim(), largo: true },
    { rotulo: "Hinos executados", valor: String(entrada.hinosExecutados.length) },
    {
      rotulo: "Total de participantes",
      valor: entrada.totalParticipantes === undefined ? "" : String(entrada.totalParticipantes),
    },
    { rotulo: "Emitido em", valor: entrada.geradoEm },
    { rotulo: "Emitido por", valor: entrada.emitidoPor },
  ];

  return {
    titulo: "Dados do Ensaio",
    colunas: ["Nº", "Hino executado"],
    linhas: entrada.hinosExecutados.map((hino, indice) => [String(indice + 1), hino]),
    informacoes,
    orientacao: "retrato",
    colunasCompactas: true,
    paginacao: true,
    marca: entrada.marca,
    logoUrl: entrada.logoUrl,
    geradoEm: entrada.geradoEm,
    rodapeItens: entrada.marca ? [entrada.marca] : [],
  };
}
''',
    'src/modules/ensaio/impressao.test.ts': r'''/** Sysmusica — Testes da impressão dos Dados do Ensaio. */
import { describe, expect, it } from "vitest";
import { montarImpressaoEnsaio, type EntradaImpressaoEnsaio } from "./impressao";

const base: EntradaImpressaoEnsaio = {
  tipoEvento: "Ensaio Regional",
  quando: "17/10/2026 às 19h30",
  local: "Central Itinga · Lauro de Freitas",
  atende: "João Silva — Ancião",
  rotuloEncarregados: "Encarregados Regionais",
  encarregados: ["Pedro Souza (Salvador-BA)", "Paulo Lima (Jequié-BA)"],
  hinoAbertura: "12 - Exemplo de hino",
  palavra: " Salmo 23 ",
  hinosExecutados: ["45 - Primeiro", "46 - Segundo"],
  emitidoPor: "Levi Alencar",
  geradoEm: "18/10/2026 01:31",
  marca: "Sysmusica",
};

const comoMapa = (saida: ReturnType<typeof montarImpressaoEnsaio>) =>
  Object.fromEntries((saida.informacoes ?? []).map((item) => [item.rotulo, item.valor]));

describe("montarImpressaoEnsaio", () => {
  it("lista os hinos executados na ordem, numerados", () => {
    const saida = montarImpressaoEnsaio(base);
    expect(saida.titulo).toBe("Dados do Ensaio");
    expect(saida.linhas).toEqual([
      ["1", "45 - Primeiro"],
      ["2", "46 - Segundo"],
    ]);
  });

  it("mostra quem atendeu, os encarregados, a abertura e a palavra no cabeçalho", () => {
    const itens = comoMapa(montarImpressaoEnsaio(base));
    expect(itens["Quem atendeu"]).toBe("João Silva — Ancião");
    expect(itens["Encarregados Regionais (2)"]).toBe("Pedro Souza (Salvador-BA); Paulo Lima (Jequié-BA)");
    expect(itens["Hino de abertura"]).toBe("12 - Exemplo de hino");
    expect(itens["Palavra"]).toBe("Salmo 23");
    expect(itens["Hinos executados"]).toBe("2");
    expect(itens["Emitido por"]).toBe("Levi Alencar");
  });

  it("deixa vazios (e portanto fora da folha) a palavra do ensaio local e o total sem permissão", () => {
    const itens = comoMapa(montarImpressaoEnsaio({ ...base, palavra: "", tipoEvento: "Ensaio Local" }));
    expect(itens["Palavra"]).toBe("");
    expect(itens["Total de participantes"]).toBe("");
    expect(comoMapa(montarImpressaoEnsaio({ ...base, totalParticipantes: 31 }))["Total de participantes"]).toBe("31");
  });

  it("o rodapé leva só o nome do sistema", () => {
    expect(montarImpressaoEnsaio(base).rodapeItens).toEqual(["Sysmusica"]);
    expect(montarImpressaoEnsaio({ ...base, marca: undefined }).rodapeItens).toEqual([]);
  });
});
''',
    'src/modules/ensaio/components/BotaoImprimirEnsaio.tsx': r'''"use client";

/**
 * Sysmusica — Botão "Imprimir" dos Dados do Ensaio. Imprime o que está GRAVADO para o ensaio escolhido
 * (quem atendeu, encarregados, hino de abertura, palavra e hinos executados), em janela própria.
 */
import { useState } from "react";
import { Printer } from "lucide-react";
import { abrirJanelaImpressao, escreverImpressao } from "@/lib/exportacao";
import { opcoesMarca } from "@/lib/impressaoMarca";
import { useSessao } from "@/modules/autenticacao/SessaoProvider";
import { rotuloCompleto, type Hino } from "@/modules/hinos/regras";
import { formatarDiaDoEvento, formatarHoraDoEvento } from "@/modules/painel/regras";
import type { DadosPainel } from "@/modules/painel/tipos";
import { agoraEmSalvador } from "@/modules/relatorios/regras";
import { montarImpressaoEnsaio } from "../impressao";
import { rotuloDoCargo, rotuloEncarregado } from "../regras";
import type { RespostaEnsaio } from "../tipos";

interface BotaoImprimirEnsaioProps {
  resposta: RespostaEnsaio;
  hinos: Hino[];
  totais: DadosPainel | null;
}

export default function BotaoImprimirEnsaio({ resposta, hinos, totais }: BotaoImprimirEnsaioProps) {
  const { conta } = useSessao();
  const [aviso, setAviso] = useState<string | null>(null);
  const dados = resposta.dados;
  if (!dados) return null; // nada gravado ainda: não há o que imprimir

  function imprimir() {
    if (!dados) return;
    const janela = abrirJanelaImpressao();
    if (!janela) {
      setAviso("O navegador bloqueou a janela de impressão. Permita pop-ups para este site e tente de novo.");
      return;
    }
    setAviso(null);

    const evento = resposta.evento;
    const rotuloDoHino = (id: string) => {
      const hino = hinos.find((item) => item.id === id);
      return hino ? rotuloCompleto(hino) : "Hino não encontrado";
    };
    escreverImpressao(
      janela,
      montarImpressaoEnsaio({
        tipoEvento: evento.tipo,
        quando: `${formatarDiaDoEvento(evento.data_evento)} às ${formatarHoraDoEvento(evento.data_evento)}`,
        local: [evento.casa_oracao ?? evento.local, evento.cidade].filter((parte): parte is string => Boolean(parte)).join(" · "),
        atende: `${dados.atende_nome.trim()} — ${rotuloDoCargo(dados.atende_cargo)}`,
        rotuloEncarregados: rotuloEncarregado(evento.modelo_ensaio),
        encarregados: dados.encarregados
          .filter((item) => item.nome.trim() !== "")
          .map((item) => item.nome.trim() + (item.cidade_uf ? ` (${item.cidade_uf})` : "")),
        hinoAbertura: rotuloDoHino(dados.hino_abertura_id),
        palavra: dados.palavra ?? "",
        hinosExecutados: dados.hinos.map(rotuloDoHino),
        totalParticipantes: totais?.total,
        emitidoPor: conta?.nome ?? "usuário",
        geradoEm: agoraEmSalvador(),
        ...opcoesMarca(),
      })
    );
  }

  return (
    <div className="flex flex-col items-start gap-1">
      <button
        type="button"
        onClick={imprimir}
        className="inline-flex items-center gap-1.5 rounded-lg border border-slate-300 bg-white px-3 py-1.5 text-sm font-medium text-slate-700 shadow-sm hover:bg-slate-50 focus:outline-none focus:ring-2 focus:ring-brand-200"
      >
        <Printer className="h-4 w-4" aria-hidden="true" />
        Imprimir dados do ensaio
      </button>
      <p className="text-xs text-slate-500">Imprime o que está gravado. Salve o formulário antes, se alterou algo.</p>
      {aviso && (
        <p role="alert" className="text-xs text-red-600">
          {aviso}
        </p>
      )}
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
  if "$@" > /tmp/impressaopai-passo.out 2>&1; then
    echo "  ok"
  else
    echo "  FALHOU: $nome"; tail -40 /tmp/impressaopai-passo.out
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
echo "Pronto. Abra Painel ao Vivo e Dados do Ensaio, clique em Imprimir e confira; depois faça o git push."
echo "Depois confira as telas (passo a passo na conversa) e, se estiver tudo certo, faça o git push."
) 2>&1 | tee "$LOG"
