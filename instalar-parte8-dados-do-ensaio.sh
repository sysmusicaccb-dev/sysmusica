#!/usr/bin/env bash
# =============================================================================
# SysMúsica — PARTE 8: Tipo do Evento, Hinos e Dados do Ensaio
#
#  ATENÇÃO: rode ANTES o SQL supabase/migrations/0041_dados_do_ensaio_hinos.sql no Supabase (SQL Editor).
#  Este instalador cria as telas (Tipo do Evento, Hinos, Dados do Ensaio), troca o campo de tipo do formulário de
#  Eventos por uma lista e coloca a migração na pasta supabase/migrations (para o histórico do projeto).
#
# Segurança: confere cada trecho (exatamente 1 vez), faz backup em /tmp/bkp-parte8-*, aplica,
# roda tsc, vitest, eslint e build; se algo falhar, DESFAZ tudo sozinho (inclusive os arquivos novos).
#
# Uso:  cd /workspaces/sysmusica/sysmusica && rm -rf .next && bash instalar-parte8-dados-do-ensaio.sh
# Log:  /tmp/instalar-parte8.log
# =============================================================================

LOG=/tmp/instalar-parte8.log
BKP=/tmp/bkp-parte8-$(date +%Y%m%d-%H%M%S)
RAIZ="$(pwd)"

(
[ -f package.json ] && [ -d src ] || { echo "ERRO: rode dentro da pasta sysmusica (onde está o package.json)."; exit 1; }
mkdir -p "$BKP"
export BKP RAIZ

echo "== 1/3  Conferindo e aplicando as alterações =="
# (se o SQL 0041 ainda não foi rodado no Supabase, as telas novas darão erro até rodar)
python3 - <<'PYSCRIPT'
import os, shutil, sys, hashlib

RAIZ = os.environ["RAIZ"]
BKP = os.environ["BKP"]

# (arquivo, trecho antigo, trecho novo) — cada "antigo" precisa existir EXATAMENTE 1 vez no arquivo.
# Os trechos usam \n; o instalador converte para o fim de linha do próprio arquivo (CRLF ou LF).
EDITS = [
    ("src/types/database.ts",
     r'''  tipo: string; // ex: "Ensaio", "Culto"
''',
     r'''  tipo: string; // ex: "Ensaio", "Culto" (nome do tipo; o banco o mantém igual ao nome do tipo escolhido)
  tipo_evento_id?: string | null; // FK -> tipos_evento.id (nula em eventos antigos até alguém editar o evento)
'''),
    ("src/lib/permissoes.ts",
     r'''  { codigo: "grupos.excluir", modulo: "Grupos e permissões", acao: "Excluir" },
] as const;''',
     r'''  { codigo: "grupos.excluir", modulo: "Grupos e permissões", acao: "Excluir" },
  { codigo: "tipoevento.visualizar", modulo: "Tipos de evento", acao: "Visualizar" },
  { codigo: "tipoevento.criar", modulo: "Tipos de evento", acao: "Criar" },
  { codigo: "tipoevento.editar", modulo: "Tipos de evento", acao: "Editar" },
  { codigo: "tipoevento.excluir", modulo: "Tipos de evento", acao: "Excluir" },
  { codigo: "hinos.visualizar", modulo: "Hinos", acao: "Visualizar" },
  { codigo: "hinos.criar", modulo: "Hinos", acao: "Criar" },
  { codigo: "hinos.editar", modulo: "Hinos", acao: "Editar" },
  { codigo: "hinos.excluir", modulo: "Hinos", acao: "Excluir" },
  { codigo: "ensaio.visualizar", modulo: "Dados do Ensaio", acao: "Visualizar" },
  { codigo: "ensaio.registrar", modulo: "Dados do Ensaio", acao: "Preencher" },
] as const;'''),
    ("src/components/layout/navegacao.ts",
     r'''  ClipboardList,
  DoorOpen,
''',
     r'''  ClipboardCheck,
  ClipboardList,
  DoorOpen,
'''),
    ("src/components/layout/navegacao.ts",
     r'''  LayoutDashboard,
  ShieldCheck,
''',
     r'''  LayoutDashboard,
  Music2,
  ShieldCheck,
  Tag,
'''),
    ("src/components/layout/navegacao.ts",
     r'''        permissao: "instrumentos.visualizar",
      },
    ],
  },''',
     r'''        permissao: "instrumentos.visualizar",
      },
      { href: "/tipos-evento", rotulo: "Tipo do Evento", icone: Tag, permissao: "tipoevento.visualizar" },
      { href: "/hinos", rotulo: "Hinos", icone: Music2, permissao: "hinos.visualizar" },
    ],
  },'''),
    ("src/components/layout/navegacao.ts",
     r'''      { href: "/painel-ao-vivo", rotulo: "Painel ao vivo",''',
     r'''      {
        href: "/ensaio",
        rotulo: "Dados do Ensaio",
        icone: ClipboardCheck,
        permissao: "ensaio.visualizar",
        qualquer: ["ensaio.registrar"], // quem só preenche (sem ver) também acessa
      },
      { href: "/painel-ao-vivo", rotulo: "Painel ao vivo",'''),
    ("src/modules/backup/tabelas.ts",
     r'''  | "instrumentos"
  | "grupos"''',
     r'''  | "instrumentos"
  | "tipos_evento"
  | "hinos"
  | "grupos"'''),
    ("src/modules/backup/tabelas.ts",
     r'''  | "eventos"
  | "portarias"
  | "portarias_historico"''',
     r'''  | "eventos"
  | "dados_ensaio"
  | "dados_ensaio_encarregados"
  | "dados_ensaio_hinos"
  | "portarias"
  | "portarias_historico"'''),
    ("src/modules/backup/tabelas.ts",
     r'''  tabela("grupos", "Grupos de acesso", "grupos"),''',
     r'''  tabela("tipos_evento", "Tipos de evento", "cadastros"),
  tabela("hinos", "Hinos e coros", "cadastros"),
  tabela("grupos", "Grupos de acesso", "grupos"),'''),
    ("src/modules/backup/tabelas.ts",
     r'''      { coluna: "finalidade_id", tabela: "finalidades_evento" },
      { coluna: "casa_oracao_id", tabela: "casas_oracao" },
    ],
  }),
  tabela("portarias"''',
     r'''      { coluna: "finalidade_id", tabela: "finalidades_evento" },
      { coluna: "casa_oracao_id", tabela: "casas_oracao" },
      { coluna: "tipo_evento_id", tabela: "tipos_evento" },
    ],
  }),
  // Dados do Ensaio: um registro por evento, com os encarregados e os hinos executados (filhos)
  tabela("dados_ensaio", "Dados do ensaio", "eventos", {
    referencias: [
      { coluna: "evento_id", tabela: "eventos" },
      { coluna: "hino_abertura_id", tabela: "hinos" },
    ],
  }),
  tabela("dados_ensaio_encarregados", "Encarregados do ensaio", "eventos", {
    referencias: [{ coluna: "dados_ensaio_id", tabela: "dados_ensaio" }],
  }),
  tabela("dados_ensaio_hinos", "Hinos executados no ensaio", "eventos", {
    referencias: [
      { coluna: "dados_ensaio_id", tabela: "dados_ensaio" },
      { coluna: "hino_id", tabela: "hinos" },
    ],
  }),
  tabela("portarias"'''),
    ("src/modules/backup/tabelas.ts",
     r'''    descricao: "Cargos, famílias, instrumentos e finalidades de evento",
    tabelas: ["familias", "cargos", "finalidades_evento", "instrumentos"],''',
     r'''    descricao: "Cargos, famílias, instrumentos, finalidades e tipos de evento e hinos",
    tabelas: ["familias", "cargos", "finalidades_evento", "instrumentos", "tipos_evento", "hinos"],'''),
    ("src/modules/backup/tabelas.ts",
     r'''    descricao: "Eventos cadastrados",
    tabelas: ["eventos"],''',
     r'''    descricao: "Eventos cadastrados e os dados dos ensaios",
    tabelas: ["eventos", "dados_ensaio", "dados_ensaio_encarregados", "dados_ensaio_hinos"],'''),
    ("src/modules/auditoria/regras.ts",
     r'''  entrada_avulsa_desfeita: "Desfez entrada sem cadastro",
};''',
     r'''  entrada_avulsa_desfeita: "Desfez entrada sem cadastro",
  ensaio_registrado: "Registrou os dados do ensaio",
  ensaio_alterado: "Alterou os dados do ensaio",
  hinos_importados: "Importou lista de hinos",
};'''),
    ("src/modules/auditoria/regras.ts",
     r'''  backup: "Backup",
};''',
     r'''  backup: "Backup",
  tipos_evento: "Tipo de evento",
  hinos: "Hino",
  ensaio: "Dados do ensaio",
};'''),
    ("src/modules/auditoria/regras.ts",
     r'''  sem_cadastro: "Sem cadastro",
};''',
     r'''  sem_cadastro: "Sem cadastro",
  tipo_evento_id: "Tipo do evento",
  modelo_ensaio: "Dados do Ensaio",
  ordem: "Ordem",
  categoria: "Categoria",
  numero: "Número",
  atende: "Quem atende",
  palavra: "Palavra",
  hino_abertura: "Hino de abertura",
  encarregados: "Encarregados",
  hinos: "Hinos executados",
};'''),
    ("src/modules/eventos/camposEvento.ts",
     r'''  tipo: string; // "Descrição do evento" na tela''',
     r'''  tipo: string; // nome do tipo escolhido (lista "Tipo do evento" na tela)'''),
    ("src/modules/eventos/camposEvento.ts",
     r'''export const ROTULO_TIPO = "Descrição do evento";''',
     r'''export const ROTULO_TIPO = "Tipo do evento";'''),
    ("src/modules/eventos/camposEvento.ts",
     r'''  // Ordem do formulário: Descrição do evento, Data e hora, Casa de Oração, Cidade''',
     r'''  // Ordem do formulário: Tipo do evento, Data e hora, Casa de Oração, Cidade'''),
    ("src/modules/eventos/camposEvento.test.ts",
     r'''      "Descrição do evento",
      "Data e hora",''',
     r'''      "Tipo do evento",
      "Data e hora",'''),
    ("src/modules/eventos/camposEvento.test.ts",
     r'''toEqual(["Descrição do evento", "Cidade"])''',
     r'''toEqual(["Tipo do evento", "Cidade"])'''),
    ("src/components/FormularioEvento.tsx",
     r''' * Campos: Descrição do evento, Data e hora, Casa de Oração e Cidade.
''',
     r''' * Campos: Tipo do evento (lista do cadastro Tipo do Evento), Data e hora, Casa de Oração e Cidade.
 *  - O tipo vem da lista cadastrada em "Tipo do Evento"; o banco grava o nome do tipo em eventos.tipo.
 *    Eventos antigos sem tipo escolhido pedem para escolher um ao serem editados.
'''),
    ("src/components/FormularioEvento.tsx",
     r'''import { useRef, useState, type FormEvent } from "react";''',
     r'''import { useEffect, useRef, useState, type FormEvent } from "react";'''),
    ("src/components/FormularioEvento.tsx",
     r'''import { atualizarEvento, criarEvento } from "@/modules/eventos/services/eventos";
''',
     r'''import { atualizarEvento, criarEvento } from "@/modules/eventos/services/eventos";
import { tiposParaEscolher, type TipoEvento } from "@/modules/tiposEvento/regras";
import { listarTiposEvento } from "@/modules/tiposEvento/services/tiposEvento";
'''),
    ("src/components/FormularioEvento.tsx",
     r'''  const [tipo, setTipo] = useState(evento?.tipo ?? "");
''',
     r'''  // Tipo do evento: escolhido na lista cadastrada (eventos antigos podem não ter tipo ligado ainda)
  const [tipoEventoId, setTipoEventoId] = useState(evento?.tipo_evento_id ?? "");
  const [tipos, setTipos] = useState<TipoEvento[]>([]);
  const [erroTipos, setErroTipos] = useState<string | null>(null);
  const tipoEscolhido = tipos.find((item) => item.id === tipoEventoId);

  // Carrega a lista de tipos ao abrir o formulário (os inativos só aparecem se já forem o tipo deste evento)
  useEffect(() => {
    let ativo = true;
    listarTiposEvento()
      .then((lista) => {
        if (ativo) setTipos(lista);
      })
      .catch(() => {
        if (ativo) setErroTipos("Não foi possível carregar os tipos de evento. Feche e abra o formulário novamente.");
      });
    return () => {
      ativo = false;
    };
  }, []);
'''),
    ("src/components/FormularioEvento.tsx",
     r'''    const vazios = camposFaltando({ tipo, dataEvento, cidade, casaOracaoId });''',
     r'''    const vazios = camposFaltando({ tipo: tipoEscolhido?.nome ?? "", dataEvento, cidade, casaOracaoId });'''),
    ("src/components/FormularioEvento.tsx",
     r'''        tipo: tipo.trim(),
''',
     r'''        tipo: tipoEscolhido?.nome ?? "", // o banco mantém eventos.tipo igual ao nome do tipo escolhido
        tipo_evento_id: tipoEventoId,
'''),
    ("src/components/FormularioEvento.tsx",
     r'''          Descrição do evento <span className="text-red-600"> *</span>
        </label>
        {/* Campo livre com sugestões (datalist): aceita Ensaio, Culto ou qualquer outro tipo */}
        <input
          id="tipo"
          type="text"
          list="sugestoes-tipo-evento"
          required
          value={tipo}
          onChange={(e) => setTipo(e.target.value)}
          disabled={salvando}
          placeholder="Ex: Ensaio Regional, Culto Oficial"
          className={classeCampo(ROTULO_TIPO)}
        />
        <datalist id="sugestoes-tipo-evento">
          <option value="Ensaio" />
          <option value="Culto" />
        </datalist>
      </div>''',
     r'''          Tipo do evento <span className="text-red-600"> *</span>
        </label>
        {/* Lista dos tipos cadastrados em "Tipo do Evento" (só os ativos, mais o tipo atual do evento) */}
        <select
          id="tipo"
          required
          value={tipoEventoId}
          onChange={(e) => setTipoEventoId(e.target.value)}
          disabled={salvando}
          className={classeCampo(ROTULO_TIPO)}
        >
          <option value="">Selecione o tipo...</option>
          {tiposParaEscolher(tipos, tipoEventoId || null).map((item) => (
            <option key={item.id} value={item.id}>
              {item.nome}
            </option>
          ))}
        </select>
        {evento && !evento.tipo_evento_id && (
          <p role="status" className="text-xs text-amber-700">
            Tipo antigo: “{evento.tipo}”. Escolha o tipo na lista para ligar este evento ao cadastro.
          </p>
        )}
        {erroTipos && (
          <p role="alert" className="text-xs text-red-700">
            {erroTipos}
          </p>
        )}
      </div>'''),
]


# Arquivos NOVOS (o instalador recusa se algum já existir)
NOVOS = {
    "src/app/(painel)/ensaio/layout.tsx": r'''import type { ReactNode } from "react";
import RequerPermissao from "@/modules/autenticacao/components/RequerPermissao";

/** Entra quem pode ver os Dados do Ensaio ou quem pode preenchê-los. */
export default function EnsaioLayout({ children }: { children: ReactNode }) {
  return (
    <RequerPermissao permissao="ensaio.visualizar" ou={["ensaio.registrar"]}>
      {children}
    </RequerPermissao>
  );
}
''',
    "src/app/(painel)/ensaio/page.tsx": r'''"use client";

/**
 * SysMúsica — Página /ensaio: Dados do Ensaio (Local ou Regional).
 * Escolha o ensaio na lista; o formulário aparece abaixo. Quem tem "Painel ao vivo" também vê os totais do evento.
 * Quem preenche (ensaio.registrar) edita de 2 h antes até 3 h depois do início; depois disso só o Administrador.
 */
import { useCallback, useEffect, useState } from "react";
import { formatarDiaDoEvento, formatarHoraDoEvento } from "@/modules/painel/regras";
import { buscarPainel } from "@/modules/painel/services/painel";
import type { DadosPainel } from "@/modules/painel/tipos";
import ResumoTempoReal from "@/modules/painel/components/ResumoTempoReal";
import { listarHinos } from "@/modules/hinos/services/hinos";
import type { Hino } from "@/modules/hinos/regras";
import FormularioEnsaio from "@/modules/ensaio/components/FormularioEnsaio";
import { carregarCidades } from "@/modules/ensaio/services/cidades";
import { listarEventosParaEnsaio, obterDadosEnsaio } from "@/modules/ensaio/services/ensaio";
import type { Cidade } from "@/modules/ensaio/cidades";
import type { EventoParaEnsaio, RespostaEnsaio } from "@/modules/ensaio/tipos";
import { useSessao } from "@/modules/autenticacao/SessaoProvider";
import EmptyState from "@/components/ui/EmptyState";
import ErrorState from "@/components/ui/ErrorState";
import Notificacao from "@/components/ui/Notificacao";
import PageHeader from "@/components/ui/PageHeader";
import Skeleton from "@/components/ui/Skeleton";

export default function EnsaioPage() {
  const { pode } = useSessao();
  const [eventos, setEventos] = useState<EventoParaEnsaio[]>([]);
  const [hinos, setHinos] = useState<Hino[]>([]);
  const [cidades, setCidades] = useState<Cidade[]>([]);
  const [carregando, setCarregando] = useState(true);
  const [erro, setErro] = useState<string | null>(null);

  const [eventoId, setEventoId] = useState("");
  const [resposta, setResposta] = useState<RespostaEnsaio | null>(null);
  const [totais, setTotais] = useState<DadosPainel | null>(null);
  const [carregandoEvento, setCarregandoEvento] = useState(false);
  const [erroEvento, setErroEvento] = useState<string | null>(null);
  const [versao, setVersao] = useState(0); // muda a cada gravação para recriar o formulário com os dados novos
  const [aviso, setAviso] = useState<string | null>(null);

  const verTotais = pode("painel.visualizar");

  // Lista de ensaios + hinos (as cidades do IBGE carregam em segundo plano: nunca travam a tela)
  const carregar = useCallback(async () => {
    try {
      const [lista, todosHinos] = await Promise.all([listarEventosParaEnsaio(), listarHinos()]);
      setEventos(lista);
      setHinos(todosHinos);
      setErro(null);
    } catch (e) {
      console.error("Falha ao carregar os ensaios:", e);
      setErro("Não foi possível carregar os ensaios. Verifique a conexão e tente novamente.");
    } finally {
      setCarregando(false);
    }
  }, []);

  useEffect(() => {
    // O setState só roda DEPOIS do await, então o aviso da regra set-state-in-effect não se aplica aqui.
    // eslint-disable-next-line react-hooks/set-state-in-effect
    void carregar();
    void carregarCidades().then(setCidades);
  }, [carregar]);

  // Carrega os dados do ensaio escolhido (e os totais, se a pessoa pode ver o painel)
  const carregarEvento = useCallback(
    async (id: string) => {
      setCarregandoEvento(true);
      setErroEvento(null);
      try {
        const [dados, painel] = await Promise.all([
          obterDadosEnsaio(id),
          verTotais ? buscarPainel(id).catch(() => null) : Promise.resolve(null),
        ]);
        setResposta(dados);
        setTotais(painel);
        setVersao((v) => v + 1);
      } catch (e) {
        setResposta(null);
        setErroEvento(e instanceof Error ? e.message : "Não foi possível carregar os dados do ensaio.");
      } finally {
        setCarregandoEvento(false);
      }
    },
    [verTotais]
  );

  function escolher(id: string) {
    setEventoId(id);
    setResposta(null);
    setTotais(null);
    if (id) void carregarEvento(id);
  }

  async function aoSalvar(mensagem: string) {
    await Promise.all([carregarEvento(eventoId), carregar()]);
    setAviso(mensagem);
  }

  return (
    <main className="text-slate-900">
      <div className="mx-auto max-w-7xl px-4 py-8 sm:px-6 lg:px-8">
        <PageHeader
          titulo="Dados do Ensaio"
          descricao="Registre quem atendeu, os encarregados, o hino de abertura e os hinos executados."
        />

        {carregando ? (
          <div role="status" aria-live="polite" className="space-y-3">
            <span className="sr-only">Carregando ensaios...</span>
            <Skeleton className="h-12 rounded-xl" />
            <Skeleton className="h-64 rounded-2xl" />
          </div>
        ) : erro ? (
          <ErrorState
            titulo="Não foi possível carregar os ensaios."
            mensagem={erro}
            onTentarNovamente={() => {
              setCarregando(true);
              void carregar();
            }}
          />
        ) : eventos.length === 0 ? (
          <EmptyState
            titulo="Nenhum ensaio recente ou próximo."
            descricao="Só aparecem eventos cujo tipo usa Dados do Ensaio (Ensaio Local ou Regional), de 30 dias atrás até 2 dias à frente. Confira o tipo do evento em Eventos."
          />
        ) : (
          <div className="space-y-6">
            <div className="max-w-xl space-y-1.5">
              <label htmlFor="ensaio-evento" className="text-sm font-medium text-slate-700">
                Ensaio
              </label>
              <select
                id="ensaio-evento"
                value={eventoId}
                onChange={(e) => escolher(e.target.value)}
                className="w-full rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 shadow-sm focus:border-brand-500 focus:outline-none focus:ring-2 focus:ring-brand-200"
              >
                <option value="">Selecione o ensaio...</option>
                {eventos.map((ev) => (
                  <option key={ev.id} value={ev.id}>
                    {formatarDiaDoEvento(ev.data_evento)} {formatarHoraDoEvento(ev.data_evento)} — {ev.tipo}
                    {ev.casa_oracao_nome ? ` — ${ev.casa_oracao_nome}` : ev.cidade ? ` — ${ev.cidade}` : ""}
                    {ev.preenchido ? " ✓" : ""}
                  </option>
                ))}
              </select>
              <p className="text-xs text-slate-500">✓ = dados já registrados.</p>
            </div>

            {carregandoEvento && (
              <div role="status" aria-live="polite" className="space-y-3">
                <span className="sr-only">Carregando dados do ensaio...</span>
                <Skeleton className="h-64 rounded-2xl" />
              </div>
            )}
            {erroEvento && !carregandoEvento && (
              <ErrorState titulo="Não foi possível abrir este ensaio." mensagem={erroEvento} onTentarNovamente={() => void carregarEvento(eventoId)} />
            )}
            {resposta && !carregandoEvento && (
              <FormularioEnsaio
                key={`${resposta.evento.id}-${versao}`}
                resposta={resposta}
                hinos={hinos}
                cidades={cidades}
                temPermissaoPreencher={pode("ensaio.registrar")}
                lateral={totais ? <ResumoTempoReal dados={totais} /> : undefined}
                onSalvo={aoSalvar}
              />
            )}
          </div>
        )}
      </div>

      <Notificacao mensagem={aviso} onFechar={() => setAviso(null)} />
    </main>
  );
}
''',
    "src/app/(painel)/hinos/layout.tsx": r'''import type { ReactNode } from "react";
import RequerPermissao from "@/modules/autenticacao/components/RequerPermissao";

/** Protege todas as telas deste módulo: só entra quem tem a permissão de visualizar. */
export default function HinosLayout({ children }: { children: ReactNode }) {
  return <RequerPermissao permissao="hinos.visualizar">{children}</RequerPermissao>;
}
''',
    "src/app/(painel)/hinos/page.tsx": r'''"use client";

/**
 * SysMúsica — Página /hinos: lista de hinos do hinário e coros (corinhos), usada nos Dados do Ensaio.
 * Permite adicionar, editar, ativar/desativar, excluir (só se nunca foi usado) e importar uma lista colada.
 */
import { useCallback, useEffect, useState } from "react";
import { FileUp, Plus } from "lucide-react";
import { excluirHino, listarHinos, salvarHino } from "@/modules/hinos/services/hinos";
import FormularioHino from "@/modules/hinos/components/FormularioHino";
import ImportarHinos from "@/modules/hinos/components/ImportarHinos";
import TabelaHinos from "@/modules/hinos/components/TabelaHinos";
import { rotuloHino, type Hino } from "@/modules/hinos/regras";
import { useSessao } from "@/modules/autenticacao/SessaoProvider";
import Button from "@/components/ui/Button";
import ConfirmDialog from "@/components/ui/ConfirmDialog";
import Drawer from "@/components/ui/Drawer";
import EmptyState from "@/components/ui/EmptyState";
import ErrorState from "@/components/ui/ErrorState";
import Notificacao from "@/components/ui/Notificacao";
import PageHeader from "@/components/ui/PageHeader";
import Skeleton from "@/components/ui/Skeleton";

type Painel = { tipo: "novo" } | { tipo: "editar"; item: Hino } | { tipo: "importar" };

export default function HinosPage() {
  const { pode } = useSessao();
  const [hinos, setHinos] = useState<Hino[]>([]);
  const [carregando, setCarregando] = useState(true);
  const [erro, setErro] = useState<string | null>(null);
  const [painel, setPainel] = useState<Painel | null>(null);
  const [alvoExclusao, setAlvoExclusao] = useState<Hino | null>(null);
  const [excluindo, setExcluindo] = useState(false);
  const [erroExclusao, setErroExclusao] = useState<string | null>(null);
  const [alternandoId, setAlternandoId] = useState<string | null>(null);
  const [aviso, setAviso] = useState<string | null>(null);

  const carregar = useCallback(async () => {
    try {
      setHinos(await listarHinos());
      setErro(null);
    } catch (e) {
      console.error("Falha ao carregar hinos:", e);
      setErro("Não foi possível carregar os hinos. Verifique a conexão e tente novamente.");
    } finally {
      setCarregando(false);
    }
  }, []);

  useEffect(() => {
    // O setState só roda DEPOIS do await, então o aviso da regra set-state-in-effect não se aplica aqui.
    // eslint-disable-next-line react-hooks/set-state-in-effect
    void carregar();
  }, [carregar]);

  function tentarNovamente() {
    setCarregando(true);
    void carregar();
  }

  async function aoSalvar(mensagem: string) {
    await carregar();
    setPainel(null);
    setAviso(mensagem);
  }

  async function alternar(hino: Hino) {
    setAlternandoId(hino.id);
    try {
      await salvarHino(hino.id, { categoria: hino.categoria, numero: hino.numero, nome: hino.nome, ativo: !hino.ativo });
      await carregar();
      setAviso(`${rotuloHino(hino.categoria, hino.numero)} ${hino.ativo ? "desativado" : "ativado"}.`);
    } catch (e) {
      setAviso(e instanceof Error ? e.message : "Não foi possível alterar o status.");
    } finally {
      setAlternandoId(null);
    }
  }

  async function confirmarExclusao() {
    if (!alvoExclusao) return;
    setExcluindo(true);
    setErroExclusao(null);
    try {
      await excluirHino(alvoExclusao.id);
      await carregar();
      setAviso(`${rotuloHino(alvoExclusao.categoria, alvoExclusao.numero)} excluído.`);
      setAlvoExclusao(null);
    } catch (e) {
      setErroExclusao(e instanceof Error ? e.message : "Não foi possível excluir o hino.");
    } finally {
      setExcluindo(false);
    }
  }

  const podeCriar = pode("hinos.criar");

  return (
    <main className="text-slate-900">
      <div className="mx-auto max-w-7xl px-4 py-8 sm:px-6 lg:px-8">
        <PageHeader
          titulo="Hinos"
          descricao={`Hinário e coros usados nos Dados do Ensaio.${!carregando && !erro ? ` ${hinos.length} cadastrado(s).` : ""}`}
          acoes={
            podeCriar ? (
              <div className="flex flex-wrap gap-2">
                {/* Botão simples (não usamos uma variante do Button que pode não existir no projeto) */}
                <button
                  type="button"
                  onClick={() => setPainel({ tipo: "importar" })}
                  disabled={carregando || !!erro}
                  className="inline-flex items-center gap-2 rounded-lg border border-slate-300 bg-white px-4 py-2 text-sm font-medium text-slate-700 shadow-sm transition hover:bg-slate-50 disabled:cursor-not-allowed disabled:opacity-50"
                >
                  <FileUp className="h-4 w-4" aria-hidden="true" />
                  Importar lista
                </button>
                <Button icone={Plus} onClick={() => setPainel({ tipo: "novo" })} disabled={carregando || !!erro}>
                  Adicionar
                </Button>
              </div>
            ) : undefined
          }
        />

        {carregando ? (
          <div role="status" aria-live="polite" className="space-y-3">
            <span className="sr-only">Carregando hinos...</span>
            <Skeleton className="h-14 rounded-2xl" />
            {[0, 1, 2, 3].map((i) => (
              <Skeleton key={i} className="h-10" />
            ))}
          </div>
        ) : erro ? (
          <ErrorState titulo="Não foi possível carregar os hinos." mensagem={erro} onTentarNovamente={tentarNovamente} />
        ) : hinos.length === 0 ? (
          <EmptyState
            titulo="Nenhum hino cadastrado ainda."
            descricao={podeCriar ? "Use “Importar lista” para colar o hinário de uma vez, ou “Adicionar” para um por um." : undefined}
          />
        ) : (
          <TabelaHinos
            hinos={hinos}
            podeEditar={pode("hinos.editar")}
            podeExcluir={pode("hinos.excluir")}
            alternandoId={alternandoId}
            onEditar={(item) => setPainel({ tipo: "editar", item })}
            onExcluir={(item) => {
              setErroExclusao(null);
              setAlvoExclusao(item);
            }}
            onAlternar={(item) => void alternar(item)}
          />
        )}
      </div>

      <Drawer
        aberto={painel !== null}
        onFechar={() => setPainel(null)}
        titulo={painel?.tipo === "importar" ? "Importar lista de hinos" : painel?.tipo === "editar" ? "Editar hino" : "Novo hino"}
        descricao={
          painel?.tipo === "importar"
            ? "Só acrescenta: números que já existem são mantidos como estão."
            : "Hino do hinário aparece como “002”; coro aparece como “Coro 2”."
        }
      >
        {painel?.tipo === "importar" ? (
          <ImportarHinos existentes={hinos} onImportado={aoSalvar} />
        ) : painel ? (
          <FormularioHino
            hino={painel.tipo === "editar" ? painel.item : null}
            hinos={hinos}
            categoriaInicial="HINO"
            onSalvo={aoSalvar}
          />
        ) : null}
      </Drawer>

      <ConfirmDialog
        aberto={alvoExclusao !== null}
        titulo="Excluir hino?"
        mensagem={
          <>
            <p>
              <strong>{alvoExclusao && `${rotuloHino(alvoExclusao.categoria, alvoExclusao.numero)} – ${alvoExclusao.nome}`}</strong> será
              excluído. Esta ação não pode ser desfeita. Hinos já usados em ensaios não podem ser excluídos: desative-os.
            </p>
            {erroExclusao && (
              <p role="alert" className="mt-3 rounded-lg bg-red-50 px-3 py-2 text-red-700">
                {erroExclusao}
              </p>
            )}
          </>
        }
        textoConfirmar="Excluir"
        processando={excluindo}
        onConfirmar={() => void confirmarExclusao()}
        onCancelar={() => setAlvoExclusao(null)}
      />

      <Notificacao mensagem={aviso} onFechar={() => setAviso(null)} />
    </main>
  );
}
''',
    "src/app/(painel)/tipos-evento/layout.tsx": r'''import type { ReactNode } from "react";
import RequerPermissao from "@/modules/autenticacao/components/RequerPermissao";

/** Protege todas as telas deste módulo: só entra quem tem a permissão de visualizar. */
export default function TiposEventoLayout({ children }: { children: ReactNode }) {
  return <RequerPermissao permissao="tipoevento.visualizar">{children}</RequerPermissao>;
}
''',
    "src/app/(painel)/tipos-evento/page.tsx": r'''"use client";

/**
 * SysMúsica — Página /tipos-evento: cadastro dos tipos de evento (Ensaio Regional, Culto Oficial...).
 * Cada tipo diz se usa a tela Dados do Ensaio e em qual modelo. Os botões só aparecem para quem tem a
 * permissão; o banco confere de novo.
 */
import { useCallback, useEffect, useState } from "react";
import { Plus } from "lucide-react";
import { excluirTipoEvento, listarTiposEvento, salvarTipoEvento } from "@/modules/tiposEvento/services/tiposEvento";
import FormularioTipoEvento from "@/modules/tiposEvento/components/FormularioTipoEvento";
import TabelaTiposEvento from "@/modules/tiposEvento/components/TabelaTiposEvento";
import type { TipoEvento } from "@/modules/tiposEvento/regras";
import { useSessao } from "@/modules/autenticacao/SessaoProvider";
import Button from "@/components/ui/Button";
import ConfirmDialog from "@/components/ui/ConfirmDialog";
import Drawer from "@/components/ui/Drawer";
import EmptyState from "@/components/ui/EmptyState";
import ErrorState from "@/components/ui/ErrorState";
import Notificacao from "@/components/ui/Notificacao";
import PageHeader from "@/components/ui/PageHeader";
import Skeleton from "@/components/ui/Skeleton";

type Painel = { tipo: "novo" } | { tipo: "editar"; item: TipoEvento };

export default function TiposEventoPage() {
  const { pode } = useSessao();
  const [tipos, setTipos] = useState<TipoEvento[]>([]);
  const [carregando, setCarregando] = useState(true);
  const [erro, setErro] = useState<string | null>(null);
  const [painel, setPainel] = useState<Painel | null>(null);
  const [alvoExclusao, setAlvoExclusao] = useState<TipoEvento | null>(null);
  const [excluindo, setExcluindo] = useState(false);
  const [erroExclusao, setErroExclusao] = useState<string | null>(null);
  const [alternandoId, setAlternandoId] = useState<string | null>(null);
  const [aviso, setAviso] = useState<string | null>(null);

  const carregar = useCallback(async () => {
    try {
      setTipos(await listarTiposEvento());
      setErro(null);
    } catch (e) {
      console.error("Falha ao carregar tipos de evento:", e);
      setErro("Não foi possível carregar os tipos de evento. Verifique a conexão e tente novamente.");
    } finally {
      setCarregando(false);
    }
  }, []);

  useEffect(() => {
    // O setState só roda DEPOIS do await, então o aviso da regra set-state-in-effect não se aplica aqui.
    // eslint-disable-next-line react-hooks/set-state-in-effect
    void carregar();
  }, [carregar]);

  function tentarNovamente() {
    setCarregando(true);
    void carregar();
  }

  async function aoSalvar(mensagem: string) {
    await carregar();
    setPainel(null);
    setAviso(mensagem);
  }

  // Liga/desliga o tipo sem abrir o formulário (mantém os demais campos como estão)
  async function alternar(tipo: TipoEvento) {
    setAlternandoId(tipo.id);
    try {
      await salvarTipoEvento(tipo.id, {
        nome: tipo.nome,
        descricao: tipo.descricao ?? "",
        modelo_ensaio: tipo.modelo_ensaio,
        ativo: !tipo.ativo,
      });
      await carregar();
      setAviso(`Tipo "${tipo.nome}" ${tipo.ativo ? "desativado" : "ativado"}.`);
    } catch (e) {
      setAviso(e instanceof Error ? e.message : "Não foi possível alterar o status.");
    } finally {
      setAlternandoId(null);
    }
  }

  async function confirmarExclusao() {
    if (!alvoExclusao) return;
    setExcluindo(true);
    setErroExclusao(null);
    try {
      await excluirTipoEvento(alvoExclusao.id);
      await carregar();
      setAviso(`Tipo "${alvoExclusao.nome}" excluído.`);
      setAlvoExclusao(null);
    } catch (e) {
      setErroExclusao(e instanceof Error ? e.message : "Não foi possível excluir o tipo de evento.");
    } finally {
      setExcluindo(false);
    }
  }

  return (
    <main className="text-slate-900">
      <div className="mx-auto max-w-7xl px-4 py-8 sm:px-6 lg:px-8">
        <PageHeader
          titulo="Tipo do Evento"
          descricao={`Os tipos aparecem na lista ao criar um evento.${
            !carregando && !erro ? ` ${tipos.length} tipo(s).` : ""
          }`}
          acoes={
            pode("tipoevento.criar") ? (
              <Button icone={Plus} onClick={() => setPainel({ tipo: "novo" })} disabled={carregando || !!erro}>
                Adicionar
              </Button>
            ) : undefined
          }
        />

        {carregando ? (
          <div role="status" aria-live="polite" className="space-y-3">
            <span className="sr-only">Carregando tipos de evento...</span>
            <Skeleton className="h-14 rounded-2xl" />
            {[0, 1, 2, 3].map((i) => (
              <Skeleton key={i} className="h-10" />
            ))}
          </div>
        ) : erro ? (
          <ErrorState titulo="Não foi possível carregar os tipos de evento." mensagem={erro} onTentarNovamente={tentarNovamente} />
        ) : tipos.length === 0 ? (
          <EmptyState titulo="Nenhum tipo de evento cadastrado." descricao="Clique em “Adicionar” para criar o primeiro." />
        ) : (
          <TabelaTiposEvento
            tipos={tipos}
            podeEditar={pode("tipoevento.editar")}
            podeExcluir={pode("tipoevento.excluir")}
            alternandoId={alternandoId}
            onEditar={(item) => setPainel({ tipo: "editar", item })}
            onExcluir={(item) => {
              setErroExclusao(null);
              setAlvoExclusao(item);
            }}
            onAlternar={(item) => void alternar(item)}
          />
        )}
      </div>

      <Drawer
        aberto={painel !== null}
        onFechar={() => setPainel(null)}
        titulo={painel?.tipo === "editar" ? "Editar tipo de evento" : "Novo tipo de evento"}
        descricao="Defina o nome e se este tipo usa a tela Dados do Ensaio."
      >
        {painel && (
          <FormularioTipoEvento tipo={painel.tipo === "editar" ? painel.item : null} tipos={tipos} onSalvo={aoSalvar} />
        )}
      </Drawer>

      <ConfirmDialog
        aberto={alvoExclusao !== null}
        titulo="Excluir tipo de evento?"
        mensagem={
          <>
            <p>
              O tipo <strong>{alvoExclusao?.nome}</strong> será excluído. Esta ação não pode ser desfeita. Tipos que já
              foram usados em eventos não podem ser excluídos: desative-os.
            </p>
            {erroExclusao && (
              <p role="alert" className="mt-3 rounded-lg bg-red-50 px-3 py-2 text-red-700">
                {erroExclusao}
              </p>
            )}
          </>
        }
        textoConfirmar="Excluir"
        processando={excluindo}
        onConfirmar={() => void confirmarExclusao()}
        onCancelar={() => setAlvoExclusao(null)}
      />

      <Notificacao mensagem={aviso} onFechar={() => setAviso(null)} />
    </main>
  );
}
''',
    "src/modules/ensaio/cidades.test.ts": r'''import { describe, expect, it } from "vitest";
import { buscarCidades, lerMunicipiosDoIbge, rotuloDaCidade, type Cidade } from "./cidades";

const lista: Cidade[] = [
  { nome: "São Paulo", uf: "SP" },
  { nome: "São Pedro", uf: "SP" },
  { nome: "São Paulo do Potengi", uf: "RN" },
  { nome: "Salvador", uf: "BA" },
  { nome: "Santos", uf: "SP" },
  { nome: "Paulo Afonso", uf: "BA" },
  { nome: "Jequié", uf: "BA" },
  { nome: "Palmas", uf: "TO" },
  { nome: "Palmas", uf: "PR" },
];

describe("rotuloDaCidade", () => {
  it("junta cidade e estado", () => {
    expect(rotuloDaCidade({ nome: "São Paulo", uf: "SP" })).toBe("São Paulo-SP");
  });
});

describe("buscarCidades", () => {
  it("não sugere nada com menos de 2 letras", () => {
    expect(buscarCidades(lista, "")).toEqual([]);
    expect(buscarCidades(lista, "s")).toEqual([]);
  });

  it("ignora acento e maiúsculas; quem começa com o texto vem antes de quem só contém", () => {
    expect(buscarCidades(lista, "sao pa").map(rotuloDaCidade)).toEqual(["São Paulo-SP", "São Paulo do Potengi-RN"]);
    expect(buscarCidades(lista, "PAULO").map(rotuloDaCidade)).toEqual(["Paulo Afonso-BA", "São Paulo-SP", "São Paulo do Potengi-RN"]);
  });

  it("aceita 'cidade-uf' e filtra pelo estado", () => {
    expect(buscarCidades(lista, "palmas-to").map(rotuloDaCidade)).toEqual(["Palmas-TO"]);
    expect(buscarCidades(lista, "Palmas - PR").map(rotuloDaCidade)).toEqual(["Palmas-PR"]);
    expect(buscarCidades(lista, "são paulo-sp").map(rotuloDaCidade)).toEqual(["São Paulo-SP"]);
  });

  it("duas letras depois de um espaço NÃO viram estado (ex.: 'sao jo' segue sendo busca por nome)", () => {
    expect(buscarCidades([{ nome: "São José", uf: "SC" }], "sao jo").map(rotuloDaCidade)).toEqual(["São José-SC"]);
  });

  it("respeita o limite de sugestões", () => {
    const muitas = Array.from({ length: 30 }, (_, i) => ({ nome: `Cidade ${i}`, uf: "BA" }));
    expect(buscarCidades(muitas, "cidade")).toHaveLength(8);
    expect(buscarCidades(muitas, "cidade", 3)).toHaveLength(3);
  });

  it("sem resultado devolve lista vazia", () => {
    expect(buscarCidades(lista, "zzzz")).toEqual([]);
  });
});

describe("lerMunicipiosDoIbge", () => {
  it("lê a forma com microrregião e a forma com região imediata, e ignora o que não presta", () => {
    const resposta = [
      { id: 1, nome: "Jequié", microrregiao: { mesorregiao: { UF: { sigla: "BA" } } } },
      { id: 2, nome: "Nova Cidade", microrregiao: null, "regiao-imediata": { "regiao-intermediaria": { UF: { sigla: "MG" } } } },
      { id: 3, nome: "Sem estado" },
      { id: 4, nome: "", microrregiao: { mesorregiao: { UF: { sigla: "SP" } } } },
      { id: 5, nome: "Sigla ruim", microrregiao: { mesorregiao: { UF: { sigla: "sp" } } } },
      null,
      "texto",
    ];
    expect(lerMunicipiosDoIbge(resposta)).toEqual([
      { nome: "Jequié", uf: "BA" },
      { nome: "Nova Cidade", uf: "MG" },
    ]);
  });

  it("resposta que não é lista vira lista vazia", () => {
    expect(lerMunicipiosDoIbge({ erro: true })).toEqual([]);
    expect(lerMunicipiosDoIbge(null)).toEqual([]);
  });
});
''',
    "src/modules/ensaio/cidades.ts": r'''/**
 * SysMúsica — Busca de cidade (regra pura) para o campo Cidade-UF dos encarregados.
 * A lista de municípios vem do IBGE (services/cidades.ts); aqui ficam a leitura da resposta e a busca.
 */
import { SIGLAS_UF } from "./regras";

export interface Cidade {
  nome: string;
  uf: string;
}

/** Texto gravado: "São Paulo-SP". */
export function rotuloDaCidade(cidade: Cidade): string {
  return `${cidade.nome}-${cidade.uf}`;
}

function semAcento(texto: string): string {
  return texto.normalize("NFD").replace(/[̀-ͯ]/g, "").toLowerCase().replace(/\s+/g, " ").trim();
}

/**
 * Lê a resposta da API de municípios do IBGE. Aceita as duas formas em que o estado vem
 * (microrregiao > mesorregiao > UF, ou regiao-imediata > regiao-intermediaria > UF) e ignora o que não for válido.
 */
export function lerMunicipiosDoIbge(resposta: unknown): Cidade[] {
  if (!Array.isArray(resposta)) return [];
  const cidades: Cidade[] = [];
  for (const item of resposta) {
    if (typeof item !== "object" || item === null) continue;
    const registro = item as Record<string, unknown>;
    const nome = typeof registro.nome === "string" ? registro.nome.trim() : "";
    const uf = siglaDoEstado(registro);
    if (nome !== "" && uf !== null) cidades.push({ nome, uf });
  }
  return cidades;
}

function pegar(objeto: unknown, ...caminho: string[]): unknown {
  let atual: unknown = objeto;
  for (const chave of caminho) {
    if (typeof atual !== "object" || atual === null) return undefined;
    atual = (atual as Record<string, unknown>)[chave];
  }
  return atual;
}

function siglaDoEstado(registro: Record<string, unknown>): string | null {
  const candidatos = [
    pegar(registro, "microrregiao", "mesorregiao", "UF", "sigla"),
    pegar(registro, "regiao-imediata", "regiao-intermediaria", "UF", "sigla"),
  ];
  for (const candidato of candidatos) {
    if (typeof candidato === "string" && /^[A-Z]{2}$/.test(candidato)) return candidato;
  }
  return null;
}

/**
 * Sugestões para o que a pessoa digitou. Aceita "são pau" e "sao paulo-sp".
 * Quem COMEÇA com o texto vem primeiro; depois quem apenas contém. No máximo `limite` sugestões.
 */
export function buscarCidades(lista: Cidade[], digitado: string, limite = 8): Cidade[] {
  let termo = semAcento(digitado);
  if (termo.length < 2) return [];

  // "cidade-uf": separa a sigla do estado (só depois de um hífen e se for uma sigla de verdade) para filtrar por ela
  let ufFiltro: string | null = null;
  const comSigla = /^(.*?)\s*-\s*([a-z]{2})$/.exec(termo);
  if (comSigla && comSigla[1].length >= 2 && SIGLAS_UF.includes(comSigla[2].toUpperCase())) {
    ufFiltro = comSigla[2].toUpperCase();
    termo = comSigla[1];
  }

  const comecam: Cidade[] = [];
  const contem: Cidade[] = [];
  for (const cidade of lista) {
    if (ufFiltro && cidade.uf !== ufFiltro) continue;
    const nome = semAcento(cidade.nome);
    if (nome.startsWith(termo)) comecam.push(cidade);
    else if (nome.includes(termo)) contem.push(cidade);
  }
  const porNome = (a: Cidade, b: Cidade) => a.nome.localeCompare(b.nome, "pt-BR") || a.uf.localeCompare(b.uf);
  return [...comecam.sort(porNome), ...contem.sort(porNome)].slice(0, limite);
}
''',
    "src/modules/ensaio/components/CampoCidadeUf.tsx": r'''"use client";

/**
 * SysMúsica — Campo "Cidade-UF" com sugestões do IBGE.
 * Ao digitar ("sao pau"), aparece a lista de municípios; ao escolher, o texto vira "São Paulo-SP".
 * Se o IBGE estiver fora do ar a lista fica vazia e a pessoa digita à mão no formato Cidade-UF (o banco confere).
 */
import { useState } from "react";
import { buscarCidades, rotuloDaCidade, type Cidade } from "../cidades";

interface CampoCidadeUfProps {
  id: string;
  valor: string;
  onChange: (valor: string) => void;
  cidades: Cidade[];
  disabled?: boolean;
  invalido?: boolean;
}

const classeInput =
  "w-full rounded-lg border bg-white px-3 py-2 text-sm text-slate-900 placeholder:text-slate-400 shadow-sm " +
  "focus:outline-none focus:ring-2 disabled:cursor-not-allowed disabled:opacity-60 ";

export default function CampoCidadeUf({ id, valor, onChange, cidades, disabled, invalido }: CampoCidadeUfProps) {
  const [aberto, setAberto] = useState(false);
  const [ativa, setAtiva] = useState(-1);
  const sugestoes = aberto ? buscarCidades(cidades, valor) : [];
  const idLista = `${id}-sugestoes`;

  function escolher(cidade: Cidade) {
    onChange(rotuloDaCidade(cidade));
    setAberto(false);
    setAtiva(-1);
  }

  return (
    <div className="relative">
      <input
        id={id}
        type="text"
        role="combobox"
        aria-expanded={sugestoes.length > 0}
        aria-controls={idLista}
        aria-autocomplete="list"
        aria-invalid={invalido || undefined}
        autoComplete="off"
        value={valor}
        disabled={disabled}
        placeholder="Digite a cidade (ex: São Paulo-SP)"
        onChange={(e) => {
          onChange(e.target.value);
          setAberto(true);
          setAtiva(-1);
        }}
        onFocus={() => setAberto(true)}
        onBlur={() => setAberto(false)}
        onKeyDown={(e) => {
          if (sugestoes.length === 0) return;
          if (e.key === "ArrowDown") {
            e.preventDefault();
            setAtiva((i) => Math.min(i + 1, sugestoes.length - 1));
          } else if (e.key === "ArrowUp") {
            e.preventDefault();
            setAtiva((i) => Math.max(i - 1, 0));
          } else if (e.key === "Enter" && ativa >= 0) {
            e.preventDefault(); // não envia o formulário: só escolhe a sugestão
            escolher(sugestoes[ativa]);
          } else if (e.key === "Escape") {
            setAberto(false);
          }
        }}
        className={classeInput + (invalido ? "border-red-400 focus:ring-red-200" : "border-slate-300 focus:border-brand-500 focus:ring-brand-200")}
      />
      {sugestoes.length > 0 && (
        <ul
          id={idLista}
          role="listbox"
          className="absolute z-20 mt-1 max-h-56 w-full overflow-y-auto rounded-lg border border-slate-200 bg-white py-1 text-sm shadow-lg"
        >
          {sugestoes.map((cidade, indice) => (
            <li
              key={rotuloDaCidade(cidade)}
              role="option"
              aria-selected={indice === ativa}
              // mouseDown (e não click): acontece antes do onBlur do campo, senão a lista fecharia antes de escolher
              onMouseDown={(e) => {
                e.preventDefault();
                escolher(cidade);
              }}
              className={"cursor-pointer px-3 py-1.5 " + (indice === ativa ? "bg-brand-50 text-brand-800" : "hover:bg-slate-50")}
            >
              {rotuloDaCidade(cidade)}
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}
''',
    "src/modules/ensaio/components/FormularioEnsaio.tsx": r'''"use client";

/**
 * SysMúsica — Formulário dos Dados do Ensaio (Local ou Regional).
 *
 * Regional: quem atende é sempre Ancião e há a "palavra" (obrigatória, até 500 caracteres).
 * Local: quem atende é Ancião, Diácono, Cooperador do Ofício ou Cooperador de RJM; não há palavra.
 * De 1 a 3 encarregados (nome + Cidade-UF do IBGE). Hino de abertura obrigatório (fora da lista de executados).
 * Zero hinos executados é permitido: dá para salvar e completar durante o ensaio.
 * Fora do prazo (2 h antes até 3 h depois do início) só o Administrador edita: a tela fica só para consulta.
 * O banco refaz todas as conferências ao salvar.
 */
import { useMemo, useState, type FormEvent, type ReactNode } from "react";
import Button from "@/components/ui/Button";
import { rotuloCompleto, type Hino } from "@/modules/hinos/regras";
import type { Cidade } from "../cidades";
import {
  CARGOS_ATENDE,
  MAXIMO_ENCARREGADOS,
  PALAVRA_MAXIMA,
  acharPeloRotulo,
  ajustarQuantidade,
  cargosDoModelo,
  escolherAbertura,
  estadoDosDados,
  estadoVazio,
  montarCarga,
  motivoSemEdicao,
  rotuloEncarregado,
  temPalavra,
  validarEnsaio,
  type EstadoEnsaio,
  type ErroCampo,
} from "../regras";
import { salvarDadosEnsaio } from "../services/ensaio";
import type { RespostaEnsaio } from "../tipos";
import CampoCidadeUf from "./CampoCidadeUf";
import ResumoDoEnsaio from "./ResumoDoEnsaio";
import SeletorHinos from "./SeletorHinos";

interface FormularioEnsaioProps {
  resposta: RespostaEnsaio;
  hinos: Hino[];
  cidades: Cidade[];
  temPermissaoPreencher: boolean; // ensaio.registrar
  /** Conteúdo extra na coluna lateral (ex.: totais do painel ao vivo). */
  lateral?: ReactNode;
  onSalvo: (mensagem: string) => void | Promise<void>;
}

const classeInput =
  "w-full rounded-lg border bg-white px-3 py-2 text-sm text-slate-900 placeholder:text-slate-400 shadow-sm " +
  "focus:outline-none focus:ring-2 disabled:cursor-not-allowed disabled:opacity-60 ";
const bordaOk = "border-slate-300 focus:border-brand-500 focus:ring-brand-200";
const bordaErro = "border-red-400 focus:border-red-500 focus:ring-red-200";

export default function FormularioEnsaio({ resposta, hinos, cidades, temPermissaoPreencher, lateral, onSalvo }: FormularioEnsaioProps) {
  const { evento, dados, pode_editar: podeEditar } = resposta;
  const modelo = evento.modelo_ensaio;

  const [estado, setEstado] = useState<EstadoEnsaio>(() => estadoDosDados(dados, modelo));
  // Texto digitado no campo do hino de abertura (a escolha vale quando bate exatamente com uma opção)
  const [textoAbertura, setTextoAbertura] = useState(() => {
    const atual = hinos.find((h) => h.id === dados?.hino_abertura_id);
    return atual ? rotuloCompleto(atual) : "";
  });
  const [erros, setErros] = useState<ErroCampo[]>([]);
  const [erroGeral, setErroGeral] = useState<string | null>(null);
  const [avisoAbertura, setAvisoAbertura] = useState<string | null>(null);
  const [salvando, setSalvando] = useState(false);

  const bloqueio = motivoSemEdicao(evento, podeEditar, temPermissaoPreencher);
  const desabilitado = !podeEditar || salvando;

  // Opções do hino de abertura: ativos (e o já gravado, mesmo que desativado depois)
  const opcoesAbertura = useMemo(
    () =>
      hinos
        .filter((h) => h.ativo || h.id === dados?.hino_abertura_id)
        .map((hino) => ({ rotulo: rotuloCompleto(hino), hino })),
    [hinos, dados?.hino_abertura_id]
  );

  const erroDe = (campo: string) => erros.find((e) => e.campo === campo)?.mensagem;
  const mudar = (parte: Partial<EstadoEnsaio>) => setEstado((atual) => ({ ...atual, ...parte }));

  function digitarAbertura(texto: string) {
    setTextoAbertura(texto);
    const achado = acharPeloRotulo(opcoesAbertura, texto);
    const r = escolherAbertura(estado, achado?.id ?? "");
    setEstado(r.estado);
    setAvisoAbertura(r.saiuDaLista ? "Este hino estava na lista de executados e foi retirado de lá (a abertura não conta na lista)." : null);
  }

  function limpar() {
    setEstado(estadoVazio(modelo));
    setTextoAbertura("");
    setErros([]);
    setErroGeral(null);
    setAvisoAbertura(null);
  }

  function alterarEncarregado(indice: number, parte: Partial<EstadoEnsaio["encarregados"][number]>) {
    mudar({ encarregados: estado.encarregados.map((e, i) => (i === indice ? { ...e, ...parte } : e)) });
  }

  async function salvar(submissao: FormEvent<HTMLFormElement>) {
    submissao.preventDefault();
    if (desabilitado) return; // evita envio duplicado e envio sem permissão
    setErroGeral(null);

    const encontrados = validarEnsaio(estado, modelo);
    setErros(encontrados);
    if (encontrados.length > 0) {
      setErroGeral("Corrija os campos destacados antes de salvar.");
      return;
    }

    setSalvando(true);
    try {
      await salvarDadosEnsaio(evento.id, montarCarga(estado, modelo));
      await onSalvo(dados ? "Dados do ensaio atualizados." : "Dados do ensaio registrados.");
    } catch (e) {
      setErroGeral(e instanceof Error ? e.message : "Não foi possível salvar os dados do ensaio.");
    } finally {
      setSalvando(false);
    }
  }

  const cargos = CARGOS_ATENDE.filter((c) => cargosDoModelo(modelo).includes(c.codigo));

  return (
    <form onSubmit={salvar} className="grid gap-6 lg:grid-cols-[minmax(0,1fr)_320px]" noValidate>
      <div className="space-y-6">
        {bloqueio && (
          <p role="status" className="rounded-xl border border-amber-200 bg-amber-50 px-4 py-3 text-sm text-amber-900">
            {bloqueio}
          </p>
        )}

        <fieldset disabled={!podeEditar} className="space-y-6 disabled:opacity-90">
          {/* Quem atende */}
          <section className="space-y-4 rounded-2xl border border-slate-200 bg-white p-4 shadow-sm">
            <h2 className="text-base font-semibold text-slate-900">Quem atende</h2>
            <div className="grid gap-4 sm:grid-cols-2">
              <div className="space-y-1.5">
                <label htmlFor="ensaio-cargo" className="text-sm font-medium text-slate-700">
                  Cargo
                </label>
                <select
                  id="ensaio-cargo"
                  value={estado.atendeCargo}
                  onChange={(e) => mudar({ atendeCargo: e.target.value as EstadoEnsaio["atendeCargo"] })}
                  disabled={desabilitado}
                  className={classeInput + (erroDe("atende_cargo") ? bordaErro : bordaOk)}
                >
                  {modelo === "LOCAL" && <option value="">Selecione...</option>}
                  {cargos.map((c) => (
                    <option key={c.codigo} value={c.codigo}>
                      {c.rotulo}
                    </option>
                  ))}
                </select>
                {erroDe("atende_cargo") && <p className="text-xs text-red-700">{erroDe("atende_cargo")}</p>}
              </div>
              <div className="space-y-1.5">
                <label htmlFor="ensaio-nome" className="text-sm font-medium text-slate-700">
                  Nome
                </label>
                <input
                  id="ensaio-nome"
                  type="text"
                  maxLength={120}
                  value={estado.atendeNome}
                  onChange={(e) => mudar({ atendeNome: e.target.value })}
                  disabled={desabilitado}
                  className={classeInput + (erroDe("atende_nome") ? bordaErro : bordaOk)}
                />
                {erroDe("atende_nome") && <p className="text-xs text-red-700">{erroDe("atende_nome")}</p>}
              </div>
            </div>

            {temPalavra(modelo) && (
              <div className="space-y-1.5">
                <label htmlFor="ensaio-palavra" className="text-sm font-medium text-slate-700">
                  Palavra
                </label>
                <textarea
                  id="ensaio-palavra"
                  rows={3}
                  maxLength={PALAVRA_MAXIMA}
                  value={estado.palavra}
                  onChange={(e) => mudar({ palavra: e.target.value })}
                  disabled={desabilitado}
                  className={classeInput + (erroDe("palavra") ? bordaErro : bordaOk)}
                />
                <p className="text-right text-xs text-slate-500">
                  {estado.palavra.length}/{PALAVRA_MAXIMA}
                </p>
                {erroDe("palavra") && <p className="text-xs text-red-700">{erroDe("palavra")}</p>}
              </div>
            )}
          </section>

          {/* Encarregados */}
          <section className="space-y-4 rounded-2xl border border-slate-200 bg-white p-4 shadow-sm">
            <div className="flex flex-wrap items-center justify-between gap-2">
              <h2 className="text-base font-semibold text-slate-900">{rotuloEncarregado(modelo)}</h2>
              <div role="group" aria-label="Quantidade de encarregados" className="flex items-center gap-1">
                <span className="mr-1 text-xs text-slate-500">Quantos?</span>
                {Array.from({ length: MAXIMO_ENCARREGADOS }, (_, i) => i + 1).map((n) => (
                  <button
                    key={n}
                    type="button"
                    aria-pressed={estado.encarregados.length === n}
                    disabled={desabilitado}
                    onClick={() => mudar({ encarregados: ajustarQuantidade(estado.encarregados, n) })}
                    className={
                      "h-8 w-8 rounded-lg text-sm font-semibold transition disabled:opacity-50 " +
                      (estado.encarregados.length === n ? "bg-brand-600 text-white" : "bg-slate-100 text-slate-700 hover:bg-slate-200")
                    }
                  >
                    {n}
                  </button>
                ))}
              </div>
            </div>
            {erroDe("encarregados") && <p className="text-xs text-red-700">{erroDe("encarregados")}</p>}

            {estado.encarregados.map((encarregado, i) => (
              <div key={i} className="grid gap-3 sm:grid-cols-2">
                <div className="space-y-1.5">
                  <label htmlFor={`enc-nome-${i}`} className="text-sm font-medium text-slate-700">
                    Nome {estado.encarregados.length > 1 ? `(${i + 1})` : ""}
                  </label>
                  <input
                    id={`enc-nome-${i}`}
                    type="text"
                    maxLength={120}
                    value={encarregado.nome}
                    onChange={(e) => alterarEncarregado(i, { nome: e.target.value })}
                    disabled={desabilitado}
                    className={classeInput + (erroDe(`encarregado_${i}_nome`) ? bordaErro : bordaOk)}
                  />
                  {erroDe(`encarregado_${i}_nome`) && <p className="text-xs text-red-700">{erroDe(`encarregado_${i}_nome`)}</p>}
                </div>
                <div className="space-y-1.5">
                  <label htmlFor={`enc-cidade-${i}`} className="text-sm font-medium text-slate-700">
                    Cidade-UF
                  </label>
                  <CampoCidadeUf
                    id={`enc-cidade-${i}`}
                    valor={encarregado.cidadeUf}
                    onChange={(valor) => alterarEncarregado(i, { cidadeUf: valor })}
                    cidades={cidades}
                    disabled={desabilitado}
                    invalido={!!erroDe(`encarregado_${i}_cidade`)}
                  />
                  {erroDe(`encarregado_${i}_cidade`) && <p className="text-xs text-red-700">{erroDe(`encarregado_${i}_cidade`)}</p>}
                </div>
              </div>
            ))}
          </section>

          {/* Hinos */}
          <section className="space-y-4 rounded-2xl border border-slate-200 bg-white p-4 shadow-sm">
            <h2 className="text-base font-semibold text-slate-900">Hinos</h2>
            <div className="space-y-1.5">
              <label htmlFor="ensaio-abertura" className="text-sm font-medium text-slate-700">
                Hino de abertura
              </label>
              <input
                id="ensaio-abertura"
                type="text"
                list="ensaio-abertura-opcoes"
                autoComplete="off"
                value={textoAbertura}
                onChange={(e) => digitarAbertura(e.target.value)}
                disabled={desabilitado}
                placeholder="Digite o número ou o título e escolha na lista"
                className={classeInput + (erroDe("hino_abertura") ? bordaErro : bordaOk)}
              />
              <datalist id="ensaio-abertura-opcoes">
                {opcoesAbertura.map((o) => (
                  <option key={o.hino.id} value={o.rotulo} />
                ))}
              </datalist>
              {erroDe("hino_abertura") && <p className="text-xs text-red-700">{erroDe("hino_abertura")}</p>}
              {textoAbertura.trim() !== "" && estado.hinoAberturaId === "" && (
                <p className="text-xs text-amber-800">Escolha um hino da lista de sugestões.</p>
              )}
              {avisoAbertura && <p className="text-xs text-slate-600">{avisoAbertura}</p>}
            </div>

            <div className="space-y-1.5">
              <p className="text-sm font-medium text-slate-700">Hinos executados</p>
              <SeletorHinos
                hinos={hinos}
                selecionados={estado.hinosIds}
                abertura={estado.hinoAberturaId}
                onChange={(ids) => mudar({ hinosIds: ids })}
                disabled={desabilitado}
              />
              {erroDe("hinos") && <p className="text-xs text-red-700">{erroDe("hinos")}</p>}
            </div>
          </section>
        </fieldset>

        {erroGeral && (
          <p role="alert" className="rounded-lg bg-red-50 px-3 py-2 text-sm text-red-700">
            {erroGeral}
          </p>
        )}

        {podeEditar && (
          <div className="flex flex-wrap gap-3">
            <Button type="submit" disabled={salvando}>
              {salvando ? "Salvando..." : dados ? "Salvar alterações" : "Salvar dados do ensaio"}
            </Button>
            <button
              type="button"
              onClick={limpar}
              disabled={salvando}
              className="rounded-lg border border-slate-300 bg-white px-4 py-2 text-sm font-medium text-slate-700 shadow-sm transition hover:bg-slate-50 disabled:opacity-50"
            >
              Limpar formulário
            </button>
          </div>
        )}
      </div>

      <aside className="space-y-4 lg:sticky lg:top-4 lg:self-start">
        <ResumoDoEnsaio estado={estado} modelo={modelo} hinos={hinos} />
        {lateral}
      </aside>
    </form>
  );
}
''',
    "src/modules/ensaio/components/ResumoDoEnsaio.tsx": r'''"use client";

/**
 * SysMúsica — Resumo lateral do ensaio: o que já foi preenchido, em tempo real, conforme a pessoa digita.
 */
import { rotuloCompleto, type Hino } from "@/modules/hinos/regras";
import { rotuloDoCargo, rotuloEncarregado, type EstadoEnsaio } from "../regras";
import type { ModeloEnsaio } from "@/modules/tiposEvento/regras";

interface ResumoDoEnsaioProps {
  estado: EstadoEnsaio;
  modelo: ModeloEnsaio;
  hinos: Hino[];
}

export default function ResumoDoEnsaio({ estado, modelo, hinos }: ResumoDoEnsaioProps) {
  const abertura = hinos.find((h) => h.id === estado.hinoAberturaId);
  const preenchidos = estado.encarregados.filter((e) => e.nome.trim() !== "");

  return (
    <section aria-label="Resumo do ensaio" className="rounded-2xl border border-slate-200 bg-white p-4 shadow-sm">
      <h2 className="text-lg font-bold text-slate-900">Resumo do ensaio</h2>
      <dl className="mt-3 space-y-3 text-sm">
        <div>
          <dt className="text-xs font-semibold uppercase tracking-wide text-slate-500">Quem atende</dt>
          <dd className="text-slate-800">
            {estado.atendeNome.trim() ? `${estado.atendeNome.trim()} — ${rotuloDoCargo(estado.atendeCargo)}` : "—"}
          </dd>
        </div>
        <div>
          <dt className="text-xs font-semibold uppercase tracking-wide text-slate-500">
            {rotuloEncarregado(modelo)} ({preenchidos.length})
          </dt>
          <dd className="text-slate-800">
            {preenchidos.length === 0 ? "—" : preenchidos.map((e) => e.nome.trim() + (e.cidadeUf ? ` (${e.cidadeUf})` : "")).join("; ")}
          </dd>
        </div>
        <div>
          <dt className="text-xs font-semibold uppercase tracking-wide text-slate-500">Hino de abertura</dt>
          <dd className="text-slate-800">{abertura ? rotuloCompleto(abertura) : "—"}</dd>
        </div>
        <div>
          <dt className="text-xs font-semibold uppercase tracking-wide text-slate-500">Hinos executados</dt>
          <dd className="text-2xl font-bold tabular-nums text-slate-900">{estado.hinosIds.length}</dd>
        </div>
      </dl>
    </section>
  );
}
''',
    "src/modules/ensaio/components/SeletorHinos.tsx": r'''"use client";

/**
 * SysMúsica — Escolha dos hinos executados no ensaio.
 * Esquerda: lista de hinos ativos (com busca) para marcar e adicionar. Direita: hinos já escolhidos, na ordem
 * em que foram cantados (dá para subir, descer e remover). Hino não se repete e o hino de abertura fica de fora.
 */
import { useMemo, useState } from "react";
import { ArrowDown, ArrowUp, X } from "lucide-react";
import BotaoIcone from "@/components/ui/BotaoIcone";
import { filtrarHinos, rotuloCompleto, rotuloHino, type Hino } from "@/modules/hinos/regras";
import { MAXIMO_HINOS, adicionarHinos, hinosDisponiveis, moverHino, removerHinos } from "../regras";

interface SeletorHinosProps {
  hinos: Hino[]; // todos
  selecionados: string[];
  abertura: string; // id do hino de abertura (fora da lista)
  onChange: (ids: string[]) => void;
  disabled?: boolean;
}

const LIMITE_LISTA = 60; // quantos hinos desenhar de uma vez na coluna da esquerda

export default function SeletorHinos({ hinos, selecionados, abertura, onChange, disabled }: SeletorHinosProps) {
  const [busca, setBusca] = useState("");
  const [marcados, setMarcados] = useState<string[]>([]);

  const porId = useMemo(() => new Map(hinos.map((h) => [h.id, h] as const)), [hinos]);
  const encontrados = useMemo(
    () => filtrarHinos(hinosDisponiveis(hinos, selecionados, abertura), busca),
    [hinos, selecionados, abertura, busca]
  );
  const visiveis = encontrados.slice(0, LIMITE_LISTA);
  const marcadosValidos = marcados.filter((id) => visiveis.some((h) => h.id === id));

  function alternarMarca(id: string) {
    setMarcados((atual) => (atual.includes(id) ? atual.filter((x) => x !== id) : [...atual, id]));
  }
  function adicionar(ids: string[]) {
    onChange(adicionarHinos(selecionados, ids, abertura));
    setMarcados([]);
  }

  return (
    <div className="grid gap-4 lg:grid-cols-2">
      {/* Esquerda: disponíveis */}
      <div className="rounded-xl border border-slate-200 p-3">
        <label htmlFor="busca-hino-ensaio" className="text-sm font-medium text-slate-700">
          Buscar hino (número ou título)
        </label>
        <input
          id="busca-hino-ensaio"
          type="search"
          autoComplete="off"
          value={busca}
          onChange={(e) => setBusca(e.target.value)}
          disabled={disabled}
          placeholder="Ex: 12, coro 3, suave"
          className="mt-1 w-full rounded-lg border border-slate-300 px-3 py-2 text-sm shadow-sm focus:border-brand-500 focus:outline-none focus:ring-2 focus:ring-brand-200 disabled:opacity-60"
        />
        <ul className="mt-2 max-h-64 divide-y divide-slate-100 overflow-y-auto rounded-lg border border-slate-100" aria-label="Hinos disponíveis">
          {visiveis.length === 0 ? (
            <li className="px-3 py-6 text-center text-sm text-slate-500">Nenhum hino disponível.</li>
          ) : (
            visiveis.map((hino) => (
              <li key={hino.id}>
                <label className="flex cursor-pointer items-center gap-2 px-3 py-1.5 text-sm hover:bg-slate-50">
                  <input
                    type="checkbox"
                    checked={marcados.includes(hino.id)}
                    onChange={() => alternarMarca(hino.id)}
                    disabled={disabled}
                    className="h-4 w-4 rounded border-slate-300"
                  />
                  <span className="text-slate-800">{rotuloCompleto(hino)}</span>
                </label>
              </li>
            ))
          )}
        </ul>
        {encontrados.length > visiveis.length && (
          <p className="mt-1 text-xs text-slate-500">
            Mostrando {visiveis.length} de {encontrados.length}. Use a busca para achar os demais.
          </p>
        )}
        <div className="mt-3 flex flex-wrap gap-2">
          <button
            type="button"
            disabled={disabled || marcadosValidos.length === 0}
            onClick={() => adicionar(marcadosValidos)}
            className="rounded-lg bg-brand-600 px-3 py-1.5 text-sm font-medium text-white transition hover:bg-brand-700 disabled:cursor-not-allowed disabled:opacity-50"
          >
            Adicionar marcados ({marcadosValidos.length})
          </button>
          <button
            type="button"
            disabled={disabled || visiveis.length === 0}
            onClick={() => adicionar(visiveis.map((h) => h.id))}
            className="rounded-lg border border-slate-300 bg-white px-3 py-1.5 text-sm font-medium text-slate-700 transition hover:bg-slate-50 disabled:cursor-not-allowed disabled:opacity-50"
          >
            Adicionar todos da lista
          </button>
        </div>
      </div>

      {/* Direita: escolhidos */}
      <div className="rounded-xl border border-slate-200 p-3">
        <div className="flex items-center justify-between">
          <h3 className="text-sm font-medium text-slate-700">
            Hinos executados ({selecionados.length}/{MAXIMO_HINOS})
          </h3>
          {selecionados.length > 0 && !disabled && (
            <button type="button" onClick={() => onChange([])} className="text-xs font-medium text-red-700 hover:underline">
              Limpar lista
            </button>
          )}
        </div>
        {selecionados.length === 0 ? (
          <p className="mt-3 rounded-lg bg-slate-50 px-3 py-6 text-center text-sm text-slate-500">
            Nenhum hino ainda. Dá para salvar assim e completar durante o ensaio.
          </p>
        ) : (
          <ol className="mt-2 max-h-80 divide-y divide-slate-100 overflow-y-auto rounded-lg border border-slate-100">
            {selecionados.map((id, indice) => {
              const hino = porId.get(id);
              const texto = hino ? rotuloCompleto(hino) : "Hino removido do cadastro";
              return (
                <li key={id} className="flex items-center gap-2 px-3 py-1.5 text-sm">
                  <span className="w-6 shrink-0 text-right tabular-nums text-slate-400">{indice + 1}.</span>
                  <span className="min-w-0 flex-1 truncate text-slate-800">{texto}</span>
                  {!disabled && (
                    <span className="flex shrink-0">
                      <BotaoIcone
                        icone={ArrowUp}
                        rotulo={`Subir ${hino ? rotuloHino(hino.categoria, hino.numero) : "hino"}`}
                        onClick={() => onChange(moverHino(selecionados, indice, -1))}
                      />
                      <BotaoIcone
                        icone={ArrowDown}
                        rotulo={`Descer ${hino ? rotuloHino(hino.categoria, hino.numero) : "hino"}`}
                        onClick={() => onChange(moverHino(selecionados, indice, 1))}
                      />
                      <BotaoIcone
                        icone={X}
                        variante="perigo"
                        rotulo={`Remover ${hino ? rotuloHino(hino.categoria, hino.numero) : "hino"}`}
                        onClick={() => onChange(removerHinos(selecionados, [id]))}
                      />
                    </span>
                  )}
                </li>
              );
            })}
          </ol>
        )}
      </div>
    </div>
  );
}
''',
    "src/modules/ensaio/regras.test.ts": r'''import { describe, expect, it } from "vitest";
import {
  acharPeloRotulo,
  adicionarHinos,
  ajustarQuantidade,
  cargosDoModelo,
  escolherAbertura,
  estaVazio,
  estadoDosDados,
  estadoVazio,
  hinosDisponiveis,
  moverHino,
  montarCarga,
  montarCidadeUf,
  motivoSemEdicao,
  removerHinos,
  rotuloEncarregado,
  temPalavra,
  validarCidadeUf,
  validarEnsaio,
  type EstadoEnsaio,
} from "./regras";
import type { DadosSalvos } from "./tipos";

const valido = (sobrepor: Partial<EstadoEnsaio> = {}): EstadoEnsaio => ({
  atendeCargo: "ANCIAO",
  atendeNome: "Elias Ramos",
  palavra: "Salmo 150",
  hinoAberturaId: "h1",
  encarregados: [{ nome: "João Ferreira", cidadeUf: "São Paulo-SP" }],
  hinosIds: ["h2", "h5"],
  ...sobrepor,
});
const campos = (e: ReturnType<typeof validarEnsaio>) => e.map((x) => x.campo);

describe("modelo", () => {
  it("Regional: só Ancião, tem palavra, 'Encarregado Regional'", () => {
    expect(cargosDoModelo("REGIONAL")).toEqual(["ANCIAO"]);
    expect(temPalavra("REGIONAL")).toBe(true);
    expect(rotuloEncarregado("REGIONAL")).toBe("Encarregado Regional");
  });
  it("Local: quatro cargos, sem palavra, 'Encarregado Local'", () => {
    expect(cargosDoModelo("LOCAL")).toEqual(["ANCIAO", "DIACONO", "COOPERADOR_OFICIO", "COOPERADOR_RJM"]);
    expect(temPalavra("LOCAL")).toBe(false);
    expect(rotuloEncarregado("LOCAL")).toBe("Encarregado Local");
  });
});

describe("Cidade-UF", () => {
  it("monta e valida", () => {
    expect(montarCidadeUf(" São  Paulo ", "sp")).toBe("São Paulo-SP");
    expect(validarCidadeUf("São Paulo-SP")).toBeNull();
    expect(validarCidadeUf("Palmas-TO")).toBeNull();
    expect(validarCidadeUf("  Rio   Branco-AC ")).toBeNull();
  });
  it("recusa sem UF, UF minúscula, UF que não existe e cidade curta", () => {
    for (const ruim of ["São Paulo", "São Paulo-sp", "São Paulo-XX", "A-SP", "", "-SP", "São Paulo-SPP"]) {
      expect(validarCidadeUf(ruim), ruim).toMatch(/Cidade-UF/);
    }
  });
});

describe("estado do formulário", () => {
  it("em branco: Regional já vem com Ancião; Local sem cargo; 1 encarregado vazio", () => {
    expect(estadoVazio("REGIONAL").atendeCargo).toBe("ANCIAO");
    expect(estadoVazio("LOCAL").atendeCargo).toBe("");
    expect(estadoVazio("LOCAL").encarregados).toHaveLength(1);
  });

  it("monta o estado a partir dos dados gravados (encarregados na ordem)", () => {
    const dados: DadosSalvos = {
      atende_cargo: "DIACONO",
      atende_nome: "Fulano",
      palavra: null,
      hino_abertura_id: "h1",
      atualizado_em: "2026-10-21T00:00:00Z",
      encarregados: [
        { ordem: 2, nome: "B", cidade_uf: "Salvador-BA" },
        { ordem: 1, nome: "A", cidade_uf: "São Paulo-SP" },
      ],
      hinos: ["h2", "h3"],
    };
    const estado = estadoDosDados(dados, "LOCAL");
    expect(estado.encarregados.map((e) => e.nome)).toEqual(["A", "B"]);
    expect(estado.palavra).toBe("");
    expect(estado.hinosIds).toEqual(["h2", "h3"]);
    expect(estadoDosDados(null, "REGIONAL")).toEqual(estadoVazio("REGIONAL"));
  });

  it("ajustar a quantidade mantém o que foi digitado e fica entre 1 e 3", () => {
    const base = [{ nome: "A", cidadeUf: "X-SP" }, { nome: "B", cidadeUf: "Y-BA" }];
    expect(ajustarQuantidade(base, 3).map((e) => e.nome)).toEqual(["A", "B", ""]);
    expect(ajustarQuantidade(base, 1).map((e) => e.nome)).toEqual(["A"]);
    expect(ajustarQuantidade(base, 0)).toHaveLength(1);
    expect(ajustarQuantidade(base, 9)).toHaveLength(3);
    expect(ajustarQuantidade(base, Number.NaN)).toHaveLength(1);
  });

  it("estaVazio", () => {
    expect(estaVazio(estadoVazio("REGIONAL"), "REGIONAL")).toBe(true);
    expect(estaVazio({ ...estadoVazio("REGIONAL"), atendeNome: "x" }, "REGIONAL")).toBe(false);
    expect(estaVazio({ ...estadoVazio("LOCAL"), hinosIds: ["a"] }, "LOCAL")).toBe(false);
  });
});

describe("hinos executados", () => {
  it("adicionar não repete e não aceita o hino de abertura", () => {
    expect(adicionarHinos(["a"], ["a", "b", "c", "b"], "c")).toEqual(["a", "b"]);
  });
  it("respeita o limite de 100", () => {
    const cem = Array.from({ length: 100 }, (_, i) => `h${i}`);
    expect(adicionarHinos(cem, ["novo"], "")).toHaveLength(100);
  });
  it("remover e mover", () => {
    expect(removerHinos(["a", "b", "c"], ["b"])).toEqual(["a", "c"]);
    expect(moverHino(["a", "b", "c"], 1, -1)).toEqual(["b", "a", "c"]);
    expect(moverHino(["a", "b", "c"], 1, 1)).toEqual(["a", "c", "b"]);
    expect(moverHino(["a", "b", "c"], 0, -1)).toEqual(["a", "b", "c"]);
    expect(moverHino(["a", "b", "c"], 2, 1)).toEqual(["a", "b", "c"]);
    expect(moverHino(["a"], 5, 1)).toEqual(["a"]);
  });
  it("disponíveis: ativos, fora da lista e diferentes da abertura", () => {
    const todos = [{ id: "a", ativo: true }, { id: "b", ativo: false }, { id: "c", ativo: true }, { id: "d", ativo: true }];
    expect(hinosDisponiveis(todos, ["c"], "d").map((h) => h.id)).toEqual(["a"]);
  });
  it("escolher a abertura tira o hino da lista de executados e avisa", () => {
    const antes = valido({ hinosIds: ["h2", "h3"] });
    const r = escolherAbertura(antes, "h3");
    expect(r.estado.hinoAberturaId).toBe("h3");
    expect(r.estado.hinosIds).toEqual(["h2"]);
    expect(r.saiuDaLista).toBe(true);
    expect(escolherAbertura(antes, "h9").saiuDaLista).toBe(false);
    expect(escolherAbertura(antes, "").estado.hinoAberturaId).toBe("");
  });
  it("acha o hino pelo texto exato da opção", () => {
    const opcoes = [{ rotulo: "002 – Oh! quão suave", hino: { id: "x" } }, { rotulo: "Coro 1 – Um", hino: { id: "y" } }];
    expect(acharPeloRotulo(opcoes, "  coro 1 –  um ")?.id).toBe("y");
    expect(acharPeloRotulo(opcoes, "002")).toBeNull();
    expect(acharPeloRotulo(opcoes, "")).toBeNull();
  });
});

describe("validarEnsaio", () => {
  it("o ensaio completo passa (Regional e Local)", () => {
    expect(validarEnsaio(valido(), "REGIONAL")).toEqual([]);
    expect(validarEnsaio(valido({ atendeCargo: "DIACONO", palavra: "" }), "LOCAL")).toEqual([]);
  });

  it("zero hinos executados é permitido (preenche-se durante o ensaio)", () => {
    expect(validarEnsaio(valido({ hinosIds: [] }), "REGIONAL")).toEqual([]);
  });

  it("Regional exige Ancião e palavra; Local não exige palavra", () => {
    expect(campos(validarEnsaio(valido({ atendeCargo: "DIACONO" }), "REGIONAL"))).toEqual(["atende_cargo"]);
    expect(campos(validarEnsaio(valido({ palavra: "   " }), "REGIONAL"))).toEqual(["palavra"]);
    expect(campos(validarEnsaio(valido({ palavra: "a".repeat(501) }), "REGIONAL"))).toEqual(["palavra"]);
    expect(validarEnsaio(valido({ atendeCargo: "COOPERADOR_RJM", palavra: "" }), "LOCAL")).toEqual([]);
    expect(campos(validarEnsaio(valido({ atendeCargo: "" }), "LOCAL"))).toEqual(["atende_cargo"]);
  });

  it("nome de quem atende: obrigatório e com limite", () => {
    expect(campos(validarEnsaio(valido({ atendeNome: " ab " }), "REGIONAL"))).toEqual(["atende_nome"]);
    expect(campos(validarEnsaio(valido({ atendeNome: "a".repeat(121) }), "REGIONAL"))).toEqual(["atende_nome"]);
  });

  it("encarregados: nome e cidade obrigatórios, nomes não repetem, no máximo 3", () => {
    const e1 = { nome: "", cidadeUf: "" };
    expect(campos(validarEnsaio(valido({ encarregados: [e1] }), "REGIONAL"))).toEqual(["encarregado_0_nome", "encarregado_0_cidade"]);
    const repetido = validarEnsaio(
      valido({ encarregados: [{ nome: "João Ferreira", cidadeUf: "São Paulo-SP" }, { nome: "joao  ferreira", cidadeUf: "Salvador-BA" }] }),
      "REGIONAL"
    );
    expect(campos(repetido)).toEqual(["encarregado_1_nome"]);
    expect(campos(validarEnsaio(valido({ encarregados: [] }), "REGIONAL"))).toEqual(["encarregados"]);
    const quatro = Array.from({ length: 4 }, (_, i) => ({ nome: `Nome ${i}x`, cidadeUf: "Palmas-TO" }));
    expect(campos(validarEnsaio(valido({ encarregados: quatro }), "REGIONAL"))).toEqual(["encarregados"]);
  });

  it("hino de abertura obrigatório e fora da lista de executados", () => {
    expect(campos(validarEnsaio(valido({ hinoAberturaId: "" }), "REGIONAL"))).toEqual(["hino_abertura"]);
    expect(campos(validarEnsaio(valido({ hinosIds: ["h1", "h2"] }), "REGIONAL"))).toEqual(["hinos"]);
  });

  it("hino repetido na lista", () => {
    expect(campos(validarEnsaio(valido({ hinosIds: ["h2", "h2"] }), "REGIONAL"))).toEqual(["hinos"]);
  });

  it("os erros vêm na ordem da tela", () => {
    const e = validarEnsaio(estadoVazio("REGIONAL"), "REGIONAL");
    expect(campos(e)).toEqual(["atende_nome", "palavra", "encarregado_0_nome", "encarregado_0_cidade", "hino_abertura"]);
  });
});

describe("montarCarga", () => {
  it("limpa os textos; Regional leva a palavra, Local manda nulo", () => {
    const estado = valido({ atendeNome: "  Elias   Ramos ", palavra: " Salmo 150 ", encarregados: [{ nome: " João  Ferreira ", cidadeUf: " São Paulo-SP " }] });
    expect(montarCarga(estado, "REGIONAL")).toEqual({
      atende_cargo: "ANCIAO",
      atende_nome: "Elias Ramos",
      palavra: "Salmo 150",
      hino_abertura_id: "h1",
      encarregados: [{ nome: "João Ferreira", cidade_uf: "São Paulo-SP" }],
      hinos: ["h2", "h5"],
    });
    expect(montarCarga(estado, "LOCAL").palavra).toBeNull();
  });
});

describe("motivoSemEdicao", () => {
  const ev = { cancelado: false, iniciado: true, encerrado: false };
  it("null quando dá para editar", () => {
    expect(motivoSemEdicao(ev, true, true)).toBeNull();
  });
  it("explica cada caso, na ordem", () => {
    expect(motivoSemEdicao({ ...ev, cancelado: true }, false, true)).toMatch(/cancelado/);
    expect(motivoSemEdicao(ev, false, false)).toMatch(/permissão/);
    expect(motivoSemEdicao({ ...ev, iniciado: false }, false, true)).toMatch(/ainda não começou/);
    expect(motivoSemEdicao({ ...ev, encerrado: true }, false, true)).toMatch(/encerrado/);
    expect(motivoSemEdicao(ev, false, true)).toMatch(/Não é possível/);
  });
});
''',
    "src/modules/ensaio/regras.ts": r'''/**
 * SysMúsica — Regras puras dos Dados do Ensaio (sem banco). Testadas em regras.test.ts.
 *
 * Só ensaios Local e Regional. O que se registra:
 *   - quem atendeu (Regional: sempre um Ancião; Local: Ancião, Diácono, Cooperador do Ofício ou de RJM) e o nome;
 *   - a palavra exortada (só no Regional, obrigatória, até 500 caracteres; o Local não tem palavra);
 *   - de 1 a 3 encarregados, cada um com nome e Cidade-UF;
 *   - o hino de abertura (obrigatório e FORA da lista) e os hinos executados (sem repetir).
 * O banco aplica as mesmas regras (migração 0041); aqui ficam as conferências para a tela.
 */
import type { ModeloEnsaio } from "@/modules/tiposEvento/regras";
import type { CargaEnsaio, CargoAtende, DadosSalvos, EventoDoEnsaio } from "./tipos";

export const CARGOS_ATENDE: { codigo: CargoAtende; rotulo: string }[] = [
  { codigo: "ANCIAO", rotulo: "Ancião" },
  { codigo: "DIACONO", rotulo: "Diácono" },
  { codigo: "COOPERADOR_OFICIO", rotulo: "Cooperador do Ofício Ministerial" },
  { codigo: "COOPERADOR_RJM", rotulo: "Cooperador da Reunião de Jovens e Menores" },
];

export const PALAVRA_MAXIMA = 500;
export const MAXIMO_ENCARREGADOS = 3;
export const NOME_MINIMO = 3;
export const NOME_MAXIMO = 120;
export const MAXIMO_HINOS = 100;

/** Siglas dos 26 estados e do Distrito Federal. */
export const SIGLAS_UF = [
  "AC", "AL", "AP", "AM", "BA", "CE", "DF", "ES", "GO", "MA", "MT", "MS", "MG", "PA",
  "PB", "PR", "PE", "PI", "RJ", "RN", "RS", "RO", "RR", "SC", "SP", "SE", "TO",
];

export function rotuloDoCargo(cargo: CargoAtende | ""): string {
  return CARGOS_ATENDE.find((item) => item.codigo === cargo)?.rotulo ?? "";
}

/** Cargos que podem atender: no Regional só o Ancião; no Local, os quatro. */
export function cargosDoModelo(modelo: ModeloEnsaio): CargoAtende[] {
  return modelo === "REGIONAL" ? ["ANCIAO"] : CARGOS_ATENDE.map((item) => item.codigo);
}

/** O ensaio tem o campo Palavra? (só o Regional) */
export function temPalavra(modelo: ModeloEnsaio): boolean {
  return modelo === "REGIONAL";
}

/** Rótulo do encarregado conforme o modelo: "Encarregado Regional" ou "Encarregado Local". */
export function rotuloEncarregado(modelo: ModeloEnsaio): string {
  return modelo === "REGIONAL" ? "Encarregado Regional" : "Encarregado Local";
}

const ESPACOS = /\s+/g;
export function limparEspacos(texto: string): string {
  return texto.trim().replace(ESPACOS, " ");
}

// ---------------------------------------------------------------------------
// Cidade-UF
// ---------------------------------------------------------------------------

/** Monta o texto gravado: "São Paulo-SP". */
export function montarCidadeUf(cidade: string, uf: string): string {
  return `${limparEspacos(cidade)}-${uf.trim().toUpperCase()}`;
}

/** Confere "Cidade-UF" (ex.: "São Paulo-SP"). Devolve a mensagem de erro ou null. */
export function validarCidadeUf(texto: string): string | null {
  const limpo = limparEspacos(texto);
  const achou = /^(.{2,})-([A-Z]{2})$/.exec(limpo);
  if (!achou || !SIGLAS_UF.includes(achou[2])) {
    return "Informe a cidade no formato Cidade-UF (ex.: São Paulo-SP). Escolha uma das sugestões.";
  }
  return null;
}

// ---------------------------------------------------------------------------
// Estado do formulário
// ---------------------------------------------------------------------------

export interface EncarregadoForm {
  nome: string;
  cidadeUf: string;
}

export interface EstadoEnsaio {
  atendeCargo: CargoAtende | "";
  atendeNome: string;
  palavra: string;
  hinoAberturaId: string;
  encarregados: EncarregadoForm[]; // de 1 a 3
  hinosIds: string[]; // hinos executados, na ordem em que foram cantados
}

const ENCARREGADO_VAZIO: EncarregadoForm = { nome: "", cidadeUf: "" };

/** Formulário em branco. No Regional o cargo já vem como Ancião (é o único possível). */
export function estadoVazio(modelo: ModeloEnsaio): EstadoEnsaio {
  return {
    atendeCargo: modelo === "REGIONAL" ? "ANCIAO" : "",
    atendeNome: "",
    palavra: "",
    hinoAberturaId: "",
    encarregados: [{ ...ENCARREGADO_VAZIO }],
    hinosIds: [],
  };
}

/** Formulário a partir do que já foi gravado (ou em branco, se ainda não há dados). */
export function estadoDosDados(dados: DadosSalvos | null, modelo: ModeloEnsaio): EstadoEnsaio {
  if (!dados) return estadoVazio(modelo);
  const encarregados = [...dados.encarregados]
    .sort((a, b) => a.ordem - b.ordem)
    .map((item) => ({ nome: item.nome, cidadeUf: item.cidade_uf }));
  return {
    atendeCargo: dados.atende_cargo,
    atendeNome: dados.atende_nome,
    palavra: dados.palavra ?? "",
    hinoAberturaId: dados.hino_abertura_id,
    encarregados: encarregados.length > 0 ? encarregados : [{ ...ENCARREGADO_VAZIO }],
    hinosIds: [...dados.hinos],
  };
}

/** Muda a quantidade de encarregados (1 a 3): mantém os já digitados e acrescenta linhas em branco. */
export function ajustarQuantidade(encarregados: EncarregadoForm[], quantidade: number): EncarregadoForm[] {
  const alvo = Math.min(MAXIMO_ENCARREGADOS, Math.max(1, Math.trunc(quantidade) || 1));
  const novos = encarregados.slice(0, alvo);
  while (novos.length < alvo) novos.push({ ...ENCARREGADO_VAZIO });
  return novos;
}

// ---------------------------------------------------------------------------
// Hinos executados
// ---------------------------------------------------------------------------

/** Acrescenta hinos ao fim da lista, sem repetir e sem o hino de abertura. */
export function adicionarHinos(selecionados: string[], novos: string[], abertura: string): string[] {
  const resultado = [...selecionados];
  for (const id of novos) {
    if (id === abertura || resultado.includes(id)) continue;
    if (resultado.length >= MAXIMO_HINOS) break;
    resultado.push(id);
  }
  return resultado;
}

export function removerHinos(selecionados: string[], remover: string[]): string[] {
  return selecionados.filter((id) => !remover.includes(id));
}

/** Sobe (-1) ou desce (+1) um hino na ordem de execução. */
export function moverHino(selecionados: string[], indice: number, passo: -1 | 1): string[] {
  const destino = indice + passo;
  if (indice < 0 || indice >= selecionados.length || destino < 0 || destino >= selecionados.length) return selecionados;
  const copia = [...selecionados];
  [copia[indice], copia[destino]] = [copia[destino], copia[indice]];
  return copia;
}

/** Hinos que ainda podem ser escolhidos: ativos, fora da lista e diferentes do hino de abertura. */
export function hinosDisponiveis<T extends { id: string; ativo: boolean }>(
  todos: T[],
  selecionados: string[],
  abertura: string
): T[] {
  return todos.filter((hino) => hino.ativo && hino.id !== abertura && !selecionados.includes(hino.id));
}

/**
 * Escolhe o hino de abertura. Se ele estava entre os hinos executados, sai de lá (a abertura não conta na lista);
 * `saiuDaLista` avisa a tela para mostrar a informação.
 */
export function escolherAbertura(
  estado: EstadoEnsaio,
  hinoId: string
): { estado: EstadoEnsaio; saiuDaLista: boolean } {
  const saiuDaLista = hinoId !== "" && estado.hinosIds.includes(hinoId);
  return {
    estado: { ...estado, hinoAberturaId: hinoId, hinosIds: removerHinos(estado.hinosIds, [hinoId]) },
    saiuDaLista,
  };
}

/** Acha o hino pelo texto do campo de busca do hino de abertura (o texto exato de uma das opções). */
export function acharPeloRotulo<T extends { id: string }>(
  opcoes: { rotulo: string; hino: T }[],
  texto: string
): T | null {
  const alvo = limparEspacos(texto).toLowerCase();
  if (alvo === "") return null;
  return opcoes.find((opcao) => limparEspacos(opcao.rotulo).toLowerCase() === alvo)?.hino ?? null;
}

// ---------------------------------------------------------------------------
// Validação e envio
// ---------------------------------------------------------------------------

export interface ErroCampo {
  campo: string; // "atende_cargo", "atende_nome", "palavra", "hino_abertura", "encarregado_0_nome", "encarregado_0_cidade"
  mensagem: string;
}

/** Confere o formulário na ordem em que aparece na tela. Lista vazia = pode salvar. */
export function validarEnsaio(estado: EstadoEnsaio, modelo: ModeloEnsaio): ErroCampo[] {
  const erros: ErroCampo[] = [];

  if (!estado.atendeCargo || !cargosDoModelo(modelo).includes(estado.atendeCargo)) {
    erros.push({
      campo: "atende_cargo",
      mensagem:
        modelo === "REGIONAL"
          ? "No ensaio Regional quem atende é sempre um Ancião."
          : "Escolha o cargo de quem atendeu o ensaio.",
    });
  }
  const nome = limparEspacos(estado.atendeNome);
  if (nome.length < NOME_MINIMO) {
    erros.push({ campo: "atende_nome", mensagem: "Informe o nome de quem atendeu o ensaio." });
  } else if (nome.length > NOME_MAXIMO) {
    erros.push({ campo: "atende_nome", mensagem: `O nome pode ter no máximo ${NOME_MAXIMO} caracteres.` });
  }

  if (temPalavra(modelo)) {
    const palavra = estado.palavra.trim();
    if (palavra === "") erros.push({ campo: "palavra", mensagem: "Informe a palavra que foi exortada." });
    else if (palavra.length > PALAVRA_MAXIMA) {
      erros.push({ campo: "palavra", mensagem: `A palavra pode ter no máximo ${PALAVRA_MAXIMA} caracteres.` });
    }
  }

  if (estado.encarregados.length < 1 || estado.encarregados.length > MAXIMO_ENCARREGADOS) {
    erros.push({ campo: "encarregados", mensagem: `Informe de 1 a ${MAXIMO_ENCARREGADOS} encarregados.` });
  }
  const nomesVistos = new Set<string>();
  estado.encarregados.forEach((item, indice) => {
    const nomeEnc = limparEspacos(item.nome);
    if (nomeEnc.length < NOME_MINIMO || nomeEnc.length > NOME_MAXIMO) {
      erros.push({
        campo: `encarregado_${indice}_nome`,
        mensagem: `Informe o nome do ${indice + 1}º encarregado.`,
      });
    } else {
      const chave = nomeEnc.normalize("NFD").replace(/[̀-ͯ]/g, "").toLowerCase();
      if (nomesVistos.has(chave)) {
        erros.push({ campo: `encarregado_${indice}_nome`, mensagem: "Este nome já foi informado em outro encarregado." });
      }
      nomesVistos.add(chave);
    }
    const erroCidade = validarCidadeUf(item.cidadeUf);
    if (erroCidade) erros.push({ campo: `encarregado_${indice}_cidade`, mensagem: erroCidade });
  });

  if (!estado.hinoAberturaId) {
    erros.push({ campo: "hino_abertura", mensagem: "Escolha o hino de abertura na lista." });
  } else if (estado.hinosIds.includes(estado.hinoAberturaId)) {
    erros.push({ campo: "hinos", mensagem: "O hino de abertura não conta entre os hinos executados." });
  }
  if (new Set(estado.hinosIds).size !== estado.hinosIds.length) {
    erros.push({ campo: "hinos", mensagem: "O mesmo hino não pode ser executado duas vezes." });
  }
  if (estado.hinosIds.length > MAXIMO_HINOS) {
    erros.push({ campo: "hinos", mensagem: `Informe no máximo ${MAXIMO_HINOS} hinos executados.` });
  }
  return erros;
}

/** Monta o que é enviado ao banco (já limpo). Só chame depois de validarEnsaio devolver lista vazia. */
export function montarCarga(estado: EstadoEnsaio, modelo: ModeloEnsaio): CargaEnsaio {
  return {
    atende_cargo: (estado.atendeCargo || "ANCIAO") as CargoAtende,
    atende_nome: limparEspacos(estado.atendeNome),
    palavra: temPalavra(modelo) ? estado.palavra.trim() : null,
    hino_abertura_id: estado.hinoAberturaId,
    encarregados: estado.encarregados.map((item) => ({
      nome: limparEspacos(item.nome),
      cidade_uf: limparEspacos(item.cidadeUf),
    })),
    hinos: [...estado.hinosIds],
  };
}

/** Nada foi digitado ainda? (o botão Limpar só faz sentido quando há algo) */
export function estaVazio(estado: EstadoEnsaio, modelo: ModeloEnsaio): boolean {
  const base = estadoVazio(modelo);
  return (
    estado.atendeCargo === base.atendeCargo &&
    estado.atendeNome.trim() === "" &&
    estado.palavra.trim() === "" &&
    estado.hinoAberturaId === "" &&
    estado.hinosIds.length === 0 &&
    estado.encarregados.every((item) => item.nome.trim() === "" && item.cidadeUf.trim() === "")
  );
}

// ---------------------------------------------------------------------------
// Quando dá para preencher
// ---------------------------------------------------------------------------

/**
 * Por que a tela está só para consulta (ou null, se dá para editar). O banco decide; aqui só se explica.
 * Ordem: cancelado, ainda não começou, encerrado, sem permissão.
 */
export function motivoSemEdicao(
  evento: Pick<EventoDoEnsaio, "cancelado" | "iniciado" | "encerrado">,
  podeEditar: boolean,
  temPermissaoPreencher: boolean
): string | null {
  if (podeEditar) return null;
  if (evento.cancelado) return "Este evento foi cancelado: os dados não podem ser alterados.";
  if (!temPermissaoPreencher) return "Você pode ver os dados do ensaio, mas não tem permissão para preenchê-los.";
  if (!evento.iniciado) {
    return "O ensaio ainda não começou. Os dados podem ser preenchidos a partir de 2 horas antes do horário.";
  }
  if (evento.encerrado) return "Este ensaio já foi encerrado. Só o Administrador pode alterar os dados.";
  return "Não é possível alterar os dados deste ensaio agora.";
}
''',
    "src/modules/ensaio/services/cidades.ts": r'''/**
 * SysMúsica — Lista de municípios do IBGE para o campo Cidade-UF.
 * Baixada uma vez por visita e guardada em memória. Nunca lança erro: se o IBGE estiver fora do ar, devolve
 * lista vazia e a tela deixa a pessoa digitar "Cidade-UF" à mão (o banco confere o formato).
 */
import { lerMunicipiosDoIbge, type Cidade } from "../cidades";

const URL_MUNICIPIOS = "https://servicodados.ibge.gov.br/api/v1/localidades/municipios?orderBy=nome";
const TEMPO_LIMITE_MS = 10_000;

let guardada: Promise<Cidade[]> | null = null;

export function carregarCidades(): Promise<Cidade[]> {
  if (guardada) return guardada;
  guardada = (async () => {
    const controle = new AbortController();
    const relogio = setTimeout(() => controle.abort(), TEMPO_LIMITE_MS);
    try {
      const resposta = await fetch(URL_MUNICIPIOS, { signal: controle.signal });
      if (!resposta.ok) throw new Error(String(resposta.status));
      const lista = lerMunicipiosDoIbge(await resposta.json());
      if (lista.length === 0) throw new Error("vazia");
      return lista;
    } catch {
      guardada = null; // falhou: na próxima vez tenta de novo
      return [];
    } finally {
      clearTimeout(relogio);
    }
  })();
  return guardada;
}
''',
    "src/modules/ensaio/services/ensaio.ts": r'''/**
 * SysMúsica — Serviço dos Dados do Ensaio. Tudo passa por funções do banco (migração 0041), que conferem
 * permissão, abrangência (região/casa de oração) e o prazo de edição.
 */
import { supabase } from "@/lib/supabase";
import { mensagemDoErro } from "@/lib/erros";
import type { CargaEnsaio, EventoParaEnsaio, RespostaEnsaio } from "../tipos";

/** Ensaios (Local/Regional) recentes ou próximos, dentro da abrangência de quem consulta. */
export async function listarEventosParaEnsaio(): Promise<EventoParaEnsaio[]> {
  const { data, error } = await supabase.rpc("eventos_para_ensaio");
  if (error) throw new Error(mensagemDoErro(error, "Não foi possível carregar os ensaios."));
  return (data ?? []) as EventoParaEnsaio[];
}

/** Evento + dados já gravados (ou null) + se esta pessoa pode editar agora. */
export async function obterDadosEnsaio(eventoId: string): Promise<RespostaEnsaio> {
  const { data, error } = await supabase.rpc("obter_dados_ensaio", { p_evento_id: eventoId });
  if (error) throw new Error(mensagemDoErro(error, "Não foi possível carregar os dados do ensaio."));
  return data as RespostaEnsaio;
}

/** Grava (cria ou substitui) os dados do ensaio. O banco refaz todas as conferências. */
export async function salvarDadosEnsaio(eventoId: string, carga: CargaEnsaio): Promise<void> {
  const { error } = await supabase.rpc("salvar_dados_ensaio", { p_evento_id: eventoId, p_dados: carga });
  if (error) throw new Error(mensagemDoErro(error, "Não foi possível salvar os dados do ensaio."));
}
''',
    "src/modules/ensaio/tipos.ts": r'''/** SysMúsica — Tipos do módulo Dados do Ensaio (campos = o que as funções do banco devolvem, migração 0041). */
import type { ModeloEnsaio } from "@/modules/tiposEvento/regras";

export type CargoAtende = "ANCIAO" | "DIACONO" | "COOPERADOR_OFICIO" | "COOPERADOR_RJM";

/** Um ensaio da lista para escolher (eventos_para_ensaio). */
export interface EventoParaEnsaio {
  id: string;
  tipo: string;
  modelo_ensaio: ModeloEnsaio;
  data_evento: string;
  local_evento: string | null;
  cidade: string | null;
  casa_oracao_nome: string | null;
  preenchido: boolean;
  encerrado: boolean;
}

/** O evento como obter_dados_ensaio devolve (inclui as situações que decidem se dá para preencher). */
export interface EventoDoEnsaio {
  id: string;
  tipo: string;
  modelo_ensaio: ModeloEnsaio;
  data_evento: string;
  local: string | null;
  cidade: string | null;
  casa_oracao: string | null;
  cancelado: boolean;
  iniciado: boolean; // já passou de 2h antes do horário
  encerrado: boolean; // já passou de 3h depois do horário
}

export interface EncarregadoSalvo {
  ordem: number;
  nome: string;
  cidade_uf: string;
}

/** Dados já gravados do ensaio. */
export interface DadosSalvos {
  atende_cargo: CargoAtende;
  atende_nome: string;
  palavra: string | null;
  hino_abertura_id: string;
  atualizado_em: string;
  encarregados: EncarregadoSalvo[];
  hinos: string[]; // ids dos hinos executados, na ordem
}

export interface RespostaEnsaio {
  evento: EventoDoEnsaio;
  /** O banco já calcula: tem a permissão e o ensaio está dentro do prazo (ou é o Administrador). */
  pode_editar: boolean;
  dados: DadosSalvos | null;
}

/** O que a tela envia para salvar_dados_ensaio. */
export interface CargaEnsaio {
  atende_cargo: CargoAtende;
  atende_nome: string;
  palavra: string | null;
  hino_abertura_id: string;
  encarregados: { nome: string; cidade_uf: string }[];
  hinos: string[];
}
''',
    "src/modules/hinos/components/FormularioHino.tsx": r'''"use client";

/**
 * SysMúsica — Formulário de hino/coro (novo ou edição) — conteúdo do painel lateral.
 * Hino do hinário aparece como "002"; coro (corinho) aparece como "Coro 2".
 * Se o hino já foi usado em algum ensaio, o banco não deixa trocar o número/categoria (só o título e o status).
 */
import { useState, type FormEvent } from "react";
import Button from "@/components/ui/Button";
import {
  NUMERO_MAXIMO,
  NUMERO_MINIMO,
  TITULO_MAXIMO,
  formatarTitulo,
  rotuloHino,
  validarHino,
  type CategoriaHino,
  type Hino,
} from "../regras";
import { salvarHino } from "../services/hinos";

interface FormularioHinoProps {
  hino: Hino | null;
  hinos: Hino[]; // todos, para avisar de número repetido
  categoriaInicial: CategoriaHino;
  onSalvo: (mensagem: string) => void | Promise<void>;
}

const classeInput =
  "w-full rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 " +
  "placeholder:text-slate-400 shadow-sm focus:border-brand-500 focus:outline-none " +
  "focus:ring-2 focus:ring-brand-200 disabled:cursor-not-allowed disabled:opacity-60";

export default function FormularioHino({ hino, hinos, categoriaInicial, onSalvo }: FormularioHinoProps) {
  const editando = hino !== null;
  const [categoria, setCategoria] = useState<CategoriaHino>(hino?.categoria ?? categoriaInicial);
  const [numero, setNumero] = useState(hino ? String(hino.numero) : "");
  const [nome, setNome] = useState(hino?.nome ?? "");
  const [ativo, setAtivo] = useState(hino?.ativo ?? true);
  const [salvando, setSalvando] = useState(false);
  const [erro, setErro] = useState<string | null>(null);

  const travado = editando && (hino?.em_uso ?? 0) > 0; // número e categoria não mudam se já foi usado

  async function salvar(submissao: FormEvent<HTMLFormElement>) {
    submissao.preventDefault();
    if (salvando) return;
    setErro(null);

    const n = numero.trim() === "" ? null : Number(numero);
    const erroForm = validarHino({ categoria, numero: n, nome });
    if (erroForm) return setErro(erroForm);
    if (hinos.some((h) => h.id !== hino?.id && h.categoria === categoria && h.numero === n)) {
      return setErro(`Já existe ${categoria === "CORO" ? "o" : "o hino"} ${rotuloHino(categoria, n as number)} cadastrado.`);
    }

    setSalvando(true);
    try {
      await salvarHino(hino?.id ?? null, { categoria, numero: n as number, nome: formatarTitulo(nome), ativo });
      await onSalvo(`${rotuloHino(categoria, n as number)} ${editando ? "atualizado" : "cadastrado"}.`);
    } catch (e) {
      setErro(e instanceof Error ? e.message : "Não foi possível salvar o hino.");
    } finally {
      setSalvando(false);
    }
  }

  return (
    <form onSubmit={salvar} className="space-y-5">
      <div className="grid grid-cols-2 gap-3">
        <div className="space-y-1.5">
          <label htmlFor="categoria-hino" className="text-sm font-medium text-slate-700">
            Categoria
          </label>
          <select
            id="categoria-hino"
            value={categoria}
            onChange={(e) => setCategoria(e.target.value as CategoriaHino)}
            disabled={salvando || travado}
            className={classeInput}
          >
            <option value="HINO">Hino</option>
            <option value="CORO">Coro (corinho)</option>
          </select>
        </div>
        <div className="space-y-1.5">
          <label htmlFor="numero-hino" className="text-sm font-medium text-slate-700">
            Número
          </label>
          <input
            id="numero-hino"
            type="number"
            inputMode="numeric"
            required
            min={NUMERO_MINIMO}
            max={NUMERO_MAXIMO}
            value={numero}
            onChange={(e) => setNumero(e.target.value)}
            disabled={salvando || travado}
            className={classeInput}
          />
        </div>
      </div>
      {travado && (
        <p className="text-xs text-slate-500">
          Este hino já foi usado em {hino?.em_uso} ensaio(s): só o título e o status podem ser alterados.
        </p>
      )}

      <div className="space-y-1.5">
        <label htmlFor="titulo-hino" className="text-sm font-medium text-slate-700">
          Título
        </label>
        <input
          id="titulo-hino"
          type="text"
          required
          maxLength={TITULO_MAXIMO}
          value={nome}
          onChange={(e) => setNome(e.target.value)}
          disabled={salvando}
          placeholder="Ex: Oh! quão suave é confiar em Jesus"
          className={classeInput}
        />
      </div>

      <label className="flex items-center gap-2 text-sm text-slate-700">
        <input
          type="checkbox"
          checked={ativo}
          onChange={(e) => setAtivo(e.target.checked)}
          disabled={salvando}
          className="h-4 w-4 rounded border-slate-300"
        />
        Ativo (pode ser escolhido nos Dados do Ensaio)
      </label>

      {erro && (
        <p role="alert" className="rounded-lg bg-red-50 px-3 py-2 text-sm text-red-700">
          {erro}
        </p>
      )}

      <Button type="submit" disabled={salvando} className="w-full">
        {salvando ? "Salvando..." : editando ? "Salvar alterações" : "Cadastrar"}
      </Button>
    </form>
  );
}
''',
    "src/modules/hinos/components/ImportarHinos.tsx": r'''"use client";

/**
 * SysMúsica — Importar lista de hinos (conteúdo do painel lateral).
 * Cole um hino por linha ("001 - Título", "1. Título" ou "Coro 1 - Título"). A tela mostra uma prévia antes de
 * gravar. A importação só ACRESCENTA: número que já existe é ignorado (nada é alterado nem apagado).
 */
import { useMemo, useState } from "react";
import Button from "@/components/ui/Button";
import { IMPORTACAO_MAXIMA, interpretarLista, resumirImportacao, rotuloHino, type CategoriaHino, type Hino } from "../regras";
import { importarHinos } from "../services/hinos";

interface ImportarHinosProps {
  existentes: Hino[];
  onImportado: (mensagem: string) => void | Promise<void>;
}

const classeInput =
  "w-full rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 " +
  "placeholder:text-slate-400 shadow-sm focus:border-brand-500 focus:outline-none " +
  "focus:ring-2 focus:ring-brand-200 disabled:cursor-not-allowed disabled:opacity-60";

export default function ImportarHinos({ existentes, onImportado }: ImportarHinosProps) {
  const [texto, setTexto] = useState("");
  const [categoriaPadrao, setCategoriaPadrao] = useState<CategoriaHino>("HINO");
  const [importando, setImportando] = useState(false);
  const [erro, setErro] = useState<string | null>(null);

  const lista = useMemo(() => interpretarLista(texto, categoriaPadrao), [texto, categoriaPadrao]);
  const resumo = useMemo(() => resumirImportacao(lista.itens, existentes), [lista.itens, existentes]);
  const acimaDoLimite = lista.itens.length > IMPORTACAO_MAXIMA;

  async function importar() {
    if (importando || lista.itens.length === 0 || acimaDoLimite) return;
    setImportando(true);
    setErro(null);
    try {
      const r = await importarHinos(lista.itens);
      await onImportado(
        `${r.novos} cadastrado(s)${r.ja_existiam > 0 ? `, ${r.ja_existiam} já existia(m) e foi(ram) mantido(s)` : ""}.`
      );
    } catch (e) {
      setErro(e instanceof Error ? e.message : "Não foi possível importar a lista.");
    } finally {
      setImportando(false);
    }
  }

  return (
    <div className="space-y-5">
      <div className="space-y-1.5">
        <label htmlFor="categoria-importar" className="text-sm font-medium text-slate-700">
          Linhas sem “Coro” são
        </label>
        <select
          id="categoria-importar"
          value={categoriaPadrao}
          onChange={(e) => setCategoriaPadrao(e.target.value as CategoriaHino)}
          disabled={importando}
          className={classeInput}
        >
          <option value="HINO">Hinos do hinário</option>
          <option value="CORO">Coros (corinhos)</option>
        </select>
      </div>

      <div className="space-y-1.5">
        <label htmlFor="texto-importar" className="text-sm font-medium text-slate-700">
          Lista (um por linha)
        </label>
        <textarea
          id="texto-importar"
          rows={10}
          value={texto}
          onChange={(e) => setTexto(e.target.value)}
          disabled={importando}
          placeholder={"001 - Título do hino\n002 - Outro hino\nCoro 1 - Título do coro"}
          className={classeInput + " font-mono"}
        />
      </div>

      {texto.trim() !== "" && (
        <div className="space-y-2 rounded-xl bg-slate-50 p-3 text-sm text-slate-700" aria-live="polite">
          <p>
            <strong>{lista.itens.length}</strong> linha(s) lida(s): <strong>{resumo.novos}</strong> nova(s),{" "}
            <strong>{resumo.jaExistem}</strong> já cadastrada(s)
            {resumo.tituloDiferente > 0 && ` (${resumo.tituloDiferente} com título diferente — o título atual será mantido)`}.
          </p>
          {lista.itens.length > 0 && (
            <p className="text-xs text-slate-500">
              Primeira: {rotuloHino(lista.itens[0].categoria, lista.itens[0].numero)} – {lista.itens[0].nome}
            </p>
          )}
          {acimaDoLimite && (
            <p role="alert" className="text-red-700">
              Máximo de {IMPORTACAO_MAXIMA} itens por vez. Divida a lista.
            </p>
          )}
          {lista.problemas.length > 0 && (
            <div>
              <p className="font-medium text-amber-800">{lista.problemas.length} linha(s) ignorada(s):</p>
              <ul className="mt-1 max-h-40 list-disc space-y-0.5 overflow-y-auto pl-5 text-xs text-amber-900">
                {lista.problemas.slice(0, 50).map((p) => (
                  <li key={p.linha}>
                    Linha {p.linha}: {p.motivo} <span className="text-slate-500">“{p.texto.slice(0, 60)}”</span>
                  </li>
                ))}
              </ul>
            </div>
          )}
        </div>
      )}

      {erro && (
        <p role="alert" className="rounded-lg bg-red-50 px-3 py-2 text-sm text-red-700">
          {erro}
        </p>
      )}

      <Button onClick={() => void importar()} disabled={importando || lista.itens.length === 0 || acimaDoLimite} className="w-full">
        {importando ? "Importando..." : `Importar ${resumo.novos} novo(s)`}
      </Button>
    </div>
  );
}
''',
    "src/modules/hinos/components/TabelaHinos.tsx": r'''"use client";

/**
 * SysMúsica — Tabela de hinos e coros: filtro Todos | Hinos | Coros, busca (número ou título) e status.
 * Hino já usado em ensaio não pode ser excluído (só desativado).
 */
import { useMemo, useState } from "react";
import { Pencil, Search, Trash2 } from "lucide-react";
import Badge from "@/components/ui/Badge";
import BotaoIcone from "@/components/ui/BotaoIcone";
import { filtrarHinos, rotuloHino, type Hino } from "../regras";

type Filtro = "TODOS" | "HINO" | "CORO";

interface TabelaHinosProps {
  hinos: Hino[];
  podeEditar: boolean;
  podeExcluir: boolean;
  alternandoId: string | null;
  onEditar: (hino: Hino) => void;
  onExcluir: (hino: Hino) => void;
  onAlternar: (hino: Hino) => void;
}

const classeCabecalho = "px-4 py-3 text-left text-xs font-semibold uppercase tracking-wide text-slate-500";
const FILTROS: { valor: Filtro; rotulo: string }[] = [
  { valor: "TODOS", rotulo: "Todos" },
  { valor: "HINO", rotulo: "Hinos" },
  { valor: "CORO", rotulo: "Coros" },
];
const POR_PAGINA = 100; // evita desenhar milhares de linhas de uma vez

export default function TabelaHinos({ hinos, podeEditar, podeExcluir, alternandoId, onEditar, onExcluir, onAlternar }: TabelaHinosProps) {
  const [busca, setBusca] = useState("");
  const [filtro, setFiltro] = useState<Filtro>("TODOS");
  const [limite, setLimite] = useState(POR_PAGINA);
  const mostrarAcoes = podeEditar || podeExcluir;

  const filtrados = useMemo(
    () => filtrarHinos(filtro === "TODOS" ? hinos : hinos.filter((h) => h.categoria === filtro), busca),
    [hinos, filtro, busca]
  );
  const visiveis = filtrados.slice(0, limite);

  return (
    <div className="overflow-hidden rounded-2xl border border-slate-200 bg-white shadow-sm">
      <div className="flex flex-col gap-3 border-b border-slate-200 p-4 sm:flex-row sm:items-center sm:justify-between">
        <div className="relative w-full max-w-md">
          <label htmlFor="busca-hino" className="sr-only">
            Pesquisar hino por número ou título
          </label>
          <Search
            className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-slate-400"
            aria-hidden="true"
          />
          <input
            id="busca-hino"
            type="search"
            autoComplete="off"
            value={busca}
            onChange={(e) => {
              setBusca(e.target.value);
              setLimite(POR_PAGINA);
            }}
            placeholder="Pesquisar por número ou título..."
            className="w-full rounded-lg border border-slate-300 bg-white py-2 pl-9 pr-3 text-sm text-slate-900 placeholder:text-slate-400 shadow-sm focus:border-brand-500 focus:outline-none focus:ring-2 focus:ring-brand-200"
          />
        </div>
        <div role="group" aria-label="Filtrar por categoria" className="flex gap-1">
          {FILTROS.map((item) => (
            <button
              key={item.valor}
              type="button"
              aria-pressed={filtro === item.valor}
              onClick={() => {
                setFiltro(item.valor);
                setLimite(POR_PAGINA);
              }}
              className={
                "rounded-lg px-3 py-1.5 text-sm font-medium transition " +
                (filtro === item.valor ? "bg-brand-600 text-white" : "bg-slate-100 text-slate-700 hover:bg-slate-200")
              }
            >
              {item.rotulo}
            </button>
          ))}
        </div>
      </div>

      <div className="overflow-x-auto">
        <table className="min-w-full divide-y divide-slate-200 text-sm">
          <thead className="bg-slate-50">
            <tr>
              <th scope="col" className={classeCabecalho}>Nº</th>
              <th scope="col" className={classeCabecalho}>Título</th>
              <th scope="col" className={classeCabecalho + " text-right"}>Usado em</th>
              <th scope="col" className={classeCabecalho}>Status</th>
              {mostrarAcoes && <th scope="col" className={classeCabecalho + " text-right"}>Ações</th>}
            </tr>
          </thead>
          <tbody className="divide-y divide-slate-100">
            {visiveis.length === 0 ? (
              <tr>
                <td colSpan={mostrarAcoes ? 5 : 4} className="px-4 py-10 text-center text-sm text-slate-500">
                  Nenhum hino encontrado.
                </td>
              </tr>
            ) : (
              visiveis.map((hino) => {
                const rotulo = rotuloHino(hino.categoria, hino.numero);
                return (
                  <tr key={hino.id} className="transition hover:bg-slate-50">
                    <td className="whitespace-nowrap px-4 py-3 font-semibold tabular-nums text-slate-900">{rotulo}</td>
                    <td className="px-4 py-3 text-slate-800">{hino.nome}</td>
                    <td className="px-4 py-3 text-right tabular-nums text-slate-700">{hino.em_uso}</td>
                    <td className="px-4 py-3">
                      {podeEditar ? (
                        <button
                          type="button"
                          role="switch"
                          aria-checked={hino.ativo}
                          aria-label={`${hino.ativo ? "Desativar" : "Ativar"} ${rotulo}`}
                          disabled={alternandoId === hino.id}
                          onClick={() => onAlternar(hino)}
                          className={
                            "relative inline-flex h-6 w-11 items-center rounded-full transition disabled:opacity-50 " +
                            (hino.ativo ? "bg-brand-600" : "bg-slate-300")
                          }
                        >
                          <span
                            className={
                              "inline-block h-5 w-5 transform rounded-full bg-white shadow transition " +
                              (hino.ativo ? "translate-x-5" : "translate-x-0.5")
                            }
                          />
                        </button>
                      ) : (
                        <Badge variante={hino.ativo ? "sucesso" : "neutro"}>{hino.ativo ? "Ativo" : "Inativo"}</Badge>
                      )}
                    </td>
                    {mostrarAcoes && (
                      <td className="px-4 py-3">
                        <div className="flex justify-end gap-1">
                          {podeEditar && <BotaoIcone icone={Pencil} rotulo={`Editar ${rotulo}`} onClick={() => onEditar(hino)} />}
                          {podeExcluir && hino.em_uso === 0 && (
                            <BotaoIcone icone={Trash2} variante="perigo" rotulo={`Excluir ${rotulo}`} onClick={() => onExcluir(hino)} />
                          )}
                        </div>
                      </td>
                    )}
                  </tr>
                );
              })
            )}
          </tbody>
        </table>
      </div>

      <div className="flex items-center justify-between border-t border-slate-200 bg-slate-50 px-4 py-3 text-xs text-slate-500">
        <span>
          Exibindo {visiveis.length} de {filtrados.length} ({hinos.length} no total)
        </span>
        {filtrados.length > visiveis.length && (
          <button type="button" onClick={() => setLimite((l) => l + POR_PAGINA)} className="font-medium text-brand-700 hover:underline">
            Mostrar mais
          </button>
        )}
      </div>
    </div>
  );
}
''',
    "src/modules/hinos/regras.test.ts": r'''import { describe, expect, it } from "vitest";
import {
  compararHinos,
  filtrarHinos,
  formatarTitulo,
  interpretarLista,
  resumirImportacao,
  rotuloCompleto,
  rotuloHino,
  validarHino,
  type Hino,
} from "./regras";

const h = (categoria: Hino["categoria"], numero: number, nome: string) => ({ categoria, numero, nome });

describe("rotuloHino", () => {
  it("hino do hinário tem 3 dígitos e coro aparece como 'Coro N'", () => {
    expect(rotuloHino("HINO", 2)).toBe("002");
    expect(rotuloHino("HINO", 480)).toBe("480");
    expect(rotuloHino("CORO", 1)).toBe("Coro 1");
    expect(rotuloHino("CORO", 12)).toBe("Coro 12");
  });

  it("monta o rótulo completo com o título", () => {
    expect(rotuloCompleto(h("HINO", 2, "Oh! quão suave é confiar em Jesus"))).toBe("002 – Oh! quão suave é confiar em Jesus");
    expect(rotuloCompleto(h("CORO", 3, "Título"))).toBe("Coro 3 – Título");
  });
});

describe("validarHino", () => {
  it("aceita hino e coro corretos", () => {
    expect(validarHino({ categoria: "HINO", numero: 1, nome: "Saudai o nome de Jesus" })).toBeNull();
    expect(validarHino({ categoria: "CORO", numero: 9999, nome: "Ab" })).toBeNull();
  });

  it("recusa categoria inválida, número fora da faixa e título curto ou longo", () => {
    expect(validarHino({ categoria: "X", numero: 1, nome: "Abc" })).toMatch(/hino ou coro/);
    for (const numero of [0, -1, 10000, 1.5, null]) {
      expect(validarHino({ categoria: "HINO", numero, nome: "Abc" }), String(numero)).toMatch(/número/);
    }
    expect(validarHino({ categoria: "HINO", numero: 1, nome: " a " })).toMatch(/título/);
    expect(validarHino({ categoria: "HINO", numero: 1, nome: "x".repeat(151) })).toMatch(/no máximo/);
  });

  it("conta o título sem os espaços extras", () => {
    expect(formatarTitulo("  Louvor,   honra  e glória ")).toBe("Louvor, honra e glória");
  });
});

describe("compararHinos", () => {
  it("hinos antes dos coros, cada grupo pelo número", () => {
    const lista = [h("CORO", 1, "a"), h("HINO", 10, "b"), h("HINO", 2, "c"), h("CORO", 3, "d")];
    expect([...lista].sort(compararHinos).map((x) => rotuloHino(x.categoria, x.numero))).toEqual(["002", "010", "Coro 1", "Coro 3"]);
  });
});

describe("filtrarHinos", () => {
  const lista = [
    h("HINO", 1, "Saudai o nome de Jesus"),
    h("HINO", 2, "Oh! quão suave é confiar em Jesus"),
    h("HINO", 20, "Firmes nas promessas"),
    h("HINO", 200, "Eis a igreja de Deus"),
    h("CORO", 2, "Coro dois"),
    h("CORO", 3, "Terceiro"),
  ];
  const numeros = (r: typeof lista) => r.map((x) => rotuloHino(x.categoria, x.numero));

  it("sem busca devolve tudo", () => {
    expect(filtrarHinos(lista, "")).toHaveLength(6);
    expect(filtrarHinos(lista, "   ")).toHaveLength(6);
  });

  it("busca pelo número (com ou sem zeros à esquerda)", () => {
    expect(numeros(filtrarHinos(lista, "2"))).toEqual(["002", "020", "200", "Coro 2"]);
    // com zeros à esquerda a busca é de hino do hinário (o coro aparece como "Coro 2")
    expect(numeros(filtrarHinos(lista, "002"))).toEqual(["002", "020", "200"]);
    expect(numeros(filtrarHinos(lista, "20"))).toEqual(["020", "200"]);
  });

  it("busca coro pelo rótulo", () => {
    expect(numeros(filtrarHinos(lista, "coro 3"))).toEqual(["Coro 3"]);
    expect(numeros(filtrarHinos(lista, "coro"))).toEqual(["Coro 2", "Coro 3"]);
  });

  it("busca pelo título sem acento e sem diferenciar maiúsculas", () => {
    expect(numeros(filtrarHinos(lista, "QUAO suave"))).toEqual(["002"]);
    expect(numeros(filtrarHinos(lista, "jesus"))).toEqual(["001", "002"]);
    expect(filtrarHinos(lista, "zzz")).toEqual([]);
  });
});

describe("interpretarLista", () => {
  it("lê os formatos comuns de lista", () => {
    const texto = [
      "001 - Saudai o nome de Jesus",
      "2. Oh! quão suave é confiar em Jesus",
      "3) Louvor, honra e glória",
      "004 – Canta, minha alma, canta",
      "5 Firmes nas promessas",
    ].join("\n");
    const { itens, problemas } = interpretarLista(texto, "HINO");
    expect(problemas).toEqual([]);
    expect(itens.map((i) => [i.categoria, i.numero, i.nome])).toEqual([
      ["HINO", 1, "Saudai o nome de Jesus"],
      ["HINO", 2, "Oh! quão suave é confiar em Jesus"],
      ["HINO", 3, "Louvor, honra e glória"],
      ["HINO", 4, "Canta, minha alma, canta"],
      ["HINO", 5, "Firmes nas promessas"],
    ]);
  });

  it("'Coro N' vira coro e a categoria escolhida vale para as demais linhas", () => {
    const { itens } = interpretarLista("Coro 1 - Primeiro\n2 - Segundo", "HINO");
    expect(itens.map((i) => [i.categoria, i.numero])).toEqual([["CORO", 1], ["HINO", 2]]);
    const todosCoros = interpretarLista("1 - Primeiro\n2 - Segundo", "CORO");
    expect(todosCoros.itens.every((i) => i.categoria === "CORO")).toBe(true);
  });

  it("ignora linhas vazias e guarda o número da linha", () => {
    const { itens } = interpretarLista("\n\n7 - Sete\n   \n8 - Oito", "HINO");
    expect(itens.map((i) => i.linha)).toEqual([3, 5]);
  });

  it("separa as linhas com problema: sem número, título curto, número repetido, número grande demais", () => {
    const { itens, problemas } = interpretarLista(
      ["Saudai o nome", "9 - A", "10 - Dez", "10 - Dez de novo", "123456 - Longo", "0 - Zero"].join("\n"),
      "HINO"
    );
    expect(itens.map((i) => i.numero)).toEqual([10]);
    expect(problemas.map((p) => p.linha)).toEqual([1, 2, 4, 5, 6]);
    expect(problemas[0].motivo).toMatch(/número/);
    expect(problemas[1].motivo).toMatch(/título/);
    expect(problemas[2].motivo).toMatch(/repetido/);
  });

  it("o mesmo número em categorias diferentes não é repetido", () => {
    const { itens, problemas } = interpretarLista("1 - Hino um\nCoro 1 - Coro um", "HINO");
    expect(problemas).toEqual([]);
    expect(itens).toHaveLength(2);
  });

  it("aceita fim de linha do Windows", () => {
    expect(interpretarLista("1 - Um\r\n2 - Dois\r\n", "HINO").itens).toHaveLength(2);
  });
});

describe("resumirImportacao", () => {
  it("conta novos, já existentes e títulos diferentes", () => {
    const { itens } = interpretarLista("1 - Saudai o nome de Jesus\n2 - Título novo\n3 - Terceiro", "HINO");
    const resumo = resumirImportacao(itens, [
      h("HINO", 1, "SAUDAI o nome de Jesus"),
      h("HINO", 2, "Título antigo"),
      h("CORO", 3, "Outro"),
    ]);
    expect(resumo).toEqual({ novos: 1, jaExistem: 2, tituloDiferente: 1 });
  });
});
''',
    "src/modules/hinos/regras.ts": r'''/**
 * SysMúsica — Regras puras dos Hinos (sem banco). Testadas em regras.test.ts.
 *
 * Duas categorias: HINO (hinário 5, exibido como "002") e CORO (corinhos, exibidos como "Coro 1", "Coro 2"...).
 * O mesmo número pode existir nas duas categorias (hino 1 e Coro 1). As mesmas regras são aplicadas no banco
 * (migração 0041); aqui ficam as conferências para a tela, a busca e a leitura da lista colada na importação.
 */
import { normalizarTexto } from "@/lib/texto";

export type CategoriaHino = "HINO" | "CORO";

/** Um hino como a função listar_hinos devolve. */
export interface Hino {
  id: string;
  categoria: CategoriaHino;
  numero: number;
  nome: string; // o título do hino
  ativo: boolean;
  em_uso: number; // em quantos ensaios foi usado (hino usado não pode ser excluído, só desativado)
}

export const NUMERO_MINIMO = 1;
export const NUMERO_MAXIMO = 9999;
export const TITULO_MINIMO = 2;
export const TITULO_MAXIMO = 150;
/** Limite de itens por importação (o banco recusa acima disso). */
export const IMPORTACAO_MAXIMA = 2000;

export const ROTULO_CATEGORIA: Record<CategoriaHino, string> = {
  HINO: "Hino",
  CORO: "Coro",
};

/** Como o número aparece: hino do hinário = "002"; coro = "Coro 3". */
export function rotuloHino(categoria: CategoriaHino, numero: number): string {
  return categoria === "CORO" ? `Coro ${numero}` : String(numero).padStart(3, "0");
}

/** "002 – Oh! quão suave é confiar em Jesus" / "Coro 3 – Título". */
export function rotuloCompleto(hino: Pick<Hino, "categoria" | "numero" | "nome">): string {
  return `${rotuloHino(hino.categoria, hino.numero)} – ${hino.nome}`;
}

/** Tira espaços das pontas e os repetidos do título. */
export function formatarTitulo(texto: string): string {
  return texto.trim().replace(/\s+/g, " ");
}

/** Confere os dados de um hino; devolve a mensagem de erro ou null quando está tudo certo. */
export function validarHino(dados: { categoria: string; numero: number | null; nome: string }): string | null {
  if (dados.categoria !== "HINO" && dados.categoria !== "CORO") return "Escolha se é hino ou coro.";
  if (
    dados.numero === null ||
    !Number.isInteger(dados.numero) ||
    dados.numero < NUMERO_MINIMO ||
    dados.numero > NUMERO_MAXIMO
  ) {
    return `Informe o número (de ${NUMERO_MINIMO} a ${NUMERO_MAXIMO}).`;
  }
  const titulo = formatarTitulo(dados.nome);
  if (titulo.length < TITULO_MINIMO) return "Informe o título.";
  if (titulo.length > TITULO_MAXIMO) return `O título pode ter no máximo ${TITULO_MAXIMO} caracteres.`;
  return null;
}

/** Ordem da lista: hinos do hinário primeiro, depois os coros; dentro de cada um, pelo número. */
export function compararHinos(a: Pick<Hino, "categoria" | "numero">, b: Pick<Hino, "categoria" | "numero">): number {
  if (a.categoria !== b.categoria) return a.categoria === "HINO" ? -1 : 1;
  return a.numero - b.numero;
}

/**
 * Busca por número ou título (sem diferenciar acento nem maiúsculas). Exemplos:
 *   "2" ou "002" -> hinos 2, 20..29, 200..299 (e "Coro 2"...); "coro 3" -> Coro 3, 30..39; "suave" -> pelo título.
 */
export function filtrarHinos<T extends Pick<Hino, "categoria" | "numero" | "nome">>(lista: T[], busca: string): T[] {
  const termo = normalizarTexto(busca).replace(/\s+/g, " ");
  if (termo === "") return lista;
  const soNumero = /^\d+$/.test(termo) ? String(Number(termo)) : null;
  return lista.filter((hino) => {
    if (normalizarTexto(hino.nome).includes(termo)) return true;
    if (hino.categoria === "CORO" && normalizarTexto(rotuloHino("CORO", hino.numero)).includes(termo)) return true;
    return soNumero !== null && hino.categoria === "HINO" && String(hino.numero).startsWith(soNumero);
  });
}

// ---------------------------------------------------------------------------
// Importação de uma lista colada (um hino por linha)
// ---------------------------------------------------------------------------

export interface ItemImportacao {
  categoria: CategoriaHino;
  numero: number;
  nome: string;
  linha: number; // linha do texto colado (começa em 1), para avisar onde está um problema
}

export interface ProblemaImportacao {
  linha: number;
  texto: string;
  motivo: string;
}

export interface ListaImportada {
  itens: ItemImportacao[];
  problemas: ProblemaImportacao[];
}

// "001 - Título", "1. Título", "1) Título", "001 Título" e "Coro 1 - Título"
const LINHA_DE_HINO = /^(?:(coro)\s*[-.:]?\s*)?(\d{1,4})(?!\d)\s*[-–—.:)]*\s*(.+)$/i;

/**
 * Lê o texto colado. Linhas começadas por "Coro N" viram coros; as demais usam a categoria escolhida
 * (categoriaPadrao). Linhas vazias são ignoradas; linhas com problema são devolvidas à parte (não são importadas).
 */
export function interpretarLista(texto: string, categoriaPadrao: CategoriaHino): ListaImportada {
  const itens: ItemImportacao[] = [];
  const problemas: ProblemaImportacao[] = [];
  const vistos = new Set<string>();

  texto.split(/\r?\n/).forEach((bruta, indice) => {
    const linha = indice + 1;
    const limpa = bruta.trim();
    if (limpa === "") return;

    const achou = LINHA_DE_HINO.exec(limpa);
    if (!achou) {
      problemas.push({ linha, texto: limpa, motivo: "Não encontrei o número no começo da linha." });
      return;
    }
    const categoria: CategoriaHino = achou[1] ? "CORO" : categoriaPadrao;
    const numero = Number(achou[2]);
    const nome = formatarTitulo(achou[3]);

    const erro = validarHino({ categoria, numero, nome });
    if (erro) {
      problemas.push({ linha, texto: limpa, motivo: erro });
      return;
    }
    const chave = `${categoria}:${numero}`;
    if (vistos.has(chave)) {
      problemas.push({ linha, texto: limpa, motivo: "Número repetido na lista." });
      return;
    }
    vistos.add(chave);
    itens.push({ categoria, numero, nome, linha });
  });

  return { itens, problemas };
}

export interface ResumoImportacao {
  novos: number;
  jaExistem: number; // mesmo número já cadastrado (a importação não altera o título de quem já existe)
  tituloDiferente: number; // dos que já existem, quantos têm título diferente do colado
}

/** Compara a lista lida com o que já está cadastrado. */
export function resumirImportacao(
  itens: ItemImportacao[],
  existentes: Pick<Hino, "categoria" | "numero" | "nome">[]
): ResumoImportacao {
  const mapa = new Map(existentes.map((hino) => [`${hino.categoria}:${hino.numero}`, hino.nome] as const));
  let jaExistem = 0;
  let tituloDiferente = 0;
  for (const item of itens) {
    const atual = mapa.get(`${item.categoria}:${item.numero}`);
    if (atual === undefined) continue;
    jaExistem += 1;
    if (normalizarTexto(atual) !== normalizarTexto(item.nome)) tituloDiferente += 1;
  }
  return { novos: itens.length - jaExistem, jaExistem, tituloDiferente };
}
''',
    "src/modules/hinos/services/hinos.ts": r'''/**
 * SysMúsica — Serviço dos Hinos. Tudo passa por funções do banco (migração 0041), que conferem a permissão
 * de cada operação: a tabela não é acessada diretamente.
 */
import { supabase } from "@/lib/supabase";
import { mensagemDoErro } from "@/lib/erros";
import type { CategoriaHino, Hino, ItemImportacao } from "../regras";

/** Lista os hinos e coros (ativos e desativados): hinos do hinário primeiro, depois os coros. */
export async function listarHinos(): Promise<Hino[]> {
  const { data, error } = await supabase.rpc("listar_hinos");
  if (error) throw new Error(mensagemDoErro(error, "Não foi possível carregar os hinos."));
  return ((data ?? []) as Hino[]).map((hino) => ({ ...hino, numero: Number(hino.numero), em_uso: Number(hino.em_uso) }));
}

export interface DadosHino {
  categoria: CategoriaHino;
  numero: number;
  nome: string;
  ativo: boolean;
}

/** Cria (id = null) ou altera um hino. Devolve o id. */
export async function salvarHino(id: string | null, dados: DadosHino): Promise<string> {
  const { data, error } = await supabase.rpc("salvar_hino", { p_id: id, p_dados: dados });
  if (error) throw new Error(mensagemDoErro(error, "Não foi possível salvar o hino."));
  return data as string;
}

/** Exclui um hino que nunca foi usado em ensaio (o banco recusa se já foi usado). */
export async function excluirHino(id: string): Promise<void> {
  const { error } = await supabase.rpc("excluir_hino", { p_id: id });
  if (error) throw new Error(mensagemDoErro(error, "Não foi possível excluir o hino."));
}

export interface ResultadoImportacao {
  recebidos: number;
  novos: number;
  ja_existiam: number;
}

/** Importa a lista de uma vez. Só acrescenta: número que já existe é ignorado. */
export async function importarHinos(itens: ItemImportacao[]): Promise<ResultadoImportacao> {
  const carga = itens.map(({ categoria, numero, nome }) => ({ categoria, numero, nome }));
  const { data, error } = await supabase.rpc("importar_hinos", { p_itens: carga });
  if (error) throw new Error(mensagemDoErro(error, "Não foi possível importar os hinos."));
  return data as ResultadoImportacao;
}
''',
    "src/modules/tiposEvento/components/FormularioTipoEvento.tsx": r'''"use client";

/**
 * SysMúsica — Formulário de tipo de evento (novo ou edição) — conteúdo do painel lateral.
 * tipo = null -> criar; preenchido -> editar.
 *
 * O campo "Dados do Ensaio" diz se os eventos deste tipo usam a tela Dados do Ensaio e em qual modelo
 * (Local ou Regional). O banco não deixa trocar o modelo de um tipo que já tem ensaios preenchidos.
 */
import { useState, type FormEvent } from "react";
import Button from "@/components/ui/Button";
import { DESCRICAO_MAXIMA, NOME_MAXIMO, ROTULO_MODELO, validarTipoEvento, type ModeloEnsaio, type TipoEvento } from "../regras";
import { salvarTipoEvento } from "../services/tiposEvento";

interface FormularioTipoEventoProps {
  tipo: TipoEvento | null;
  tipos: TipoEvento[]; // todos, para impedir nomes repetidos
  onSalvo: (mensagem: string) => void | Promise<void>;
}

const classeInput =
  "w-full rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 " +
  "placeholder:text-slate-400 shadow-sm focus:border-brand-500 focus:outline-none " +
  "focus:ring-2 focus:ring-brand-200 disabled:cursor-not-allowed disabled:opacity-60";

export default function FormularioTipoEvento({ tipo, tipos, onSalvo }: FormularioTipoEventoProps) {
  const editando = tipo !== null;
  const [nome, setNome] = useState(tipo?.nome ?? "");
  const [descricao, setDescricao] = useState(tipo?.descricao ?? "");
  const [modelo, setModelo] = useState<ModeloEnsaio | "">(tipo?.modelo_ensaio ?? "");
  const [ativo, setAtivo] = useState(tipo?.ativo ?? true);
  const [salvando, setSalvando] = useState(false);
  const [erro, setErro] = useState<string | null>(null);

  async function salvar(submissao: FormEvent<HTMLFormElement>) {
    submissao.preventDefault();
    if (salvando) return; // evita envio duplicado
    setErro(null);

    const erroForm = validarTipoEvento({ nome, descricao }, tipos, tipo?.id);
    if (erroForm) return setErro(erroForm);

    setSalvando(true);
    try {
      await salvarTipoEvento(tipo?.id ?? null, {
        nome: nome.trim().replace(/\s+/g, " "),
        descricao: descricao.trim(),
        modelo_ensaio: modelo === "" ? null : modelo,
        ativo,
      });
      await onSalvo(editando ? `Tipo "${nome.trim()}" atualizado.` : `Tipo "${nome.trim()}" criado.`);
    } catch (e) {
      setErro(e instanceof Error ? e.message : "Não foi possível salvar o tipo de evento.");
    } finally {
      setSalvando(false);
    }
  }

  return (
    <form onSubmit={salvar} className="space-y-5">
      <div className="space-y-1.5">
        <label htmlFor="nome-tipo" className="text-sm font-medium text-slate-700">
          Nome do tipo
        </label>
        <input
          id="nome-tipo"
          type="text"
          required
          maxLength={NOME_MAXIMO}
          value={nome}
          onChange={(e) => setNome(e.target.value)}
          disabled={salvando}
          placeholder="Ex: Ensaio Regional"
          className={classeInput}
        />
        {editando && (tipo?.em_uso ?? 0) > 0 && (
          <p className="text-xs text-slate-500">
            Ao renomear, os {tipo?.em_uso} evento(s) deste tipo passam a mostrar o novo nome.
          </p>
        )}
      </div>

      <div className="space-y-1.5">
        <label htmlFor="descricao-tipo" className="text-sm font-medium text-slate-700">
          Descrição <span className="font-normal text-slate-400">(opcional)</span>
        </label>
        <textarea
          id="descricao-tipo"
          rows={3}
          maxLength={DESCRICAO_MAXIMA}
          value={descricao}
          onChange={(e) => setDescricao(e.target.value)}
          disabled={salvando}
          className={classeInput}
        />
      </div>

      <div className="space-y-1.5">
        <label htmlFor="modelo-tipo" className="text-sm font-medium text-slate-700">
          Dados do Ensaio
        </label>
        <select
          id="modelo-tipo"
          value={modelo}
          onChange={(e) => setModelo(e.target.value as ModeloEnsaio | "")}
          disabled={salvando}
          className={classeInput}
        >
          <option value="">Não usa (sem tela de ensaio)</option>
          <option value="LOCAL">{ROTULO_MODELO.LOCAL}</option>
          <option value="REGIONAL">{ROTULO_MODELO.REGIONAL}</option>
        </select>
        <p className="text-xs text-slate-500">
          Regional: quem atende é sempre Ancião e há a palavra. Local: quem atende pode ser Ancião, Diácono ou
          Cooperador, sem palavra.
        </p>
      </div>

      <label className="flex items-center gap-2 text-sm text-slate-700">
        <input
          type="checkbox"
          checked={ativo}
          onChange={(e) => setAtivo(e.target.checked)}
          disabled={salvando}
          className="h-4 w-4 rounded border-slate-300"
        />
        Ativo (aparece na lista de tipos ao criar um evento)
      </label>

      {erro && (
        <p role="alert" className="rounded-lg bg-red-50 px-3 py-2 text-sm text-red-700">
          {erro}
        </p>
      )}

      <Button type="submit" disabled={salvando} className="w-full">
        {salvando ? "Salvando..." : editando ? "Salvar alterações" : "Criar tipo"}
      </Button>
    </form>
  );
}
''',
    "src/modules/tiposEvento/components/TabelaTiposEvento.tsx": r'''"use client";

/**
 * SysMúsica — Tabela de tipos de evento, com busca e botão de ativar/desativar.
 * Tipo já usado por algum evento não pode ser excluído (só desativado); o banco confere de novo.
 */
import { useState } from "react";
import { Pencil, Search, Trash2 } from "lucide-react";
import Badge from "@/components/ui/Badge";
import BotaoIcone from "@/components/ui/BotaoIcone";
import { filtrarTipos, rotuloDoModelo, type TipoEvento } from "../regras";

interface TabelaTiposEventoProps {
  tipos: TipoEvento[];
  podeEditar: boolean;
  podeExcluir: boolean;
  alternandoId: string | null; // tipo cujo status está sendo trocado (trava o botão)
  onEditar: (tipo: TipoEvento) => void;
  onExcluir: (tipo: TipoEvento) => void;
  onAlternar: (tipo: TipoEvento) => void;
}

const classeCabecalho = "px-4 py-3 text-left text-xs font-semibold uppercase tracking-wide text-slate-500";

export default function TabelaTiposEvento({
  tipos,
  podeEditar,
  podeExcluir,
  alternandoId,
  onEditar,
  onExcluir,
  onAlternar,
}: TabelaTiposEventoProps) {
  const [busca, setBusca] = useState("");
  const mostrarAcoes = podeEditar || podeExcluir;
  const filtrados = filtrarTipos(tipos, busca);

  return (
    <div className="overflow-hidden rounded-2xl border border-slate-200 bg-white shadow-sm">
      <div className="border-b border-slate-200 p-4">
        <div className="relative max-w-md">
          <label htmlFor="busca-tipo" className="sr-only">
            Pesquisar tipo de evento
          </label>
          <Search
            className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-slate-400"
            aria-hidden="true"
          />
          <input
            id="busca-tipo"
            type="search"
            autoComplete="off"
            value={busca}
            onChange={(e) => setBusca(e.target.value)}
            placeholder="Pesquisar tipo de evento..."
            className="w-full rounded-lg border border-slate-300 bg-white py-2 pl-9 pr-3 text-sm text-slate-900 placeholder:text-slate-400 shadow-sm focus:border-brand-500 focus:outline-none focus:ring-2 focus:ring-brand-200"
          />
        </div>
      </div>

      <div className="overflow-x-auto">
        <table className="min-w-full divide-y divide-slate-200 text-sm">
          <thead className="bg-slate-50">
            <tr>
              <th scope="col" className={classeCabecalho}>Tipo</th>
              <th scope="col" className={classeCabecalho}>Dados do Ensaio</th>
              <th scope="col" className={classeCabecalho + " text-right"}>Eventos</th>
              <th scope="col" className={classeCabecalho}>Status</th>
              {mostrarAcoes && <th scope="col" className={classeCabecalho + " text-right"}>Ações</th>}
            </tr>
          </thead>
          <tbody className="divide-y divide-slate-100">
            {filtrados.length === 0 ? (
              <tr>
                <td colSpan={mostrarAcoes ? 5 : 4} className="px-4 py-10 text-center text-sm text-slate-500">
                  Nenhum tipo de evento encontrado.
                </td>
              </tr>
            ) : (
              filtrados.map((tipo) => (
                <tr key={tipo.id} className="transition hover:bg-slate-50">
                  <td className="px-4 py-3">
                    <p className="font-medium text-slate-900">{tipo.nome}</p>
                    {tipo.descricao && <p className="text-xs text-slate-500">{tipo.descricao}</p>}
                  </td>
                  <td className="px-4 py-3">
                    <Badge variante={tipo.modelo_ensaio ? "marca" : "neutro"}>{rotuloDoModelo(tipo.modelo_ensaio)}</Badge>
                  </td>
                  <td className="px-4 py-3 text-right tabular-nums text-slate-700">{tipo.em_uso}</td>
                  <td className="px-4 py-3">
                    {podeEditar ? (
                      <button
                        type="button"
                        role="switch"
                        aria-checked={tipo.ativo}
                        aria-label={`${tipo.ativo ? "Desativar" : "Ativar"} ${tipo.nome}`}
                        disabled={alternandoId === tipo.id}
                        onClick={() => onAlternar(tipo)}
                        className={
                          "relative inline-flex h-6 w-11 items-center rounded-full transition disabled:opacity-50 " +
                          (tipo.ativo ? "bg-brand-600" : "bg-slate-300")
                        }
                      >
                        <span
                          className={
                            "inline-block h-5 w-5 transform rounded-full bg-white shadow transition " +
                            (tipo.ativo ? "translate-x-5" : "translate-x-0.5")
                          }
                        />
                      </button>
                    ) : (
                      <Badge variante={tipo.ativo ? "sucesso" : "neutro"}>{tipo.ativo ? "Ativo" : "Inativo"}</Badge>
                    )}
                  </td>
                  {mostrarAcoes && (
                    <td className="px-4 py-3">
                      <div className="flex justify-end gap-1">
                        {podeEditar && (
                          <BotaoIcone icone={Pencil} rotulo={`Editar ${tipo.nome}`} onClick={() => onEditar(tipo)} />
                        )}
                        {podeExcluir && tipo.em_uso === 0 && (
                          <BotaoIcone
                            icone={Trash2}
                            variante="perigo"
                            rotulo={`Excluir ${tipo.nome}`}
                            onClick={() => onExcluir(tipo)}
                          />
                        )}
                      </div>
                    </td>
                  )}
                </tr>
              ))
            )}
          </tbody>
        </table>
      </div>

      <div className="border-t border-slate-200 bg-slate-50 px-4 py-3 text-xs text-slate-500">
        Exibindo {filtrados.length} de {tipos.length} tipo(s)
      </div>
    </div>
  );
}
''',
    "src/modules/tiposEvento/regras.test.ts": r'''import { describe, expect, it } from "vitest";
import {
  DESCRICAO_MAXIMA,
  filtrarTipos,
  formatarNomeTipo,
  rotuloDoModelo,
  tiposParaEscolher,
  validarTipoEvento,
} from "./regras";

const existentes = [
  { id: "1", nome: "Ensaio Regional" },
  { id: "2", nome: "Reunião Musical" },
];

describe("validarTipoEvento", () => {
  it("aceita um nome novo, com ou sem descrição", () => {
    expect(validarTipoEvento({ nome: "Culto Oficial", descricao: "" }, existentes)).toBeNull();
    expect(validarTipoEvento({ nome: "Culto Oficial", descricao: "Culto com participação musical" }, existentes)).toBeNull();
  });

  it("recusa nome curto (ignorando espaços), longo e descrição longa", () => {
    expect(validarTipoEvento({ nome: "  ab ", descricao: "" }, existentes)).toMatch(/mínimo/);
    expect(validarTipoEvento({ nome: "x".repeat(61), descricao: "" }, existentes)).toMatch(/no máximo/);
    expect(validarTipoEvento({ nome: "Novo tipo", descricao: "a".repeat(DESCRICAO_MAXIMA + 1) }, existentes)).toMatch(/descrição/);
  });

  it("recusa nome repetido sem diferenciar acento, maiúsculas e espaços", () => {
    expect(validarTipoEvento({ nome: "reuniao   MUSICAL", descricao: "" }, existentes)).toMatch(/Já existe/);
  });

  it("na edição, o próprio tipo não conta como repetido", () => {
    expect(validarTipoEvento({ nome: "Reunião Musical", descricao: "" }, existentes, "2")).toBeNull();
    expect(validarTipoEvento({ nome: "Reunião Musical", descricao: "" }, existentes, "1")).toMatch(/Já existe/);
  });
});

describe("formatarNomeTipo e rotuloDoModelo", () => {
  it("limpa os espaços", () => {
    expect(formatarNomeTipo("  Ensaio   Técnico ")).toBe("Ensaio Técnico");
  });

  it("mostra o modelo do ensaio ou 'Não usa'", () => {
    expect(rotuloDoModelo("LOCAL")).toBe("Ensaio Local");
    expect(rotuloDoModelo("REGIONAL")).toBe("Ensaio Regional");
    expect(rotuloDoModelo(null)).toBe("Não usa");
  });
});

describe("filtrarTipos", () => {
  const lista = [
    { nome: "Ensaio Regional", descricao: "Ensaio do ministério regional" },
    { nome: "Congresso", descricao: "Congresso ou convenção" },
    { nome: "Outro", descricao: null },
  ];
  it("busca no nome e na descrição, sem acento", () => {
    expect(filtrarTipos(lista, "").length).toBe(3);
    expect(filtrarTipos(lista, "convencao").map((t) => t.nome)).toEqual(["Congresso"]);
    expect(filtrarTipos(lista, "ENSAIO").map((t) => t.nome)).toEqual(["Ensaio Regional"]);
    expect(filtrarTipos(lista, "zzz")).toEqual([]);
  });
});

describe("tiposParaEscolher", () => {
  const lista = [
    { id: "a", ativo: true },
    { id: "b", ativo: false },
    { id: "c", ativo: false },
  ];
  it("só os ativos para um evento novo", () => {
    expect(tiposParaEscolher(lista, null).map((t) => t.id)).toEqual(["a"]);
  });
  it("na edição mantém o tipo atual do evento, mesmo desativado", () => {
    expect(tiposParaEscolher(lista, "b").map((t) => t.id)).toEqual(["a", "b"]);
  });
});
''',
    "src/modules/tiposEvento/regras.ts": r'''/**
 * SysMúsica — Regras puras dos Tipos de evento (sem banco). Testadas em regras.test.ts.
 *
 * O tipo do evento (Ensaio Regional, Ensaio Local, Culto Oficial...) é um cadastro. Cada tipo diz se usa a tela
 * "Dados do Ensaio" e em qual modelo: LOCAL, REGIONAL ou nenhum. As mesmas regras valem no banco (migração 0041).
 */
import { normalizarTexto } from "@/lib/texto";

export type ModeloEnsaio = "LOCAL" | "REGIONAL";

/** Um tipo como a função listar_tipos_evento devolve. */
export interface TipoEvento {
  id: string;
  nome: string;
  descricao: string | null;
  modelo_ensaio: ModeloEnsaio | null; // nulo = o tipo não usa a tela Dados do Ensaio
  ativo: boolean;
  em_uso: number; // quantos eventos usam o tipo (tipo usado não pode ser excluído, só desativado)
}

export const NOME_MINIMO = 3;
export const NOME_MAXIMO = 60;
export const DESCRICAO_MAXIMA = 200;

export const ROTULO_MODELO: Record<ModeloEnsaio, string> = {
  LOCAL: "Ensaio Local",
  REGIONAL: "Ensaio Regional",
};

/** Texto para a coluna "Dados do Ensaio" da tabela. */
export function rotuloDoModelo(modelo: ModeloEnsaio | null): string {
  return modelo ? ROTULO_MODELO[modelo] : "Não usa";
}

/** Tira espaços das pontas e os repetidos. */
export function formatarNomeTipo(texto: string): string {
  return texto.trim().replace(/\s+/g, " ");
}

/** Confere o formulário; devolve a mensagem de erro ou null quando está tudo certo. */
export function validarTipoEvento(
  dados: { nome: string; descricao: string },
  existentes: Pick<TipoEvento, "id" | "nome">[],
  idEmEdicao?: string
): string | null {
  const nome = formatarNomeTipo(dados.nome);
  if (nome.length < NOME_MINIMO) return `Informe o nome do tipo de evento (mínimo de ${NOME_MINIMO} caracteres).`;
  if (nome.length > NOME_MAXIMO) return `O nome pode ter no máximo ${NOME_MAXIMO} caracteres.`;
  if (dados.descricao.trim().length > DESCRICAO_MAXIMA) {
    return `A descrição pode ter no máximo ${DESCRICAO_MAXIMA} caracteres.`;
  }
  const chave = normalizarTexto(nome);
  if (existentes.some((tipo) => tipo.id !== idEmEdicao && normalizarTexto(tipo.nome) === chave)) {
    return "Já existe um tipo de evento com este nome.";
  }
  return null;
}

/** Filtra a tabela pela busca no nome ou na descrição (sem acento, sem diferenciar maiúsculas). */
export function filtrarTipos<T extends Pick<TipoEvento, "nome" | "descricao">>(lista: T[], busca: string): T[] {
  const termo = normalizarTexto(busca);
  if (termo === "") return lista;
  return lista.filter(
    (tipo) => normalizarTexto(tipo.nome).includes(termo) || normalizarTexto(tipo.descricao ?? "").includes(termo)
  );
}

/**
 * Tipos que podem ser escolhidos no formulário de evento: os ativos e, ao editar, também o tipo atual do evento
 * (mesmo que já tenha sido desativado), para a tela não "perder" a escolha.
 */
export function tiposParaEscolher<T extends Pick<TipoEvento, "id" | "ativo">>(lista: T[], idAtual: string | null): T[] {
  return lista.filter((tipo) => tipo.ativo || tipo.id === idAtual);
}
''',
    "src/modules/tiposEvento/services/tiposEvento.ts": r'''/**
 * SysMúsica — Serviço dos Tipos de evento. Tudo passa por funções do banco (migração 0041), que conferem a
 * permissão de cada operação: a tabela não é acessada diretamente.
 */
import { supabase } from "@/lib/supabase";
import { mensagemDoErro } from "@/lib/erros";
import type { ModeloEnsaio, TipoEvento } from "../regras";

/** Lista os tipos (ativos e desativados), na ordem de cadastro. */
export async function listarTiposEvento(): Promise<TipoEvento[]> {
  const { data, error } = await supabase.rpc("listar_tipos_evento");
  if (error) throw new Error(mensagemDoErro(error, "Não foi possível carregar os tipos de evento."));
  return ((data ?? []) as TipoEvento[]).map((tipo) => ({ ...tipo, em_uso: Number(tipo.em_uso) }));
}

export interface DadosTipoEvento {
  nome: string;
  descricao: string;
  modelo_ensaio: ModeloEnsaio | null;
  ativo: boolean;
}

/** Cria (id = null) ou altera um tipo. Devolve o id. */
export async function salvarTipoEvento(id: string | null, dados: DadosTipoEvento): Promise<string> {
  const { data, error } = await supabase.rpc("salvar_tipo_evento", {
    p_id: id,
    p_dados: {
      nome: dados.nome,
      descricao: dados.descricao.trim() === "" ? null : dados.descricao,
      modelo_ensaio: dados.modelo_ensaio,
      ativo: dados.ativo,
    },
  });
  if (error) throw new Error(mensagemDoErro(error, "Não foi possível salvar o tipo de evento."));
  return data as string;
}

/** Exclui um tipo que nunca foi usado (o banco recusa se algum evento usar). */
export async function excluirTipoEvento(id: string): Promise<void> {
  const { error } = await supabase.rpc("excluir_tipo_evento", { p_id: id });
  if (error) throw new Error(mensagemDoErro(error, "Não foi possível excluir o tipo de evento."));
}
''',
    "supabase/migrations/0041_dados_do_ensaio_hinos.sql": r'''-- 0041 — Parte 8: Tipos de evento, Hinos e Dados do Ensaio
--
-- O QUE ESTA MIGRAÇÃO FAZ
--   A) Tipo do Evento vira um cadastro (tipos_evento). O evento ganha eventos.tipo_evento_id; a coluna de texto
--      eventos.tipo continua existindo (relatórios, painel e portaria a usam) e é preenchida SOZINHA com o nome do
--      tipo escolhido. Eventos antigos "Ensaio Local" e "Ensaio Regional" são ligados ao tipo automaticamente;
--      os demais (ex.: "Ensaio") continuam como estão até alguém editar o evento e escolher o tipo.
--      Cada tipo diz se usa a tela "Dados do Ensaio" e em qual modelo (LOCAL, REGIONAL ou nenhum).
--   B) Hinos: lista editável (hinário 5 = categoria HINO; corinhos = categoria CORO, exibidos como "Coro 1", "Coro 2"...).
--   C) Dados do Ensaio (só ensaios Local e Regional): quem atendeu, hino de abertura, palavra (só no Regional),
--      de 1 a 3 encarregados (nome + Cidade/UF) e os hinos executados (sem repetir; o de abertura fica fora da lista).
--   D) Permissões novas (só o Administrador recebe; os demais grupos são liberados em Grupos e permissões):
--        tipoevento.visualizar|criar|editar|excluir, hinos.visualizar|criar|editar|excluir,
--        ensaio.visualizar, ensaio.registrar (preencher os Dados do Ensaio).
--   E) Backup (backup_aplicar) passa a conhecer as tabelas novas; a Auditoria registra tipos, hinos e ensaios.
--
-- SEGURANÇA: as tabelas novas têm RLS ligado e NENHUM acesso direto para anon/authenticated; tudo passa por
-- funções (security definer, search_path fixo) que conferem permissão e abrangência.
begin;
set local check_function_bodies = off;

do $$
begin
  if to_regclass('public.eventos') is null or to_regclass('public.permissoes') is null
     or to_regprocedure('public.exigir_permissao(text)') is null
     or to_regprocedure('public.evento_na_abrangencia(uuid)') is null
     or to_regprocedure('public.registrar_auditoria(text, text, uuid, jsonb)') is null
     or to_regprocedure('public.auditar_tabela()') is null
     or to_regprocedure('public.normalizar_texto(text)') is null
     or to_regprocedure('public.portaria_encerrada(timestamptz, timestamptz)') is null
     or to_regprocedure('public.backup_aplicar(uuid, jsonb, jsonb)') is null then
    raise exception 'Aplique primeiro as migrações até a 0040. Nada foi alterado.';
  end if;
  if to_regclass('public.tipos_evento') is not null then
    raise exception 'A migração 0041 já foi aplicada. Nada foi alterado.';
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 1. Funções de apoio
-- ---------------------------------------------------------------------------
-- Tira espaços das pontas e repetidos; vazio vira nulo.
create or replace function public.limpar_espacos(p_texto text)
returns text language sql immutable set search_path to 'public'
as $$ select nullif(btrim(regexp_replace(coalesce(p_texto, ''), '\s+', ' ', 'g')), '') $$;

-- Como o hino aparece para as pessoas: hino do hinário = "002"; corinho = "Coro 3".
create or replace function public.rotulo_hino(p_categoria text, p_numero integer)
returns text language sql immutable set search_path to 'public'
as $$ select case when p_categoria = 'CORO' then 'Coro ' || p_numero::text else lpad(p_numero::text, 3, '0') end $$;

-- ---------------------------------------------------------------------------
-- 2. Tipos de evento
-- ---------------------------------------------------------------------------
create table public.tipos_evento (
  id            uuid primary key default gen_random_uuid(),
  nome          text not null check (char_length(btrim(nome)) between 3 and 60),
  descricao     text check (descricao is null or char_length(descricao) <= 200),
  -- Qual modelo da tela "Dados do Ensaio" o tipo usa (nulo = o tipo não usa essa tela)
  modelo_ensaio text check (modelo_ensaio is null or modelo_ensaio in ('LOCAL', 'REGIONAL')),
  ativo         boolean not null default true,
  ordem         integer not null default 100,   -- só organiza a lista (os 8 iniciais vêm de 1 a 8)
  criado_em     timestamptz not null default now(),
  atualizado_em timestamptz not null default now()
);
create unique index tipos_evento_nome_unico on public.tipos_evento (lower(btrim(nome)));

alter table public.tipos_evento enable row level security;
revoke all on public.tipos_evento from public, anon, authenticated;

insert into public.tipos_evento (nome, descricao, modelo_ensaio, ordem) values
  ('Ensaio Regional',  'Ensaio do ministério regional',        'REGIONAL', 1),
  ('Ensaio Local',     'Ensaio do ministério local',           'LOCAL',    2),
  ('Reunião Musical',  'Reunião de músicos e organistas',      null,       3),
  ('Culto Oficial',    'Culto com participação musical',       null,       4),
  ('Treinamento',      'Treinamento de músicos',               null,       5),
  ('Congresso',        'Congresso ou convenção',               null,       6),
  ('Visita Oficial',   'Visita de irmãos oficiais',            null,       7),
  ('Outro',            'Outros tipos de evento',               null,       8);

-- O evento aponta para o tipo; eventos.tipo (texto) é mantido igual ao nome do tipo por um gatilho
alter table public.eventos add column tipo_evento_id uuid references public.tipos_evento(id);
create index eventos_tipo_evento_idx on public.eventos (tipo_evento_id);
-- Colunas liberadas uma a uma (o cliente lê com select("*") e a edição só toca nas colunas permitidas)
grant select (tipo_evento_id) on public.eventos to authenticated;
grant insert (tipo_evento_id) on public.eventos to authenticated;
grant update (tipo_evento_id) on public.eventos to authenticated;

create or replace function public.eventos_sincroniza_tipo()
returns trigger
language plpgsql security definer set search_path to 'public'
as $$
declare
  v public.tipos_evento;
begin
  if new.tipo_evento_id is null then
    return new;   -- evento antigo, ainda sem tipo cadastrado: o texto de eventos.tipo é mantido
  end if;
  if tg_op = 'UPDATE' and new.tipo_evento_id is not distinct from old.tipo_evento_id then
    return new;   -- o tipo não mudou
  end if;
  select * into v from public.tipos_evento t where t.id = new.tipo_evento_id;
  if not found then
    raise exception 'Tipo de evento não encontrado.';
  end if;
  -- Tipo desativado não pode ser escolhido de novo (a restauração de backup não é barrada)
  if not v.ativo and coalesce(current_setting('sysmusica.restaurando', true), '') = '' then
    raise exception 'O tipo de evento "%" está desativado. Escolha outro tipo.', v.nome;
  end if;
  new.tipo := v.nome;
  return new;
end;
$$;

create trigger trg_eventos_sincroniza_tipo before insert or update on public.eventos
  for each row execute function public.eventos_sincroniza_tipo();

-- Liga os eventos antigos cujo texto é igual ao nome de um tipo (ignorando acento e maiúsculas)
select set_config('sysmusica.restaurando', 'sim', true);
update public.eventos e
   set tipo_evento_id = t.id
  from public.tipos_evento t
 where e.tipo_evento_id is null
   and public.normalizar_texto(btrim(e.tipo)) = public.normalizar_texto(t.nome);
select set_config('sysmusica.restaurando', '', true);

-- ---------------------------------------------------------------------------
-- 3. Hinos
-- ---------------------------------------------------------------------------
create table public.hinos (
  id            uuid primary key default gen_random_uuid(),
  categoria     text not null check (categoria in ('HINO', 'CORO')),
  numero        integer not null check (numero between 1 and 9999),
  nome          text not null check (char_length(btrim(nome)) between 2 and 150),   -- o título do hino
  ativo         boolean not null default true,
  criado_em     timestamptz not null default now(),
  atualizado_em timestamptz not null default now(),
  constraint hinos_categoria_numero_unico unique (categoria, numero)
);
alter table public.hinos enable row level security;
revoke all on public.hinos from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 4. Dados do Ensaio
-- ---------------------------------------------------------------------------
create table public.dados_ensaio (
  id               uuid primary key default gen_random_uuid(),
  evento_id        uuid not null unique references public.eventos(id),
  atende_cargo     text not null check (atende_cargo in ('ANCIAO', 'DIACONO', 'COOPERADOR_OFICIO', 'COOPERADOR_RJM')),
  atende_nome      text not null check (char_length(btrim(atende_nome)) between 3 and 120),
  palavra          text check (palavra is null or char_length(palavra) <= 500),   -- só no ensaio Regional
  hino_abertura_id uuid not null references public.hinos(id),
  criado_por       uuid,
  criado_em        timestamptz not null default now(),
  atualizado_por   uuid,
  atualizado_em    timestamptz not null default now()
);

create table public.dados_ensaio_encarregados (
  id              uuid primary key default gen_random_uuid(),
  dados_ensaio_id uuid not null references public.dados_ensaio(id) on delete cascade,
  ordem           smallint not null check (ordem between 1 and 3),   -- no máximo 3 encarregados
  nome            text not null check (char_length(btrim(nome)) between 3 and 120),
  cidade_uf       text not null check (cidade_uf ~ '^.{2,}-[A-Z]{2}$'),   -- ex.: "São Paulo-SP"
  unique (dados_ensaio_id, ordem)
);

create table public.dados_ensaio_hinos (
  id              uuid primary key default gen_random_uuid(),
  dados_ensaio_id uuid not null references public.dados_ensaio(id) on delete cascade,
  hino_id         uuid not null references public.hinos(id),
  ordem           smallint not null check (ordem between 1 and 100),
  unique (dados_ensaio_id, hino_id),   -- o mesmo hino não repete no ensaio
  unique (dados_ensaio_id, ordem)
);

alter table public.dados_ensaio enable row level security;
alter table public.dados_ensaio_encarregados enable row level security;
alter table public.dados_ensaio_hinos enable row level security;
revoke all on public.dados_ensaio, public.dados_ensaio_encarregados, public.dados_ensaio_hinos
  from public, anon, authenticated;

-- O hino de abertura NÃO conta entre os hinos executados: o banco impede o mesmo hino nos dois lugares
create or replace function public.dados_ensaio_hino_nao_e_abertura()
returns trigger language plpgsql security definer set search_path to 'public'
as $$
begin
  if exists (select 1 from public.dados_ensaio d where d.id = new.dados_ensaio_id and d.hino_abertura_id = new.hino_id) then
    raise exception 'O hino de abertura não pode estar entre os hinos executados.';
  end if;
  return new;
end;
$$;
create trigger trg_dados_ensaio_hinos_abertura before insert or update on public.dados_ensaio_hinos
  for each row execute function public.dados_ensaio_hino_nao_e_abertura();

create or replace function public.dados_ensaio_abertura_nao_e_executado()
returns trigger language plpgsql security definer set search_path to 'public'
as $$
begin
  if exists (select 1 from public.dados_ensaio_hinos h where h.dados_ensaio_id = new.id and h.hino_id = new.hino_abertura_id) then
    raise exception 'O hino de abertura não pode estar entre os hinos executados.';
  end if;
  return new;
end;
$$;
create trigger trg_dados_ensaio_abertura before update of hino_abertura_id on public.dados_ensaio
  for each row execute function public.dados_ensaio_abertura_nao_e_executado();

-- Auditoria: tipos e hinos pela função comum; o ensaio registra uma linha própria (com encarregados e hinos)
create trigger trg_auditar after insert or update or delete on public.tipos_evento
  for each row execute function public.auditar_tabela();
create trigger trg_auditar after insert or update or delete on public.hinos
  for each row execute function public.auditar_tabela();

-- ---------------------------------------------------------------------------
-- 5. Permissões (iguais a CATALOGO_PERMISSOES em src/lib/permissoes.ts). Só o Administrador recebe;
--    os demais grupos são liberados na tela Grupos e permissões.
-- ---------------------------------------------------------------------------
insert into public.permissoes (codigo, modulo, acao, descricao) values
  ('tipoevento.visualizar', 'Tipos de evento', 'Visualizar', 'Ver a lista de tipos de evento'),
  ('tipoevento.criar',      'Tipos de evento', 'Criar',      'Cadastrar tipos de evento'),
  ('tipoevento.editar',     'Tipos de evento', 'Editar',     'Editar, ativar e desativar tipos de evento'),
  ('tipoevento.excluir',    'Tipos de evento', 'Excluir',    'Excluir tipos de evento que nunca foram usados'),
  ('hinos.visualizar',        'Hinos',           'Visualizar', 'Ver a lista de hinos'),
  ('hinos.criar',             'Hinos',           'Criar',      'Cadastrar e importar hinos'),
  ('hinos.editar',            'Hinos',           'Editar',     'Editar, ativar e desativar hinos'),
  ('hinos.excluir',           'Hinos',           'Excluir',    'Excluir hinos que nunca foram usados'),
  ('ensaio.visualizar',       'Dados do Ensaio', 'Visualizar', 'Ver os dados dos ensaios Local e Regional'),
  ('ensaio.registrar',        'Dados do Ensaio', 'Preencher',  'Preencher e alterar os Dados do Ensaio (quem atendeu, palavra, encarregados e hinos)')
on conflict (codigo) do update
  set modulo = excluded.modulo, acao = excluded.acao, descricao = excluded.descricao;

insert into public.grupo_permissoes (grupo_id, permissao_codigo)
select g.id, p.codigo
  from public.grupos g
  cross join public.permissoes p
 where g.sistema and g.nome = 'Administrador'
   and p.codigo in ('tipoevento.visualizar', 'tipoevento.criar', 'tipoevento.editar', 'tipoevento.excluir',
                    'hinos.visualizar', 'hinos.criar', 'hinos.editar', 'hinos.excluir',
                    'ensaio.visualizar', 'ensaio.registrar')
on conflict do nothing;

-- ---------------------------------------------------------------------------
-- 6. Funções — Tipos de evento
-- ---------------------------------------------------------------------------
create or replace function public.listar_tipos_evento()
returns table (id uuid, nome text, descricao text, modelo_ensaio text, ativo boolean, em_uso bigint)
language plpgsql stable security definer set search_path to 'public'
as $$
begin
  -- Quem cadastra ou edita eventos precisa ver a lista para escolher o tipo
  if not public.tem_alguma_permissao(array['tipoevento.visualizar', 'eventos.criar', 'eventos.editar']) then
    raise exception 'Você não tem permissão para esta operação.' using errcode = '42501';
  end if;
  return query
    select t.id, t.nome, t.descricao, t.modelo_ensaio, t.ativo,
           (select count(*) from public.eventos e where e.tipo_evento_id = t.id and e.excluido_em is null)
      from public.tipos_evento t
     order by t.ordem, lower(t.nome);
end;
$$;

create or replace function public.salvar_tipo_evento(p_id uuid, p_dados jsonb)
returns uuid
language plpgsql security definer set search_path to 'public'
as $$
declare
  v_nome   text := public.limpar_espacos(p_dados ->> 'nome');
  v_desc   text := public.limpar_espacos(p_dados ->> 'descricao');
  v_modelo text := nullif(btrim(coalesce(p_dados ->> 'modelo_ensaio', '')), '');
  v_ativo  boolean := coalesce((p_dados ->> 'ativo')::boolean, true);
  v_id     uuid;
  v_ant    public.tipos_evento;
begin
  if p_id is null then
    perform public.exigir_permissao('tipoevento.criar');
  else
    perform public.exigir_permissao('tipoevento.editar');
  end if;

  if v_nome is null or char_length(v_nome) < 3 then
    raise exception 'Informe o nome do tipo de evento (mínimo de 3 caracteres).';
  end if;
  if char_length(v_nome) > 60 then
    raise exception 'O nome pode ter no máximo 60 caracteres.';
  end if;
  if v_desc is not null and char_length(v_desc) > 200 then
    raise exception 'A descrição pode ter no máximo 200 caracteres.';
  end if;
  if v_modelo is not null and v_modelo not in ('LOCAL', 'REGIONAL') then
    raise exception 'Modelo de Dados do Ensaio inválido.';
  end if;
  if exists (select 1 from public.tipos_evento t
              where public.normalizar_texto(t.nome) = public.normalizar_texto(v_nome)
                and (p_id is null or t.id <> p_id)) then
    raise exception 'Já existe um tipo de evento com este nome.';
  end if;

  if p_id is null then
    insert into public.tipos_evento (nome, descricao, modelo_ensaio, ativo)
    values (v_nome, v_desc, v_modelo, v_ativo)
    returning id into v_id;
  else
    select * into v_ant from public.tipos_evento t where t.id = p_id for update;
    if not found then
      raise exception 'Tipo de evento não encontrado.';
    end if;
    -- Mudar o modelo de um tipo que já tem ensaios preenchidos deixaria os dados sem sentido
    if v_ant.modelo_ensaio is distinct from v_modelo
       and exists (select 1 from public.dados_ensaio d join public.eventos e on e.id = d.evento_id
                    where e.tipo_evento_id = p_id) then
      raise exception 'Este tipo já tem Dados do Ensaio preenchidos: não é possível mudar o modelo.';
    end if;
    update public.tipos_evento
       set nome = v_nome, descricao = v_desc, modelo_ensaio = v_modelo, ativo = v_ativo, atualizado_em = now()
     where id = p_id;
    v_id := p_id;
    -- Renomear o tipo atualiza o texto dos eventos dele (ação do sistema: não passa pelas travas de data
    -- e não gera uma linha de auditoria por evento; a alteração do tipo já fica registrada)
    if v_ant.nome is distinct from v_nome then
      perform set_config('sysmusica.restaurando', 'sim', true);
      update public.eventos set tipo = v_nome where tipo_evento_id = p_id and tipo is distinct from v_nome;
      perform set_config('sysmusica.restaurando', '', true);
    end if;
  end if;
  return v_id;
exception when unique_violation then
  raise exception 'Já existe um tipo de evento com este nome.';
end;
$$;

create or replace function public.excluir_tipo_evento(p_id uuid)
returns void
language plpgsql security definer set search_path to 'public'
as $$
begin
  perform public.exigir_permissao('tipoevento.excluir');
  if exists (select 1 from public.eventos e where e.tipo_evento_id = p_id) then
    raise exception 'Este tipo já foi usado em eventos e não pode ser excluído. Desative-o para que não seja mais escolhido.';
  end if;
  delete from public.tipos_evento where id = p_id;
  if not found then
    raise exception 'Tipo de evento não encontrado.';
  end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- 7. Funções — Hinos
-- ---------------------------------------------------------------------------
create or replace function public.listar_hinos()
returns table (id uuid, categoria text, numero integer, nome text, ativo boolean, em_uso bigint)
language plpgsql stable security definer set search_path to 'public'
as $$
begin
  if not public.tem_alguma_permissao(array['hinos.visualizar', 'ensaio.visualizar', 'ensaio.registrar']) then
    raise exception 'Você não tem permissão para esta operação.' using errcode = '42501';
  end if;
  return query
    select h.id, h.categoria, h.numero, h.nome, h.ativo,
           ((select count(*) from public.dados_ensaio_hinos x where x.hino_id = h.id)
          + (select count(*) from public.dados_ensaio d where d.hino_abertura_id = h.id))
      from public.hinos h
     order by (h.categoria = 'CORO'), h.numero;
end;
$$;

create or replace function public.salvar_hino(p_id uuid, p_dados jsonb)
returns uuid
language plpgsql security definer set search_path to 'public'
as $$
declare
  v_cat    text := upper(coalesce(p_dados ->> 'categoria', ''));
  v_num    integer;
  v_nome   text := public.limpar_espacos(p_dados ->> 'nome');
  v_ativo  boolean := coalesce((p_dados ->> 'ativo')::boolean, true);
  v_id     uuid;
begin
  if p_id is null then
    perform public.exigir_permissao('hinos.criar');
  else
    perform public.exigir_permissao('hinos.editar');
  end if;

  if v_cat not in ('HINO', 'CORO') then
    raise exception 'Escolha se é hino ou coro.';
  end if;
  begin
    v_num := (p_dados ->> 'numero')::integer;
  exception when others then
    v_num := null;
  end;
  if v_num is null or v_num < 1 or v_num > 9999 then
    raise exception 'Informe o número do hino (de 1 a 9999).';
  end if;
  if v_nome is null or char_length(v_nome) < 2 then
    raise exception 'Informe o título do hino.';
  end if;
  if char_length(v_nome) > 150 then
    raise exception 'O título pode ter no máximo 150 caracteres.';
  end if;

  if p_id is null then
    insert into public.hinos (categoria, numero, nome, ativo) values (v_cat, v_num, v_nome, v_ativo)
    returning id into v_id;
  else
    update public.hinos
       set categoria = v_cat, numero = v_num, nome = v_nome, ativo = v_ativo, atualizado_em = now()
     where id = p_id
    returning id into v_id;
    if v_id is null then
      raise exception 'Hino não encontrado.';
    end if;
  end if;
  return v_id;
exception when unique_violation then
  raise exception 'Já existe % com este número.', case when v_cat = 'CORO' then 'um coro' else 'um hino' end;
end;
$$;

create or replace function public.excluir_hino(p_id uuid)
returns void
language plpgsql security definer set search_path to 'public'
as $$
begin
  perform public.exigir_permissao('hinos.excluir');
  if exists (select 1 from public.dados_ensaio_hinos x where x.hino_id = p_id)
     or exists (select 1 from public.dados_ensaio d where d.hino_abertura_id = p_id) then
    raise exception 'Este hino já foi usado em um ensaio e não pode ser excluído. Desative-o para que não seja mais escolhido.';
  end if;
  delete from public.hinos where id = p_id;
  if not found then
    raise exception 'Hino não encontrado.';
  end if;
end;
$$;

-- Importa uma lista de hinos de uma vez: [{"categoria":"HINO","numero":1,"nome":"..."}, ...]
-- Só ACRESCENTA: número que já existe é ignorado (para corrigir um título, use Editar).
create or replace function public.importar_hinos(p_itens jsonb)
returns jsonb
language plpgsql security definer set search_path to 'public'
as $$
declare
  v_item   jsonb;
  v_total  integer;
  v_novos  integer;
  v_cat    text;
  v_num    integer;
  v_nome   text;
begin
  perform public.exigir_permissao('hinos.criar');
  if p_itens is null or jsonb_typeof(p_itens) <> 'array' or jsonb_array_length(p_itens) = 0 then
    raise exception 'Nenhum hino para importar.';
  end if;
  v_total := jsonb_array_length(p_itens);
  if v_total > 2000 then
    raise exception 'Importe no máximo 2000 hinos por vez.';
  end if;

  for v_item in select * from jsonb_array_elements(p_itens) loop
    v_cat := upper(coalesce(v_item ->> 'categoria', ''));
    begin
      v_num := (v_item ->> 'numero')::integer;
    exception when others then
      v_num := null;
    end;
    v_nome := public.limpar_espacos(v_item ->> 'nome');
    if v_cat not in ('HINO', 'CORO') or v_num is null or v_num < 1 or v_num > 9999
       or v_nome is null or char_length(v_nome) < 2 or char_length(v_nome) > 150 then
      raise exception 'Item inválido na lista: %', left(v_item::text, 80);
    end if;
  end loop;

  if exists (select 1 from jsonb_to_recordset(p_itens) as x(categoria text, numero integer, nome text)
              group by upper(x.categoria), x.numero having count(*) > 1) then
    raise exception 'A lista tem números repetidos.';
  end if;

  -- Uma única linha de auditoria para a importação (não uma por hino)
  perform set_config('sysmusica.restaurando', 'sim', true);
  insert into public.hinos (categoria, numero, nome)
  select upper(x.categoria), x.numero, public.limpar_espacos(x.nome)
    from jsonb_to_recordset(p_itens) as x(categoria text, numero integer, nome text)
  on conflict (categoria, numero) do nothing;
  get diagnostics v_novos = row_count;
  perform set_config('sysmusica.restaurando', '', true);

  perform public.registrar_auditoria('hinos_importados', 'hino', null,
            jsonb_build_object('rotulo', 'Importação de hinos', 'recebidos', v_total, 'novos', v_novos));
  return jsonb_build_object('recebidos', v_total, 'novos', v_novos, 'ja_existiam', v_total - v_novos);
end;
$$;

-- ---------------------------------------------------------------------------
-- 8. Funções — Dados do Ensaio
-- ---------------------------------------------------------------------------
-- Texto do cargo de quem atendeu (para o histórico de auditoria)
create or replace function public.rotulo_cargo_ensaio(p_cargo text)
returns text language sql immutable set search_path to 'public'
as $$ select case p_cargo
  when 'ANCIAO' then 'Ancião'
  when 'DIACONO' then 'Diácono'
  when 'COOPERADOR_OFICIO' then 'Cooperador do Ofício Ministerial'
  when 'COOPERADOR_RJM' then 'Cooperador da Reunião de Jovens e Menores'
  else p_cargo end $$;

-- Resumo em texto simples do ensaio (usado só no histórico de auditoria)
create or replace function public.ensaio_resumo(p_dados_id uuid)
returns jsonb
language sql stable security definer set search_path to 'public'
as $$
  select jsonb_build_object(
    'atende', d.atende_nome || ' (' || public.rotulo_cargo_ensaio(d.atende_cargo) || ')',
    'palavra', d.palavra,
    'hino_abertura', public.rotulo_hino(h.categoria, h.numero) || ' - ' || h.nome,
    'encarregados', (select string_agg(e.nome || ' (' || e.cidade_uf || ')', '; ' order by e.ordem)
                       from public.dados_ensaio_encarregados e where e.dados_ensaio_id = d.id),
    'hinos', (select string_agg(public.rotulo_hino(x.categoria, x.numero), ', ' order by dh.ordem)
                from public.dados_ensaio_hinos dh join public.hinos x on x.id = dh.hino_id
               where dh.dados_ensaio_id = d.id))
    from public.dados_ensaio d join public.hinos h on h.id = d.hino_abertura_id
   where d.id = p_dados_id
$$;
revoke all on function public.ensaio_resumo(uuid) from public, anon, authenticated;

-- Ensaios (Local e Regional) que a pessoa pode ver: de 30 dias atrás a 2 dias à frente, do mais próximo de agora
create or replace function public.eventos_para_ensaio()
returns table (id uuid, tipo text, modelo_ensaio text, data_evento timestamptz, local_evento text,
               cidade text, casa_oracao_nome text, preenchido boolean, encerrado boolean)
language plpgsql stable security definer set search_path to 'public'
as $$
begin
  if not public.tem_alguma_permissao(array['ensaio.visualizar', 'ensaio.registrar']) then
    raise exception 'Você não tem permissão para esta operação.' using errcode = '42501';
  end if;
  return query
    select e.id, e.tipo, t.modelo_ensaio, e.data_evento, e.local, e.cidade, c.nome,
           exists (select 1 from public.dados_ensaio d where d.evento_id = e.id),
           public.portaria_encerrada(e.data_evento)
      from public.eventos e
      join public.tipos_evento t on t.id = e.tipo_evento_id and t.modelo_ensaio is not null
      left join public.casas_oracao c on c.id = e.casa_oracao_id
     where e.excluido_em is null
       and e.cancelado_em is null
       and public.evento_na_abrangencia(e.id)
       and e.data_evento between now() - interval '30 days' and now() + interval '2 days'
     order by abs(extract(epoch from (e.data_evento - now())))
     limit 40;
end;
$$;

create or replace function public.obter_dados_ensaio(p_evento_id uuid)
returns jsonb
language plpgsql stable security definer set search_path to 'public'
as $$
declare
  v_e        record;
  v_d        public.dados_ensaio;
  v_admin    boolean;
  v_iniciado boolean;
  v_encerr   boolean;
begin
  if not public.tem_alguma_permissao(array['ensaio.visualizar', 'ensaio.registrar']) then
    raise exception 'Você não tem permissão para esta operação.' using errcode = '42501';
  end if;

  select e.id, e.tipo, e.data_evento, e.local, e.cidade, e.cancelado_em, t.modelo_ensaio, c.nome as casa
    into v_e
    from public.eventos e
    left join public.tipos_evento t on t.id = e.tipo_evento_id
    left join public.casas_oracao c on c.id = e.casa_oracao_id
   where e.id = p_evento_id and e.excluido_em is null;
  if not found then
    raise exception 'Evento não encontrado.';
  end if;
  if not public.evento_na_abrangencia(p_evento_id) then
    raise exception 'Este evento está fora da sua abrangência.' using errcode = '42501';
  end if;
  if v_e.modelo_ensaio is null then
    raise exception 'Este evento não é um ensaio Local ou Regional.';
  end if;

  v_admin    := public.tem_permissao('eventos.cancelar');
  v_iniciado := now() >= v_e.data_evento - interval '2 hours';
  v_encerr   := public.portaria_encerrada(v_e.data_evento);
  select * into v_d from public.dados_ensaio d where d.evento_id = p_evento_id;

  return jsonb_build_object(
    'evento', jsonb_build_object(
      'id', v_e.id, 'tipo', v_e.tipo, 'modelo_ensaio', v_e.modelo_ensaio, 'data_evento', v_e.data_evento,
      'local', v_e.local, 'cidade', v_e.cidade, 'casa_oracao', v_e.casa,
      'cancelado', v_e.cancelado_em is not null, 'iniciado', v_iniciado, 'encerrado', v_encerr),
    -- A tela só deixa editar quando o banco deixaria salvar
    'pode_editar', public.tem_permissao('ensaio.registrar') and v_e.cancelado_em is null
                   and (v_admin or (v_iniciado and not v_encerr)),
    'dados', case when v_d.id is null then null else jsonb_build_object(
      'atende_cargo', v_d.atende_cargo, 'atende_nome', v_d.atende_nome, 'palavra', v_d.palavra,
      'hino_abertura_id', v_d.hino_abertura_id, 'atualizado_em', v_d.atualizado_em,
      'encarregados', (select coalesce(jsonb_agg(jsonb_build_object('ordem', x.ordem, 'nome', x.nome, 'cidade_uf', x.cidade_uf)
                                                 order by x.ordem), '[]'::jsonb)
                         from public.dados_ensaio_encarregados x where x.dados_ensaio_id = v_d.id),
      'hinos', (select coalesce(jsonb_agg(h.hino_id order by h.ordem), '[]'::jsonb)
                  from public.dados_ensaio_hinos h where h.dados_ensaio_id = v_d.id)) end);
end;
$$;

create or replace function public.salvar_dados_ensaio(p_evento_id uuid, p_dados jsonb)
returns uuid
language plpgsql security definer set search_path to 'public'
as $$
declare
  v_uid      uuid := (select auth.uid());
  v_e        record;
  v_d        public.dados_ensaio;
  v_admin    boolean;
  v_cargo    text := upper(coalesce(p_dados ->> 'atende_cargo', ''));
  v_nome     text := public.limpar_espacos(p_dados ->> 'atende_nome');
  v_palavra  text := nullif(btrim(coalesce(p_dados ->> 'palavra', '')), '');
  v_abertura uuid;
  v_enc      jsonb := coalesce(p_dados -> 'encarregados', '[]'::jsonb);
  v_hinos    jsonb := coalesce(p_dados -> 'hinos', '[]'::jsonb);
  v_item     jsonb;
  v_ordem    integer;
  v_n        integer;
  v_nomeenc  text;
  v_cidade   text;
  v_id       uuid;
  v_antes    jsonb;
  v_depois   jsonb;
  v_mud      jsonb;
  v_ufs      text[] := array['AC','AL','AP','AM','BA','CE','DF','ES','GO','MA','MT','MS','MG','PA','PB','PR','PE','PI','RJ','RN','RS','RO','RR','SC','SP','SE','TO'];
begin
  perform public.exigir_permissao('ensaio.registrar');
  -- Duas pessoas salvando o mesmo ensaio ao mesmo tempo: a segunda espera a primeira
  perform pg_advisory_xact_lock(hashtextextended('ensaio:' || p_evento_id::text, 0));

  select e.id, e.tipo, e.local, e.data_evento, e.cancelado_em, t.modelo_ensaio
    into v_e
    from public.eventos e
    left join public.tipos_evento t on t.id = e.tipo_evento_id
   where e.id = p_evento_id and e.excluido_em is null;
  if not found then
    raise exception 'Evento não encontrado.';
  end if;
  if not public.evento_na_abrangencia(p_evento_id) then
    raise exception 'Este evento está fora da sua abrangência.' using errcode = '42501';
  end if;
  if v_e.modelo_ensaio is null then
    raise exception 'Este evento não é um ensaio Local ou Regional.';
  end if;
  if v_e.cancelado_em is not null then
    raise exception 'Este evento foi cancelado.';
  end if;

  -- Preenche-se DURANTE o ensaio (a partir de 2h antes até 3h depois do início). Só o Administrador
  -- (permissão eventos.cancelar) corrige fora dessa janela, como nos demais dados de evento encerrado.
  v_admin := public.tem_permissao('eventos.cancelar');
  if not v_admin then
    if now() < v_e.data_evento - interval '2 hours' then
      raise exception 'O ensaio ainda não começou. Os dados podem ser preenchidos a partir de 2 horas antes do horário.';
    end if;
    if public.portaria_encerrada(v_e.data_evento) then
      raise exception 'Este ensaio já foi encerrado. Só o Administrador pode alterar os dados.' using errcode = '42501';
    end if;
  end if;

  -- Quem atende
  if v_e.modelo_ensaio = 'REGIONAL' then
    if v_cargo <> 'ANCIAO' then
      raise exception 'No ensaio Regional quem atende é sempre um Ancião.';
    end if;
  elsif v_cargo not in ('ANCIAO', 'DIACONO', 'COOPERADOR_OFICIO', 'COOPERADOR_RJM') then
    raise exception 'Escolha o cargo de quem atendeu (Ancião, Diácono, Cooperador do Ofício ou Cooperador de RJM).';
  end if;
  if v_nome is null or char_length(v_nome) < 3 then
    raise exception 'Informe o nome de quem atendeu o ensaio.';
  end if;
  if char_length(v_nome) > 120 then
    raise exception 'O nome de quem atendeu pode ter no máximo 120 caracteres.';
  end if;

  -- Palavra: obrigatória no Regional; o Local não tem palavra
  if v_e.modelo_ensaio = 'REGIONAL' then
    if v_palavra is null then
      raise exception 'Informe a palavra que foi exortada.';
    end if;
    if char_length(v_palavra) > 500 then
      raise exception 'A palavra pode ter no máximo 500 caracteres.';
    end if;
  else
    v_palavra := null;
  end if;

  -- Hino de abertura (obrigatório; fica fora da lista de hinos executados)
  begin
    v_abertura := (p_dados ->> 'hino_abertura_id')::uuid;
  exception when others then
    v_abertura := null;
  end;
  if v_abertura is null then
    raise exception 'Escolha o hino de abertura.';
  end if;
  if not exists (select 1 from public.hinos h where h.id = v_abertura) then
    raise exception 'Hino de abertura não encontrado.';
  end if;

  select * into v_d from public.dados_ensaio d where d.evento_id = p_evento_id;

  if v_abertura is distinct from v_d.hino_abertura_id
     and exists (select 1 from public.hinos h where h.id = v_abertura and not h.ativo) then
    raise exception 'O hino de abertura escolhido está desativado.';
  end if;

  -- Encarregados: de 1 a 3, com nome e Cidade/UF
  if jsonb_typeof(v_enc) <> 'array' or jsonb_array_length(v_enc) < 1 then
    raise exception 'Informe pelo menos 1 encarregado.';
  end if;
  if jsonb_array_length(v_enc) > 3 then
    raise exception 'Informe no máximo 3 encarregados.';
  end if;
  for v_item in select * from jsonb_array_elements(v_enc) loop
    v_nomeenc := public.limpar_espacos(v_item ->> 'nome');
    v_cidade  := public.limpar_espacos(v_item ->> 'cidade_uf');
    if v_nomeenc is null or char_length(v_nomeenc) < 3 or char_length(v_nomeenc) > 120 then
      raise exception 'Informe o nome de cada encarregado (de 3 a 120 caracteres).';
    end if;
    if v_cidade is null or v_cidade !~ '^.{2,}-[A-Z]{2}$' or not (right(v_cidade, 2) = any (v_ufs)) then
      raise exception 'Informe a cidade de % no formato Cidade-UF (ex.: São Paulo-SP).', v_nomeenc;
    end if;
  end loop;
  if (select count(distinct public.normalizar_texto(public.limpar_espacos(x ->> 'nome')))
        from jsonb_array_elements(v_enc) x) <> jsonb_array_length(v_enc) then
    raise exception 'Há encarregados com o mesmo nome.';
  end if;

  -- Hinos executados: sem repetir, sem o hino de abertura
  if jsonb_typeof(v_hinos) <> 'array' then
    raise exception 'Lista de hinos inválida.';
  end if;
  if jsonb_array_length(v_hinos) > 100 then
    raise exception 'Informe no máximo 100 hinos executados.';
  end if;
  if exists (select 1 from jsonb_array_elements_text(v_hinos) x
              where x !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$') then
    raise exception 'Lista de hinos inválida.';
  end if;
  if (select count(distinct lower(x)) from jsonb_array_elements_text(v_hinos) x) <> jsonb_array_length(v_hinos) then
    raise exception 'O mesmo hino não pode ser executado duas vezes no ensaio.';
  end if;
  if exists (select 1 from jsonb_array_elements_text(v_hinos) x where x::uuid = v_abertura) then
    raise exception 'O hino de abertura não conta entre os hinos executados. Tire-o da lista.';
  end if;
  select count(*) into v_n from jsonb_array_elements_text(v_hinos) x join public.hinos h on h.id = x::uuid;
  if v_n <> jsonb_array_length(v_hinos) then
    raise exception 'Algum hino escolhido não foi encontrado.';
  end if;
  -- Hino desativado só pode ficar se já fazia parte deste ensaio
  if exists (select 1 from jsonb_array_elements_text(v_hinos) x join public.hinos h on h.id = x::uuid
              where not h.ativo
                and not exists (select 1 from public.dados_ensaio_hinos dh where dh.dados_ensaio_id = v_d.id and dh.hino_id = h.id)) then
    raise exception 'Algum hino escolhido está desativado.';
  end if;

  if v_d.id is not null then
    v_antes := public.ensaio_resumo(v_d.id);
  end if;

  if v_d.id is null then
    insert into public.dados_ensaio (evento_id, atende_cargo, atende_nome, palavra, hino_abertura_id, criado_por, atualizado_por)
    values (p_evento_id, v_cargo, v_nome, v_palavra, v_abertura, v_uid, v_uid)
    returning id into v_id;
  else
    v_id := v_d.id;
    -- Apaga os itens antes de trocar o hino de abertura (o gatilho confere abertura x executados)
    delete from public.dados_ensaio_encarregados where dados_ensaio_id = v_id;
    delete from public.dados_ensaio_hinos where dados_ensaio_id = v_id;
    update public.dados_ensaio
       set atende_cargo = v_cargo, atende_nome = v_nome, palavra = v_palavra, hino_abertura_id = v_abertura,
           atualizado_por = v_uid, atualizado_em = now()
     where id = v_id;
  end if;

  v_ordem := 0;
  for v_item in select * from jsonb_array_elements(v_enc) loop
    v_ordem := v_ordem + 1;
    insert into public.dados_ensaio_encarregados (dados_ensaio_id, ordem, nome, cidade_uf)
    values (v_id, v_ordem, public.limpar_espacos(v_item ->> 'nome'), public.limpar_espacos(v_item ->> 'cidade_uf'));
  end loop;

  v_ordem := 0;
  for v_item in select * from jsonb_array_elements(v_hinos) loop
    v_ordem := v_ordem + 1;
    insert into public.dados_ensaio_hinos (dados_ensaio_id, hino_id, ordem)
    values (v_id, (v_item #>> '{}')::uuid, v_ordem);
  end loop;

  -- Auditoria: uma linha por gravação, com o que mudou (texto simples)
  v_depois := public.ensaio_resumo(v_id);
  if v_antes is null then
    perform public.registrar_auditoria('ensaio_registrado', 'ensaio', p_evento_id,
              jsonb_build_object('rotulo', v_e.tipo || ' · ' || v_e.local, 'depois', v_depois));
  else
    select coalesce(jsonb_object_agg(n.key, jsonb_build_object('de', o.value, 'para', n.value)), '{}'::jsonb)
      into v_mud
      from jsonb_each(v_depois) n
      left join jsonb_each(v_antes) o on o.key = n.key
     where n.value is distinct from o.value;
    if v_mud <> '{}'::jsonb then
      perform public.registrar_auditoria('ensaio_alterado', 'ensaio', p_evento_id,
                jsonb_build_object('rotulo', v_e.tipo || ' · ' || v_e.local, 'mudancas', v_mud));
    end if;
  end if;

  return v_id;
end;
$$;

-- ---------------------------------------------------------------------------
-- 9. Quem pode executar cada função (só usuários logados; cada função confere a permissão)
-- ---------------------------------------------------------------------------
revoke all on function public.listar_tipos_evento() from public, anon;
revoke all on function public.salvar_tipo_evento(uuid, jsonb) from public, anon;
revoke all on function public.excluir_tipo_evento(uuid) from public, anon;
revoke all on function public.listar_hinos() from public, anon;
revoke all on function public.salvar_hino(uuid, jsonb) from public, anon;
revoke all on function public.excluir_hino(uuid) from public, anon;
revoke all on function public.importar_hinos(jsonb) from public, anon;
revoke all on function public.eventos_para_ensaio() from public, anon;
revoke all on function public.obter_dados_ensaio(uuid) from public, anon;
revoke all on function public.salvar_dados_ensaio(uuid, jsonb) from public, anon;
grant execute on function public.listar_tipos_evento() to authenticated;
grant execute on function public.salvar_tipo_evento(uuid, jsonb) to authenticated;
grant execute on function public.excluir_tipo_evento(uuid) to authenticated;
grant execute on function public.listar_hinos() to authenticated;
grant execute on function public.salvar_hino(uuid, jsonb) to authenticated;
grant execute on function public.excluir_hino(uuid) to authenticated;
grant execute on function public.importar_hinos(jsonb) to authenticated;
grant execute on function public.eventos_para_ensaio() to authenticated;
grant execute on function public.obter_dados_ensaio(uuid) to authenticated;
grant execute on function public.salvar_dados_ensaio(uuid, jsonb) to authenticated;
grant execute on function public.rotulo_hino(text, integer) to authenticated;

-- ---------------------------------------------------------------------------
-- 10. Backup: a função de restauração passa a aceitar as tabelas novas
--     (cópia da versão da migração 0039 com as linhas novas na lista permitida)
-- ---------------------------------------------------------------------------
create or replace function public.backup_aplicar(p_usuario uuid, p_operacoes jsonb, p_resumo jsonb)
returns jsonb
language plpgsql security definer set search_path to 'public'
as $$
declare
  v_op        jsonb;
  v_tabela    text;
  v_acao      text;
  v_linhas    jsonb;
  v_colunas   text[];
  v_def       record;
  v_cols      text;
  v_bcols     text;
  v_set       text;
  v_pk_cond   text;
  v_extra     text;
  v_n         bigint;
  v_ignorados bigint;
  v_resultado jsonb := '[]'::jsonb;
begin
  if p_operacoes is null or jsonb_typeof(p_operacoes) <> 'array' then
    raise exception 'Operações inválidas.';
  end if;

  perform set_config('sysmusica.restaurando', 'sim', true);

  for v_op in select * from jsonb_array_elements(p_operacoes) loop
    v_tabela := v_op ->> 'tabela';
    v_acao   := v_op ->> 'acao';
    v_linhas := coalesce(v_op -> 'linhas', '[]'::jsonb);

    select t.* into v_def
    from (values
      ('estados',             array['id'],                              false, false, ''),
      ('rrms',                array['id'],                              false, false, ''),
      ('ras',                 array['id'],                              false, false, ''),
      ('adms',                array['id'],                              false, false, ''),
      ('setores',             array['id'],                              false, false, ''),
      ('casas_oracao',        array['id'],                              false, false, ''),
      ('familias',            array['id'],                              false, false, ''),
      ('cargos',              array['id'],                              false, false, ''),
      ('finalidades_evento',  array['id'],                              false, false, ''),
      ('instrumentos',        array['id'],                              false, false, ''),
      ('tipos_evento',        array['id'],                              false, false, ''),
      ('hinos',               array['id'],                              false, false, ''),
      ('dados_ensaio',        array['id'],                              false, false, ''),
      ('dados_ensaio_encarregados', array['id'],                        false, false, ''),
      ('dados_ensaio_hinos',  array['id'],                              false, false, ''),
      ('grupos',              array['id'],                              false, false, ''),
      ('grupo_permissoes',    array['grupo_id', 'permissao_codigo'],    false, false, ''),
      ('usuarios',            array['id'],                              false, false, 'login'),
      ('usuario_grupos',      array['usuario_id', 'grupo_id'],          false, false, ''),
      ('usuario_vinculos',    array['usuario_id', 'nivel', 'alvo_id'],  false, false, ''),
      ('membros',             array['id'],                              true,  false, ''),
      ('eventos',             array['id'],                              true,  false, ''),
      ('portarias',           array['id'],                              true,  false, ''),
      ('portarias_historico', array['id'],                              false, true,  ''),
      ('presencas',           array['id'],                              true,  false, ''),
      ('presencas_avulsas',   array['id'],                              true,  false, '')
    ) as t(tabela, pk, soft, so_inserir, extra)
    where t.tabela = v_tabela;
    if not found then
      raise exception 'Tabela não permitida na restauração: %', coalesce(v_tabela, '(vazia)');
    end if;

    if v_acao is null or v_acao not in ('inserir', 'atualizar', 'excluir_logico', 'excluir') then
      raise exception 'Ação inválida na restauração: %', coalesce(v_acao, '(vazia)');
    end if;
    if v_def.so_inserir and v_acao <> 'inserir' then
      raise exception 'A tabela % só aceita devolver registros apagados.', v_tabela;
    end if;
    if v_acao = 'excluir_logico' and not v_def.soft then
      raise exception 'A tabela % não usa exclusão lógica.', v_tabela;
    end if;
    if v_acao = 'excluir' and v_def.soft then
      raise exception 'Os itens da tabela % são excluídos logicamente.', v_tabela;
    end if;
    if jsonb_typeof(v_linhas) <> 'array' then
      raise exception 'Linhas inválidas em %.', v_tabela;
    end if;
    if jsonb_array_length(v_linhas) = 0 then
      continue;
    end if;

    select coalesce(array_agg(x), '{}'::text[]) into v_colunas
    from jsonb_array_elements_text(coalesce(v_op -> 'colunas', '[]'::jsonb)) as x;

    if not (v_def.pk <@ v_colunas) then
      raise exception 'Faltam as colunas de identificação em %.', v_tabela;
    end if;

    -- Só colunas que existem e podem ser gravadas (as geradas ficam de fora)
    select string_agg(quote_ident(c.column_name), ', ' order by c.ordinal_position),
           string_agg(format('b.%I', c.column_name), ', ' order by c.ordinal_position),
           string_agg(format('%1$I = b.%1$I', c.column_name), ', ' order by c.ordinal_position)
             filter (where c.column_name <> all (v_def.pk))
      into v_cols, v_bcols, v_set
    from information_schema.columns c
    where c.table_schema = 'public' and c.table_name = v_tabela
      and c.is_generated = 'NEVER' and c.column_name = any (v_colunas);

    select string_agg(format('c.%1$I = b.%1$I', k), ' and ') into v_pk_cond from unnest(v_def.pk) as k;

    v_ignorados := 0;

    if v_acao = 'inserir' then
      -- Usuários só voltam se a conta de login ainda existir (a senha não é guardada no backup)
      v_extra := case when v_def.extra = 'login' then 'where exists (select 1 from auth.users a where a.id = b.id)' else '' end;
      execute format(
        'insert into public.%1$I (%2$s) select %3$s from jsonb_populate_recordset(null::public.%1$I, $1) b %4$s',
        v_tabela, v_cols, v_bcols, v_extra) using v_linhas;
      get diagnostics v_n = row_count;
      v_ignorados := jsonb_array_length(v_linhas) - v_n;

    elsif v_acao = 'atualizar' then
      if v_set is null then
        v_n := 0;
      else
        execute format(
          'update public.%1$I c set %2$s from jsonb_populate_recordset(null::public.%1$I, $1) b where %3$s',
          v_tabela, v_set, v_pk_cond) using v_linhas;
        get diagnostics v_n = row_count;
      end if;

    elsif v_acao = 'excluir_logico' then
      execute format(
        'update public.%1$I c set excluido_em = now() from jsonb_populate_recordset(null::public.%1$I, $1) b where %2$s and c.excluido_em is null',
        v_tabela, v_pk_cond) using v_linhas;
      get diagnostics v_n = row_count;

    else
      execute format(
        'delete from public.%1$I c using jsonb_populate_recordset(null::public.%1$I, $1) b where %2$s',
        v_tabela, v_pk_cond) using v_linhas;
      get diagnostics v_n = row_count;
    end if;

    v_resultado := v_resultado || jsonb_build_object(
      'tabela', v_tabela, 'acao', v_acao, 'afetados', v_n, 'ignorados', v_ignorados);
  end loop;

  perform set_config('sysmusica.restaurando', '', true);

  -- Uma única entrada resumida na auditoria (a auditoria linha a linha ficou pausada)
  insert into public.auditoria (usuario_id, acao, entidade, entidade_id, detalhes)
  values (p_usuario, 'backup_restaurado', 'backup', null,
          coalesce(p_resumo, '{}'::jsonb) || jsonb_build_object('operacoes', v_resultado));

  return v_resultado;
end;
$$;

-- ---------------------------------------------------------------------------
-- 11. Conferência final
-- ---------------------------------------------------------------------------
do $$
begin
  if (select count(*) from public.tipos_evento) < 8
     or (select count(*) from public.permissoes where codigo in (
           'tipoevento.visualizar', 'tipoevento.criar', 'tipoevento.editar', 'tipoevento.excluir',
           'hinos.visualizar', 'hinos.criar', 'hinos.editar', 'hinos.excluir', 'ensaio.visualizar', 'ensaio.registrar')) <> 10
     or to_regprocedure('public.salvar_dados_ensaio(uuid, jsonb)') is null
     or not exists (select 1 from pg_trigger where tgname = 'trg_eventos_sincroniza_tipo') then
    raise exception 'Teste falhou: objetos da Parte 8 ausentes. Nada foi alterado.';
  end if;
  raise notice 'OK: tipos de evento, hinos e dados do ensaio instalados.';
end $$;

select set_config('sysmusica.restaurando', '', true);
commit;
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
  if "$@" > /tmp/p8-passo.out 2>&1; then
    echo "  ok"
  else
    echo "  FALHOU: $nome"; tail -40 /tmp/p8-passo.out
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
echo "Lembrete: o SQL 0041 precisa ter sido rodado no Supabase ANTES de testar as telas."
echo "Depois confira as telas (passo a passo na conversa) e, se estiver tudo certo, faça o git push."
) 2>&1 | tee "$LOG"
