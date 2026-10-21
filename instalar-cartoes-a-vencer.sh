#!/usr/bin/env bash
# =============================================================================
# SysMúsica — PARTE 9-B: alerta de vencimento do cartão de identificação (Dashboard + tela Cartões a Vencer)
#
#  PRECISA DE SQL (migração 0044): rode o arquivo supabase/migrations/0044_cartoes_a_vencer.sql UMA vez no
#  SQL Editor do Supabase ANTES do git push. Este instalador só copia o arquivo e o código da tela.
#  Cria: permissão "cartoes.visualizar", card "Cartões de identificação" no Dashboard e a tela
#  Cadastros > Cartões a Vencer (menu).
#
# Segurança: confere cada trecho (exatamente 1 vez), faz backup em /tmp/bkp-cartoes-a-vencer-*, aplica,
# roda tsc, vitest, eslint e build; se algo falhar, DESFAZ tudo sozinho (inclusive os arquivos novos).
#
# Uso:  cd /workspaces/sysmusica/sysmusica && rm -rf .next && bash instalar-cartoes-a-vencer.sh
# Log:  /tmp/instalar-cartoes-a-vencer.log
# =============================================================================

LOG=/tmp/instalar-cartoes-a-vencer.log
BKP=/tmp/bkp-cartoes-a-vencer-$(date +%Y%m%d-%H%M%S)
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
    ('src/lib/permissoes.ts',
     r'''  { codigo: "cadastros.aprovar", modulo: "Cadastros pendentes", acao: "Aprovar" },''',
     r'''  { codigo: "cadastros.aprovar", modulo: "Cadastros pendentes", acao: "Aprovar" },
  { codigo: "cartoes.visualizar", modulo: "Cartões", acao: "Visualizar" },'''),
    ('src/components/layout/navegacao.ts',
     r'''  ClipboardCheck,
  ClipboardList,
  DoorOpen,''',
     r'''  ClipboardCheck,
  ClipboardList,
  CreditCard,
  DoorOpen,'''),
    ('src/components/layout/navegacao.ts',
     r'''icone: Inbox, permissao: "cadastros.visualizar" },
''',
     r'''icone: Inbox, permissao: "cadastros.visualizar" },
      // Cartões de identificação vencidos / a vencer (card do Dashboard + esta lista)
      { href: "/cartoes", rotulo: "Cartões a Vencer", icone: CreditCard, permissao: "cartoes.visualizar" },
'''),
    ('src/modules/dashboard/components/DashboardConteudo.tsx',
     r'''import AtalhosRapidos from "@/modules/dashboard/components/AtalhosRapidos";
''',
     r'''import AtalhosRapidos from "@/modules/dashboard/components/AtalhosRapidos";
import CartoesAVencerCard from "@/modules/cartoes/components/CartoesAVencerCard";
'''),
    ('src/modules/dashboard/components/DashboardConteudo.tsx',
     r'''            <PainelGraficos dados={graficos} />
''',
     r'''            {/* Alerta de cartões de identificação (só aparece para quem tem a permissão cartoes.visualizar) */}
            <CartoesAVencerCard />

            <PainelGraficos dados={graficos} />
'''),
]


# Arquivos NOVOS (o instalador recusa se algum já existir)
NOVOS = {
    'src/modules/cartoes/regras.test.ts': r'''import { describe, expect, it } from "vitest";
import { GRUPOS_MENU, filtrarMenu, montarMigalhas } from "@/components/layout/navegacao";
import type { CodigoPermissao } from "@/lib/permissoes";
import { contarSituacoes, filtrarCartoes, formatarValidade, textoPrazo } from "./regras";
import type { LinhaCartao } from "./tipos";

function linha(nome: string, situacao: LinhaCartao["situacao"], dias: number | null): LinhaCartao {
  return { membro_id: nome, nome, cargo_nome: null, casa_nome: null, cartao_numero: null, cartao_validade: null, dias, situacao };
}

describe("formatarValidade", () => {
  it("troca AAAA-MM-DD por DD/MM/AAAA", () => {
    expect(formatarValidade("2026-11-05")).toBe("05/11/2026");
  });
  it("sem data mostra um traço", () => {
    expect(formatarValidade(null)).toBe("—");
    expect(formatarValidade("")).toBe("—");
  });
});

describe("textoPrazo", () => {
  it("cartão vencido", () => {
    expect(textoPrazo("VENCIDO", -1)).toBe("venceu ontem");
    expect(textoPrazo("VENCIDO", -5)).toBe("venceu há 5 dias");
  });
  it("cartão a vencer", () => {
    expect(textoPrazo("A_VENCER", 0)).toBe("vence hoje");
    expect(textoPrazo("A_VENCER", 1)).toBe("vence amanhã");
    expect(textoPrazo("A_VENCER", 12)).toBe("vence em 12 dias");
  });
  it("sem validade", () => {
    expect(textoPrazo("SEM_VALIDADE", null)).toBe("validade não informada");
  });
});

describe("filtrarCartoes e contarSituacoes", () => {
  const itens = [linha("A", "VENCIDO", -3), linha("B", "A_VENCER", 4), linha("C", "A_VENCER", 20), linha("D", "SEM_VALIDADE", null)];

  it("TODOS mantém tudo; os demais filtram pela situação", () => {
    expect(filtrarCartoes(itens, "TODOS")).toHaveLength(4);
    expect(filtrarCartoes(itens, "A_VENCER").map((i) => i.nome)).toEqual(["B", "C"]);
    expect(filtrarCartoes(itens, "VENCIDO").map((i) => i.nome)).toEqual(["A"]);
  });

  it("conta cada situação", () => {
    expect(contarSituacoes(itens)).toEqual({ TODOS: 4, VENCIDO: 1, A_VENCER: 2, SEM_VALIDADE: 1 });
  });
});

describe("menu: Cartões a Vencer", () => {
  const hrefsDe = (permitidas: CodigoPermissao[]) =>
    filtrarMenu(GRUPOS_MENU, (p) => permitidas.includes(p)).flatMap((grupo) => grupo.itens.map((item) => item.href));

  it("só aparece para quem tem a permissão cartoes.visualizar", () => {
    expect(hrefsDe(["cartoes.visualizar"])).toEqual(["/cartoes"]);
    expect(hrefsDe(["membros.visualizar"])).not.toContain("/cartoes");
  });

  it("breadcrumbs: Início > Cadastros > Cartões a Vencer", () => {
    expect(montarMigalhas("/cartoes")).toEqual([
      { rotulo: "Início", href: "/" },
      { rotulo: "Cadastros" },
      { rotulo: "Cartões a Vencer" },
    ]);
  });
});
''',
    'src/modules/cartoes/regras.ts': r'''/**
 * SysMúsica — Regras PURAS do módulo Cartões (sem acesso ao banco), testadas em regras.test.ts.
 * Quem decide o que está vencido ou a vencer é o banco (fuso America/Sao_Paulo); aqui só se
 * formatam textos e se filtra a lista que o banco já devolveu.
 */
import type { FiltroCartao, LinhaCartao, SituacaoCartao } from "./tipos";

/** Prazo padrão do alerta (card do Dashboard e primeira abertura da tela). */
export const PRAZO_PADRAO_DIAS = 30;

/** Prazos que a tela oferece (o banco aceita de 1 a 365). */
export const PRAZOS_DIAS = [30, 60, 90] as const;

export const ROTULO_SITUACAO: Record<SituacaoCartao, string> = {
  VENCIDO: "Vencido",
  A_VENCER: "A vencer",
  SEM_VALIDADE: "Sem validade",
};

// Cores dos selos (as mesmas variantes de Badge usadas no resto do sistema)
export const VARIANTE_SITUACAO: Record<SituacaoCartao, "perigo" | "alerta" | "neutro"> = {
  VENCIDO: "perigo",
  A_VENCER: "alerta",
  SEM_VALIDADE: "neutro",
};

/** "2026-11-05" -> "05/11/2026" (sem usar Date, para o fuso não mudar o dia). */
export function formatarValidade(iso: string | null): string {
  const partes = /^(\d{4})-(\d{2})-(\d{2})/.exec(iso ?? "");
  return partes ? `${partes[3]}/${partes[2]}/${partes[1]}` : "—";
}

/** Texto do prazo: "venceu há 5 dias", "vence hoje", "vence em 12 dias"... */
export function textoPrazo(situacao: SituacaoCartao, dias: number | null): string {
  if (situacao === "SEM_VALIDADE" || dias === null) return "validade não informada";
  if (dias < 0) {
    const atras = Math.abs(dias);
    return atras === 1 ? "venceu ontem" : `venceu há ${atras} dias`;
  }
  if (dias === 0) return "vence hoje";
  return dias === 1 ? "vence amanhã" : `vence em ${dias} dias`;
}

/** Aplica o filtro de situação da tela. */
export function filtrarCartoes(itens: LinhaCartao[], filtro: FiltroCartao): LinhaCartao[] {
  return filtro === "TODOS" ? itens : itens.filter((item) => item.situacao === filtro);
}

/** Quantidade de cada situação (os números dos botões de filtro). */
export function contarSituacoes(itens: LinhaCartao[]): Record<FiltroCartao, number> {
  const total: Record<FiltroCartao, number> = { TODOS: itens.length, VENCIDO: 0, A_VENCER: 0, SEM_VALIDADE: 0 };
  for (const item of itens) total[item.situacao] += 1;
  return total;
}
''',
    'src/modules/cartoes/tipos.ts': r'''/**
 * SysMúsica — Tipos do módulo Cartões (alerta de vencimento do cartão de identificação).
 * Os dados vêm das funções do banco resumo_cartoes e listar_cartoes (migração 0044).
 */
export type SituacaoCartao = "VENCIDO" | "A_VENCER" | "SEM_VALIDADE";

/** Filtro da tela: uma situação ou todas. */
export type FiltroCartao = "TODOS" | SituacaoCartao;

export interface LinhaCartao {
  membro_id: string;
  nome: string;
  cargo_nome: string | null;
  casa_nome: string | null;
  cartao_numero: string | null;
  cartao_validade: string | null; // "AAAA-MM-DD"; nulo = validade não informada
  dias: number | null; // negativo = já venceu há N dias; 0 = vence hoje; nulo = sem validade
  situacao: SituacaoCartao;
}

export interface ResumoCartoes {
  dias: number;
  vencidos: number;
  a_vencer: number;
  sem_validade: number;
}
''',
    'src/modules/cartoes/components/CartoesAVencerCard.tsx': r'''"use client";

/**
 * SysMúsica — Card "Cartões de identificação" do Dashboard.
 * Mostra quantos cartões já venceram, quantos vencem nos próximos 30 dias e quantos não têm validade
 * informada, com um atalho para a lista. Só aparece para quem tem a permissão cartoes.visualizar; os
 * números vêm do banco já filtrados pela abrangência de quem está logado. Se a busca falhar, o erro
 * fica só neste card (o resto do Dashboard continua normal).
 */
import { useCallback, useEffect, useState } from "react";
import Link from "next/link";
import Card from "@/components/ui/Card";
import Skeleton from "@/components/ui/Skeleton";
import { cn } from "@/lib/cn";
import { useSessao } from "@/modules/autenticacao/SessaoProvider";
import { PRAZO_PADRAO_DIAS } from "../regras";
import { buscarResumoCartoes } from "../services/cartoes";
import type { ResumoCartoes } from "../tipos";

function Numero({ valor, rotulo, classe }: { valor: number; rotulo: string; classe: string }) {
  return (
    <div className="rounded-xl border border-slate-200 p-3 text-center">
      <p className={cn("text-2xl font-bold tabular-nums", classe)}>{valor}</p>
      <p className="mt-0.5 text-xs text-slate-600">{rotulo}</p>
    </div>
  );
}

export default function CartoesAVencerCard() {
  const { pode } = useSessao();
  const permitido = pode("cartoes.visualizar");

  const [resumo, setResumo] = useState<ResumoCartoes | null>(null);
  const [carregando, setCarregando] = useState(true); // inicia true: primeira busca no mount
  const [erro, setErro] = useState<string | null>(null);

  const carregar = useCallback(async () => {
    try {
      setResumo(await buscarResumoCartoes(PRAZO_PADRAO_DIAS));
      setErro(null);
    } catch (e) {
      console.error("Falha ao carregar o resumo dos cartões:", e);
      setErro(e instanceof Error ? e.message : "Não foi possível carregar os cartões.");
    } finally {
      setCarregando(false);
    }
  }, []);

  useEffect(() => {
    if (!permitido) return;
    // O setState só roda DEPOIS do await (nunca de forma síncrona), então o aviso da regra
    // set-state-in-effect não se aplica a esta carga inicial. Ignorado apenas nesta linha.
    // eslint-disable-next-line react-hooks/set-state-in-effect
    void carregar();
  }, [permitido, carregar]);

  if (!permitido) return null;

  const tudoEmDia = resumo !== null && resumo.vencidos === 0 && resumo.a_vencer === 0 && resumo.sem_validade === 0;

  return (
    <Card
      titulo="Cartões de identificação"
      descricao={`Vencidos e a vencer nos próximos ${PRAZO_PADRAO_DIAS} dias.`}
    >
      {carregando ? (
        <div role="status" aria-live="polite">
          <span className="sr-only">Carregando os cartões...</span>
          <Skeleton className="h-20 rounded-xl" />
        </div>
      ) : erro || !resumo ? (
        <div role="alert" className="rounded-lg bg-red-50 px-3 py-2 text-sm text-red-700">
          {erro ?? "Não foi possível carregar os cartões."}{" "}
          <button
            type="button"
            className="font-semibold underline"
            onClick={() => {
              setCarregando(true);
              void carregar();
            }}
          >
            Tentar novamente
          </button>
        </div>
      ) : (
        <div className="space-y-3">
          {tudoEmDia ? (
            <p className="rounded-lg bg-emerald-50 px-3 py-2 text-sm text-emerald-800">
              Nenhum cartão vencido, a vencer ou sem validade informada.
            </p>
          ) : (
            <div className="grid grid-cols-3 gap-2">
              <Numero valor={resumo.vencidos} rotulo="Vencidos" classe="text-red-600" />
              <Numero valor={resumo.a_vencer} rotulo="A vencer" classe="text-amber-600" />
              <Numero valor={resumo.sem_validade} rotulo="Sem validade" classe="text-slate-600" />
            </div>
          )}
          <Link href="/cartoes" className="inline-block text-sm font-semibold text-brand-700 hover:underline">
            Ver a lista completa
          </Link>
        </div>
      )}
    </Card>
  );
}
''',
    'src/modules/cartoes/components/TabelaCartoes.tsx': r'''/**
 * SysMúsica — Tabela da tela "Cartões a Vencer" (componente de apresentação).
 * Recebe a lista pronta do banco; a cor do selo mostra a urgência (vencido, a vencer, sem validade).
 */
import Badge from "@/components/ui/Badge";
import { ROTULO_SITUACAO, VARIANTE_SITUACAO, formatarValidade, textoPrazo } from "../regras";
import type { LinhaCartao } from "../tipos";

const classeCabecalho = "px-4 py-3 text-left text-xs font-semibold uppercase tracking-wide text-slate-500";

export default function TabelaCartoes({ itens }: { itens: LinhaCartao[] }) {
  return (
    <div className="overflow-hidden rounded-2xl border border-slate-200 bg-white shadow-sm">
      <div className="overflow-x-auto">
        <table className="min-w-full divide-y divide-slate-200 text-sm">
          <thead className="bg-slate-50">
            <tr>
              <th scope="col" className={classeCabecalho}>Nome</th>
              <th scope="col" className={classeCabecalho}>Cargo</th>
              <th scope="col" className={classeCabecalho}>Casa de Oração</th>
              <th scope="col" className={classeCabecalho}>Nº do cartão</th>
              <th scope="col" className={classeCabecalho}>Validade</th>
              <th scope="col" className={classeCabecalho}>Situação</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-slate-100">
            {itens.map((item) => (
              <tr key={item.membro_id} className="transition hover:bg-slate-50">
                <td className="px-4 py-3 font-medium text-slate-900">{item.nome}</td>
                <td className="px-4 py-3 text-slate-800">{item.cargo_nome ?? "—"}</td>
                <td className="px-4 py-3 text-slate-800">{item.casa_nome ?? "—"}</td>
                <td className="px-4 py-3 tabular-nums text-slate-700">{item.cartao_numero ?? "—"}</td>
                <td className="whitespace-nowrap px-4 py-3 tabular-nums text-slate-700">{formatarValidade(item.cartao_validade)}</td>
                <td className="px-4 py-3">
                  <Badge variante={VARIANTE_SITUACAO[item.situacao]}>{ROTULO_SITUACAO[item.situacao]}</Badge>
                  <div className="mt-1 text-xs text-slate-500">{textoPrazo(item.situacao, item.dias)}</div>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}
''',
    'src/modules/cartoes/services/cartoes.ts': r'''/**
 * SysMúsica — Serviço do módulo Cartões. As duas consultas passam por funções do banco
 * (resumo_cartoes e listar_cartoes) que conferem a permissão cartoes.visualizar e a abrangência
 * de quem consulta: o navegador nunca lê a tabela diretamente.
 */
import { supabase } from "@/lib/supabase";
import { mensagemDoErro } from "@/lib/erros";
import type { LinhaCartao, ResumoCartoes } from "../tipos";

/** Totais do card do Dashboard (vencidos, a vencer no prazo e sem validade). */
export async function buscarResumoCartoes(dias: number): Promise<ResumoCartoes> {
  const { data, error } = await supabase.rpc("resumo_cartoes", { p_dias: dias });
  if (error) throw new Error(mensagemDoErro(error, "Não foi possível carregar os cartões."));
  const r = (data ?? {}) as Partial<ResumoCartoes>;
  return {
    dias: Number(r.dias ?? dias),
    vencidos: Number(r.vencidos ?? 0),
    a_vencer: Number(r.a_vencer ?? 0),
    sem_validade: Number(r.sem_validade ?? 0),
  };
}

/** Lista da tela "Cartões a Vencer" (já vem ordenada pelo banco: mais urgentes primeiro). */
export async function listarCartoes(dias: number): Promise<LinhaCartao[]> {
  const { data, error } = await supabase.rpc("listar_cartoes", { p_dias: dias });
  if (error) throw new Error(mensagemDoErro(error, "Não foi possível carregar os cartões."));
  return ((data ?? []) as LinhaCartao[]).map((linha) => ({ ...linha, dias: linha.dias === null ? null : Number(linha.dias) }));
}
''',
    'src/app/(painel)/cartoes/layout.tsx': r'''import type { ReactNode } from "react";
import RequerPermissao from "@/modules/autenticacao/components/RequerPermissao";

/** Protege a tela de Cartões a Vencer: só entra quem tem a permissão de visualizar. */
export default function CartoesLayout({ children }: { children: ReactNode }) {
  return <RequerPermissao permissao="cartoes.visualizar">{children}</RequerPermissao>;
}
''',
    'src/app/(painel)/cartoes/page.tsx': r'''"use client";

/**
 * SysMúsica — Cadastros > Cartões a Vencer: lista dos cartões de identificação vencidos, a vencer no
 * prazo escolhido (30, 60 ou 90 dias) e dos cargos que exigem cartão mas estão sem validade informada.
 * Só mostra membros ativos da abrangência de quem consulta (o banco confere a permissão e a abrangência).
 * Para corrigir uma validade: Músicos e Organistas > editar o cadastro, ou aprovar a atualização
 * enviada pelo link público em Cadastros Pendentes.
 */
import { useCallback, useEffect, useMemo, useState } from "react";
import EmptyState from "@/components/ui/EmptyState";
import ErrorState from "@/components/ui/ErrorState";
import PageHeader from "@/components/ui/PageHeader";
import Skeleton from "@/components/ui/Skeleton";
import { cn } from "@/lib/cn";
import TabelaCartoes from "@/modules/cartoes/components/TabelaCartoes";
import { PRAZOS_DIAS, PRAZO_PADRAO_DIAS, ROTULO_SITUACAO, contarSituacoes, filtrarCartoes } from "@/modules/cartoes/regras";
import { listarCartoes } from "@/modules/cartoes/services/cartoes";
import type { FiltroCartao, LinhaCartao } from "@/modules/cartoes/tipos";

const FILTROS: { valor: FiltroCartao; rotulo: string }[] = [
  { valor: "TODOS", rotulo: "Todos" },
  { valor: "VENCIDO", rotulo: ROTULO_SITUACAO.VENCIDO },
  { valor: "A_VENCER", rotulo: ROTULO_SITUACAO.A_VENCER },
  { valor: "SEM_VALIDADE", rotulo: ROTULO_SITUACAO.SEM_VALIDADE },
];

export default function CartoesPage() {
  const [dias, setDias] = useState<number>(PRAZO_PADRAO_DIAS);
  const [filtro, setFiltro] = useState<FiltroCartao>("TODOS");
  const [itens, setItens] = useState<LinhaCartao[]>([]);
  const [carregando, setCarregando] = useState(true); // inicia true: primeira busca no mount
  const [erro, setErro] = useState<string | null>(null);

  // Busca a lista no banco para o prazo escolhido
  const carregar = useCallback(async (prazo: number) => {
    try {
      setItens(await listarCartoes(prazo));
      setErro(null);
    } catch (e) {
      console.error("Falha ao carregar os cartões:", e);
      setErro(e instanceof Error ? e.message : "Não foi possível carregar os cartões.");
    } finally {
      setCarregando(false);
    }
  }, []);

  // Carrega ao abrir a página e sempre que o prazo mudar
  useEffect(() => {
    // O setState só roda DEPOIS do await (nunca de forma síncrona), então o aviso da regra
    // set-state-in-effect não se aplica a esta carga. Ignorado apenas nesta linha.
    // eslint-disable-next-line react-hooks/set-state-in-effect
    void carregar(dias);
  }, [carregar, dias]);

  function trocarPrazo(novo: number) {
    setCarregando(true);
    setDias(novo);
  }

  function tentarNovamente() {
    setCarregando(true);
    void carregar(dias);
  }

  const contagem = useMemo(() => contarSituacoes(itens), [itens]);
  const visiveis = useMemo(() => filtrarCartoes(itens, filtro), [itens, filtro]);

  return (
    <main className="text-slate-900">
      <div className="mx-auto max-w-7xl px-4 py-8 sm:px-6 lg:px-8">
        <PageHeader
          titulo="Cartões a Vencer"
          descricao="Cartões de identificação vencidos, a vencer no prazo escolhido e cargos que exigem cartão sem validade informada."
        />

        <div className="mb-4 flex flex-wrap items-center gap-3">
          <div role="group" aria-label="Filtrar por situação" className="flex flex-wrap gap-2">
            {FILTROS.map(({ valor, rotulo }) => (
              <button
                key={valor}
                type="button"
                aria-pressed={filtro === valor}
                onClick={() => setFiltro(valor)}
                className={cn(
                  "rounded-full border px-3 py-1.5 text-sm font-medium transition focus:outline-none focus-visible:ring-2 focus-visible:ring-brand-300",
                  filtro === valor
                    ? "border-brand-600 bg-brand-50 text-brand-700"
                    : "border-slate-200 bg-white text-slate-600 hover:border-slate-300"
                )}
              >
                {rotulo} <span className="tabular-nums">({contagem[valor]})</span>
              </button>
            ))}
          </div>

          <div className="ml-auto flex items-center gap-2 text-sm text-slate-600">
            <label htmlFor="prazo-cartoes">Vencem em até</label>
            <select
              id="prazo-cartoes"
              value={dias}
              onChange={(evento) => trocarPrazo(Number(evento.target.value))}
              className="rounded-lg border border-slate-300 bg-white px-3 py-1.5 text-sm text-slate-800 focus:outline-none focus-visible:ring-2 focus-visible:ring-brand-300"
            >
              {PRAZOS_DIAS.map((prazo) => (
                <option key={prazo} value={prazo}>
                  {prazo} dias
                </option>
              ))}
            </select>
          </div>
        </div>

        {carregando ? (
          <div role="status" aria-live="polite" className="space-y-3">
            <span className="sr-only">Carregando os cartões...</span>
            <Skeleton className="h-14 rounded-2xl" />
            {[0, 1, 2, 3].map((i) => (
              <Skeleton key={i} className="h-12" />
            ))}
          </div>
        ) : erro ? (
          <ErrorState titulo="Não foi possível carregar os cartões." mensagem={erro} onTentarNovamente={tentarNovamente} />
        ) : itens.length === 0 ? (
          <EmptyState
            titulo="Nenhum cartão vencido ou a vencer."
            descricao={`Nenhum cartão vence nos próximos ${dias} dias e nenhum cargo que exige cartão está sem validade.`}
          />
        ) : visiveis.length === 0 ? (
          <EmptyState titulo="Nenhum cartão nesta situação." descricao="Escolha outro filtro para ver os demais." />
        ) : (
          <TabelaCartoes itens={visiveis} />
        )}
      </div>
    </main>
  );
}
''',
    'supabase/migrations/0044_cartoes_a_vencer.sql': r'''-- =============================================================================
-- SysMúsica — Migração 0044: Cartões a vencer (Parte 9-B)
--
--  Alerta de vencimento do cartão de identificação (dados em membros_cadastro.cartao_validade).
--  O que esta migração faz:
--   A) Permissão nova "cartoes.visualizar" (só o Administrador recebe; os demais grupos são liberados
--      em Grupos e Permissões).
--   B) resumo_cartoes(p_dias): totais para o card do Dashboard (vencidos, a vencer no prazo, sem validade).
--   C) listar_cartoes(p_dias): lista para a tela "Cartões a Vencer".
--  Regras:
--   * Só membros ativos e não excluídos. Quem consulta só enxerga as Casas de Oração da sua abrangência.
--   * "Vencido" = validade anterior a hoje; "A vencer" = validade de hoje até hoje + p_dias.
--   * "Sem validade" = cargo que exige cartão (ex.: Encarregado, Examinadora) sem a validade informada.
--   * "Hoje" é sempre o dia no fuso America/Sao_Paulo (não o do servidor).
--   * Não altera nenhum dado; só cria a permissão e duas funções de leitura.
-- Rode UMA vez no SQL Editor do Supabase, ANTES do git push. Se der erro, rode:  rollback;
-- =============================================================================
begin;
set local check_function_bodies = off;

do $$
begin
  if to_regclass('public.membros') is null or to_regclass('public.membros_cadastro') is null
     or to_regclass('public.cargos') is null or to_regclass('public.casas_oracao') is null
     or to_regprocedure('public.exigir_permissao(text)') is null
     or to_regprocedure('public.casa_oracao_na_abrangencia(uuid)') is null
     or to_regprocedure('public.aprovar_cadastro_pendente(uuid, uuid, text, text, text, uuid)') is null then
    raise exception 'Aplique primeiro as migrações até a 0043. Nada foi alterado.';
  end if;
  if to_regprocedure('public.listar_cartoes(integer)') is not null then
    raise exception 'A migração 0044 já foi aplicada. Nada foi alterado.';
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- A) Permissão (igual a CATALOGO_PERMISSOES em src/lib/permissoes.ts). Só o Administrador recebe.
-- ---------------------------------------------------------------------------
insert into public.permissoes (codigo, modulo, acao, descricao) values
  ('cartoes.visualizar', 'Cartões', 'Visualizar', 'Ver os cartões de identificação vencidos, a vencer e sem validade informada')
on conflict (codigo) do update
  set modulo = excluded.modulo, acao = excluded.acao, descricao = excluded.descricao;

insert into public.grupo_permissoes (grupo_id, permissao_codigo)
select g.id, p.codigo
  from public.grupos g
  cross join public.permissoes p
 where g.sistema and g.nome = 'Administrador'
   and p.codigo = 'cartoes.visualizar'
on conflict do nothing;

-- ---------------------------------------------------------------------------
-- B) Totais do card do Dashboard
-- ---------------------------------------------------------------------------
create or replace function public.resumo_cartoes(p_dias integer default 30)
returns jsonb
language plpgsql stable security definer set search_path to 'public'
as $$
declare
  v_hoje date := (now() at time zone 'America/Sao_Paulo')::date;
  v_vencidos integer;
  v_a_vencer integer;
  v_sem      integer;
begin
  perform public.exigir_permissao('cartoes.visualizar');
  if p_dias is null or p_dias < 1 or p_dias > 365 then
    raise exception 'O prazo deve ficar entre 1 e 365 dias.' using errcode = '22023';
  end if;

  select count(*) filter (where mc.cartao_validade < v_hoje),
         count(*) filter (where mc.cartao_validade >= v_hoje and mc.cartao_validade <= v_hoje + p_dias),
         count(*) filter (where mc.cartao_validade is null and coalesce(g.exige_cartao, false))
    into v_vencidos, v_a_vencer, v_sem
    from public.membros m
    left join public.membros_cadastro mc on mc.membro_id = m.id
    left join public.cargos g on g.id = m.cargo_id
   where m.excluido_em is null
     and m.status = 'Ativo'
     and (m.casa_oracao_id is null or public.casa_oracao_na_abrangencia(m.casa_oracao_id));

  return jsonb_build_object('dias', p_dias, 'vencidos', v_vencidos, 'a_vencer', v_a_vencer, 'sem_validade', v_sem);
end;
$$;

-- ---------------------------------------------------------------------------
-- C) Lista da tela "Cartões a Vencer"
--    dias: negativo = já venceu há N dias; 0 = vence hoje; nulo = sem validade informada.
-- ---------------------------------------------------------------------------
create or replace function public.listar_cartoes(p_dias integer default 30)
returns table (
  membro_id uuid, nome text, cargo_nome text, casa_nome text,
  cartao_numero text, cartao_validade date, dias integer, situacao text
)
language plpgsql stable security definer set search_path to 'public'
as $$
declare
  v_hoje date := (now() at time zone 'America/Sao_Paulo')::date;
begin
  perform public.exigir_permissao('cartoes.visualizar');
  if p_dias is null or p_dias < 1 or p_dias > 365 then
    raise exception 'O prazo deve ficar entre 1 e 365 dias.' using errcode = '22023';
  end if;

  return query
    select m.id, m.nome, g.nome, ca.nome, mc.cartao_numero, mc.cartao_validade,
           (mc.cartao_validade - v_hoje)::integer,
           case when mc.cartao_validade is null then 'SEM_VALIDADE'
                when mc.cartao_validade < v_hoje then 'VENCIDO'
                else 'A_VENCER' end
      from public.membros m
      left join public.membros_cadastro mc on mc.membro_id = m.id
      left join public.cargos g on g.id = m.cargo_id
      left join public.casas_oracao ca on ca.id = m.casa_oracao_id
     where m.excluido_em is null
       and m.status = 'Ativo'
       and (m.casa_oracao_id is null or public.casa_oracao_na_abrangencia(m.casa_oracao_id))
       and (   mc.cartao_validade <= v_hoje + p_dias
            or (mc.cartao_validade is null and coalesce(g.exige_cartao, false)))
     order by case when mc.cartao_validade is null then 2 else 1 end,
              mc.cartao_validade asc, m.nome asc
     limit 1000;
end;
$$;

-- ---------------------------------------------------------------------------
-- Acessos: só usuários logados (e a função confere a permissão e a abrangência)
-- ---------------------------------------------------------------------------
revoke all on function public.resumo_cartoes(integer) from public, anon, authenticated;
revoke all on function public.listar_cartoes(integer) from public, anon, authenticated;
grant execute on function public.resumo_cartoes(integer) to authenticated;
grant execute on function public.listar_cartoes(integer) to authenticated;

do $$
begin
  if has_function_privilege('anon', 'public.resumo_cartoes(integer)', 'execute')
     or has_function_privilege('anon', 'public.listar_cartoes(integer)', 'execute') then
    raise exception 'Permissões inesperadas para o papel anon. Nada foi alterado.';
  end if;
  if not exists (select 1 from public.permissoes where codigo = 'cartoes.visualizar') then
    raise exception 'A permissão não foi criada. Nada foi alterado.';
  end if;
end $$;

commit;
select set_config('sysmusica.migracao_0044', 'ok', false);
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
  if "$@" > /tmp/cartoesvencer-passo.out 2>&1; then
    echo "  ok"
  else
    echo "  FALHOU: $nome"; tail -40 /tmp/cartoesvencer-passo.out
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
echo "Pronto. PRÓXIMO PASSO: rode o SQL supabase/migrations/0044_cartoes_a_vencer.sql no Supabase (SQL Editor) e só então o git push."
echo "Depois confira as telas (passo a passo na conversa) e, se estiver tudo certo, faça o git push."
) 2>&1 | tee "$LOG"
