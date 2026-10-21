#!/usr/bin/env bash
# =============================================================================
# SysMúsica — AJUSTE: prazo dos pedidos de Cadastros Pendentes configurável (botão com engrenagem)
#
#  PRECISA DE SQL (migração 0045): rode o arquivo supabase/migrations/0045_prazo_cadastros_pendentes.sql UMA vez
#  no SQL Editor do Supabase ANTES do git push. Este instalador só copia o arquivo e o código da tela.
#  Cria o botão (engrenagem) "Prazo dos pedidos" em Cadastros Pendentes e a permissão cadastros.configurar.
#
# Segurança: confere cada trecho (exatamente 1 vez), faz backup em /tmp/bkp-prazo-cadastros-*, aplica,
# roda tsc, vitest, eslint e build; se algo falhar, DESFAZ tudo sozinho (inclusive os arquivos novos).
#
# Uso:  cd /workspaces/sysmusica/sysmusica && rm -rf .next && bash instalar-prazo-cadastros.sh
# Log:  /tmp/instalar-prazo-cadastros.log
# =============================================================================

LOG=/tmp/instalar-prazo-cadastros.log
BKP=/tmp/bkp-prazo-cadastros-$(date +%Y%m%d-%H%M%S)
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
     r'''  { codigo: "cartoes.visualizar", modulo: "Cartões", acao: "Visualizar" },''',
     r'''  { codigo: "cartoes.visualizar", modulo: "Cartões", acao: "Visualizar" },
  { codigo: "cadastros.configurar", modulo: "Cadastros pendentes", acao: "Configurar" },'''),
    ('src/app/(painel)/cadastros-pendentes/page.tsx',
     r'''import Skeleton from "@/components/ui/Skeleton";
''',
     r'''import Skeleton from "@/components/ui/Skeleton";
import { Settings } from "lucide-react";
import Button from "@/components/ui/Button";
import ConfigurarPrazo from "@/modules/cadastrosPendentes/components/ConfigurarPrazo";
'''),
    ('src/app/(painel)/cadastros-pendentes/page.tsx',
     r'''  const [casaEscolhida, setCasaEscolhida] = useState(""); // casa escolhida ao aprovar um pedido com casa digitada
''',
     r'''  const [casaEscolhida, setCasaEscolhida] = useState(""); // casa escolhida ao aprovar um pedido com casa digitada
  const [configAberta, setConfigAberta] = useState(false); // painel "Prazo dos pedidos" (engrenagem)
'''),
    ('src/app/(painel)/cadastros-pendentes/page.tsx',
     r'''          descricao="Cadastros enviados pelo link público. Nada entra no sistema sem a sua aprovação."
        />''',
     r'''          descricao="Cadastros enviados pelo link público. Nada entra no sistema sem a sua aprovação."
          acoes={
            // Só quem tem a permissão cadastros.configurar (Administrador) vê o botão do prazo dos pedidos
            pode("cadastros.configurar") ? (
              <Button variante="secundario" icone={Settings} onClick={() => setConfigAberta(true)}>
                Prazo dos pedidos
              </Button>
            ) : undefined
          }
        />'''),
    ('src/app/(painel)/cadastros-pendentes/page.tsx',
     r'''      <ConfirmDialog
        aberto={confirmando !== null}''',
     r'''      {/* Painel lateral: prazo (em dias) que um pedido pode esperar antes de vencer */}
      <Drawer
        aberto={configAberta}
        onFechar={() => setConfigAberta(false)}
        titulo="Prazo dos pedidos"
        descricao="Por quantos dias um cadastro pode esperar a sua análise antes de vencer."
      >
        {configAberta && (
          <ConfigurarPrazo
            onSalvo={(mensagem) => {
              setConfigAberta(false);
              setAviso(mensagem);
              void carregar(filtro); // os vencimentos mostrados na lista mudaram
            }}
          />
        )}
      </Drawer>

      <ConfirmDialog
        aberto={confirmando !== null}'''),
]


# Arquivos NOVOS (o instalador recusa se algum já existir)
NOVOS = {
    'src/modules/cadastrosPendentes/prazo.test.ts': r'''import { describe, expect, it } from "vitest";
import { GRUPOS_MENU } from "@/components/layout/navegacao";
import { CATALOGO_PERMISSOES } from "@/lib/permissoes";
import { dataDeVencimento, formatarDataCurta, validarPrazo } from "./prazo";

describe("validarPrazo", () => {
  it("aceita números inteiros de 7 a 365 (com espaços ao redor)", () => {
    expect(validarPrazo("60")).toEqual({ ok: true, dias: 60 });
    expect(validarPrazo(" 45 ")).toEqual({ ok: true, dias: 45 });
    expect(validarPrazo("7")).toEqual({ ok: true, dias: 7 });
    expect(validarPrazo("365")).toEqual({ ok: true, dias: 365 });
  });

  it("recusa vazio, texto, decimal e negativo", () => {
    for (const texto of ["", "   ", "abc", "30,5", "30.5", "-10", "1e2"]) {
      expect(validarPrazo(texto).ok, texto).toBe(false);
    }
  });

  it("recusa fora do intervalo, com mensagem clara", () => {
    expect(validarPrazo("6")).toEqual({ ok: false, erro: "O prazo deve ficar entre 7 e 365 dias." });
    expect(validarPrazo("366")).toEqual({ ok: false, erro: "O prazo deve ficar entre 7 e 365 dias." });
    expect(validarPrazo("0").ok).toBe(false);
  });
});

describe("dataDeVencimento e formatarDataCurta", () => {
  // 21/10/2026 16:18 em São Paulo (UTC-3) = 19:18 UTC
  const base = new Date("2026-10-21T19:18:00Z");

  it("soma os dias à data de envio", () => {
    expect(formatarDataCurta(dataDeVencimento(60, base))).toBe("20/12/2026");
    expect(formatarDataCurta(dataDeVencimento(30, base))).toBe("20/11/2026");
  });
});

describe("permissão de configurar o prazo", () => {
  it("existe no catálogo, junto das demais de Cadastros pendentes", () => {
    const codigos = CATALOGO_PERMISSOES.map((permissao) => permissao.codigo as string);
    expect(codigos).toContain("cadastros.configurar");
    expect(codigos).toContain("cadastros.visualizar");
  });

  it("não vira item de menu (é um botão dentro de Cadastros Pendentes)", () => {
    const permissoesDoMenu = GRUPOS_MENU.flatMap((grupo) => grupo.itens.map((item) => item.permissao as string));
    expect(permissoesDoMenu).not.toContain("cadastros.configurar");
  });
});
''',
    'src/modules/cadastrosPendentes/prazo.ts': r'''/**
 * SysMúsica — Regras PURAS do prazo dos Cadastros Pendentes (sem acesso ao banco), testadas em prazo.test.ts.
 * O banco é quem manda: ele recusa prazos fora de 7 a 365 dias (migração 0045). Aqui só se valida o que a
 * pessoa digitou, para avisar na hora, e se calcula a data de exemplo mostrada na tela.
 */
export const PRAZO_MINIMO_DIAS = 7;
export const PRAZO_MAXIMO_DIAS = 365;
export const PRAZO_PADRAO_DIAS = 60;

/** Atalhos de prazo mostrados como botões na tela. */
export const ATALHOS_PRAZO = [30, 60, 90, 180] as const;

export type ResultadoPrazo = { ok: true; dias: number } | { ok: false; erro: string };

/** Confere o texto digitado: só números inteiros, de 7 a 365. */
export function validarPrazo(texto: string): ResultadoPrazo {
  const limpo = texto.trim();
  if (limpo === "") return { ok: false, erro: "Informe o prazo em dias." };
  if (!/^\d+$/.test(limpo)) return { ok: false, erro: "Use apenas números inteiros (exemplo: 60)." };
  const dias = Number(limpo);
  if (dias < PRAZO_MINIMO_DIAS || dias > PRAZO_MAXIMO_DIAS) {
    return { ok: false, erro: `O prazo deve ficar entre ${PRAZO_MINIMO_DIAS} e ${PRAZO_MAXIMO_DIAS} dias.` };
  }
  return { ok: true, dias };
}

/** Data em que venceria um pedido enviado em "base" (padrão: agora), no prazo informado. */
export function dataDeVencimento(dias: number, base: Date = new Date()): Date {
  return new Date(base.getTime() + dias * 86_400_000);
}

/** "20/12/2026" no fuso de São Paulo (o mesmo do banco). */
export function formatarDataCurta(data: Date): string {
  return data.toLocaleDateString("pt-BR", { timeZone: "America/Sao_Paulo" });
}
''',
    'src/modules/cadastrosPendentes/components/ConfigurarPrazo.tsx': r'''"use client";

/**
 * SysMúsica — Painel "Prazo dos pedidos" (botão com ícone de engrenagem em Cadastros Pendentes).
 * Define por quantos dias um pedido do formulário público espera análise antes de vencer. O novo prazo vale
 * para os pedidos novos e para os que já estão pendentes. Se algum pendente já passou do novo prazo, a tela
 * avisa quantos são e pede confirmação antes de salvar. Só aparece para quem tem a permissão cadastros.configurar
 * (o banco confere de novo ao salvar).
 */
import { useCallback, useEffect, useState } from "react";
import Button from "@/components/ui/Button";
import ConfirmDialog from "@/components/ui/ConfirmDialog";
import Skeleton from "@/components/ui/Skeleton";
import { cn } from "@/lib/cn";
import { ATALHOS_PRAZO, dataDeVencimento, formatarDataCurta, validarPrazo } from "../prazo";
import { obterConfigPrazo, previaPrazo, salvarPrazo, type ConfigPrazo } from "../services/prazo";
import { avisarQueFilaMudou } from "../services/cadastrosPendentes";

export default function ConfigurarPrazo({ onSalvo }: { onSalvo: (mensagem: string) => void }) {
  const [config, setConfig] = useState<ConfigPrazo | null>(null);
  const [texto, setTexto] = useState("");
  const [carregando, setCarregando] = useState(true); // inicia true: primeira busca no mount
  const [erroCarga, setErroCarga] = useState<string | null>(null);
  const [salvando, setSalvando] = useState(false);
  const [erroSalvar, setErroSalvar] = useState<string | null>(null);
  const [vencerao, setVencerao] = useState<number | null>(null); // pedidos que passariam do novo prazo (pede confirmação)

  const carregar = useCallback(async () => {
    try {
      const atual = await obterConfigPrazo();
      setConfig(atual);
      setTexto(String(atual.prazo_dias));
      setErroCarga(null);
    } catch (e) {
      console.error("Falha ao carregar o prazo dos cadastros:", e);
      setErroCarga(e instanceof Error ? e.message : "Não foi possível carregar o prazo.");
    } finally {
      setCarregando(false);
    }
  }, []);

  useEffect(() => {
    // O setState só roda DEPOIS do await (nunca de forma síncrona), então o aviso da regra
    // set-state-in-effect não se aplica a esta carga inicial. Ignorado apenas nesta linha.
    // eslint-disable-next-line react-hooks/set-state-in-effect
    void carregar();
  }, [carregar]);

  const validacao = validarPrazo(texto);
  const igualAoAtual = config !== null && validacao.ok && validacao.dias === config.prazo_dias;

  // forcar = true depois que a pessoa confirmou o aviso de pedidos que vencerão
  async function salvar(forcar: boolean) {
    if (!validacao.ok) {
      setErroSalvar(validacao.erro);
      return;
    }
    setSalvando(true);
    setErroSalvar(null);
    try {
      if (!forcar) {
        const qtd = await previaPrazo(validacao.dias);
        if (qtd > 0) {
          setVencerao(qtd);
          return;
        }
      }
      const resultado = await salvarPrazo(validacao.dias);
      avisarQueFilaMudou();
      onSalvo(
        `Prazo alterado para ${resultado.prazo_dias} dias.` +
          (resultado.vencerao_agora > 0
            ? ` ${resultado.vencerao_agora} pedido(s) já passaram do prazo e serão apagados na limpeza diária.`
            : "")
      );
    } catch (e) {
      setErroSalvar(e instanceof Error ? e.message : "Não foi possível salvar o prazo.");
    } finally {
      setSalvando(false);
    }
  }

  if (carregando) {
    return (
      <div role="status" aria-live="polite" className="space-y-3">
        <span className="sr-only">Carregando o prazo...</span>
        <Skeleton className="h-12" />
        <Skeleton className="h-24" />
      </div>
    );
  }

  if (erroCarga || !config) {
    return (
      <div role="alert" className="rounded-lg bg-red-50 px-3 py-2 text-sm text-red-700">
        {erroCarga ?? "Não foi possível carregar o prazo."}{" "}
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
    );
  }

  return (
    <div className="space-y-5">
      <div className="space-y-2">
        <label htmlFor="prazo-pedidos" className="text-sm font-medium text-slate-800">
          Prazo para analisar cada pedido (em dias)
        </label>
        <input
          id="prazo-pedidos"
          type="text"
          inputMode="numeric"
          maxLength={3}
          value={texto}
          onChange={(evento) => {
            setTexto(evento.target.value.replace(/\D/g, ""));
            setErroSalvar(null);
          }}
          aria-describedby="ajuda-prazo"
          className="w-32 rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm tabular-nums text-slate-900 focus:outline-none focus-visible:ring-2 focus-visible:ring-brand-300"
        />
        <p id="ajuda-prazo" className="text-xs text-slate-500">
          De {config.minimo} a {config.maximo} dias. Prazo atual: <strong>{config.prazo_dias} dias</strong> (padrão: {config.padrao}).
        </p>
        <div className="flex flex-wrap gap-2" role="group" aria-label="Prazos sugeridos">
          {ATALHOS_PRAZO.map((dias) => (
            <button
              key={dias}
              type="button"
              onClick={() => {
                setTexto(String(dias));
                setErroSalvar(null);
              }}
              className={cn(
                "rounded-full border px-3 py-1 text-sm font-medium transition focus:outline-none focus-visible:ring-2 focus-visible:ring-brand-300",
                texto === String(dias)
                  ? "border-brand-600 bg-brand-50 text-brand-700"
                  : "border-slate-200 bg-white text-slate-600 hover:border-slate-300"
              )}
            >
              {dias} dias
            </button>
          ))}
        </div>
      </div>

      <div className="space-y-2 rounded-xl bg-slate-50 p-3 text-sm text-slate-700">
        {validacao.ok && (
          <p>
            Um pedido enviado <strong>hoje</strong> vai vencer em <strong>{formatarDataCurta(dataDeVencimento(validacao.dias))}</strong>.
          </p>
        )}
        <p>O prazo é contado a partir do envio de cada pedido e vale também para os que já estão na fila de pendentes.</p>
        <p>Pedidos já vencidos, aprovados ou recusados não mudam.</p>
        <p>Ao vencer, o pedido sai de Pendentes, as fotos e os dados enviados são apagados e a pessoa precisa preencher o formulário de novo.</p>
      </div>

      {(erroSalvar || (!validacao.ok && texto !== "")) && (
        <p role="alert" className="rounded-lg bg-red-50 px-3 py-2 text-sm text-red-700">
          {erroSalvar ?? (!validacao.ok ? validacao.erro : "")}
        </p>
      )}

      <Button onClick={() => void salvar(false)} disabled={salvando || !validacao.ok || igualAoAtual} className="w-full">
        {salvando ? "Salvando..." : igualAoAtual ? "Este já é o prazo atual" : "Salvar prazo"}
      </Button>

      <ConfirmDialog
        aberto={vencerao !== null}
        titulo="Alguns pedidos vão vencer"
        mensagem={
          <p>
            Com o prazo de <strong>{validacao.ok ? validacao.dias : "?"} dias</strong>, <strong>{vencerao}</strong> pedido(s) pendente(s) já passaram
            do limite e vencem na próxima limpeza diária. Os dados e as fotos deles serão apagados e não poderão ser
            recuperados. Deseja continuar?
          </p>
        }
        textoConfirmar="Salvar mesmo assim"
        variante="perigo"
        processando={salvando}
        onConfirmar={() => {
          setVencerao(null);
          void salvar(true);
        }}
        onCancelar={() => setVencerao(null)}
      />
    </div>
  );
}
''',
    'src/modules/cadastrosPendentes/services/prazo.ts': r'''/**
 * SysMúsica — Serviço do prazo dos Cadastros Pendentes. Tudo passa por funções do banco (migração 0045),
 * que conferem a permissão: ler a configuração exige cadastros.visualizar; ver a prévia e salvar exigem
 * cadastros.configurar. O navegador nunca lê nem grava a tabela de configuração diretamente.
 */
import { supabase } from "@/lib/supabase";
import { mensagemDoErro } from "@/lib/erros";

export interface ConfigPrazo {
  prazo_dias: number;
  minimo: number;
  maximo: number;
  padrao: number;
}

export interface ResultadoSalvarPrazo {
  prazo_dias: number;
  atualizados: number; // pedidos pendentes que passaram a seguir o novo prazo
  vencerao_agora: number; // pedidos pendentes que já passaram do novo prazo (vencem na próxima limpeza)
}

export async function obterConfigPrazo(): Promise<ConfigPrazo> {
  const { data, error } = await supabase.rpc("obter_config_cadastros");
  if (error) throw new Error(mensagemDoErro(error, "Não foi possível carregar o prazo."));
  if (!data) throw new Error("Não foi possível carregar o prazo.");
  const c = data as Partial<ConfigPrazo>;
  return {
    prazo_dias: Number(c.prazo_dias ?? 60),
    minimo: Number(c.minimo ?? 7),
    maximo: Number(c.maximo ?? 365),
    padrao: Number(c.padrao ?? 60),
  };
}

/** Quantos pedidos pendentes já passaram do prazo informado (só consulta, não altera nada). */
export async function previaPrazo(dias: number): Promise<number> {
  const { data, error } = await supabase.rpc("previa_prazo_cadastros", { p_dias: dias });
  if (error) throw new Error(mensagemDoErro(error, "Não foi possível conferir o novo prazo."));
  return Number(data ?? 0);
}

export async function salvarPrazo(dias: number): Promise<ResultadoSalvarPrazo> {
  const { data, error } = await supabase.rpc("salvar_config_cadastros", { p_dias: dias });
  if (error) throw new Error(mensagemDoErro(error, "Não foi possível salvar o prazo."));
  if (!data) throw new Error("Não foi possível salvar o prazo.");
  const r = data as Partial<ResultadoSalvarPrazo>;
  return {
    prazo_dias: Number(r.prazo_dias ?? dias),
    atualizados: Number(r.atualizados ?? 0),
    vencerao_agora: Number(r.vencerao_agora ?? 0),
  };
}
''',
    'supabase/migrations/0045_prazo_cadastros_pendentes.sql': r'''-- =============================================================================
-- SysMúsica — Migração 0045: prazo dos Cadastros Pendentes configurável
--
--  Hoje todo pedido do formulário público (/cadastro) vence 60 dias depois de enviado. Esta migração deixa
--  o Administrador mudar esse prazo na tela Cadastros Pendentes (botão com ícone de engrenagem).
--  O que faz:
--   A) Tabela cadastro_publico_config (uma única linha): prazo_dias, de 7 a 365 (padrão 60).
--   B) prazo_cadastro_dias(): lê o prazo; o valor padrão de expira_em dos novos pedidos passa a usá-la.
--   C) Permissão nova "cadastros.configurar" (só o Administrador recebe).
--   D) obter_config_cadastros(), previa_prazo_cadastros(dias) e salvar_config_cadastros(dias).
--  Regras ao salvar:
--   * O novo prazo vale para os pedidos NOVOS e para todos os que já estão PENDENTES (contado a partir do
--     envio de cada um). Pedidos já vencidos, aprovados ou recusados não mudam.
--   * Se o prazo diminuir e algum pedido pendente já passou dele, esse pedido vence na próxima limpeza diária
--     (e os dados dele são apagados). A tela mostra quantos são ANTES de confirmar (previa_prazo_cadastros).
--   * Tudo é registrado na Auditoria.
-- Rode UMA vez no SQL Editor do Supabase, ANTES do git push. Se der erro, rode:  rollback;
-- =============================================================================
begin;
set local check_function_bodies = off;

do $$
begin
  if to_regclass('public.cadastros_pendentes') is null
     or to_regprocedure('public.listar_cartoes(integer)') is null
     or to_regprocedure('public.exigir_permissao(text)') is null
     or to_regprocedure('public.registrar_auditoria(text, text, uuid, jsonb)') is null then
    raise exception 'Aplique primeiro as migrações até a 0044. Nada foi alterado.';
  end if;
  if to_regclass('public.cadastro_publico_config') is not null then
    raise exception 'A migração 0045 já foi aplicada. Nada foi alterado.';
  end if;
end $$;

-- A) Configuração (uma linha só; ninguém acessa a tabela direto, só as funções abaixo)
create table public.cadastro_publico_config (
  id            boolean primary key default true check (id),
  prazo_dias    integer not null default 60 check (prazo_dias between 7 and 365),
  atualizado_em timestamptz not null default now(),
  atualizado_por uuid
);
alter table public.cadastro_publico_config enable row level security;
revoke all on public.cadastro_publico_config from public, anon, authenticated;
insert into public.cadastro_publico_config (id, prazo_dias) values (true, 60);

-- B) Prazo atual (60 se a linha não existir). Usada como padrão do vencimento dos pedidos novos.
create or replace function public.prazo_cadastro_dias()
returns integer
language sql stable security definer set search_path to 'public'
as $$ select coalesce((select prazo_dias from public.cadastro_publico_config where id), 60) $$;

alter table public.cadastros_pendentes
  alter column expira_em set default (now() + make_interval(days => public.prazo_cadastro_dias()));

-- C) Permissão (igual a CATALOGO_PERMISSOES em src/lib/permissoes.ts). Só o Administrador recebe.
insert into public.permissoes (codigo, modulo, acao, descricao) values
  ('cadastros.configurar', 'Cadastros pendentes', 'Configurar', 'Alterar o prazo de validade dos pedidos do cadastro público')
on conflict (codigo) do update
  set modulo = excluded.modulo, acao = excluded.acao, descricao = excluded.descricao;

insert into public.grupo_permissoes (grupo_id, permissao_codigo)
select g.id, p.codigo
  from public.grupos g
  cross join public.permissoes p
 where g.sistema and g.nome = 'Administrador'
   and p.codigo = 'cadastros.configurar'
on conflict do nothing;

-- D) Funções do painel
create or replace function public.obter_config_cadastros()
returns jsonb
language plpgsql stable security definer set search_path to 'public'
as $$
begin
  perform public.exigir_permissao('cadastros.visualizar');
  return jsonb_build_object('prazo_dias', public.prazo_cadastro_dias(), 'minimo', 7, 'maximo', 365, 'padrao', 60);
end;
$$;

-- Quantos pedidos PENDENTES já passaram deste prazo (venceriam na próxima limpeza). Só leitura.
create or replace function public.previa_prazo_cadastros(p_dias integer)
returns integer
language plpgsql stable security definer set search_path to 'public'
as $$
declare v_qtd integer;
begin
  perform public.exigir_permissao('cadastros.configurar');
  if p_dias is null or p_dias < 7 or p_dias > 365 then
    raise exception 'O prazo deve ficar entre 7 e 365 dias.' using errcode = '22023';
  end if;
  select count(*) into v_qtd from public.cadastros_pendentes c
   where c.status = 'PENDENTE' and c.criado_em + make_interval(days => p_dias) < now();
  return v_qtd;
end;
$$;

create or replace function public.salvar_config_cadastros(p_dias integer)
returns jsonb
language plpgsql security definer set search_path to 'public'
as $$
declare
  v_antes   integer := public.prazo_cadastro_dias();
  v_atualiz integer;
  v_vencem  integer;
begin
  perform public.exigir_permissao('cadastros.configurar');
  if p_dias is null or p_dias < 7 or p_dias > 365 then
    raise exception 'O prazo deve ficar entre 7 e 365 dias.' using errcode = '22023';
  end if;

  insert into public.cadastro_publico_config (id, prazo_dias, atualizado_em, atualizado_por)
  values (true, p_dias, now(), (select auth.uid()))
  on conflict (id) do update
    set prazo_dias = excluded.prazo_dias, atualizado_em = now(), atualizado_por = excluded.atualizado_por;

  -- Os pedidos que já estão na fila passam a seguir o novo prazo (contado do envio de cada um)
  update public.cadastros_pendentes
     set expira_em = criado_em + make_interval(days => p_dias)
   where status = 'PENDENTE';
  get diagnostics v_atualiz = row_count;

  select count(*) into v_vencem from public.cadastros_pendentes
   where status = 'PENDENTE' and expira_em < now();

  perform public.registrar_auditoria('cadastro_prazo_alterado', 'cadastro_config', null,
            jsonb_build_object('prazo_antes', v_antes, 'prazo_depois', p_dias,
                               'pedidos_atualizados', v_atualiz, 'vencem_na_proxima_limpeza', v_vencem));
  return jsonb_build_object('prazo_dias', p_dias, 'atualizados', v_atualiz, 'vencerao_agora', v_vencem);
end;
$$;

revoke all on function public.prazo_cadastro_dias() from public, anon, authenticated;
revoke all on function public.obter_config_cadastros() from public, anon, authenticated;
revoke all on function public.previa_prazo_cadastros(integer) from public, anon, authenticated;
revoke all on function public.salvar_config_cadastros(integer) from public, anon, authenticated;
grant execute on function public.obter_config_cadastros() to authenticated;
grant execute on function public.previa_prazo_cadastros(integer) to authenticated;
grant execute on function public.salvar_config_cadastros(integer) to authenticated;

do $$
begin
  if has_function_privilege('anon', 'public.salvar_config_cadastros(integer)', 'execute')
     or has_function_privilege('anon', 'public.obter_config_cadastros()', 'execute')
     or has_function_privilege('anon', 'public.previa_prazo_cadastros(integer)', 'execute') then
    raise exception 'Permissões inesperadas para o papel anon. Nada foi alterado.';
  end if;
  if public.prazo_cadastro_dias() <> 60 then
    raise exception 'O prazo inicial deveria ser 60 dias. Nada foi alterado.';
  end if;
end $$;

commit;
select set_config('sysmusica.migracao_0045', 'ok', false);
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
  if "$@" > /tmp/prazocad-passo.out 2>&1; then
    echo "  ok"
  else
    echo "  FALHOU: $nome"; tail -40 /tmp/prazocad-passo.out
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
echo "Pronto. PRÓXIMO PASSO: rode o SQL supabase/migrations/0045_prazo_cadastros_pendentes.sql no Supabase (SQL Editor) e só então o git push."
echo "Depois confira as telas (passo a passo na conversa) e, se estiver tudo certo, faça o git push."
) 2>&1 | tee "$LOG"
