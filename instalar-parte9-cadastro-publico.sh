#!/usr/bin/env bash
# =============================================================================
# SysMúsica — PARTE 9: Cadastro Musical público (link /cadastro) e fila de Cadastros pendentes
#
#  ATENÇÃO: rode ANTES o SQL supabase/migrations/0042_cadastro_publico.sql no Supabase (SQL Editor).
#  Este instalador cria a página pública /cadastro, as rotas de envio e aprovação, a tela Cadastros pendentes,
#  o contador no menu, o botão de copiar o link e coloca a migração em supabase/migrations (histórico do projeto).
#  Depois configure as variáveis do Cloudflare Turnstile (veja o passo a passo na conversa).
#
# Segurança: confere cada trecho (exatamente 1 vez), faz backup em /tmp/bkp-parte9-*, aplica,
# roda tsc, vitest, eslint e build; se algo falhar, DESFAZ tudo sozinho (inclusive os arquivos novos).
#
# Uso:  cd /workspaces/sysmusica/sysmusica && rm -rf .next && bash instalar-parte9-cadastro-publico.sh
# Log:  /tmp/instalar-parte9.log
# =============================================================================

LOG=/tmp/instalar-parte9.log
BKP=/tmp/bkp-parte9-$(date +%Y%m%d-%H%M%S)
RAIZ="$(pwd)"

(
[ -f package.json ] && [ -d src ] || { echo "ERRO: rode dentro da pasta sysmusica (onde está o package.json)."; exit 1; }
mkdir -p "$BKP"
export BKP RAIZ

echo "== 1/3  Conferindo e aplicando as alterações =="
# (se o SQL 0042 ainda não foi rodado no Supabase, as telas novas darão erro até rodar)
python3 - <<'PYSCRIPT'
import os, shutil, sys, hashlib

RAIZ = os.environ["RAIZ"]
BKP = os.environ["BKP"]

# (arquivo, trecho antigo, trecho novo) — cada "antigo" precisa existir EXATAMENTE 1 vez no arquivo.
# Os trechos usam \n; o instalador converte para o fim de linha do próprio arquivo (CRLF ou LF).
EDITS = [
    ("src/lib/permissoes.ts",
     r'''  { codigo: "ensaio.registrar", modulo: "Dados do Ensaio", acao: "Preencher" },
] as const;''',
     r'''  { codigo: "ensaio.registrar", modulo: "Dados do Ensaio", acao: "Preencher" },
  { codigo: "cadastros.visualizar", modulo: "Cadastros pendentes", acao: "Visualizar" },
  { codigo: "cadastros.aprovar", modulo: "Cadastros pendentes", acao: "Aprovar" },
] as const;'''),
    ("src/components/layout/navegacao.ts",
     r'''  Guitar,
  KeyRound,
''',
     r'''  Guitar,
  Inbox,
  KeyRound,
'''),
    ("src/components/layout/navegacao.ts",
     r'''      { href: "/hinos", rotulo: "Hinos", icone: Music2, permissao: "hinos.visualizar" },
    ],
  },''',
     r'''      { href: "/hinos", rotulo: "Hinos", icone: Music2, permissao: "hinos.visualizar" },
      // Fila de cadastros enviados pelo link público (/cadastro); o número pendente aparece no menu (Sidebar)
      { href: "/cadastros-pendentes", rotulo: "Cadastros pendentes", icone: Inbox, permissao: "cadastros.visualizar" },
    ],
  },'''),
    ("src/components/layout/Sidebar.tsx",
     r'''import { GRUPOS_MENU, filtrarMenu, itemAtivo } from "./navegacao";
''',
     r'''import { useContadorCadastros } from "@/modules/cadastrosPendentes/useContador";
import { GRUPOS_MENU, filtrarMenu, itemAtivo } from "./navegacao";
'''),
    ("src/components/layout/Sidebar.tsx",
     r'''  const gruposVisiveis = filtrarMenu(GRUPOS_MENU, pode); // só o que o grupo do usuário pode ver
''',
     r'''  const gruposVisiveis = filtrarMenu(GRUPOS_MENU, pode); // só o que o grupo do usuário pode ver
  // Quantos cadastros públicos aguardam análise (0 para quem não tem a permissão); vira um selo no menu
  const pendentes = useContadorCadastros();
'''),
    ("src/components/layout/Sidebar.tsx",
     r'''                        <span className={cn("truncate", recolhida && "lg:sr-only")}>
                          {item.rotulo}
                        </span>
''',
     r'''                        <span className={cn("truncate", recolhida && "lg:sr-only")}>
                          {item.rotulo}
                        </span>
                        {item.href === "/cadastros-pendentes" && pendentes > 0 && (
                          <span
                            className={cn(
                              "ml-auto rounded-full bg-amber-500 px-2 py-0.5 text-xs font-semibold text-white",
                              recolhida && "lg:hidden"
                            )}
                            aria-label={`${pendentes} aguardando análise`}
                          >
                            {pendentes > 99 ? "99+" : pendentes}
                          </span>
                        )}
'''),
    ("src/modules/backup/tabelas.ts",
     r'''  | "usuario_vinculos"
  | "membros"
''',
     r'''  | "usuario_vinculos"
  | "membros"
  | "membros_cadastro"
  | "cadastros_pendentes"
'''),
    ("src/modules/backup/tabelas.ts",
     r'''  tabela("eventos", "Eventos", "eventos", {''',
     r'''  // Cadastro Musical (dados complementares do membro) e fila do cadastro público. Só entram no backup com os
  // campos pessoais marcados como protegidos (nunca vão para o navegador).
  tabela("membros_cadastro", "Cadastro musical dos membros", "membros", {
    pk: ["membro_id"],
    referencias: [{ coluna: "membro_id", tabela: "membros" }],
    sensiveis: [
      "documento_frente_path",
      "documento_verso_path",
      "cartao_numero",
      "email",
      "telefone",
      "whatsapp",
      "cep",
      "endereco",
      "numero",
      "complemento",
    ],
  }),
  tabela("cadastros_pendentes", "Cadastros pendentes (link público)", "membros", {
    referencias: [
      { coluna: "membro_id", tabela: "membros" },
      { coluna: "casa_oracao_id", tabela: "casas_oracao" },
      { coluna: "cargo_id", tabela: "cargos" },
      { coluna: "instrumento_id", tabela: "instrumentos" },
    ],
    sensiveis: ["cpf", "dados", "responsavel_nome", "responsavel_telefone", "ip_hash"],
  }),
  tabela("eventos", "Eventos", "eventos", {'''),
    ("src/modules/backup/tabelas.ts",
     r'''    descricao: "Cadastro de membros (a fotografia entra em uma etapa posterior)",
    tabelas: ["membros"],''',
     r'''    descricao: "Cadastro de membros, cadastro musical e cadastros pendentes do link público (as fotos e documentos não entram)",
    tabelas: ["membros", "membros_cadastro", "cadastros_pendentes"],'''),
    ("src/modules/auditoria/regras.ts",
     r'''  hinos_importados: "Importou lista de hinos",
};''',
     r'''  hinos_importados: "Importou lista de hinos",
  cadastro_aprovado: "Aprovou cadastro pendente",
  cadastro_rejeitado: "Recusou cadastro pendente",
};'''),
    ("src/modules/auditoria/regras.ts",
     r'''  ensaio: "Dados do ensaio",
};''',
     r'''  ensaio: "Dados do ensaio",
  cadastro_pendente: "Cadastro pendente",
};'''),
    ("src/app/(painel)/membros/page.tsx",
     r'''import PageHeader from "@/components/ui/PageHeader";
''',
     r'''import PageHeader from "@/components/ui/PageHeader";
import BotaoCopiarLinkCadastro from "@/modules/cadastroPublico/components/BotaoCopiarLink";
'''),
    ("src/app/(painel)/membros/page.tsx",
     r'''            pode("membros.criar") ? (
              <Button icone={Plus} onClick={() => setPainel({ tipo: "novo" })} disabled={carregando || !!erro}>
                Adicionar
              </Button>
            ) : undefined''',
     r'''            pode("membros.criar") ? (
              <div className="flex flex-wrap gap-2">
                {/* Copia o link público /cadastro para enviar aos membros (o "+ Adicionar" continua interno) */}
                <BotaoCopiarLinkCadastro />
                <Button icone={Plus} onClick={() => setPainel({ tipo: "novo" })} disabled={carregando || !!erro}>
                  Adicionar
                </Button>
              </div>
            ) : undefined'''),
    ("src/app/api/cron/conferir/route.ts",
     r'''import { responder } from "@/modules/backup/server/rota";
''',
     r'''import { responder } from "@/modules/backup/server/rota";
import { limparCadastroPublico } from "@/modules/cadastroPublico/server/limpeza";
'''),
    ("src/app/api/cron/conferir/route.ts",
     r'''    return await conferirDia();
''',
     r'''    const conferencia = await conferirDia();
    // Aproveita a conferência diária para apagar fotos/documentos de cadastros públicos vencidos ou recusados
    // (um erro aqui não pode derrubar a conferência do backup; a limpeza tenta de novo no dia seguinte).
    let cadastroPublico: unknown = null;
    try {
      cadastroPublico = await limparCadastroPublico();
    } catch (erro) {
      console.error("Limpeza do cadastro público falhou:", erro instanceof Error ? erro.message : erro);
      cadastroPublico = { falhou: true };
    }
    return { conferencia, cadastro_publico: cadastroPublico };
'''),
]


# Arquivos NOVOS (o instalador recusa se algum já existir)
NOVOS = {
    "src/app/(painel)/cadastros-pendentes/layout.tsx": r'''import type { ReactNode } from "react";
import RequerPermissao from "@/modules/autenticacao/components/RequerPermissao";

/** Protege a tela: só entra quem tem a permissão de visualizar os cadastros pendentes. */
export default function CadastrosPendentesLayout({ children }: { children: ReactNode }) {
  return <RequerPermissao permissao="cadastros.visualizar">{children}</RequerPermissao>;
}
''',
    "src/app/(painel)/cadastros-pendentes/page.tsx": r'''"use client";

/**
 * SysMúsica — Página /cadastros-pendentes: cadastros enviados pelo link público (/cadastro), aguardando análise.
 * Aprovar cria o membro (ou atualiza o que já existe); Recusar exige um motivo. Nada entra no sistema sem aprovação.
 * Cada pessoa só enxerga os pedidos das Casas de Oração da sua abrangência.
 */
import { useCallback, useEffect, useState } from "react";
import {
  aprovarCadastro,
  avisarQueFilaMudou,
  listarCadastros,
  obterCadastro,
  recusarCadastro,
} from "@/modules/cadastrosPendentes/services/cadastrosPendentes";
import DetalheDoCadastro from "@/modules/cadastrosPendentes/components/DetalheCadastro";
import TabelaCadastros from "@/modules/cadastrosPendentes/components/TabelaCadastros";
import { validarMotivo } from "@/modules/cadastrosPendentes/regras";
import type { DetalheCadastro, FiltroStatus, ResumoCadastro } from "@/modules/cadastrosPendentes/tipos";
import { useSessao } from "@/modules/autenticacao/SessaoProvider";
import ConfirmDialog from "@/components/ui/ConfirmDialog";
import Drawer from "@/components/ui/Drawer";
import EmptyState from "@/components/ui/EmptyState";
import ErrorState from "@/components/ui/ErrorState";
import Notificacao from "@/components/ui/Notificacao";
import PageHeader from "@/components/ui/PageHeader";
import Skeleton from "@/components/ui/Skeleton";

const FILTROS: { valor: FiltroStatus; rotulo: string }[] = [
  { valor: "PENDENTE", rotulo: "Pendentes" },
  { valor: "APROVADO", rotulo: "Aprovados" },
  { valor: "REJEITADO", rotulo: "Recusados" },
  { valor: "EXPIRADO", rotulo: "Vencidos" },
  { valor: "TODOS", rotulo: "Todos" },
];

export default function CadastrosPendentesPage() {
  const { pode } = useSessao();
  const [filtro, setFiltro] = useState<FiltroStatus>("PENDENTE");
  const [itens, setItens] = useState<ResumoCadastro[]>([]);
  const [carregando, setCarregando] = useState(true);
  const [erro, setErro] = useState<string | null>(null);
  const [aberto, setAberto] = useState<DetalheCadastro | null>(null);
  const [abrindoId, setAbrindoId] = useState<string | null>(null);
  const [confirmando, setConfirmando] = useState<"aprovar" | "recusar" | null>(null);
  const [motivo, setMotivo] = useState("");
  const [erroDecisao, setErroDecisao] = useState<string | null>(null);
  const [processando, setProcessando] = useState(false);
  const [aviso, setAviso] = useState<string | null>(null);

  const carregar = useCallback(async (status: FiltroStatus) => {
    try {
      setItens(await listarCadastros(status));
      setErro(null);
    } catch (e) {
      console.error("Falha ao carregar cadastros pendentes:", e);
      setErro("Não foi possível carregar os cadastros. Verifique a conexão e tente novamente.");
    } finally {
      setCarregando(false);
    }
  }, []);

  useEffect(() => {
    // O setState só roda DEPOIS do await, então o aviso da regra set-state-in-effect não se aplica aqui.
    // eslint-disable-next-line react-hooks/set-state-in-effect
    void carregar(filtro);
  }, [carregar, filtro]);

  function trocarFiltro(novo: FiltroStatus) {
    setCarregando(true);
    setFiltro(novo);
  }

  async function abrir(item: ResumoCadastro) {
    if (abrindoId) return;
    setAbrindoId(item.id);
    setAviso(null);
    try {
      setAberto(await obterCadastro(item.id));
    } catch (e) {
      setAviso(e instanceof Error ? e.message : "Não foi possível abrir o cadastro.");
    } finally {
      setAbrindoId(null);
    }
  }

  function fecharDecisao() {
    setConfirmando(null);
    setMotivo("");
    setErroDecisao(null);
  }

  async function decidir() {
    if (!aberto || !confirmando) return;
    if (confirmando === "recusar") {
      const problema = validarMotivo(motivo);
      if (problema) return setErroDecisao(problema);
    }
    setProcessando(true);
    setErroDecisao(null);
    try {
      if (confirmando === "aprovar") {
        await aprovarCadastro(aberto.id);
        setAviso(
          aberto.tipo === "NOVO"
            ? `Cadastro de "${aberto.nome}" aprovado: o membro foi criado.`
            : `Cadastro de "${aberto.nome}" aprovado: os dados do membro foram atualizados.`
        );
      } else {
        await recusarCadastro(aberto.id, motivo.trim());
        setAviso(`Cadastro de "${aberto.nome}" recusado.`);
      }
      fecharDecisao();
      setAberto(null);
      await carregar(filtro);
    } catch (e) {
      setErroDecisao(e instanceof Error ? e.message : "Não foi possível concluir.");
      avisarQueFilaMudou(); // se outro aprovador já decidiu, o contador do menu se acerta
    } finally {
      setProcessando(false);
    }
  }

  return (
    <main className="text-slate-900">
      <div className="mx-auto max-w-7xl px-4 py-8 sm:px-6 lg:px-8">
        <PageHeader
          titulo="Cadastros pendentes"
          descricao="Cadastros enviados pelo link público. Nada entra no sistema sem a sua aprovação."
        />

        <div role="group" aria-label="Filtrar por situação" className="mb-4 flex flex-wrap gap-1">
          {FILTROS.map((f) => (
            <button
              key={f.valor}
              type="button"
              aria-pressed={filtro === f.valor}
              onClick={() => trocarFiltro(f.valor)}
              className={
                "rounded-lg px-3 py-1.5 text-sm font-medium transition " +
                (filtro === f.valor ? "bg-brand-600 text-white" : "bg-slate-100 text-slate-700 hover:bg-slate-200")
              }
            >
              {f.rotulo}
            </button>
          ))}
        </div>

        {carregando ? (
          <div role="status" aria-live="polite" className="space-y-3">
            <span className="sr-only">Carregando cadastros...</span>
            {[0, 1, 2, 3].map((i) => (
              <Skeleton key={i} className="h-12" />
            ))}
          </div>
        ) : erro ? (
          <ErrorState
            titulo="Não foi possível carregar os cadastros."
            mensagem={erro}
            onTentarNovamente={() => {
              setCarregando(true);
              void carregar(filtro);
            }}
          />
        ) : itens.length === 0 ? (
          <EmptyState
            titulo={filtro === "PENDENTE" ? "Nenhum cadastro aguardando análise." : "Nenhum cadastro nesta situação."}
            descricao="O link para divulgar é o endereço do sistema seguido de /cadastro (há um botão para copiá-lo em Músicos / Organistas)."
          />
        ) : (
          <TabelaCadastros itens={itens} onAbrir={(item) => void abrir(item)} />
        )}
      </div>

      <Drawer
        aberto={aberto !== null}
        onFechar={() => setAberto(null)}
        titulo={aberto?.nome ?? "Cadastro"}
        descricao="Confira os dados e as imagens antes de decidir."
      >
        {aberto && (
          <DetalheDoCadastro
            key={aberto.id}
            detalhe={aberto}
            podeAprovar={pode("cadastros.aprovar")}
            ocupado={processando}
            onAprovar={() => {
              setErroDecisao(null);
              setConfirmando("aprovar");
            }}
            onRecusar={() => {
              setErroDecisao(null);
              setConfirmando("recusar");
            }}
          />
        )}
      </Drawer>

      <ConfirmDialog
        aberto={confirmando !== null}
        titulo={confirmando === "aprovar" ? "Aprovar este cadastro?" : "Recusar este cadastro?"}
        mensagem={
          <>
            {confirmando === "aprovar" ? (
              <p>
                {aberto?.tipo === "NOVO" ? (
                  <>
                    O membro <strong>{aberto?.nome}</strong> será criado com estes dados.
                  </>
                ) : (
                  <>
                    Os dados de <strong>{aberto?.nome}</strong> serão substituídos pelos do pedido.
                  </>
                )}
              </p>
            ) : (
              <div className="space-y-2">
                <p>Explique o motivo. Ele fica registrado para a secretaria; a pessoa não é avisada pelo sistema.</p>
                <label htmlFor="motivo-recusa" className="sr-only">
                  Motivo da recusa
                </label>
                <textarea
                  id="motivo-recusa"
                  rows={3}
                  maxLength={300}
                  value={motivo}
                  onChange={(e) => setMotivo(e.target.value)}
                  className="w-full rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 shadow-sm focus:border-brand-500 focus:outline-none focus:ring-2 focus:ring-brand-200 [color-scheme:light]"
                  placeholder="Ex.: documento ilegível, envie novamente"
                />
              </div>
            )}
            {erroDecisao && (
              <p role="alert" className="mt-3 rounded-lg bg-red-50 px-3 py-2 text-red-700">
                {erroDecisao}
              </p>
            )}
          </>
        }
        textoConfirmar={confirmando === "aprovar" ? "Aprovar" : "Recusar"}
        processando={processando}
        onConfirmar={() => void decidir()}
        onCancelar={fecharDecisao}
      />

      <Notificacao mensagem={aviso} onFechar={() => setAviso(null)} />
    </main>
  );
}
''',
    "src/app/(publico)/cadastro/page.tsx": r'''"use client";

/**
 * SysMúsica — Página pública /cadastro: Cadastro Musical sem login.
 * Carrega as opções (cargos, instrumentos, Casas de Oração) por uma função pública do banco e mostra o formulário.
 */
import { useEffect, useState } from "react";
import FormularioPublico from "@/modules/cadastroPublico/components/FormularioPublico";
import { carregarOpcoes } from "@/modules/cadastroPublico/services/envio";
import type { OpcoesCadastroPublico } from "@/modules/cadastroPublico/regras";

export default function CadastroPublicoPage() {
  const [opcoes, setOpcoes] = useState<OpcoesCadastroPublico | null>(null);
  const [erro, setErro] = useState<string | null>(null);

  useEffect(() => {
    let ativo = true;
    carregarOpcoes()
      .then((o) => ativo && setOpcoes(o))
      .catch((e: unknown) => ativo && setErro(e instanceof Error ? e.message : "Não foi possível carregar o formulário."));
    return () => {
      ativo = false;
    };
  }, []);

  return (
    <main className="mx-auto max-w-2xl px-4 py-8 sm:px-6">
      <h1 className="text-2xl font-semibold">Cadastro Musical</h1>
      <p className="mt-1 mb-6 text-sm text-slate-600">
        Preencha seus dados. Depois do envio, a secretaria analisa o cadastro. Campos com * são obrigatórios.
      </p>
      {erro && <p role="alert" className="rounded-lg bg-red-50 px-3 py-2 text-sm text-red-700">{erro}</p>}
      {!erro && !opcoes && <p className="text-sm text-slate-500">Carregando o formulário...</p>}
      {opcoes && <FormularioPublico opcoes={opcoes} />}
    </main>
  );
}
''',
    "src/app/(publico)/layout.tsx": r'''/**
 * SysMúsica — Layout das páginas PÚBLICAS (sem login, sem menu). Hoje: /cadastro.
 * Não usa o GuardaPainel: quem chega aqui não precisa estar logado. Nunca coloque dados internos nestas páginas.
 */
import type { ReactNode } from "react";

export const metadata = {
  title: "Cadastro Musical — SysMúsica",
  robots: { index: false, follow: false }, // o link é divulgado diretamente; não precisa aparecer em buscadores
};

export default function LayoutPublico({ children }: { children: ReactNode }) {
  return <div className="min-h-screen bg-slate-50 text-slate-900">{children}</div>;
}
''',
    "src/app/api/cadastro-publico/enviar/route.ts": r'''/**
 * SysMúsica — POST /api/cadastro-publico/enviar (PÚBLICA, sem login): passo 2 do envio do Cadastro Musical.
 *
 * Recebe o id do envio (criado no passo 1) e os dados do formulário. O banco refaz TODAS as conferências
 * (CPF, cargo, instrumento, menor de idade, aceite da LGPD, limite por CPF...) e grava um pedido PENDENTE.
 * A resposta é sempre a mesma ({ ok: true }), exista ou não um cadastro anterior com o CPF.
 */
import { NextResponse } from "next/server";
import { clienteAdmin } from "@/modules/administracao/server/clienteAdmin";
import { ErroHttp } from "@/modules/administracao/server/erros";
import { respostaDeErro } from "@/modules/administracao/server/resposta";
import { erroDoBanco, exigirUuid } from "@/modules/cadastroPublico/server/erros";
import { extrairIp, hashDoIp } from "@/modules/cadastroPublico/server/ip";

const TAMANHO_MAXIMO = 30_000; // caracteres; o formulário real fica bem abaixo disso

export async function POST(request: Request) {
  try {
    const texto = await request.text();
    if (texto.length > TAMANHO_MAXIMO) throw new ErroHttp(413, "Pedido grande demais.");
    let corpo: { envio_id?: unknown; dados?: unknown } | null = null;
    try {
      corpo = JSON.parse(texto) as { envio_id?: unknown; dados?: unknown };
    } catch {
      corpo = null;
    }
    if (!corpo || typeof corpo !== "object") throw new ErroHttp(400, "Pedido inválido.");
    const envioId = exigirUuid(corpo.envio_id);
    if (!corpo.dados || typeof corpo.dados !== "object" || Array.isArray(corpo.dados)) {
      throw new ErroHttp(400, "Pedido inválido.");
    }

    const sal = process.env.CADASTRO_PUBLICO_SALT ?? process.env.SUPABASE_SERVICE_ROLE_KEY ?? "";
    const ipHash = hashDoIp(extrairIp(request.headers), sal);
    const { error } = await clienteAdmin().rpc("registrar_cadastro_publico", {
      p_envio: envioId,
      p_dados: corpo.dados,
      p_ip_hash: ipHash,
    });
    if (error) throw erroDoBanco(error);
    return NextResponse.json({ ok: true }, { headers: { "Cache-Control": "no-store" } });
  } catch (erro) {
    return respostaDeErro(erro);
  }
}
''',
    "src/app/api/cadastro-publico/iniciar/route.ts": r'''/**
 * SysMúsica — POST /api/cadastro-publico/iniciar (PÚBLICA, sem login): passo 1 do envio do Cadastro Musical.
 *
 * 1) confere o campo-armadilha e o Turnstile (anti-robô) no servidor;
 * 2) o banco confere o limite de envios por IP e cria o id do envio;
 * 3) devolve 3 endereços de envio de uso único (foto, frente e verso) para o navegador mandar as imagens
 *    direto ao armazenamento privado (a Vercel limita o corpo de cada pedido a 4,5 MB).
 * Nada é gravado em "membros".
 */
import { NextResponse } from "next/server";
import { clienteAdmin } from "@/modules/administracao/server/clienteAdmin";
import { ErroHttp } from "@/modules/administracao/server/erros";
import { respostaDeErro } from "@/modules/administracao/server/resposta";
import { BUCKET_PUBLICO, caminhosNaFila } from "@/modules/cadastroPublico/server/arquivos";
import { erroDoBanco } from "@/modules/cadastroPublico/server/erros";
import { extrairIp, hashDoIp } from "@/modules/cadastroPublico/server/ip";
import { verificarTurnstile } from "@/modules/cadastroPublico/server/turnstile";

export async function POST(request: Request) {
  try {
    const corpo = (await request.json().catch(() => null)) as { turnstile?: unknown; site?: unknown } | null;
    if (!corpo || typeof corpo !== "object") throw new ErroHttp(400, "Pedido inválido.");
    // Campo-armadilha preenchido = robô. Mensagem genérica, sem explicar.
    if (typeof corpo.site === "string" && corpo.site.trim() !== "") {
      throw new ErroHttp(400, "Não foi possível enviar o cadastro. Atualize a página e tente de novo.");
    }

    const ip = extrairIp(request.headers);
    await verificarTurnstile(corpo.turnstile, ip);

    const admin = clienteAdmin();
    const sal = process.env.CADASTRO_PUBLICO_SALT ?? process.env.SUPABASE_SERVICE_ROLE_KEY ?? "";
    const { data, error } = await admin.rpc("iniciar_envio_publico", { p_ip_hash: hashDoIp(ip, sal) });
    if (error || typeof data !== "string") throw erroDoBanco(error ?? { message: "Envio não criado." });

    const caminhos = caminhosNaFila(data);
    const enderecos: Record<string, { caminho: string; token: string }> = {};
    for (const [nome, caminho] of Object.entries(caminhos)) {
      const { data: url, error: erroUrl } = await admin.storage.from(BUCKET_PUBLICO).createSignedUploadUrl(caminho);
      if (erroUrl || !url) throw new Error(`Endereço de envio não criado: ${erroUrl?.message ?? ""}`);
      enderecos[nome] = { caminho, token: url.token };
    }
    return NextResponse.json({ envio_id: data, ...enderecos }, { headers: { "Cache-Control": "no-store" } });
  } catch (erro) {
    return respostaDeErro(erro);
  }
}
''',
    "src/app/api/cadastros/[id]/aprovar/route.ts": r'''/**
 * SysMúsica — POST /api/cadastros/[id]/aprovar: aprova um cadastro pendente.
 *
 * Fluxo (precisa da permissão cadastros.aprovar e da abrangência, conferidas no banco):
 *  1) lê o pedido como o usuário (confirma que ele existe, está PENDENTE e é visível para quem aprova);
 *  2) MOVE as 3 imagens da fila para as pastas finais do membro (fotos-membros / documentos-membros);
 *  3) chama aprovar_cadastro_pendente COMO O USUÁRIO (cria/atualiza o membro e registra quem aprovou);
 *  4) se o banco recusar, DEVOLVE as imagens à fila; se aprovar, apaga as imagens antigas (atualização).
 */
import { NextResponse } from "next/server";
import { exigirPermissao } from "@/modules/administracao/server/autorizacao";
import { clienteAdmin } from "@/modules/administracao/server/clienteAdmin";
import { ErroHttp } from "@/modules/administracao/server/erros";
import { respostaDeErro } from "@/modules/administracao/server/resposta";
import { apagar, desfazer, moverTodos, movimentosDaAprovacao } from "@/modules/cadastroPublico/server/arquivos";
import { erroDoBanco, exigirUuid } from "@/modules/cadastroPublico/server/erros";
import { clienteDoUsuario } from "@/modules/cadastroPublico/server/usuario";

interface Detalhe {
  tipo: "NOVO" | "ATUALIZACAO";
  status: string;
  membro_id: string | null;
  arquivos_disponiveis: boolean;
  atual: unknown;
}

interface ResultadoAprovacao {
  membro_id: string;
  antigos: { foto?: string | null; doc_frente?: string | null; doc_verso?: string | null };
}

export async function POST(request: Request, contexto: { params: Promise<{ id: string }> }) {
  try {
    const id = exigirUuid((await contexto.params).id);
    await exigirPermissao(request, "cadastros.aprovar");
    const usuario = clienteDoUsuario(request);

    const { data, error } = await usuario.rpc("obter_cadastro_pendente", { p_id: id });
    if (error) throw erroDoBanco(error);
    const pedido = data as Detalhe;
    if (pedido.status !== "PENDENTE") throw new ErroHttp(409, "Este cadastro já foi analisado.");
    if (!pedido.arquivos_disponiveis) throw new ErroHttp(409, "As imagens deste cadastro não estão mais disponíveis. Recuse o pedido.");
    if (pedido.tipo === "ATUALIZACAO" && !pedido.atual) {
      throw new ErroHttp(409, "O membro deste pedido foi excluído. Recuse o pedido.");
    }

    // Atualização usa a pasta do membro existente; cadastro novo ganha um id novo (que o banco usa no INSERT)
    const membroId = pedido.tipo === "ATUALIZACAO" && pedido.membro_id ? pedido.membro_id : crypto.randomUUID();
    const mov = movimentosDaAprovacao(id, membroId, () => crypto.randomUUID());

    const admin = clienteAdmin();
    let feitos;
    try {
      feitos = await moverTodos(admin, [mov.foto, mov.frente, mov.verso]);
    } catch (e) {
      console.error("Falha ao mover as imagens do cadastro", id, e);
      throw new ErroHttp(409, "Não foi possível preparar as imagens. Atualize a lista e tente de novo.");
    }

    const { data: resultado, error: erroAprovar } = await usuario.rpc("aprovar_cadastro_pendente", {
      p_id: id,
      p_membro: pedido.tipo === "NOVO" ? membroId : null,
      p_foto: mov.foto.para.caminho,
      p_doc_frente: mov.frente.para.caminho,
      p_doc_verso: mov.verso.para.caminho,
    });
    if (erroAprovar) {
      await desfazer(admin, feitos); // o banco recusou: as imagens voltam para a fila
      throw erroDoBanco(erroAprovar);
    }

    // Atualização: apaga a foto e o documento que foram substituídos
    const antigos = (resultado as ResultadoAprovacao).antigos ?? {};
    await apagar(admin, "fotos-membros", [antigos.foto]);
    await apagar(admin, "documentos-membros", [antigos.doc_frente, antigos.doc_verso]);

    return NextResponse.json({ membro_id: (resultado as ResultadoAprovacao).membro_id }, { headers: { "Cache-Control": "no-store" } });
  } catch (erro) {
    return respostaDeErro(erro);
  }
}
''',
    "src/app/api/cadastros/[id]/arquivos/route.ts": r'''/**
 * SysMúsica — GET /api/cadastros/[id]/arquivos: endereços TEMPORÁRIOS (5 min) das imagens de um cadastro pendente.
 *
 * Quem chama precisa de cadastros.visualizar e enxergar a Casa de Oração do pedido (o banco confere em
 * obter_cadastro_pendente). A fotografia vai para quem passou nisso; a FRENTE e o VERSO do documento só vão
 * para quem também tem a permissão membros.cpf (mesma regra do documento do membro).
 */
import { NextResponse } from "next/server";
import { clienteAdmin } from "@/modules/administracao/server/clienteAdmin";
import { respostaDeErro } from "@/modules/administracao/server/resposta";
import { BUCKET_PUBLICO, caminhosNaFila } from "@/modules/cadastroPublico/server/arquivos";
import { erroDoBanco, exigirUuid } from "@/modules/cadastroPublico/server/erros";
import { clienteDoUsuario } from "@/modules/cadastroPublico/server/usuario";

const VALIDADE_SEGUNDOS = 300;

export async function GET(request: Request, contexto: { params: Promise<{ id: string }> }) {
  try {
    const id = exigirUuid((await contexto.params).id);
    const usuario = clienteDoUsuario(request);

    const { data: detalhe, error } = await usuario.rpc("obter_cadastro_pendente", { p_id: id });
    if (error) throw erroDoBanco(error);
    const cabecalhos = { "Cache-Control": "no-store" };
    if (!(detalhe as { arquivos_disponiveis?: boolean }).arquivos_disponiveis) {
      return NextResponse.json({ disponivel: false }, { headers: cabecalhos });
    }

    const { data: podeDocumento } = await usuario.rpc("tem_permissao", { p_codigo: "membros.cpf" });
    const caminhos = caminhosNaFila(id);
    const pedidos = [caminhos.foto, ...(podeDocumento === true ? [caminhos.frente, caminhos.verso] : [])];

    const { data: urls, error: erroUrls } = await clienteAdmin().storage.from(BUCKET_PUBLICO).createSignedUrls(pedidos, VALIDADE_SEGUNDOS);
    if (erroUrls || !urls) throw new Error(`Endereços não criados: ${erroUrls?.message ?? ""}`);
    const urlDe = (caminho: string) => urls.find((u) => u.path === caminho)?.signedUrl ?? null;

    return NextResponse.json(
      {
        disponivel: true,
        foto: urlDe(caminhos.foto),
        frente: podeDocumento === true ? urlDe(caminhos.frente) : null,
        verso: podeDocumento === true ? urlDe(caminhos.verso) : null,
        documentos_liberados: podeDocumento === true,
      },
      { headers: cabecalhos }
    );
  } catch (erro) {
    return respostaDeErro(erro);
  }
}
''',
    "src/modules/cadastroPublico/aviso.ts": r'''/**
 * SysMúsica — Aviso de privacidade do cadastro público (LGPD).
 *
 * ATENÇÃO (administradores): este texto é um modelo técnico, escrito para o SysMúsica. Antes de divulgar o link,
 * peça para o ministério/a CCB (e, se possível, um profissional de direito) revisar. Se o texto mudar de
 * significado, SUBA a versão (VERSAO_AVISO): o sistema grava, em cada cadastro, qual versão a pessoa aceitou.
 *
 * Os prazos abaixo são os mesmos aplicados pela limpeza automática do banco (migração 0042).
 */

/** Versão do texto aceito. Mude sempre que o texto mudar de significado. */
export const VERSAO_AVISO = "2026-10-v1";

/** Prazos de guarda dos cadastros que NÃO viraram membro (em dias). */
export const DIAS_PENDENTE_SEM_ANALISE = 60;
export const DIAS_REJEITADO_ATE_APAGAR = 30;

export interface ItemAviso {
  titulo: string;
  texto: string;
}

/**
 * Itens do aviso. `contato` é o e-mail (ou outro meio) para a pessoa exercer seus direitos; vem da variável
 * NEXT_PUBLIC_CONTATO_PRIVACIDADE. Sem ela, orienta procurar a secretaria da Casa de Oração.
 */
export function itensDoAviso(contato: string | null | undefined): ItemAviso[] {
  const meio = contato && contato.trim() !== "" ? contato.trim() : "a secretaria da sua Casa de Oração";
  return [
    {
      titulo: "Quem trata os seus dados",
      texto:
        "A administração musical da CCB da sua região, por meio do sistema SysMúsica, é quem analisa o seu cadastro e " +
        "decide como os dados são usados.",
    },
    {
      titulo: "Quais dados pedimos",
      texto:
        "Nome, CPF, data de nascimento, fotografia, documento de identificação (frente e verso), estado civil, sexo, " +
        "telefone, WhatsApp, e-mail, endereço, Casa de Oração, cargo e instrumento. Para alguns cargos, também os dados " +
        "do cartão de identificação. Para menores de 18 anos, o nome e o telefone do responsável.",
    },
    {
      titulo: "Dados sobre religião",
      texto:
        "Informar se você é batizado(a) e selado(a), e as datas, revela a sua crença religiosa, que a lei chama de dado " +
        "sensível. Por isso pedimos o seu consentimento específico para esses dados, e só os usamos para o cadastro " +
        "musical.",
    },
    {
      titulo: "Para que usamos",
      texto:
        "Avaliar e manter o seu cadastro musical, registrar a sua presença em ensaios e reuniões (portaria e QR Code) " +
        "e entrar em contato com você quando necessário. Não usamos os dados para publicidade.",
    },
    {
      titulo: "Quem pode ver",
      texto:
        "Somente pessoas autorizadas da CCB, da sua região. O CPF e o documento só podem ser vistos por quem recebeu " +
        "uma permissão específica. Não vendemos nem repassamos os dados. Os serviços de hospedagem e de banco de dados " +
        "do sistema armazenam as informações em nosso nome.",
    },
    {
      titulo: "Por quanto tempo guardamos",
      texto:
        `Enquanto o seu cadastro estiver ativo. Se ele não for aprovado, apagamos os seus dados e arquivos em até ` +
        `${DIAS_REJEITADO_ATE_APAGAR} dias depois da recusa, ou em ${DIAS_PENDENTE_SEM_ANALISE} dias se ninguém analisar.`,
    },
    {
      titulo: "Seus direitos",
      texto:
        `Você pode pedir a confirmação do tratamento, o acesso, a correção ou a exclusão dos seus dados, e retirar este ` +
        `consentimento quando quiser, falando com ${meio}.`,
    },
    {
      titulo: "Menores de 18 anos",
      texto:
        "O cadastro de menores só é enviado com o nome, o telefone e a concordância de um responsável.",
    },
  ];
}
''',
    "src/modules/cadastroPublico/components/BotaoCopiarLink.tsx": r'''"use client";

/**
 * SysMúsica — Botão "Copiar link do cadastro" (Músicos / Organistas).
 * O link é o endereço do próprio sistema + /cadastro: o mesmo para todo mundo. Quem receber preenche o formulário
 * público; o cadastro cai em "Cadastros pendentes" para aprovação.
 */
import { useState } from "react";
import { Check, Link2 } from "lucide-react";

export default function BotaoCopiarLinkCadastro() {
  const [copiado, setCopiado] = useState(false);
  const [falhou, setFalhou] = useState(false);

  async function copiar() {
    const link = `${window.location.origin}/cadastro`;
    setFalhou(false);
    try {
      await navigator.clipboard.writeText(link);
      setCopiado(true);
      setTimeout(() => setCopiado(false), 2500);
    } catch {
      // Sem permissão para a área de transferência: mostra o link para copiar à mão
      setFalhou(true);
      window.prompt("Copie o link do cadastro:", link);
    }
  }

  return (
    <button
      type="button"
      onClick={() => void copiar()}
      title="Copia o link do formulário público de cadastro, para enviar às pessoas"
      className="inline-flex items-center gap-2 rounded-lg border border-slate-300 bg-white px-4 py-2 text-sm font-medium text-slate-700 shadow-sm transition hover:bg-slate-50"
    >
      {copiado ? <Check className="h-4 w-4 text-emerald-600" aria-hidden="true" /> : <Link2 className="h-4 w-4" aria-hidden="true" />}
      {copiado ? "Link copiado!" : falhou ? "Copiar link" : "Copiar link do cadastro"}
    </button>
  );
}
''',
    "src/modules/cadastroPublico/components/Campos.tsx": r'''import type { ReactNode } from "react";

/** Estilo único dos campos do formulário público (igual ao do cadastro interno). */
export const classeInput =
  "w-full rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 " +
  "placeholder:text-slate-400 shadow-sm focus:border-brand-500 focus:outline-none " +
  "focus:ring-2 focus:ring-brand-200 disabled:cursor-not-allowed disabled:opacity-60 " +
  "[color-scheme:light]";

/** Bloco com título (ex.: "Identificação"). */
export function Secao({ titulo, children }: { titulo: string; children: ReactNode }) {
  return (
    <section className="space-y-4">
      <h2 className="border-b border-slate-200 pb-1 text-xs font-semibold uppercase tracking-wide text-slate-500">
        {titulo}
      </h2>
      {children}
    </section>
  );
}

/** Campo com rótulo, marcação de obrigatório (*) ou (opcional) e dica opcional. */
export function Campo({
  id,
  rotulo,
  obrigatorio = false,
  dica,
  children,
}: {
  id: string;
  rotulo: string;
  obrigatorio?: boolean;
  dica?: string;
  children: ReactNode;
}) {
  return (
    <div className="space-y-1.5">
      <label htmlFor={id} className="text-sm font-medium text-slate-700">
        {rotulo}{" "}
        {obrigatorio ? (
          <span className="font-normal text-red-600" aria-hidden="true">
            *
          </span>
        ) : (
          <span className="font-normal text-slate-400">(opcional)</span>
        )}
      </label>
      {children}
      {dica && <p className="text-xs text-slate-500">{dica}</p>}
    </div>
  );
}
''',
    "src/modules/cadastroPublico/components/FormularioPublico.tsx": r'''"use client";

/**
 * SysMúsica — Formulário PÚBLICO do Cadastro Musical (sem login). Página: /cadastro.
 * Mesmos campos do cadastro interno, mais: aviso de privacidade (LGPD), responsável (menores de 18 anos) e
 * verificação anti-robô. O envio NÃO cria o membro: gera um pedido que a secretaria aprova em "Cadastros pendentes".
 * Depois de enviar, a tela é sempre a mesma, exista ou não um cadastro anterior com o mesmo CPF.
 */
import { useCallback, useMemo, useState, type FormEvent } from "react";
import { CheckCircle2, Send } from "lucide-react";
import CampoFoto from "@/modules/membros/components/CampoFoto";
import CampoDocumento from "@/modules/membros/components/CampoDocumento";
import SeletorInstrumento, { FamiliaAutomatica } from "@/modules/instrumentos/components/SeletorInstrumento";
import { buscarEnderecoPorCep } from "@/modules/membros/services/cep";
import {
  ESTADOS_CIVIS,
  SEXOS,
  UFS,
  CADASTRO_VAZIO,
  cargoExigeCartao,
  formatarCep,
  formatarTelefone,
  formatarWhatsapp,
  somenteDigitos,
  type CadastroMusical,
  type SimNao,
} from "@/modules/membros/cadastroMusical";
import { CATEGORIAS, cargoUsaCategoria } from "@/modules/painel/regras";
import { formatarCpfParcial } from "../cpf";
import { itensDoAviso } from "../aviso";
import { enviarCadastroPublico } from "../services/envio";
import {
  MENSAGEM_ENVIO_RECEBIDO,
  cargosDoFormularioPublico,
  ehMenorDeIdade,
  formularioVazio,
  instrumentosDoFormularioPublico,
  montarCargaPublica,
  validarEnvioPublico,
  type DadosFormularioPublico,
  type OpcoesCadastroPublico,
} from "../regras";
import { Campo, Secao, classeInput } from "./Campos";
import SeletorCasaPublico from "./SeletorCasaPublico";
import Turnstile from "./Turnstile";

/** Data de hoje (AAAA-MM-DD) no fuso do navegador. */
function hojeIso(): string {
  const d = new Date();
  const p = (n: number) => String(n).padStart(2, "0");
  return `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())}`;
}

export default function FormularioPublico({ opcoes }: { opcoes: OpcoesCadastroPublico }) {
  const [dados, setDados] = useState<DadosFormularioPublico>(() => formularioVazio(CADASTRO_VAZIO));
  const [foto, setFoto] = useState<Blob | null>(null);
  const [frente, setFrente] = useState<Blob | null>(null);
  const [verso, setVerso] = useState<Blob | null>(null);
  const [token, setToken] = useState("");
  const [reiniciarTurnstile, setReiniciarTurnstile] = useState(0);
  const [enviando, setEnviando] = useState(false);
  const [erro, setErro] = useState<string | null>(null);
  const [enviado, setEnviado] = useState(false);
  const [avisoCep, setAvisoCep] = useState<string | null>(null);
  const [buscandoCep, setBuscandoCep] = useState(false);

  const cargos = useMemo(() => cargosDoFormularioPublico(opcoes.cargos), [opcoes.cargos]);
  const cargo = cargos.find((c) => c.id === dados.cargoId);
  const tipoCategoria = cargoUsaCategoria(cargo?.nome);
  const instrumentos = instrumentosDoFormularioPublico(opcoes.instrumentos, cargo);
  const menor = ehMenorDeIdade(dados.dataNascimento, hojeIso());
  const itens = useMemo(() => itensDoAviso(process.env.NEXT_PUBLIC_CONTATO_PRIVACIDADE), []);

  const mudar = <K extends keyof DadosFormularioPublico>(campo: K, valor: DadosFormularioPublico[K]) =>
    setDados((d) => ({ ...d, [campo]: valor }));
  const mudarCad = <K extends keyof CadastroMusical>(campo: K, valor: CadastroMusical[K]) =>
    setDados((d) => ({ ...d, cadastro: { ...d.cadastro, [campo]: valor } }));

  const aoToken = useCallback((t: string) => setToken(t), []);

  // Preenche o endereço pelo CEP (ViaCEP); se falhar, a pessoa digita
  async function aoSairDoCep() {
    const cep = dados.cadastro.cep;
    setAvisoCep(null);
    if (!/^\d{8}$/.test(cep)) return;
    setBuscandoCep(true);
    const r = await buscarEnderecoPorCep(cep);
    setBuscandoCep(false);
    if (r.tipo === "ok") {
      setDados((d) => ({
        ...d,
        cidade: r.endereco.cidade || d.cidade,
        bairro: r.endereco.bairro || d.bairro,
        cadastro: {
          ...d.cadastro,
          endereco: r.endereco.endereco || d.cadastro.endereco,
          complemento: d.cadastro.complemento || r.endereco.complemento,
          uf: r.endereco.uf || d.cadastro.uf,
        },
      }));
    } else {
      setAvisoCep(r.tipo === "nao_encontrado" ? "CEP não encontrado. Digite o endereço." : "Não consegui consultar o CEP agora. Digite o endereço.");
    }
  }

  async function aoEnviar(e: FormEvent) {
    e.preventDefault();
    if (enviando) return;
    const hoje = hojeIso();
    const problema = validarEnvioPublico(dados, {
      cargo,
      temFoto: foto !== null,
      temDocumentoFrente: frente !== null,
      temDocumentoVerso: verso !== null,
      hoje,
    });
    if (problema) return setErro(problema);
    if (token === "") return setErro("Aguarde a verificação de segurança e tente de novo.");
    if (!foto || !frente || !verso) return;

    setErro(null);
    setEnviando(true);
    try {
      await enviarCadastroPublico(montarCargaPublica(dados, { cargo, hoje }), { foto, frente, verso }, token);
      setEnviado(true);
    } catch (ex) {
      setErro(ex instanceof Error ? ex.message : "Não foi possível enviar o cadastro.");
      setToken(""); // o token vale uma só vez: pede uma nova verificação
      setReiniciarTurnstile((n) => n + 1);
    } finally {
      setEnviando(false);
    }
  }

  if (enviado) {
    return (
      <div role="status" className="rounded-2xl border border-emerald-200 bg-emerald-50 p-6 text-center">
        <CheckCircle2 className="mx-auto h-10 w-10 text-emerald-600" aria-hidden="true" />
        <p className="mt-3 text-base font-medium text-emerald-900">{MENSAGEM_ENVIO_RECEBIDO}</p>
      </div>
    );
  }

  const cad = dados.cadastro;
  const exigeCartao = cargoExigeCartao(cargo);
  const bloqueado = enviando;

  return (
    <form onSubmit={(ev) => void aoEnviar(ev)} className="space-y-8" noValidate>
      {/* Campo-armadilha: invisível para pessoas; robôs costumam preencher. Não remova. */}
      <div aria-hidden="true" className="absolute -left-[9999px] h-0 w-0 overflow-hidden">
        <label htmlFor="site">Site</label>
        <input id="site" type="text" tabIndex={-1} autoComplete="off" value={dados.site} onChange={(e) => mudar("site", e.target.value)} />
      </div>

      <Secao titulo="Fotografia">
        <CampoFoto nome={dados.nome || "você"} obrigatoria onChange={setFoto} disabled={bloqueado} />
      </Secao>

      <Secao titulo="Identificação">
        <Campo id="nome" rotulo="Nome completo" obrigatorio>
          <input id="nome" type="text" autoComplete="name" maxLength={120} value={dados.nome} onChange={(e) => mudar("nome", e.target.value)} disabled={bloqueado} className={classeInput} placeholder="Ex: João da Silva" />
        </Campo>
        <div className="grid gap-3 sm:grid-cols-2">
          <Campo id="cpf" rotulo="CPF" obrigatorio>
            <input id="cpf" type="text" inputMode="numeric" autoComplete="off" value={dados.cpf} onChange={(e) => mudar("cpf", formatarCpfParcial(e.target.value))} disabled={bloqueado} className={classeInput} placeholder="000.000.000-00" />
          </Campo>
          <Campo id="nascimento" rotulo="Data de nascimento" obrigatorio>
            <input id="nascimento" type="date" autoComplete="bday" max={hojeIso()} value={dados.dataNascimento} onChange={(e) => mudar("dataNascimento", e.target.value)} disabled={bloqueado} className={classeInput} />
          </Campo>
        </div>
        <div className="grid gap-3 sm:grid-cols-2">
          <Campo id="estado_civil" rotulo="Estado civil" obrigatorio>
            <select id="estado_civil" value={cad.estado_civil} onChange={(e) => mudarCad("estado_civil", e.target.value)} disabled={bloqueado} className={classeInput}>
              <option value="">Selecione</option>
              {ESTADOS_CIVIS.map((v) => <option key={v} value={v}>{v}</option>)}
            </select>
          </Campo>
          <Campo id="sexo" rotulo="Sexo" obrigatorio>
            <select id="sexo" value={cad.sexo} onChange={(e) => mudarCad("sexo", e.target.value)} disabled={bloqueado} className={classeInput}>
              <option value="">Selecione</option>
              {SEXOS.map((v) => <option key={v} value={v}>{v}</option>)}
            </select>
          </Campo>
        </div>
      </Secao>

      {menor && (
        <Secao titulo="Responsável (menor de 18 anos)">
          <Campo id="resp-nome" rotulo="Nome do responsável" obrigatorio>
            <input id="resp-nome" type="text" maxLength={120} value={dados.responsavelNome} onChange={(e) => mudar("responsavelNome", e.target.value)} disabled={bloqueado} className={classeInput} />
          </Campo>
          <Campo id="resp-tel" rotulo="Telefone do responsável (com DDD)" obrigatorio>
            <input id="resp-tel" type="tel" inputMode="numeric" value={dados.responsavelTelefone} onChange={(e) => mudar("responsavelTelefone", formatarWhatsapp(e.target.value))} disabled={bloqueado} className={classeInput} />
          </Campo>
          <label className="flex items-start gap-2 text-sm text-slate-700">
            <input type="checkbox" checked={dados.aceiteResponsavel} onChange={(e) => mudar("aceiteResponsavel", e.target.checked)} disabled={bloqueado} className="mt-0.5" />
            <span>Eu sou o responsável e concordo com este cadastro e com o aviso de privacidade.</span>
          </label>
        </Secao>
      )}

      <Secao titulo="Casa de Oração e cargo">
        <Campo id="casa" rotulo="Casa de Oração" obrigatorio dica="Se a sua Casa de Oração não aparecer, procure a secretaria.">
          <SeletorCasaPublico id="casa" valor={dados.casaOracaoId} onChange={(v) => mudar("casaOracaoId", v)} casas={opcoes.casas} disabled={bloqueado} />
        </Campo>
        <Campo id="cargo" rotulo="Cargo" obrigatorio>
          <select
            id="cargo"
            value={dados.cargoId}
            onChange={(e) => setDados((d) => ({ ...d, cargoId: e.target.value, categoria: "", instrumentoId: "" }))}
            disabled={bloqueado}
            className={classeInput}
          >
            <option value="">Selecione o cargo</option>
            {cargos.map((c) => <option key={c.id} value={c.id}>{c.nome}</option>)}
          </select>
        </Campo>
        {tipoCategoria && (
          <Campo id="categoria" rotulo="Categoria" obrigatorio>
            <select id="categoria" value={dados.categoria} onChange={(e) => mudar("categoria", e.target.value)} disabled={bloqueado} className={classeInput}>
              <option value="">Selecione a categoria</option>
              {CATEGORIAS.map((c) => <option key={c.valor} value={c.valor}>{c[tipoCategoria === "organista" ? "organista" : "musico"]}</option>)}
            </select>
          </Campo>
        )}
        {cargo?.permite_instrumento && (
          <>
            <Campo id="instrumento" rotulo="Instrumento" obrigatorio>
              <SeletorInstrumento id="instrumento" valor={dados.instrumentoId} onChange={(v) => mudar("instrumentoId", v)} instrumentos={instrumentos} familias={opcoes.familias} obrigatorio disabled={bloqueado} className={classeInput} />
            </Campo>
            <FamiliaAutomatica instrumentoId={dados.instrumentoId} instrumentos={instrumentos} familias={opcoes.familias} />
          </>
        )}
      </Secao>

      <Secao titulo="Dados religiosos (consentimento específico)">
        <div className="grid gap-3 sm:grid-cols-2">
          <Campo id="batizado" rotulo="É batizado(a)?" obrigatorio>
            <select id="batizado" value={cad.batizado} onChange={(e) => mudarCad("batizado", e.target.value as SimNao)} disabled={bloqueado} className={classeInput}>
              <option value="">Selecione</option>
              <option value="sim">Sim</option>
              <option value="nao">Não</option>
            </select>
          </Campo>
          {cad.batizado === "sim" && (
            <Campo id="data_batismo" rotulo="Data do batismo" obrigatorio>
              <input id="data_batismo" type="date" value={cad.data_batismo} onChange={(e) => mudarCad("data_batismo", e.target.value)} disabled={bloqueado} className={classeInput} />
            </Campo>
          )}
        </div>
        <Campo id="selado" rotulo="É selado(a)?" obrigatorio>
          <select id="selado" value={cad.selado} onChange={(e) => mudarCad("selado", e.target.value as SimNao)} disabled={bloqueado} className={classeInput}>
            <option value="">Selecione</option>
            <option value="sim">Sim</option>
            <option value="nao">Não</option>
          </select>
        </Campo>
      </Secao>

      <Secao titulo="Contato">
        <div className="grid grid-cols-3 gap-3">
          <Campo id="ddd" rotulo="DDD" obrigatorio>
            <input id="ddd" type="tel" inputMode="numeric" maxLength={2} value={cad.ddd} onChange={(e) => mudarCad("ddd", somenteDigitos(e.target.value, 2))} disabled={bloqueado} className={classeInput} />
          </Campo>
          <div className="col-span-2">
            <Campo id="telefone" rotulo="Telefone" obrigatorio>
              <input id="telefone" type="tel" inputMode="numeric" value={cad.telefone} onChange={(e) => mudarCad("telefone", formatarTelefone(e.target.value))} disabled={bloqueado} className={classeInput} />
            </Campo>
          </div>
        </div>
        <Campo id="tem_whatsapp" rotulo="O telefone tem WhatsApp?" obrigatorio>
          <select id="tem_whatsapp" value={cad.tem_whatsapp} onChange={(e) => mudarCad("tem_whatsapp", e.target.value as SimNao)} disabled={bloqueado} className={classeInput}>
            <option value="">Selecione</option>
            <option value="sim">Sim</option>
            <option value="nao">Não</option>
          </select>
        </Campo>
        {cad.tem_whatsapp === "sim" && (
          <Campo id="whatsapp" rotulo="WhatsApp (com DDD)" dica="Deixe vazio se for o mesmo número do telefone.">
            <input id="whatsapp" type="tel" inputMode="numeric" value={cad.whatsapp} onChange={(e) => mudarCad("whatsapp", formatarWhatsapp(e.target.value))} disabled={bloqueado} className={classeInput} />
          </Campo>
        )}
        <Campo id="email" rotulo="E-mail">
          <input id="email" type="email" autoComplete="email" maxLength={120} value={cad.email} onChange={(e) => mudarCad("email", e.target.value)} disabled={bloqueado} className={classeInput} />
        </Campo>
      </Secao>

      <Secao titulo="Endereço">
        <Campo id="cep" rotulo="CEP" obrigatorio dica={buscandoCep ? "Consultando o CEP..." : (avisoCep ?? undefined)}>
          <input id="cep" type="text" inputMode="numeric" autoComplete="postal-code" value={formatarCep(cad.cep)} onChange={(e) => mudarCad("cep", somenteDigitos(e.target.value, 8))} onBlur={() => void aoSairDoCep()} disabled={bloqueado} className={classeInput} />
        </Campo>
        <Campo id="endereco" rotulo="Endereço" obrigatorio>
          <input id="endereco" type="text" autoComplete="street-address" maxLength={150} value={cad.endereco} onChange={(e) => mudarCad("endereco", e.target.value)} disabled={bloqueado} className={classeInput} />
        </Campo>
        <div className="grid grid-cols-2 gap-3">
          <Campo id="numero" rotulo="Número" obrigatorio>
            <input id="numero" type="text" maxLength={20} value={cad.numero} onChange={(e) => mudarCad("numero", e.target.value)} disabled={bloqueado} className={classeInput} />
          </Campo>
          <Campo id="complemento" rotulo="Complemento">
            <input id="complemento" type="text" maxLength={80} value={cad.complemento} onChange={(e) => mudarCad("complemento", e.target.value)} disabled={bloqueado} className={classeInput} />
          </Campo>
        </div>
        <div className="grid gap-3 sm:grid-cols-3">
          <Campo id="bairro" rotulo="Bairro" obrigatorio>
            <input id="bairro" type="text" maxLength={80} value={dados.bairro} onChange={(e) => mudar("bairro", e.target.value)} disabled={bloqueado} className={classeInput} />
          </Campo>
          <Campo id="cidade" rotulo="Cidade" obrigatorio>
            <input id="cidade" type="text" maxLength={80} value={dados.cidade} onChange={(e) => mudar("cidade", e.target.value)} disabled={bloqueado} className={classeInput} />
          </Campo>
          <Campo id="uf" rotulo="UF" obrigatorio>
            <select id="uf" value={cad.uf} onChange={(e) => mudarCad("uf", e.target.value)} disabled={bloqueado} className={classeInput}>
              <option value="">UF</option>
              {UFS.map((u) => <option key={u} value={u}>{u}</option>)}
            </select>
          </Campo>
        </div>
      </Secao>

      {exigeCartao && (
        <Secao titulo="Cartão de identificação">
          <Campo id="cartao_numero" rotulo="Número do cartão" obrigatorio>
            <input id="cartao_numero" type="text" autoComplete="off" maxLength={40} value={cad.cartao_numero} onChange={(e) => mudarCad("cartao_numero", e.target.value)} disabled={bloqueado} className={classeInput} />
          </Campo>
          <div className="grid grid-cols-2 gap-3">
            <Campo id="cartao_emissao" rotulo="Emissão">
              <input id="cartao_emissao" type="date" value={cad.cartao_emissao} onChange={(e) => mudarCad("cartao_emissao", e.target.value)} disabled={bloqueado} className={classeInput} />
            </Campo>
            <Campo id="cartao_validade" rotulo="Validade" obrigatorio>
              <input id="cartao_validade" type="date" value={cad.cartao_validade} onChange={(e) => mudarCad("cartao_validade", e.target.value)} disabled={bloqueado} className={classeInput} />
            </Campo>
          </div>
        </Secao>
      )}

      <Secao titulo="Documento de identificação">
        <p className="text-xs text-slate-500">Anexe uma foto da frente e uma do verso (RG ou CNH). Os arquivos ficam em armazenamento privado.</p>
        <CampoDocumento id="pub-doc-frente" rotulo="Frente do documento" obrigatorio onChange={setFrente} disabled={bloqueado} />
        <CampoDocumento id="pub-doc-verso" rotulo="Verso do documento" obrigatorio onChange={setVerso} disabled={bloqueado} />
      </Secao>

      <Secao titulo="Aviso de privacidade (LGPD)">
        <div className="max-h-64 space-y-3 overflow-y-auto rounded-lg border border-slate-200 bg-slate-50 p-3 text-sm text-slate-700">
          {itens.map((item) => (
            <div key={item.titulo}>
              <p className="font-semibold">{item.titulo}</p>
              <p>{item.texto}</p>
            </div>
          ))}
        </div>
        <label className="flex items-start gap-2 text-sm text-slate-800">
          <input type="checkbox" checked={dados.aceitePrivacidade} onChange={(e) => mudar("aceitePrivacidade", e.target.checked)} disabled={bloqueado} className="mt-0.5" />
          <span>Li e concordo com o aviso de privacidade, inclusive com o uso dos dados sobre batismo e selamento.</span>
        </label>
      </Secao>

      <Turnstile onToken={aoToken} reiniciar={reiniciarTurnstile} />

      {erro && (
        <p role="alert" className="rounded-lg bg-red-50 px-3 py-2 text-sm text-red-700">
          {erro}
        </p>
      )}

      <button
        type="submit"
        disabled={enviando}
        className="inline-flex w-full items-center justify-center gap-2 rounded-lg bg-brand-600 px-4 py-3 text-sm font-semibold text-white shadow-sm transition hover:bg-brand-700 disabled:cursor-not-allowed disabled:opacity-60"
      >
        <Send className="h-4 w-4" aria-hidden="true" />
        {enviando ? "Enviando..." : "Enviar cadastro"}
      </button>
    </form>
  );
}
''',
    "src/modules/cadastroPublico/components/SeletorCasaPublico.tsx": r'''"use client";

/**
 * SysMúsica — Escolha da Casa de Oração no formulário público.
 * A lista vem da função pública opcoes_cadastro_publico (só nome e caminho na organização: RRM › RA › ADM › Setor).
 * Há uma busca por texto para achar a casa sem rolar a lista inteira.
 */
import { useMemo, useState } from "react";
import type { CasaPublica } from "../regras";
import { classeInput } from "./Campos";

function semAcento(texto: string): string {
  return texto.normalize("NFD").replace(/[̀-ͯ]/g, "").toLowerCase();
}

function caminho(casa: CasaPublica): string {
  return [casa.rrm, casa.ra, casa.adm, casa.setor].filter((parte): parte is string => !!parte).join(" › ");
}

interface Props {
  id: string;
  valor: string;
  onChange: (id: string) => void;
  casas: CasaPublica[];
  disabled?: boolean;
}

export default function SeletorCasaPublico({ id, valor, onChange, casas, disabled }: Props) {
  const [busca, setBusca] = useState("");

  const filtradas = useMemo(() => {
    const termo = semAcento(busca.trim());
    const lista = termo === "" ? casas : casas.filter((c) => semAcento(`${c.nome} ${caminho(c)}`).includes(termo));
    // A casa já escolhida nunca some da lista, mesmo que a busca mude
    const escolhida = casas.find((c) => c.id === valor);
    return escolhida && !lista.some((c) => c.id === valor) ? [escolhida, ...lista] : lista;
  }, [busca, casas, valor]);

  return (
    <div className="space-y-2">
      <input
        type="search"
        value={busca}
        onChange={(e) => setBusca(e.target.value)}
        disabled={disabled}
        placeholder="Digite parte do nome da Casa de Oração para filtrar"
        aria-label="Filtrar Casas de Oração"
        className={classeInput}
      />
      <select id={id} value={valor} onChange={(e) => onChange(e.target.value)} required disabled={disabled} className={classeInput}>
        <option value="">Selecione a Casa de Oração</option>
        {filtradas.map((casa) => (
          <option key={casa.id} value={casa.id}>
            {casa.nome}
            {caminho(casa) ? ` — ${caminho(casa)}` : ""}
          </option>
        ))}
      </select>
    </div>
  );
}
''',
    "src/modules/cadastroPublico/components/Turnstile.tsx": r'''"use client";

/**
 * SysMúsica — Verificação anti-robô (Cloudflare Turnstile).
 * Precisa da variável NEXT_PUBLIC_TURNSTILE_SITE_KEY (chave do site, pública). Sem ela, avisa que o formulário
 * está indisponível: o servidor também recusa o envio sem a verificação ("falha fechada").
 * Para testar localmente use a chave de teste da Cloudflare 1x00000000000000000000AA.
 */
import { useEffect, useRef, useState } from "react";

interface ApiTurnstile {
  render: (
    el: HTMLElement,
    opcoes: {
      sitekey: string;
      callback: (token: string) => void;
      "expired-callback": () => void;
      "error-callback": () => void;
      language?: string;
    }
  ) => string;
  remove: (id: string) => void;
  reset: (id: string) => void;
}

declare global {
  interface Window {
    turnstile?: ApiTurnstile;
  }
}

const SCRIPT = "https://challenges.cloudflare.com/turnstile/v0/api.js?render=explicit";

interface TurnstileProps {
  /** Recebe o token (ou "" quando expira/erra). */
  onToken: (token: string) => void;
  /** Aumente este número para pedir uma NOVA verificação (o token vale uma só vez, mesmo se o envio falhar). */
  reiniciar?: number;
}

export default function Turnstile({ onToken, reiniciar = 0 }: TurnstileProps) {
  const caixa = useRef<HTMLDivElement>(null);
  const idWidgetRef = useRef<string | null>(null);
  const [indisponivel, setIndisponivel] = useState(false);
  const chave = process.env.NEXT_PUBLIC_TURNSTILE_SITE_KEY;

  useEffect(() => {
    if (!chave || !caixa.current) return;
    const alvo = caixa.current;
    let idWidget: string | null = null;
    let cancelado = false;

    function desenhar() {
      if (cancelado || !window.turnstile) return;
      idWidget = window.turnstile.render(alvo, {
        sitekey: chave as string,
        language: "pt-br",
        callback: (token) => onToken(token),
        "expired-callback": () => onToken(""),
        "error-callback": () => onToken(""),
      });
      idWidgetRef.current = idWidget;
    }

    if (window.turnstile) {
      desenhar();
    } else {
      let script = document.querySelector<HTMLScriptElement>(`script[src="${SCRIPT}"]`);
      if (!script) {
        script = document.createElement("script");
        script.src = SCRIPT;
        script.async = true;
        document.head.appendChild(script);
      }
      script.addEventListener("load", desenhar);
      script.addEventListener("error", () => setIndisponivel(true));
    }
    return () => {
      cancelado = true;
      if (idWidget && window.turnstile) window.turnstile.remove(idWidget);
    };
  }, [chave, onToken]);

  // Nova verificação a pedido do formulário (depois de um envio que falhou)
  useEffect(() => {
    if (reiniciar > 0 && idWidgetRef.current && window.turnstile) window.turnstile.reset(idWidgetRef.current);
  }, [reiniciar]);

  if (!chave || indisponivel) {
    return (
      <p role="alert" className="rounded-lg bg-amber-50 px-3 py-2 text-sm text-amber-800">
        A verificação de segurança está indisponível no momento. Tente novamente mais tarde.
      </p>
    );
  }
  return <div ref={caixa} className="min-h-[65px]" />;
}
''',
    "src/modules/cadastroPublico/cpf.ts": r'''/**
 * SysMúsica — Conferência do CPF (dígitos verificadores) para o cadastro público.
 * Mesma regra de src/lib/cpf.ts; fica aqui para o cadastro público (e as rotas do servidor) não dependerem da tela interna.
 */

/** Só os números do texto digitado. */
export function soDigitos(texto: string): string {
  return texto.replace(/\D/g, "");
}

/** CPF válido? Aceita com ou sem pontuação. Recusa sequências repetidas (111.111.111-11 etc.). */
export function cpfValido(texto: string): boolean {
  const cpf = soDigitos(texto);
  if (cpf.length !== 11 || /^(\d)\1{10}$/.test(cpf)) return false;
  const digito = (tamanho: number): number => {
    let soma = 0;
    for (let i = 0; i < tamanho; i++) soma += Number(cpf[i]) * (tamanho + 1 - i);
    const resto = (soma * 10) % 11;
    return resto === 10 ? 0 : resto;
  };
  return digito(9) === Number(cpf[9]) && digito(10) === Number(cpf[10]);
}

/** "123.456.789-09" (aceita digitação parcial). */
export function formatarCpfParcial(texto: string): string {
  const d = soDigitos(texto).slice(0, 11);
  if (d.length > 9) return `${d.slice(0, 3)}.${d.slice(3, 6)}.${d.slice(6, 9)}-${d.slice(9)}`;
  if (d.length > 6) return `${d.slice(0, 3)}.${d.slice(3, 6)}.${d.slice(6)}`;
  if (d.length > 3) return `${d.slice(0, 3)}.${d.slice(3)}`;
  return d;
}
''',
    "src/modules/cadastroPublico/regras.test.ts": r'''import { describe, expect, it } from "vitest";
import { CADASTRO_VAZIO, type CadastroMusical } from "@/modules/membros/cadastroMusical";
import { cpfValido, formatarCpfParcial } from "./cpf";
import { VERSAO_AVISO, itensDoAviso } from "./aviso";
import {
  cargosDoFormularioPublico,
  dataIsoValida,
  ehMenorDeIdade,
  formularioVazio,
  idadeEm,
  montarCargaPublica,
  validarEnvioPublico,
  type CargoPublico,
  type DadosFormularioPublico,
} from "./regras";

const HOJE = "2026-10-21";
const musico: CargoPublico = { id: "c1", nome: "Músico", permite_instrumento: true, exige_instrumento: true, exige_cartao: false };
const encarregado: CargoPublico = { id: "c2", nome: "Encarregado Local", permite_instrumento: true, exige_instrumento: false, exige_cartao: true };
const ctx = (cargo: CargoPublico | undefined = musico) => ({ cargo, temFoto: true, temDocumentoFrente: true, temDocumentoVerso: true, hoje: HOJE });

const cadastroOk: CadastroMusical = {
  ...CADASTRO_VAZIO,
  estado_civil: "Solteiro (a)", sexo: "Masculino", batizado: "nao", selado: "nao",
  ddd: "11", telefone: "987654321", tem_whatsapp: "sim",
  cep: "01001000", endereco: "Praça da Sé", numero: "1", uf: "SP",
};
function base(extra: Partial<DadosFormularioPublico> = {}): DadosFormularioPublico {
  return {
    ...formularioVazio(CADASTRO_VAZIO),
    nome: "João da Silva", casaOracaoId: "casa1", cargoId: "c1", instrumentoId: "i1", categoria: "OFICIALIZADO",
    cpf: "529.982.247-25", dataNascimento: "1990-05-10", cidade: "São Paulo", bairro: "Sé",
    cadastro: cadastroOk, aceitePrivacidade: true, ...extra,
  };
}

describe("cpf", () => {
  it("aceita válido, recusa inválido e repetido", () => {
    expect(cpfValido("529.982.247-25")).toBe(true);
    expect(cpfValido("52998224725")).toBe(true);
    expect(cpfValido("529.982.247-24")).toBe(false);
    expect(cpfValido("111.111.111-11")).toBe(false);
    expect(cpfValido("123")).toBe(false);
  });
  it("formata parcial", () => {
    expect(formatarCpfParcial("5299822")).toBe("529.982.2");
    expect(formatarCpfParcial("52998224725999")).toBe("529.982.247-25");
  });
});

describe("datas e idade", () => {
  it("valida datas existentes", () => {
    expect(dataIsoValida("2024-02-29")).toBe(true);
    expect(dataIsoValida("2026-02-29")).toBe(false);
    expect(dataIsoValida("10/05/1990")).toBe(false);
  });
  it("calcula a idade no aniversário", () => {
    expect(idadeEm("2008-10-21", HOJE)).toBe(18);
    expect(idadeEm("2008-10-22", HOJE)).toBe(17);
    expect(ehMenorDeIdade("2008-10-22", HOJE)).toBe(true);
    expect(ehMenorDeIdade("2008-10-21", HOJE)).toBe(false);
    expect(ehMenorDeIdade("lixo", HOJE)).toBe(false);
  });
});

describe("validarEnvioPublico", () => {
  it("aceita um cadastro completo", () => expect(validarEnvioPublico(base(), ctx())).toBeNull());
  it("barra o robô (campo-armadilha) sem explicar", () =>
    expect(validarEnvioPublico(base({ site: "x" }), ctx())).toMatch(/Não foi possível/));
  it("exige foto, documento, aceite", () => {
    expect(validarEnvioPublico(base(), { ...ctx(), temFoto: false })).toMatch(/fotografia/);
    expect(validarEnvioPublico(base(), { ...ctx(), temDocumentoVerso: false })).toMatch(/verso/);
    expect(validarEnvioPublico(base({ aceitePrivacidade: false }), ctx())).toMatch(/privacidade/);
  });
  it("confere nome, CPF, nascimento, casa, cargo", () => {
    expect(validarEnvioPublico(base({ nome: "João" }), ctx())).toMatch(/completo/);
    expect(validarEnvioPublico(base({ cpf: "" }), ctx())).toMatch(/Informe o CPF/);
    expect(validarEnvioPublico(base({ cpf: "111.111.111-11" }), ctx())).toMatch(/inválido/);
    expect(validarEnvioPublico(base({ dataNascimento: "2030-01-01" }), ctx())).toMatch(/futuro/);
    expect(validarEnvioPublico(base({ casaOracaoId: "" }), ctx())).toMatch(/Casa de Oração/);
    expect(validarEnvioPublico(base({ cargoId: "" }), ctx(undefined))).toMatch(/cargo/);
  });
  it("recusa cargo sem cadastro musical", () =>
    expect(validarEnvioPublico(base(), ctx({ ...musico, nome: "Ancião" }))).toMatch(/secretaria/));
  it("exige categoria e instrumento do músico", () => {
    expect(validarEnvioPublico(base({ categoria: "" }), ctx())).toMatch(/categoria/);
    expect(validarEnvioPublico(base({ instrumentoId: "" }), ctx())).toMatch(/instrumento/i);
  });
  it("exige cartão no cargo que pede", () => {
    const d = base({ cargoId: "c2", categoria: "" });
    expect(validarEnvioPublico(d, ctx(encarregado))).toMatch(/cartão/);
  });
  it("menor: pede responsável, telefone e aceite", () => {
    const m = { dataNascimento: "2012-01-01" };
    expect(validarEnvioPublico(base(m), ctx())).toMatch(/nome do responsável/);
    expect(validarEnvioPublico(base({ ...m, responsavelNome: "Maria Silva" }), ctx())).toMatch(/telefone do responsável/);
    expect(validarEnvioPublico(base({ ...m, responsavelNome: "Maria Silva", responsavelTelefone: "11987654321" }), ctx())).toMatch(/concordar/);
    expect(validarEnvioPublico(base({ ...m, responsavelNome: "Maria Silva", responsavelTelefone: "(11) 98765-4321", aceiteResponsavel: true }), ctx())).toBeNull();
  });
  it("maior ignora responsável", () => expect(validarEnvioPublico(base(), ctx())).toBeNull());
});

describe("montarCargaPublica", () => {
  it("normaliza e não leva campos internos", () => {
    const c = montarCargaPublica(base({ nome: "  João   da Silva ", cadastro: { ...cadastroOk, observacao: "x", apresentado_por: "y" } }), ctx());
    expect(c.nome).toBe("João da Silva");
    expect(c.cpf).toBe("52998224725");
    expect(c.cadastro.observacao).toBeNull();
    expect(c.cadastro.apresentado_por).toBeNull();
    expect("documento_frente_path" in c.cadastro).toBe(false);
    expect(c.responsavel_nome).toBeNull();
    expect(c.aviso_versao).toBe(VERSAO_AVISO);
  });
  it("menor leva o responsável só com números no telefone", () => {
    const c = montarCargaPublica(base({ dataNascimento: "2012-01-01", responsavelNome: "Maria  Silva", responsavelTelefone: "(11) 98765-4321", aceiteResponsavel: true }), ctx());
    expect(c.responsavel_nome).toBe("Maria Silva");
    expect(c.responsavel_telefone).toBe("11987654321");
    expect(c.aceite_responsavel).toBe(true);
  });
});

describe("cargos e aviso", () => {
  it("lista só cargos com cadastro", () => {
    const r = cargosDoFormularioPublico([musico, encarregado, { ...musico, id: "x", nome: "Ancião" }]);
    expect(r.map((c) => c.nome)).toEqual(["Músico", "Encarregado Local"]);
  });
  it("aviso usa o contato ou o texto alternativo", () => {
    expect(JSON.stringify(itensDoAviso("lgpd@x.org"))).toContain("lgpd@x.org");
    expect(JSON.stringify(itensDoAviso(""))).toContain("secretaria da sua Casa de Oração");
  });
});
''',
    "src/modules/cadastroPublico/regras.ts": r'''/**
 * SysMúsica — Regras puras do Cadastro Musical PÚBLICO (sem banco, sem tela). Testadas em regras.test.ts.
 *
 * O formulário público usa as mesmas regras do cadastro interno (modules/membros/cadastroMusical.ts) e soma:
 *  - aceite do aviso de privacidade (LGPD) e campo-armadilha contra robôs;
 *  - menores de 18 anos: nome e telefone do responsável e o aceite dele;
 *  - fotografia e documento (frente e verso) sempre obrigatórios.
 * O banco refaz todas as conferências (função registrar_cadastro_publico, migração 0042): a tela é só a resposta rápida.
 */
import {
  cargoEntraNoCadastro,
  cargoExigeCartao,
  cargoSomenteOrgao,
  instrumentosDoCargo,
  paraEnvioAoBanco,
  somenteDigitos,
  validarCadastro,
  type CadastroMusical,
  type CargoCadastro,
} from "@/modules/membros/cadastroMusical";
import { validarInstrumentoDoCargo } from "@/modules/instrumentos/selecao";
import { cargoUsaCategoria, validarCategoria } from "@/modules/painel/regras";
import { VERSAO_AVISO } from "./aviso";
import { cpfValido, soDigitos } from "./cpf";

export const IDADE_MAIORIDADE = 18;
export const NOME_MINIMO = 5;
export const NOME_MAXIMO = 120;
export const RESPONSAVEL_NOME_MINIMO = 3;

/** Cargo como a função opcoes_cadastro_publico devolve. */
export interface CargoPublico extends CargoCadastro {
  permite_instrumento: boolean;
  exige_instrumento: boolean;
}

export interface InstrumentoPublico {
  id: string;
  nome: string;
  familia_id: string | null;
}

export interface FamiliaPublica {
  id: string;
  nome: string;
}

/** Casa de Oração com o caminho na organização (para a pessoa achar a dela). */
export interface CasaPublica {
  id: string;
  nome: string;
  adm: string | null;
  ra: string | null;
  rrm: string | null;
  setor: string | null;
}

export interface OpcoesCadastroPublico {
  cargos: CargoPublico[];
  instrumentos: InstrumentoPublico[];
  familias: FamiliaPublica[];
  casas: CasaPublica[];
}

/** Tudo o que a pessoa preenche (textos, para ligar direto nos campos). */
export interface DadosFormularioPublico {
  nome: string;
  casaOracaoId: string;
  cargoId: string;
  instrumentoId: string;
  categoria: string;
  cpf: string;
  dataNascimento: string; // AAAA-MM-DD
  cidade: string;
  bairro: string;
  cadastro: CadastroMusical;
  responsavelNome: string;
  responsavelTelefone: string; // DDD + número
  aceiteResponsavel: boolean;
  aceitePrivacidade: boolean;
  /** Campo-armadilha: invisível para pessoas; robôs costumam preencher. Deve ficar vazio. */
  site: string;
}

export interface ContextoValidacao {
  cargo: CargoPublico | undefined;
  temFoto: boolean;
  temDocumentoFrente: boolean;
  temDocumentoVerso: boolean;
  /** Data de hoje (AAAA-MM-DD), recebida de fora para a regra ser testável. */
  hoje: string;
}

/** Tira espaços das pontas e os repetidos do nome. */
export function limparNome(texto: string): string {
  return texto.trim().replace(/\s+/g, " ");
}

/** "AAAA-MM-DD" válida (existe no calendário)? */
export function dataIsoValida(texto: string): boolean {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(texto)) return false;
  const [a, m, d] = texto.split("-").map(Number);
  const data = new Date(Date.UTC(a, m - 1, d));
  return data.getUTCFullYear() === a && data.getUTCMonth() === m - 1 && data.getUTCDate() === d;
}

/** Idade em anos completos em `hoje` (AAAA-MM-DD); null se alguma data for inválida. */
export function idadeEm(dataNascimento: string, hoje: string): number | null {
  if (!dataIsoValida(dataNascimento) || !dataIsoValida(hoje)) return null;
  const [an, mn, dn] = dataNascimento.split("-").map(Number);
  const [ah, mh, dh] = hoje.split("-").map(Number);
  let idade = ah - an;
  if (mh < mn || (mh === mn && dh < dn)) idade -= 1;
  return idade;
}

export function ehMenorDeIdade(dataNascimento: string, hoje: string): boolean {
  const idade = idadeEm(dataNascimento, hoje);
  return idade !== null && idade < IDADE_MAIORIDADE;
}

export function formularioVazio(cadastroVazio: CadastroMusical): DadosFormularioPublico {
  return {
    nome: "",
    casaOracaoId: "",
    cargoId: "",
    instrumentoId: "",
    categoria: "",
    cpf: "",
    dataNascimento: "",
    cidade: "",
    bairro: "",
    cadastro: cadastroVazio,
    responsavelNome: "",
    responsavelTelefone: "",
    aceiteResponsavel: false,
    aceitePrivacidade: false,
    site: "",
  };
}

/** Cargos oferecidos no formulário público: só os que têm Cadastro Musical. */
export function cargosDoFormularioPublico(cargos: CargoPublico[]): CargoPublico[] {
  return cargos.filter((cargo) => cargoEntraNoCadastro(cargo.nome));
}

/** Instrumentos que o cargo aceita (só Órgão nos cargos travados). */
export function instrumentosDoFormularioPublico(
  instrumentos: InstrumentoPublico[],
  cargo: CargoPublico | undefined
): InstrumentoPublico[] {
  return instrumentosDoCargo(instrumentos, cargoSomenteOrgao(cargo));
}

/**
 * Confere o formulário. Devolve a mensagem do primeiro problema ou null se estiver tudo certo.
 * Fica na ordem em que os campos aparecem na tela.
 */
export function validarEnvioPublico(dados: DadosFormularioPublico, ctx: ContextoValidacao): string | null {
  // Robô: mensagem genérica, sem explicar o motivo
  if (dados.site.trim() !== "") return "Não foi possível enviar o cadastro. Atualize a página e tente de novo.";

  if (!ctx.temFoto) return "A fotografia é obrigatória. Tire a foto ou escolha uma imagem.";

  const nome = limparNome(dados.nome);
  if (nome.length < NOME_MINIMO || !nome.includes(" ")) return "Informe o nome completo (nome e sobrenome).";
  if (nome.length > NOME_MAXIMO) return `O nome pode ter no máximo ${NOME_MAXIMO} caracteres.`;

  const cpf = soDigitos(dados.cpf);
  if (cpf === "") return "Informe o CPF.";
  if (!cpfValido(cpf)) return "CPF inválido. Confira os números digitados.";

  if (dados.dataNascimento.trim() === "") return "Informe a data de nascimento.";
  if (!dataIsoValida(dados.dataNascimento)) return "Data de nascimento inválida.";
  if (dados.dataNascimento > ctx.hoje) return "A data de nascimento não pode estar no futuro.";
  if (dados.dataNascimento < "1900-01-01") return "Data de nascimento inválida.";

  if (!dados.casaOracaoId) return "Escolha a sua Casa de Oração.";

  const cargo = ctx.cargo;
  if (!dados.cargoId || !cargo) return "Escolha o cargo.";
  if (!cargoEntraNoCadastro(cargo.nome)) return "Este cargo não faz o cadastro por aqui. Procure a secretaria.";

  const erroCategoria = validarCategoria(cargo.nome, dados.categoria);
  if (erroCategoria) return erroCategoria;

  // No cadastro completo, todo cargo que aceita instrumento exige a escolha dele (mesma regra da tela interna).
  const permiteInstrumento = cargo.permite_instrumento;
  const erroInstrumento = validarInstrumentoDoCargo(permiteInstrumento, dados.instrumentoId, cargo.nome);
  if (erroInstrumento) return erroInstrumento;

  const erroCadastro = validarCadastro(dados.cadastro, {
    completo: true,
    exigeCartao: cargoExigeCartao(cargo),
    cidade: dados.cidade,
    bairro: dados.bairro,
    cpf,
    cpfObrigatorio: true,
    dataNascimento: dados.dataNascimento,
    instrumentoId: permiteInstrumento ? dados.instrumentoId : "",
    instrumentoObrigatorio: permiteInstrumento,
    temDocumentoFrente: ctx.temDocumentoFrente,
    temDocumentoVerso: ctx.temDocumentoVerso,
  });
  if (erroCadastro) return erroCadastro;

  if (ehMenorDeIdade(dados.dataNascimento, ctx.hoje)) {
    if (limparNome(dados.responsavelNome).length < RESPONSAVEL_NOME_MINIMO) {
      return "Para menores de 18 anos, informe o nome do responsável.";
    }
    if (!/^\d{10,11}$/.test(somenteDigitos(dados.responsavelTelefone))) {
      return "Informe o telefone do responsável com o DDD.";
    }
    if (!dados.aceiteResponsavel) return "O responsável precisa concordar com o cadastro.";
  }

  if (!dados.aceitePrivacidade) return "Para enviar, leia o aviso de privacidade e marque que concorda.";
  return null;
}

/** JSON que vai para a rota de envio (e dali para registrar_cadastro_publico). Chaves iguais às do banco. */
export interface CargaCadastroPublico {
  nome: string;
  casa_oracao_id: string;
  cargo_id: string;
  instrumento_id: string | null;
  categoria: string | null;
  cpf: string;
  data_nascimento: string;
  cidade: string;
  bairro: string;
  cadastro: Record<string, string | boolean | null>;
  responsavel_nome: string | null;
  responsavel_telefone: string | null;
  aceite_responsavel: boolean;
  aceite_privacidade: boolean;
  aviso_versao: string;
  site: string;
}

export function montarCargaPublica(dados: DadosFormularioPublico, ctx: Pick<ContextoValidacao, "cargo" | "hoje">): CargaCadastroPublico {
  const menor = ehMenorDeIdade(dados.dataNascimento, ctx.hoje);
  const permiteInstrumento = ctx.cargo?.permite_instrumento ?? false;
  // Os caminhos dos arquivos NÃO vão aqui: o servidor os conhece (pasta do envio).
  // Campos de uso interno (apresentação, observação) não existem no formulário público: sempre vazios.
  const cadastro = paraEnvioAoBanco({
    ...dados.cadastro,
    apresentado_em: "",
    apresentado_por: "",
    observacao: "",
    documento_frente_path: "",
    documento_verso_path: "",
  });
  delete cadastro.documento_frente_path;
  delete cadastro.documento_verso_path;
  return {
    nome: limparNome(dados.nome),
    casa_oracao_id: dados.casaOracaoId,
    cargo_id: dados.cargoId,
    instrumento_id: permiteInstrumento && dados.instrumentoId ? dados.instrumentoId : null,
    categoria: cargoUsaCategoria(ctx.cargo?.nome) && dados.categoria ? dados.categoria : null,
    cpf: soDigitos(dados.cpf),
    data_nascimento: dados.dataNascimento,
    cidade: dados.cidade.trim(),
    bairro: dados.bairro.trim(),
    cadastro,
    responsavel_nome: menor ? limparNome(dados.responsavelNome) : null,
    responsavel_telefone: menor ? somenteDigitos(dados.responsavelTelefone) : null,
    aceite_responsavel: menor ? dados.aceiteResponsavel : false,
    aceite_privacidade: dados.aceitePrivacidade,
    aviso_versao: VERSAO_AVISO,
    site: dados.site,
  };
}

/** Mensagem exibida depois do envio (a mesma em qualquer situação: não revela se o CPF já existia). */
export const MENSAGEM_ENVIO_RECEBIDO =
  "Cadastro recebido! Ele será analisado pela secretaria. Se for aprovado, você passa a constar no sistema.";
''',
    "src/modules/cadastroPublico/server/arquivos.test.ts": r'''import { describe, expect, it, vi } from "vitest";
vi.mock("server-only", () => ({}));
import { caminhosNaFila, movimentosDaAprovacao } from "./arquivos";

describe("arquivos do cadastro público", () => {
  it("monta os caminhos da fila", () => {
    expect(caminhosNaFila("abc")).toEqual({ foto: "abc/foto.jpg", frente: "abc/frente.jpg", verso: "abc/verso.jpg" });
  });
  it("move para a pasta do membro, nos buckets certos, com nomes únicos", () => {
    let n = 0;
    const m = movimentosDaAprovacao("ped", "mem", () => `u${++n}`);
    expect(m.foto.para).toEqual({ bucket: "fotos-membros", caminho: "mem/u1.jpg" });
    expect(m.frente.para).toEqual({ bucket: "documentos-membros", caminho: "mem/frente-u2.jpg" });
    expect(m.verso.para).toEqual({ bucket: "documentos-membros", caminho: "mem/verso-u3.jpg" });
    expect(m.foto.de).toEqual({ bucket: "cadastro-publico", caminho: "ped/foto.jpg" });
  });
});

import { moverTodos, type Movimento } from "./arquivos";

/** Armazenamento de mentira: guarda "bucket/caminho" num conjunto; o 3º movimento pode falhar. */
function adminFalso(falharNoMovimento: number | null) {
  const arquivos = new Set<string>(["cadastro-publico/p/foto.jpg", "cadastro-publico/p/frente.jpg", "cadastro-publico/p/verso.jpg"]);
  let chamadas = 0;
  const admin = {
    storage: {
      from: (bucket: string) => ({
        move: async (de: string, para: string, opcoes: { destinationBucket: string }) => {
          chamadas += 1;
          if (falharNoMovimento === chamadas) return { error: { message: "boom" } };
          if (!arquivos.delete(`${bucket}/${de}`)) return { error: { message: "não existe" } };
          arquivos.add(`${opcoes.destinationBucket}/${para}`);
          return { error: null };
        },
      }),
    },
  };
  return { admin: admin as never, arquivos };
}
const MOVS: Movimento[] = [
  { de: { bucket: "cadastro-publico", caminho: "p/foto.jpg" }, para: { bucket: "fotos-membros", caminho: "m/f.jpg" } },
  { de: { bucket: "cadastro-publico", caminho: "p/frente.jpg" }, para: { bucket: "documentos-membros", caminho: "m/fr.jpg" } },
  { de: { bucket: "cadastro-publico", caminho: "p/verso.jpg" }, para: { bucket: "documentos-membros", caminho: "m/ve.jpg" } },
];

describe("moverTodos", () => {
  it("move os três arquivos", async () => {
    const { admin, arquivos } = adminFalso(null);
    await moverTodos(admin, MOVS);
    expect([...arquivos].sort()).toEqual(["documentos-membros/m/fr.jpg", "documentos-membros/m/ve.jpg", "fotos-membros/m/f.jpg"]);
  });
  it("se o terceiro falhar, devolve os dois primeiros à fila", async () => {
    const { admin, arquivos } = adminFalso(3);
    await expect(moverTodos(admin, MOVS)).rejects.toThrow();
    expect([...arquivos].sort()).toEqual(["cadastro-publico/p/foto.jpg", "cadastro-publico/p/frente.jpg", "cadastro-publico/p/verso.jpg"]);
  });
});
''',
    "src/modules/cadastroPublico/server/arquivos.ts": r'''/**
 * SysMúsica — Nomes e movimentação dos arquivos do cadastro público (SOMENTE SERVIDOR).
 *
 * Enquanto o pedido está na fila, as 3 imagens ficam no bucket privado "cadastro-publico", em <id>/foto.jpg,
 * frente.jpg e verso.jpg. Na aprovação elas são MOVIDAS para as pastas finais do membro (fotos-membros e
 * documentos-membros); se a aprovação falhar no banco, são devolvidas.
 */
import "server-only";
import type { SupabaseClient } from "@supabase/supabase-js";

export const BUCKET_PUBLICO = "cadastro-publico";

export interface Movimento {
  de: { bucket: string; caminho: string };
  para: { bucket: string; caminho: string };
}

/** Caminhos dos arquivos na fila. */
export function caminhosNaFila(pedidoId: string) {
  return { foto: `${pedidoId}/foto.jpg`, frente: `${pedidoId}/frente.jpg`, verso: `${pedidoId}/verso.jpg` };
}

/** Movimentos da aprovação: fila -> pastas finais do membro (nomes únicos, como no cadastro interno). */
export function movimentosDaAprovacao(pedidoId: string, membroId: string, sufixo: () => string) {
  const fila = caminhosNaFila(pedidoId);
  const foto: Movimento = {
    de: { bucket: BUCKET_PUBLICO, caminho: fila.foto },
    para: { bucket: "fotos-membros", caminho: `${membroId}/${sufixo()}.jpg` },
  };
  const frente: Movimento = {
    de: { bucket: BUCKET_PUBLICO, caminho: fila.frente },
    para: { bucket: "documentos-membros", caminho: `${membroId}/frente-${sufixo()}.jpg` },
  };
  const verso: Movimento = {
    de: { bucket: BUCKET_PUBLICO, caminho: fila.verso },
    para: { bucket: "documentos-membros", caminho: `${membroId}/verso-${sufixo()}.jpg` },
  };
  return { foto, frente, verso };
}

/** Move um arquivo entre buckets. */
async function mover(admin: SupabaseClient, m: Movimento): Promise<void> {
  const { error } = await admin.storage.from(m.de.bucket).move(m.de.caminho, m.para.caminho, {
    destinationBucket: m.para.bucket,
  });
  if (error) throw new Error(`Falha ao mover ${m.de.caminho}: ${error.message}`);
}

/**
 * Move todos; se algum falhar, devolve os que já foram e lança o erro.
 * Devolve a lista dos movimentos feitos (para desfazer depois, se o banco recusar).
 */
export async function moverTodos(admin: SupabaseClient, movimentos: Movimento[]): Promise<Movimento[]> {
  const feitos: Movimento[] = [];
  try {
    for (const m of movimentos) {
      await mover(admin, m);
      feitos.push(m);
    }
  } catch (e) {
    await desfazer(admin, feitos);
    throw e;
  }
  return feitos;
}

/** Devolve os arquivos para a fila (melhor esforço: erros só vão para o log). */
export async function desfazer(admin: SupabaseClient, feitos: Movimento[]): Promise<void> {
  for (const m of [...feitos].reverse()) {
    try {
      await mover(admin, { de: m.para, para: m.de });
    } catch (e) {
      console.error("Não consegui devolver o arquivo à fila:", e);
    }
  }
}

/** Apaga arquivos de um bucket (melhor esforço). */
export async function apagar(admin: SupabaseClient, bucket: string, caminhos: Array<string | null | undefined>): Promise<void> {
  const lista = caminhos.filter((c): c is string => typeof c === "string" && c !== "");
  if (lista.length === 0) return;
  const { error } = await admin.storage.from(bucket).remove(lista);
  if (error) console.error(`Não consegui apagar arquivos de ${bucket}:`, error.message);
}
''',
    "src/modules/cadastroPublico/server/erros.test.ts": r'''import { describe, expect, it } from "vitest";
import { ErroHttp } from "@/modules/administracao/server/erros";
import { erroDoBanco, exigirUuid } from "./erros";

describe("erroDoBanco", () => {
  it("repassa a mensagem dos códigos esperados", () => {
    const e = erroDoBanco({ code: "P0429", message: "Muitas tentativas." });
    expect(e).toBeInstanceOf(ErroHttp);
    expect((e as ErroHttp).status).toBe(429);
    expect((erroDoBanco({ code: "42501", message: "x" }) as ErroHttp).status).toBe(403);
    expect((erroDoBanco({ code: "P0002", message: "x" }) as ErroHttp).status).toBe(404);
    expect((erroDoBanco({ code: "23505", message: "x" }) as ErroHttp).status).toBe(409);
    expect((erroDoBanco({ code: "P0001", message: "CPF inválido." }) as ErroHttp).status).toBe(400);
  });
  it("erro desconhecido NÃO vaza detalhe para a pessoa", () => {
    const e = erroDoBanco({ code: "XX000", message: "segredo interno" });
    expect(e).not.toBeInstanceOf(ErroHttp);
  });
});

describe("exigirUuid", () => {
  it("aceita uuid e recusa o resto", () => {
    expect(exigirUuid("aaaaaaaa-0000-4000-8000-000000000001")).toBe("aaaaaaaa-0000-4000-8000-000000000001");
    expect(() => exigirUuid("../../x")).toThrow();
    expect(() => exigirUuid(undefined)).toThrow();
  });
});
''',
    "src/modules/cadastroPublico/server/erros.ts": r'''/**
 * SysMúsica — Tradução dos erros do banco para respostas HTTP das rotas do cadastro público/pendentes.
 * As funções do banco escrevem a mensagem para a pessoa (em português). Só repassamos a mensagem dos códigos
 * "esperados"; qualquer outro erro vira a mensagem genérica e o detalhe fica apenas no log do servidor.
 */
import { ErroHttp } from "@/modules/administracao/server/erros";

export interface ErroDoBanco {
  code?: string;
  message?: string;
}

const STATUS_POR_CODIGO: Record<string, number> = {
  P0429: 429, // limite de tentativas
  "42501": 403, // sem permissão
  P0002: 404, // não encontrado
  "23505": 409, // CPF já existe
  "22023": 409, // regra de negócio (já analisado, arquivo ausente...)
  P0001: 400, // raise exception comum (validação do formulário)
};

/** Devolve um ErroHttp com a mensagem do banco (códigos esperados) ou um Error genérico para o log. */
export function erroDoBanco(erro: ErroDoBanco): Error {
  const status = erro.code ? STATUS_POR_CODIGO[erro.code] : undefined;
  if (status && erro.message) return new ErroHttp(status, erro.message);
  return new Error(`Erro do banco (${erro.code ?? "sem código"}): ${erro.message ?? ""}`);
}

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export function exigirUuid(valor: unknown): string {
  if (typeof valor !== "string" || !UUID.test(valor)) throw new ErroHttp(400, "Pedido inválido.");
  return valor;
}
''',
    "src/modules/cadastroPublico/server/ip.test.ts": r'''import { describe, expect, it } from "vitest";
import { extrairIp, hashDoIp } from "./ip";

describe("extrairIp", () => {
  it("usa o primeiro IP de x-forwarded-for", () => {
    expect(extrairIp(new Headers({ "x-forwarded-for": "203.0.113.5, 10.0.0.1" }))).toBe("203.0.113.5");
  });
  it("cai para x-real-ip", () => {
    expect(extrairIp(new Headers({ "x-real-ip": "198.51.100.7" }))).toBe("198.51.100.7");
  });
  it("sem cabeçalho ou com lixo enorme, devolve nulo", () => {
    expect(extrairIp(new Headers())).toBeNull();
    expect(extrairIp(new Headers({ "x-forwarded-for": "x".repeat(100) }))).toBeNull();
  });
});

describe("hashDoIp", () => {
  it("é estável, depende do sal e não devolve o IP", () => {
    const a = hashDoIp("203.0.113.5", "sal1");
    expect(a).toBe(hashDoIp("203.0.113.5", "sal1"));
    expect(a).not.toBe(hashDoIp("203.0.113.5", "sal2"));
    expect(a).toMatch(/^[0-9a-f]{64}$/);
    expect(a).not.toContain("203");
  });
  it("sem IP ou sem sal não gera hash", () => {
    expect(hashDoIp(null, "sal")).toBeNull();
    expect(hashDoIp("203.0.113.5", "")).toBeNull();
  });
});
''',
    "src/modules/cadastroPublico/server/ip.ts": r'''/**
 * SysMúsica — IP de quem chamou e o "hash" dele (SEM server-only: é função pura e testada em ip.test.ts).
 *
 * O IP nunca é guardado puro: o banco recebe só o hash (sha256 com um sal secreto), usado apenas para limitar
 * quantos envios saem de um mesmo lugar por hora. Na Vercel, o primeiro item de x-forwarded-for é o IP real
 * (a Vercel sobrescreve o cabeçalho, então quem chama não consegue forjá-lo).
 */
import { createHash } from "node:crypto";

export function extrairIp(cabecalhos: Headers): string | null {
  const encaminhado = cabecalhos.get("x-forwarded-for");
  const primeiro = encaminhado?.split(",")[0]?.trim();
  const ip = primeiro || cabecalhos.get("x-real-ip")?.trim() || "";
  return ip !== "" && ip.length <= 64 ? ip : null;
}

/** sha256(ip + ":" + sal). O sal é CADASTRO_PUBLICO_SALT ou, na falta dela, a chave de serviço (já secreta). */
export function hashDoIp(ip: string | null, sal: string): string | null {
  if (!ip || !sal) return null;
  return createHash("sha256").update(`${ip}:${sal}`).digest("hex");
}
''',
    "src/modules/cadastroPublico/server/limpeza.test.ts": r'''import { describe, expect, it, vi } from "vitest";
vi.mock("server-only", () => ({}));
vi.mock("@/modules/administracao/server/clienteAdmin", () => ({ clienteAdmin: () => ({}) }));
import { limparCadastroPublico } from "./limpeza";

function adminFalso(opcoes: { removerFalha?: boolean; pastas?: string[] }) {
  const chamadas: Array<{ fn: string; args: unknown }> = [];
  const pastas = opcoes.pastas ?? ["a", "b"];
  const admin = {
    rpc: async (fn: string, args?: unknown) => {
      chamadas.push({ fn, args });
      if (fn === "limpeza_cadastro_publico") return { data: { pastas, para_marcar: ["b"], abandonados: ["a"] }, error: null };
      return { data: 1, error: null };
    },
    storage: {
      from: () => ({
        remove: async (lista: string[]) =>
          opcoes.removerFalha ? { data: null, error: { message: "boom" } } : { data: lista.map((name) => ({ name })), error: null },
      }),
    },
  };
  return { admin: admin as never, chamadas };
}

describe("limparCadastroPublico", () => {
  it("apaga os 3 arquivos de cada pasta e depois marca os pedidos", async () => {
    const { admin, chamadas } = adminFalso({});
    const r = await limparCadastroPublico(admin);
    expect(r).toEqual({ pastas: 2, arquivos_apagados: 6, pedidos_zerados: 1, falhou: false });
    const marcar = chamadas.find((c) => c.fn === "marcar_cadastros_limpos");
    expect(marcar?.args).toEqual({ p_ids: ["b"], p_abandonados: ["a"] });
  });
  it("se não conseguir apagar os arquivos, NÃO zera os dados (tenta amanhã)", async () => {
    const { admin, chamadas } = adminFalso({ removerFalha: true });
    const r = await limparCadastroPublico(admin);
    expect(r.falhou).toBe(true);
    expect(chamadas.some((c) => c.fn === "marcar_cadastros_limpos")).toBe(false);
  });
  it("sem nada a limpar, não chama o banco de novo", async () => {
    const admin = { rpc: async () => ({ data: { pastas: [], para_marcar: [], abandonados: [] }, error: null }), storage: { from: () => ({ remove: async () => ({ data: [], error: null }) }) } };
    const r = await limparCadastroPublico(admin as never);
    expect(r).toEqual({ pastas: 0, arquivos_apagados: 0, pedidos_zerados: 0, falhou: false });
  });
});
''',
    "src/modules/cadastroPublico/server/limpeza.ts": r'''/**
 * SysMúsica — Limpeza diária do cadastro público (chamada pelo cron /api/cron/conferir, 1x por dia).
 *
 * O banco diz QUAIS pastas devem ser apagadas (envios abandonados há 24 h, pedidos vencidos em 60 dias, recusados há
 * 30 dias). Aqui o servidor apaga os arquivos do armazenamento e, SÓ se conseguiu apagar tudo, avisa o banco para
 * zerar os dados pessoais desses pedidos. Se algo falhar, nada é marcado e a limpeza tenta de novo no dia seguinte.
 */
import "server-only";
import type { SupabaseClient } from "@supabase/supabase-js";
import { clienteAdmin } from "@/modules/administracao/server/clienteAdmin";
import { BUCKET_PUBLICO, caminhosNaFila } from "./arquivos";

interface RespostaLimpeza {
  pastas: string[];
  para_marcar: string[];
  abandonados: string[];
}

export interface ResultadoLimpeza {
  pastas: number;
  arquivos_apagados: number;
  pedidos_zerados: number;
  falhou: boolean;
}

const LOTE = 100;

export async function limparCadastroPublico(admin: SupabaseClient = clienteAdmin()): Promise<ResultadoLimpeza> {
  const { data, error } = await admin.rpc("limpeza_cadastro_publico");
  if (error || !data) throw new Error(`Limpeza do cadastro público falhou: ${error?.message ?? "sem resposta"}`);
  const r = data as RespostaLimpeza;

  const caminhos = r.pastas.flatMap((id) => Object.values(caminhosNaFila(id)));
  let apagados = 0;
  let falhou = false;
  for (let i = 0; i < caminhos.length; i += LOTE) {
    const lote = caminhos.slice(i, i + LOTE);
    const { data: removidos, error: erroRemover } = await admin.storage.from(BUCKET_PUBLICO).remove(lote);
    if (erroRemover) {
      console.error("Falha ao apagar arquivos do cadastro público:", erroRemover.message);
      falhou = true;
      break;
    }
    apagados += removidos?.length ?? 0;
  }

  let zerados = 0;
  if (!falhou && (r.para_marcar.length > 0 || r.abandonados.length > 0)) {
    const { data: n, error: erroMarcar } = await admin.rpc("marcar_cadastros_limpos", {
      p_ids: r.para_marcar,
      p_abandonados: r.abandonados,
    });
    if (erroMarcar) {
      console.error("Falha ao marcar cadastros limpos:", erroMarcar.message);
      falhou = true;
    } else {
      zerados = Number(n ?? 0);
    }
  }
  return { pastas: r.pastas.length, arquivos_apagados: apagados, pedidos_zerados: zerados, falhou };
}
''',
    "src/modules/cadastroPublico/server/turnstile.ts": r'''/**
 * SysMúsica — Confere o token do Cloudflare Turnstile (anti-robô) NO SERVIDOR.
 * Falha fechada: sem a chave secreta, sem resposta da Cloudflare ou com token inválido, o envio é recusado.
 * Variável: TURNSTILE_SECRET_KEY (secreta, só no servidor). Teste local: 1x0000000000000000000000000000000AA.
 */
import "server-only";
import { ErroHttp } from "@/modules/administracao/server/erros";

const URL_VERIFICACAO = "https://challenges.cloudflare.com/turnstile/v0/siteverify";

export async function verificarTurnstile(token: unknown, ip: string | null): Promise<void> {
  const segredo = process.env.TURNSTILE_SECRET_KEY;
  if (!segredo) {
    console.error("TURNSTILE_SECRET_KEY ausente: o cadastro público está desligado.");
    throw new ErroHttp(503, "O cadastro está indisponível no momento. Tente novamente mais tarde.");
  }
  if (typeof token !== "string" || token === "" || token.length > 2048) {
    throw new ErroHttp(400, "Confirme a verificação de segurança e tente de novo.");
  }
  const corpo = new URLSearchParams({ secret: segredo, response: token });
  if (ip) corpo.set("remoteip", ip);

  let sucesso = false;
  try {
    const resposta = await fetch(URL_VERIFICACAO, {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: corpo,
      signal: AbortSignal.timeout(8000),
    });
    const json = (await resposta.json()) as { success?: boolean };
    sucesso = resposta.ok && json.success === true;
  } catch (e) {
    console.error("Falha ao consultar o Turnstile:", e);
    throw new ErroHttp(503, "Não foi possível validar a verificação de segurança. Tente novamente.");
  }
  if (!sucesso) throw new ErroHttp(400, "A verificação de segurança falhou. Recarregue a página e tente de novo.");
}
''',
    "src/modules/cadastroPublico/server/usuario.ts": r'''/**
 * SysMúsica — Cliente Supabase "como o usuário logado" para as rotas do servidor.
 * Necessário quando a função do banco usa auth.uid() (aprovar cadastro grava quem aprovou na auditoria).
 * O token vem no cabeçalho Authorization (a sessão do navegador não usa cookies).
 */
import { createClient, type SupabaseClient } from "@supabase/supabase-js";
import { ErroHttp } from "@/modules/administracao/server/erros";

export function clienteDoUsuario(request: Request): SupabaseClient {
  const cabecalho = request.headers.get("authorization") ?? "";
  const token = cabecalho.toLowerCase().startsWith("bearer ") ? cabecalho.slice(7).trim() : "";
  if (!token) throw new ErroHttp(401, "Sessão ausente. Entre novamente.");

  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const chavePublica = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;
  if (!url || !chavePublica) {
    console.error("Variáveis públicas do Supabase ausentes no servidor.");
    throw new ErroHttp(500, "Servidor sem a configuração do banco de dados.");
  }
  return createClient(url, chavePublica, {
    auth: { persistSession: false, autoRefreshToken: false },
    global: { headers: { Authorization: `Bearer ${token}` } },
  });
}
''',
    "src/modules/cadastroPublico/services/envio.ts": r'''/**
 * SysMúsica — Serviço do cadastro público (navegador, SEM login).
 *
 * Fluxo do envio (em 2 etapas, porque a Vercel limita o corpo de cada pedido a 4,5 MB):
 *  1) /api/cadastro-publico/iniciar: confere o Turnstile (anti-robô) e devolve endereços de envio de uso único;
 *  2) o navegador envia foto e documento direto para o armazenamento privado "cadastro-publico";
 *  3) /api/cadastro-publico/enviar: grava os dados. Nada entra em "membros" aqui: vira um pedido a ser aprovado.
 */
import { supabase } from "@/lib/supabase";
import type { CargaCadastroPublico, OpcoesCadastroPublico } from "../regras";

const BUCKET = "cadastro-publico";
const MENSAGEM_PADRAO = "Não foi possível enviar o cadastro agora. Tente novamente em alguns minutos.";

interface EnderecoDeEnvio {
  caminho: string;
  token: string;
}

interface RespostaIniciar {
  envio_id: string;
  foto: EnderecoDeEnvio;
  frente: EnderecoDeEnvio;
  verso: EnderecoDeEnvio;
}

/** Lê o JSON da resposta; se o servidor mandou uma mensagem de erro, repassa. */
async function lerResposta<T>(resposta: Response): Promise<T> {
  let corpo: unknown = null;
  try {
    corpo = await resposta.json();
  } catch {
    /* resposta sem JSON: cai na mensagem padrão */
  }
  if (!resposta.ok) {
    const msg = (corpo as { erro?: unknown } | null)?.erro;
    throw new Error(typeof msg === "string" && msg !== "" ? msg : MENSAGEM_PADRAO);
  }
  return corpo as T;
}

/** Cargos, instrumentos, famílias e Casas de Oração para o formulário (função pública do banco). */
export async function carregarOpcoes(): Promise<OpcoesCadastroPublico> {
  const { data, error } = await supabase.rpc("opcoes_cadastro_publico");
  if (error || !data) throw new Error("Não foi possível carregar o formulário. Atualize a página e tente de novo.");
  const o = data as Partial<OpcoesCadastroPublico>;
  return {
    cargos: o.cargos ?? [],
    instrumentos: o.instrumentos ?? [],
    familias: o.familias ?? [],
    casas: o.casas ?? [],
  };
}

async function enviarArquivo(endereco: EnderecoDeEnvio, arquivo: Blob): Promise<void> {
  const { error } = await supabase.storage.from(BUCKET).uploadToSignedUrl(endereco.caminho, endereco.token, arquivo, {
    contentType: "image/jpeg",
  });
  if (error) throw new Error("Não foi possível enviar as imagens. Confira a conexão e tente de novo.");
}

/** Faz o envio completo. `tokenTurnstile` vem do componente anti-robô. */
export async function enviarCadastroPublico(
  carga: CargaCadastroPublico,
  arquivos: { foto: Blob; frente: Blob; verso: Blob },
  tokenTurnstile: string
): Promise<void> {
  const inicio = await lerResposta<RespostaIniciar>(
    await fetch("/api/cadastro-publico/iniciar", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ turnstile: tokenTurnstile, site: carga.site }),
    })
  );

  await enviarArquivo(inicio.foto, arquivos.foto);
  await enviarArquivo(inicio.frente, arquivos.frente);
  await enviarArquivo(inicio.verso, arquivos.verso);

  await lerResposta<{ ok: true }>(
    await fetch("/api/cadastro-publico/enviar", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ envio_id: inicio.envio_id, dados: carga }),
    })
  );
}
''',
    "src/modules/cadastrosPendentes/components/DetalheCadastro.tsx": r'''"use client";

/**
 * SysMúsica — Detalhe de um cadastro enviado pelo link público (dentro do painel lateral).
 * Mostra a foto e o documento (endereços temporários), os dados e, nas ATUALIZAÇÕES, a comparação campo a campo
 * com o cadastro atual do membro. Aprovar e Recusar só aparecem para quem tem cadastros.aprovar.
 */
import { useEffect, useState } from "react";
import { AlertTriangle, Check, ExternalLink, X } from "lucide-react";
import Badge from "@/components/ui/Badge";
import Button from "@/components/ui/Button";
import Skeleton from "@/components/ui/Skeleton";
import { arquivosDoCadastro } from "../services/cadastrosPendentes";
import {
  ROTULO_STATUS,
  ROTULO_TIPO,
  VARIANTE_STATUS,
  compararComAtual,
  formatarData,
  formatarDataHora,
  quantosMudaram,
} from "../regras";
import type { ArquivosDoCadastro, DetalheCadastro } from "../tipos";

/** Imagem sem usar <img> (mesmo padrão dos campos de foto) e com link para abrir em tamanho real. */
function Imagem({ url, rotulo, alto }: { url: string | null | undefined; rotulo: string; alto: string }) {
  if (!url) {
    return (
      <div className={`flex ${alto} w-full items-center justify-center rounded-lg bg-slate-100 px-2 text-center text-xs text-slate-500`}>
        {rotulo}: indisponível
      </div>
    );
  }
  return (
    <a href={url} target="_blank" rel="noopener noreferrer" className="block" title={`Abrir ${rotulo} em tamanho real`}>
      <div role="img" aria-label={rotulo} style={{ backgroundImage: `url(${url})` }} className={`${alto} w-full rounded-lg bg-slate-100 bg-contain bg-center bg-no-repeat`} />
      <span className="mt-1 inline-flex items-center gap-1 text-xs text-brand-700">
        {rotulo} <ExternalLink className="h-3 w-3" aria-hidden="true" />
      </span>
    </a>
  );
}

interface Props {
  detalhe: DetalheCadastro;
  podeAprovar: boolean;
  ocupado: boolean;
  onAprovar: () => void;
  onRecusar: () => void;
}

export default function DetalheDoCadastro({ detalhe, podeAprovar, ocupado, onAprovar, onRecusar }: Props) {
  const [arquivos, setArquivos] = useState<ArquivosDoCadastro | null>(null);
  const [erroArquivos, setErroArquivos] = useState<string | null>(null);

  // Busca os endereços temporários das imagens quando o detalhe abre
  useEffect(() => {
    let ativo = true;
    if (!detalhe.arquivos_disponiveis) return;
    arquivosDoCadastro(detalhe.id)
      .then((r) => ativo && setArquivos(r))
      .catch((e: unknown) => ativo && setErroArquivos(e instanceof Error ? e.message : "Não foi possível carregar as imagens."));
    return () => {
      ativo = false;
    };
  }, [detalhe.id, detalhe.arquivos_disponiveis]);

  const linhas = compararComAtual(detalhe);
  const atualizacao = detalhe.tipo === "ATUALIZACAO";
  const mudancas = quantosMudaram(linhas);
  const pendente = detalhe.status === "PENDENTE";

  return (
    <div className="space-y-6">
      <div className="flex flex-wrap items-center gap-2">
        <Badge variante={VARIANTE_STATUS[detalhe.status]}>{ROTULO_STATUS[detalhe.status]}</Badge>
        <Badge variante="neutro">{ROTULO_TIPO[detalhe.tipo]}</Badge>
        {detalhe.menor && <Badge variante="marca">Menor de idade</Badge>}
      </div>

      {detalhe.cpf_conflito && (
        <p role="alert" className="flex gap-2 rounded-lg bg-red-50 px-3 py-2 text-sm text-red-800">
          <AlertTriangle className="mt-0.5 h-4 w-4 shrink-0" aria-hidden="true" />
          Já existe um membro com este CPF, mas com outra data de nascimento. Confira com a pessoa antes de decidir: este
          pedido não pode ser aprovado como novo cadastro enquanto o CPF existir.
        </p>
      )}
      {detalhe.outros_pendentes > 0 && (
        <p className="rounded-lg bg-amber-50 px-3 py-2 text-sm text-amber-900">
          Há {detalhe.outros_pendentes} outro(s) pedido(s) pendente(s) com este CPF. Aprove só um e recuse os demais.
        </p>
      )}
      {detalhe.status === "REJEITADO" && detalhe.motivo_rejeicao && (
        <p className="rounded-lg bg-slate-100 px-3 py-2 text-sm text-slate-800">
          <strong>Motivo da recusa:</strong> {detalhe.motivo_rejeicao}
        </p>
      )}
      {atualizacao && (
        <p className="rounded-lg bg-brand-50 px-3 py-2 text-sm text-slate-800">
          Esta pessoa já tem cadastro. Ao aprovar, os dados abaixo <strong>substituem</strong> os atuais
          {mudancas > 0 ? ` (${mudancas} campo(s) diferente(s), em destaque)` : " (nenhum campo mudou)"}.
        </p>
      )}

      {/* Fotografia e documento */}
      {detalhe.arquivos_disponiveis ? (
        erroArquivos ? (
          <p role="alert" className="rounded-lg bg-red-50 px-3 py-2 text-sm text-red-700">{erroArquivos}</p>
        ) : !arquivos ? (
          <Skeleton className="h-40" />
        ) : !arquivos.disponivel ? (
          <p className="text-sm text-slate-500">As imagens deste cadastro não estão mais disponíveis.</p>
        ) : (
          <div className="grid grid-cols-3 gap-3">
            <Imagem url={arquivos.foto} rotulo="Fotografia" alto="h-40" />
            <Imagem url={arquivos.frente} rotulo="Documento (frente)" alto="h-40" />
            <Imagem url={arquivos.verso} rotulo="Documento (verso)" alto="h-40" />
            {!arquivos.documentos_liberados && (
              <p className="col-span-3 text-xs text-slate-500">O documento só aparece para quem tem a permissão CPF.</p>
            )}
          </div>
        )
      ) : (
        <p className="text-sm text-slate-500">As imagens não estão mais guardadas (aprovadas ou apagadas pela limpeza automática).</p>
      )}

      {/* Dados pessoais */}
      <section>
        <h3 className="mb-2 border-b border-slate-200 pb-1 text-xs font-semibold uppercase tracking-wide text-slate-500">Identificação</h3>
        <dl className="grid grid-cols-[8rem_1fr] gap-x-3 gap-y-1 text-sm">
          <dt className="text-slate-500">Nome</dt>
          <dd className="font-medium text-slate-900">{detalhe.nome ?? "(removido)"}</dd>
          <dt className="text-slate-500">CPF</dt>
          <dd className="tabular-nums text-slate-900">{detalhe.cpf ?? "—"}</dd>
          <dt className="text-slate-500">Nascimento</dt>
          <dd className="text-slate-900">{formatarData(detalhe.data_nascimento)}</dd>
          <dt className="text-slate-500">Enviado em</dt>
          <dd className="text-slate-900">{formatarDataHora(detalhe.criado_em)}</dd>
          <dt className="text-slate-500">Aceite LGPD</dt>
          <dd className="text-slate-900">versão {detalhe.aviso_versao}, em {formatarDataHora(detalhe.aceite_em)}</dd>
        </dl>
      </section>

      {detalhe.menor && (
        <section>
          <h3 className="mb-2 border-b border-slate-200 pb-1 text-xs font-semibold uppercase tracking-wide text-slate-500">Responsável</h3>
          <dl className="grid grid-cols-[8rem_1fr] gap-x-3 gap-y-1 text-sm">
            <dt className="text-slate-500">Nome</dt>
            <dd className="text-slate-900">{detalhe.responsavel_nome ?? "—"}</dd>
            <dt className="text-slate-500">Telefone</dt>
            <dd className="tabular-nums text-slate-900">{detalhe.responsavel_telefone ?? "—"}</dd>
          </dl>
        </section>
      )}

      <section>
        <h3 className="mb-2 border-b border-slate-200 pb-1 text-xs font-semibold uppercase tracking-wide text-slate-500">
          {atualizacao ? "Hoje × pedido" : "Dados do cadastro"}
        </h3>
        <div className="overflow-x-auto">
          <table className="min-w-full text-sm">
            <thead>
              <tr className="text-left text-xs uppercase tracking-wide text-slate-500">
                <th scope="col" className="py-1 pr-3 font-semibold">Campo</th>
                {atualizacao && <th scope="col" className="py-1 pr-3 font-semibold">Hoje</th>}
                <th scope="col" className="py-1 font-semibold">{atualizacao ? "Pedido" : "Informado"}</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100">
              {linhas.map((l) => (
                <tr key={l.chave} className={l.mudou ? "bg-amber-50" : undefined}>
                  <th scope="row" className="py-1.5 pr-3 text-left font-normal text-slate-500">{l.rotulo}</th>
                  {atualizacao && <td className="py-1.5 pr-3 text-slate-700">{l.atual}</td>}
                  <td className={"py-1.5 " + (l.mudou ? "font-semibold text-slate-900" : "text-slate-800")}>{l.novo}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>

      {pendente && podeAprovar && (
        <div className="flex flex-wrap gap-2 border-t border-slate-200 pt-4">
          <Button icone={Check} onClick={onAprovar} disabled={ocupado || (detalhe.cpf_conflito && !atualizacao)}>
            Aprovar
          </Button>
          <Button variante="perigo" icone={X} onClick={onRecusar} disabled={ocupado}>
            Recusar
          </Button>
        </div>
      )}
    </div>
  );
}
''',
    "src/modules/cadastrosPendentes/components/TabelaCadastros.tsx": r'''"use client";

/**
 * SysMúsica — Lista de cadastros enviados pelo link público. Clicar em "Abrir" mostra o detalhe.
 * O CPF aparece escondido (***.123.***-45); o completo só no detalhe, para quem tem a permissão CPF.
 */
import { Eye } from "lucide-react";
import Badge from "@/components/ui/Badge";
import BotaoIcone from "@/components/ui/BotaoIcone";
import { ROTULO_STATUS, ROTULO_TIPO, VARIANTE_STATUS, diasParaVencer, formatarDataHora } from "../regras";
import type { ResumoCadastro } from "../tipos";

const classeCabecalho = "px-4 py-3 text-left text-xs font-semibold uppercase tracking-wide text-slate-500";

export default function TabelaCadastros({ itens, onAbrir }: { itens: ResumoCadastro[]; onAbrir: (item: ResumoCadastro) => void }) {
  return (
    <div className="overflow-hidden rounded-2xl border border-slate-200 bg-white shadow-sm">
      <div className="overflow-x-auto">
        <table className="min-w-full divide-y divide-slate-200 text-sm">
          <thead className="bg-slate-50">
            <tr>
              <th scope="col" className={classeCabecalho}>Nome</th>
              <th scope="col" className={classeCabecalho}>Cargo</th>
              <th scope="col" className={classeCabecalho}>Casa de Oração</th>
              <th scope="col" className={classeCabecalho}>Tipo</th>
              <th scope="col" className={classeCabecalho}>Enviado em</th>
              <th scope="col" className={classeCabecalho}>Situação</th>
              <th scope="col" className={classeCabecalho + " text-right"}>Ações</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-slate-100">
            {itens.map((item) => (
              <tr key={item.id} className="transition hover:bg-slate-50">
                <td className="px-4 py-3">
                  <div className="font-medium text-slate-900">{item.nome ?? "(dados removidos)"}</div>
                  <div className="text-xs tabular-nums text-slate-500">{item.cpf_mascarado ?? ""}</div>
                  <div className="mt-1 flex flex-wrap gap-1">
                    {item.menor && <Badge variante="marca">Menor de idade</Badge>}
                    {item.cpf_conflito && <Badge variante="perigo">CPF com outra data de nascimento</Badge>}
                    {item.outros_pendentes > 0 && <Badge variante="alerta">{item.outros_pendentes} outro(s) pedido(s) com este CPF</Badge>}
                  </div>
                </td>
                <td className="px-4 py-3 text-slate-800">{item.cargo_nome ?? "—"}</td>
                <td className="px-4 py-3 text-slate-800">{item.casa_nome ?? "—"}</td>
                <td className="px-4 py-3 text-slate-800">{ROTULO_TIPO[item.tipo]}</td>
                <td className="whitespace-nowrap px-4 py-3 tabular-nums text-slate-700">
                  {formatarDataHora(item.criado_em)}
                  {item.status === "PENDENTE" && (
                    <div className="text-xs text-slate-500">vence em {diasParaVencer(item.expira_em)} dia(s)</div>
                  )}
                </td>
                <td className="px-4 py-3">
                  <Badge variante={VARIANTE_STATUS[item.status]}>{ROTULO_STATUS[item.status]}</Badge>
                </td>
                <td className="px-4 py-3">
                  <div className="flex justify-end">
                    <BotaoIcone icone={Eye} rotulo={`Abrir o cadastro de ${item.nome ?? "pessoa sem nome"}`} onClick={() => onAbrir(item)} />
                  </div>
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
    "src/modules/cadastrosPendentes/regras.test.ts": r'''import { describe, expect, it } from "vitest";
import { compararComAtual, diasParaVencer, formatarData, quantosMudaram, simNao, validarMotivo } from "./regras";
import type { DetalheCadastro } from "./tipos";

function detalhe(extra: Partial<DetalheCadastro> = {}): DetalheCadastro {
  return {
    id: "p1", tipo: "NOVO", status: "PENDENTE", membro_id: null, nome: "Maria Souza", data_nascimento: "1990-05-10",
    cidade: "Salvador", bairro: "Centro", cpf: "***.982.***-25", cpf_completo_visivel: false, casa_oracao_id: "c1",
    casa_nome: "Central", cargo_id: "g1", cargo_nome: "Músico", instrumento_id: "i1", instrumento_nome: "Violino",
    categoria: "OFICIALIZADO", dados: { estado_civil: "Solteiro (a)", sexo: "Feminino", batizado: false, selado: false, ddd: "71", telefone: "987654321", cep: "40000000", endereco: "Rua A", numero: "10", uf: "BA" },
    menor: false, responsavel_nome: null, responsavel_telefone: null, aviso_versao: "v1", aceite_em: "2026-10-21T10:00:00Z",
    cpf_conflito: false, criado_em: "2026-10-21T10:00:00Z", expira_em: "2026-12-20T10:00:00Z", decidido_em: null,
    motivo_rejeicao: null, arquivos_disponiveis: true, outros_pendentes: 0, atual: null, ...extra,
  };
}

describe("formatações", () => {
  it("data e sim/não", () => {
    expect(formatarData("2026-10-21")).toBe("21/10/2026");
    expect(formatarData(null)).toBe("—");
    expect(simNao(true)).toBe("Sim");
    expect(simNao(false)).toBe("Não");
    expect(simNao(null)).toBe("—");
  });
  it("dias para vencer nunca fica negativo", () => {
    const agora = new Date("2026-10-21T10:00:00Z");
    expect(diasParaVencer("2026-10-31T10:00:00Z", agora)).toBe(10);
    expect(diasParaVencer("2026-10-01T10:00:00Z", agora)).toBe(0);
  });
});

describe("compararComAtual", () => {
  it("cadastro novo não marca nada como mudado", () => {
    const linhas = compararComAtual(detalhe());
    expect(quantosMudaram(linhas)).toBe(0);
    expect(linhas.find((l) => l.chave === "nome")?.novo).toBe("Maria Souza");
    expect(linhas.find((l) => l.chave === "telefone")?.novo).toBe("(71) 987654321");
  });
  it("atualização destaca só o que mudou", () => {
    const d = detalhe({
      tipo: "ATUALIZACAO", membro_id: "m1",
      atual: {
        nome: "Maria Souza", casa_oracao_id: "c1", casa_nome: "Central", cargo_id: "g1", cargo_nome: "Músico",
        instrumento_id: "i1", instrumento_nome: "Violino", categoria: "OFICIALIZADO", cidade: "Salvador", bairro: "Centro",
        data_nascimento: "1990-05-10",
        cadastro: { estado_civil: "Casado (a)", sexo: "Feminino", batizado: false, selado: false, ddd: "71", telefone: "987654321", cep: "40000000", endereco: "Rua A", numero: "10", uf: "BA" },
      },
    });
    const linhas = compararComAtual(d);
    expect(linhas.filter((l) => l.mudou).map((l) => l.chave)).toEqual(["estado_civil"]);
    const ec = linhas.find((l) => l.chave === "estado_civil");
    expect(ec?.atual).toBe("Casado (a)");
    expect(ec?.novo).toBe("Solteiro (a)");
  });
  it("campo que antes estava vazio e agora foi preenchido conta como mudança", () => {
    const d = detalhe({
      tipo: "ATUALIZACAO", membro_id: "m1",
      atual: { nome: "Maria Souza", casa_oracao_id: "c1", casa_nome: "Central", cargo_id: "g1", cargo_nome: "Músico", instrumento_id: "i1", instrumento_nome: "Violino", categoria: "OFICIALIZADO", cidade: "Salvador", bairro: "Centro", data_nascimento: "1990-05-10", cadastro: null },
    });
    expect(quantosMudaram(compararComAtual(d))).toBeGreaterThan(5);
  });
});

describe("validarMotivo", () => {
  it("exige entre 5 e 300 letras", () => {
    expect(validarMotivo("ok")).toMatch(/pelo menos 5/);
    expect(validarMotivo("   a   b   ")).toMatch(/pelo menos 5/);
    expect(validarMotivo("Documento ilegível")).toBeNull();
    expect(validarMotivo("x".repeat(301))).toMatch(/300/);
  });
});
''',
    "src/modules/cadastrosPendentes/regras.ts": r'''/**
 * SysMúsica — Regras puras da tela "Cadastros pendentes" (sem banco, sem tela). Testadas em regras.test.ts.
 * Aqui fica a COMPARAÇÃO campo a campo entre o pedido de atualização e o cadastro atual do membro.
 */
import { cargoUsaCategoria, rotuloDaCategoria } from "@/modules/painel/regras";
import type { DadosCadastro, DetalheCadastro, StatusCadastro, TipoCadastro } from "./tipos";

export const ROTULO_STATUS: Record<StatusCadastro, string> = {
  PENDENTE: "Pendente",
  APROVADO: "Aprovado",
  REJEITADO: "Recusado",
  EXPIRADO: "Vencido",
  SUBSTITUIDO: "Substituído",
};

export const ROTULO_TIPO: Record<TipoCadastro, string> = {
  NOVO: "Novo cadastro",
  ATUALIZACAO: "Atualização",
};

/** Cor do selo de cada situação (variantes do componente Badge). */
export const VARIANTE_STATUS: Record<StatusCadastro, "alerta" | "sucesso" | "perigo" | "neutro"> = {
  PENDENTE: "alerta",
  APROVADO: "sucesso",
  REJEITADO: "perigo",
  EXPIRADO: "neutro",
  SUBSTITUIDO: "neutro",
};

const VAZIO = "—";

/** "2026-10-21" -> "21/10/2026". Texto que não é data volta como está. */
export function formatarData(iso: string | null | undefined): string {
  if (!iso) return VAZIO;
  const m = /^(\d{4})-(\d{2})-(\d{2})/.exec(iso);
  return m ? `${m[3]}/${m[2]}/${m[1]}` : iso;
}

/** Data e hora de um instante (fuso de Brasília), ex.: "21/10/2026 14:05". */
export function formatarDataHora(iso: string | null | undefined): string {
  if (!iso) return VAZIO;
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return iso;
  return d.toLocaleString("pt-BR", { timeZone: "America/Sao_Paulo", day: "2-digit", month: "2-digit", year: "numeric", hour: "2-digit", minute: "2-digit" });
}

export function simNao(valor: boolean | null | undefined): string {
  return valor === true ? "Sim" : valor === false ? "Não" : VAZIO;
}

/** Dias que faltam para o pedido vencer (0 se já venceu). */
export function diasParaVencer(expiraEm: string, agora: Date = new Date()): number {
  const ms = new Date(expiraEm).getTime() - agora.getTime();
  return Number.isNaN(ms) ? 0 : Math.max(0, Math.ceil(ms / 86_400_000));
}

export interface LinhaComparacao {
  chave: string;
  rotulo: string;
  atual: string; // como está hoje (vazio em cadastro novo)
  novo: string; // como ficará
  mudou: boolean;
}

function texto(v: string | null | undefined): string {
  const t = (v ?? "").trim();
  return t === "" ? VAZIO : t;
}

function telefone(d: DadosCadastro | null | undefined): string {
  if (!d?.telefone) return VAZIO;
  return d.ddd ? `(${d.ddd}) ${d.telefone}` : d.telefone;
}

function endereco(d: DadosCadastro | null | undefined): string {
  if (!d?.endereco) return VAZIO;
  const partes = [d.endereco, d.numero, d.complemento].filter((p): p is string => !!p && p.trim() !== "");
  return partes.join(", ");
}

function cartao(d: DadosCadastro | null | undefined): string {
  if (!d?.cartao_numero) return VAZIO;
  return `${d.cartao_numero}${d.cartao_validade ? ` (validade ${formatarData(d.cartao_validade)})` : ""}`;
}

function categoria(nomeCargo: string | null, valor: string | null): string {
  if (!valor) return VAZIO;
  const tipo = cargoUsaCategoria(nomeCargo);
  return tipo ? rotuloDaCategoria(valor, tipo) : VAZIO;
}

/**
 * Linhas "campo | hoje | pedido". Em cadastro NOVO, a coluna "hoje" fica vazia. Em atualização, `mudou` marca o que
 * o aprovador precisa olhar. CPF e data de nascimento não entram: são o que identifica a pessoa e não mudam.
 */
export function compararComAtual(d: DetalheCadastro): LinhaComparacao[] {
  const a = d.atual;
  const novoDados = d.dados ?? {};
  const atualDados = a?.cadastro ?? null;
  const linha = (chave: string, rotulo: string, atual: string, novo: string): LinhaComparacao => ({
    chave,
    rotulo,
    atual: a ? atual : VAZIO,
    novo,
    mudou: !!a && atual !== novo,
  });
  return [
    linha("nome", "Nome", texto(a?.nome), texto(d.nome)),
    linha("casa", "Casa de Oração", texto(a?.casa_nome), texto(d.casa_nome)),
    linha("cargo", "Cargo", texto(a?.cargo_nome), texto(d.cargo_nome)),
    linha("instrumento", "Instrumento", texto(a?.instrumento_nome), texto(d.instrumento_nome)),
    linha("categoria", "Categoria", categoria(a?.cargo_nome ?? null, a?.categoria ?? null), categoria(d.cargo_nome, d.categoria)),
    linha("estado_civil", "Estado civil", texto(atualDados?.estado_civil), texto(novoDados.estado_civil)),
    linha("sexo", "Sexo", texto(atualDados?.sexo), texto(novoDados.sexo)),
    linha("batizado", "Batizado(a)", simNao(atualDados?.batizado), simNao(novoDados.batizado)),
    linha("data_batismo", "Data do batismo", formatarData(atualDados?.data_batismo), formatarData(novoDados.data_batismo)),
    linha("selado", "Selado(a)", simNao(atualDados?.selado), simNao(novoDados.selado)),
    linha("telefone", "Telefone", telefone(atualDados), telefone(novoDados)),
    linha("whatsapp", "WhatsApp", texto(atualDados?.whatsapp), texto(novoDados.whatsapp)),
    linha("email", "E-mail", texto(atualDados?.email), texto(novoDados.email)),
    linha("cep", "CEP", texto(atualDados?.cep), texto(novoDados.cep)),
    linha("endereco", "Endereço", endereco(atualDados), endereco(novoDados)),
    linha("bairro", "Bairro", texto(a?.bairro), texto(d.bairro)),
    linha("cidade", "Cidade", texto(a?.cidade), texto(d.cidade)),
    linha("uf", "UF", texto(atualDados?.uf), texto(novoDados.uf)),
    linha("cartao", "Cartão de identificação", cartao(atualDados), cartao(novoDados)),
  ];
}

/** Quantos campos mudam num pedido de atualização. */
export function quantosMudaram(linhas: LinhaComparacao[]): number {
  return linhas.filter((l) => l.mudou).length;
}

/** O texto do motivo da recusa é aceito? Devolve a mensagem de erro ou null (o banco confere de novo). */
export function validarMotivo(motivo: string): string | null {
  const m = motivo.trim().replace(/\s+/g, " ");
  if (m.length < 5) return "Informe o motivo da recusa (pelo menos 5 letras).";
  if (m.length > 300) return "O motivo pode ter no máximo 300 caracteres.";
  return null;
}
''',
    "src/modules/cadastrosPendentes/services/cadastrosPendentes.ts": r'''/**
 * SysMúsica — Serviço da tela "Cadastros pendentes". Listar, abrir, contar e recusar passam por funções do banco
 * (que conferem permissão e abrangência). Aprovar e ver as imagens passam por rotas do servidor, porque mexem
 * no armazenamento privado com a chave de serviço.
 */
import { supabase } from "@/lib/supabase";
import { mensagemDoErro } from "@/lib/erros";
import type { ArquivosDoCadastro, DetalheCadastro, FiltroStatus, ResumoCadastro } from "../tipos";

/** Avisa o contador do menu que a fila mudou (aprovar, recusar). */
export const EVENTO_FILA_MUDOU = "sysmusica:cadastros-mudaram";
export function avisarQueFilaMudou(): void {
  if (typeof window !== "undefined") window.dispatchEvent(new Event(EVENTO_FILA_MUDOU));
}

export async function listarCadastros(status: FiltroStatus): Promise<ResumoCadastro[]> {
  const { data, error } = await supabase.rpc("listar_cadastros_pendentes", { p_status: status });
  if (error) throw new Error(mensagemDoErro(error, "Não foi possível carregar os cadastros."));
  return ((data ?? []) as ResumoCadastro[]).map((linha) => ({ ...linha, outros_pendentes: Number(linha.outros_pendentes ?? 0) }));
}

export async function obterCadastro(id: string): Promise<DetalheCadastro> {
  const { data, error } = await supabase.rpc("obter_cadastro_pendente", { p_id: id });
  if (error || !data) throw new Error(mensagemDoErro(error, "Não foi possível abrir o cadastro."));
  const d = data as DetalheCadastro;
  return { ...d, outros_pendentes: Number(d.outros_pendentes ?? 0) };
}

/** Quantos pedidos esperam análise (0 para quem não tem permissão; nunca lança erro). */
export async function contarPendentes(): Promise<number> {
  const { data, error } = await supabase.rpc("contar_cadastros_pendentes");
  if (error) return 0;
  return Number(data ?? 0);
}

export async function recusarCadastro(id: string, motivo: string): Promise<void> {
  const { error } = await supabase.rpc("rejeitar_cadastro_pendente", { p_id: id, p_motivo: motivo });
  if (error) throw new Error(mensagemDoErro(error, "Não foi possível recusar o cadastro."));
  avisarQueFilaMudou();
}

/** Chama uma rota do servidor levando o token do login. */
async function chamar<T>(caminho: string, metodo: "GET" | "POST"): Promise<T> {
  const { data } = await supabase.auth.getSession();
  const token = data.session?.access_token;
  if (!token) throw new Error("Sua sessão expirou. Entre de novo.");
  const resposta = await fetch(caminho, { method: metodo, headers: { Authorization: `Bearer ${token}` }, cache: "no-store" });
  const json = (await resposta.json().catch(() => null)) as { erro?: string } | null;
  if (!resposta.ok) throw new Error(json?.erro ?? "Não foi possível concluir a operação.");
  return json as T;
}

export function arquivosDoCadastro(id: string): Promise<ArquivosDoCadastro> {
  return chamar<ArquivosDoCadastro>(`/api/cadastros/${id}/arquivos`, "GET");
}

export async function aprovarCadastro(id: string): Promise<{ membro_id: string }> {
  const r = await chamar<{ membro_id: string }>(`/api/cadastros/${id}/aprovar`, "POST");
  avisarQueFilaMudou();
  return r;
}
''',
    "src/modules/cadastrosPendentes/tipos.ts": r'''/** SysMúsica — Tipos da tela "Cadastros pendentes" (formato das funções do banco da migração 0042). */

export type StatusCadastro = "PENDENTE" | "APROVADO" | "REJEITADO" | "EXPIRADO" | "SUBSTITUIDO";
export type TipoCadastro = "NOVO" | "ATUALIZACAO";
/** Filtro da lista: um status ou todos. */
export type FiltroStatus = "PENDENTE" | "APROVADO" | "REJEITADO" | "EXPIRADO" | "TODOS";

export interface ResumoCadastro {
  id: string;
  tipo: TipoCadastro;
  status: StatusCadastro;
  nome: string | null;
  cpf_mascarado: string | null;
  cargo_nome: string | null;
  casa_nome: string | null;
  menor: boolean;
  cpf_conflito: boolean;
  outros_pendentes: number;
  criado_em: string;
  expira_em: string;
  decidido_em: string | null;
  motivo_rejeicao: string | null;
}

/** Campos do cadastro musical como o banco guarda no pedido (valores já limpos). */
export interface DadosCadastro {
  estado_civil?: string | null;
  sexo?: string | null;
  batizado?: boolean | null;
  data_batismo?: string | null;
  selado?: boolean | null;
  ddd?: string | null;
  telefone?: string | null;
  tem_whatsapp?: boolean | null;
  whatsapp?: string | null;
  email?: string | null;
  cep?: string | null;
  endereco?: string | null;
  numero?: string | null;
  complemento?: string | null;
  uf?: string | null;
  cartao_numero?: string | null;
  cartao_emissao?: string | null;
  cartao_validade?: string | null;
}

/** Como o membro está HOJE (só nas atualizações), para comparar com o pedido. */
export interface MembroAtual {
  nome: string | null;
  casa_oracao_id: string | null;
  casa_nome: string | null;
  cargo_id: string | null;
  cargo_nome: string | null;
  instrumento_id: string | null;
  instrumento_nome: string | null;
  categoria: string | null;
  cidade: string | null;
  bairro: string | null;
  data_nascimento: string | null;
  cadastro: DadosCadastro | null;
}

export interface DetalheCadastro {
  id: string;
  tipo: TipoCadastro;
  status: StatusCadastro;
  membro_id: string | null;
  nome: string | null;
  data_nascimento: string | null;
  cidade: string | null;
  bairro: string | null;
  cpf: string | null;
  cpf_completo_visivel: boolean;
  casa_oracao_id: string;
  casa_nome: string | null;
  cargo_id: string | null;
  cargo_nome: string | null;
  instrumento_id: string | null;
  instrumento_nome: string | null;
  categoria: string | null;
  dados: DadosCadastro;
  menor: boolean;
  responsavel_nome: string | null;
  responsavel_telefone: string | null;
  aviso_versao: string;
  aceite_em: string;
  cpf_conflito: boolean;
  criado_em: string;
  expira_em: string;
  decidido_em: string | null;
  motivo_rejeicao: string | null;
  arquivos_disponiveis: boolean;
  outros_pendentes: number;
  atual: MembroAtual | null;
}

/** Endereços temporários das imagens (documento só para quem tem a permissão CPF). */
export interface ArquivosDoCadastro {
  disponivel: boolean;
  foto?: string | null;
  frente?: string | null;
  verso?: string | null;
  documentos_liberados?: boolean;
}
''',
    "src/modules/cadastrosPendentes/useContador.ts": r'''"use client";

/**
 * SysMúsica — Contador de cadastros aguardando análise (selo no menu lateral).
 * Só consulta para quem tem cadastros.visualizar; atualiza a cada 60 s, ao voltar para a aba e quando a tela
 * "Cadastros pendentes" aprova ou recusa alguém.
 */
import { useCallback, useEffect, useState } from "react";
import { useSessao } from "@/modules/autenticacao/SessaoProvider";
import { EVENTO_FILA_MUDOU, contarPendentes } from "./services/cadastrosPendentes";

const INTERVALO_MS = 60_000;

export function useContadorCadastros(): number {
  const { pode } = useSessao();
  const permitido = pode("cadastros.visualizar");
  const [quantidade, setQuantidade] = useState(0);

  const atualizar = useCallback(async () => {
    if (!permitido) return;
    setQuantidade(await contarPendentes());
  }, [permitido]);

  useEffect(() => {
    if (!permitido) return;
    // O setState acontece DEPOIS do await (assíncrono), então o aviso set-state-in-effect não se aplica.
    // eslint-disable-next-line react-hooks/set-state-in-effect
    void atualizar();
    const relogio = setInterval(() => void atualizar(), INTERVALO_MS);
    const aoVoltar = () => {
      if (document.visibilityState === "visible") void atualizar();
    };
    window.addEventListener(EVENTO_FILA_MUDOU, aoVoltar);
    document.addEventListener("visibilitychange", aoVoltar);
    return () => {
      clearInterval(relogio);
      window.removeEventListener(EVENTO_FILA_MUDOU, aoVoltar);
      document.removeEventListener("visibilitychange", aoVoltar);
    };
  }, [permitido, atualizar]);

  return permitido ? quantidade : 0;
}
''',
    "supabase/migrations/0042_cadastro_publico.sql": r'''-- 0042 — Parte 9: Cadastro Musical PÚBLICO (link único, sem login) e fila "Cadastros pendentes"
--
-- O QUE ESTA MIGRAÇÃO FAZ
--   A) Tabelas novas (cadastros_pendentes, cadastro_publico_uploads, cadastro_publico_limites), todas com RLS ligado e
--      NENHUM acesso direto para anon/authenticated: tudo passa por funções.
--   B) Bucket privado "cadastro-publico" SEM políticas: só o servidor (chave de serviço) grava e lê. Os arquivos ficam ali
--      até o cadastro ser aprovado (aí vão para fotos-membros / documentos-membros) ou apagados pela limpeza diária.
--   C) Funções:
--        PÚBLICA (anon):  opcoes_cadastro_publico()            -> cargos, instrumentos, famílias e Casas de Oração
--        SERVIDOR:        iniciar_envio_publico, registrar_cadastro_publico, limpeza_cadastro_publico,
--                         marcar_cadastros_limpos              (somente chave de serviço; o navegador NUNCA as chama)
--        PAINEL:          listar/obter/contar_cadastros_pendentes, aprovar_cadastro_pendente, rejeitar_cadastro_pendente
--   D) Permissões: cadastros.visualizar e cadastros.aprovar (só o Administrador recebe; os demais grupos são
--      liberados em Grupos e permissões). A abrangência (casa_oracao_na_abrangencia) vale para tudo.
--   E) membros_antes_de_gravar passa a aceitar o CPF quando quem grava é a função de aprovação (o aprovador pode
--      não ter a permissão membros.cpf; ele já tem cadastros.aprovar).
--   F) Backup: backup_aplicar passa a conhecer cadastros_pendentes e membros_cadastro.
--
-- LIMITES DE SEGURANÇA (ajuste aqui se precisar): 30 envios por hora por IP, 600 por hora no total,
-- 3 envios por dia por CPF. Pendente sem análise vence em 60 dias; recusado tem os arquivos apagados em 30 dias.
begin;
set local check_function_bodies = off;

do $$
begin
  if to_regclass('public.membros') is null or to_regclass('public.membros_cadastro') is null
     or to_regclass('public.hinos') is null
     or to_regprocedure('public.exigir_permissao(text)') is null
     or to_regprocedure('public.registrar_auditoria(text, text, uuid, jsonb)') is null
     or to_regprocedure('public.casa_oracao_na_abrangencia(uuid)') is null
     or to_regprocedure('public.validar_foto_membro(uuid, text)') is null
     or to_regprocedure('public.cpf_valido(text)') is null
     or to_regprocedure('public.limpar_espacos(text)') is null
     or to_regprocedure('public.instrumento_e_orgao(text)') is null
     or to_regprocedure('public.backup_aplicar(uuid, jsonb, jsonb)') is null then
    raise exception 'Aplique primeiro as migrações até a 0041. Nada foi alterado.';
  end if;
  if to_regclass('public.cadastros_pendentes') is not null then
    raise exception 'A migração 0042 já foi aplicada. Nada foi alterado.';
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 1. Apoio
-- ---------------------------------------------------------------------------
-- Cargos que têm Cadastro Musical (mesma lista de CARGOS_DO_CADASTRO em src/modules/membros/cadastroMusical.ts)
create or replace function public.cargo_aceita_cadastro_publico(p_nome text)
returns boolean language sql immutable set search_path to 'public'
as $$ select public.normalizar_texto(p_nome) ~ '^(encarregado regional|encarregado local|examinadora|instrutor|musico|organista)' $$;

-- Texto -> data, ou nulo se não for uma data válida (evita erro técnico aparecer para o público)
create or replace function public.data_ou_nula(p_texto text)
returns date language plpgsql immutable set search_path to 'public'
as $$
begin
  if p_texto is null or p_texto !~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' then return null; end if;
  return p_texto::date;
exception when others then
  return null;
end;
$$;

-- CPF com a parte do meio escondida (para listas)
create or replace function public.cpf_escondido(p_cpf text)
returns text language sql immutable set search_path to 'public'
as $$ select case when p_cpf is null then null else '***.' || substr(p_cpf, 4, 3) || '.***-' || right(p_cpf, 2) end $$;

-- ---------------------------------------------------------------------------
-- 2. Tabelas
-- ---------------------------------------------------------------------------
-- Pedidos de cadastro feitos pela página pública. NADA aqui vira membro sem uma pessoa aprovar.
create table public.cadastros_pendentes (
  -- O id é o mesmo da pasta dos arquivos no bucket cadastro-publico (<id>/foto.jpg, frente.jpg, verso.jpg)
  id                    uuid primary key,
  tipo                  text not null check (tipo in ('NOVO', 'ATUALIZACAO')),
  status                text not null default 'PENDENTE'
                        check (status in ('PENDENTE', 'APROVADO', 'REJEITADO', 'EXPIRADO', 'SUBSTITUIDO')),
  -- ATUALIZACAO: o membro que já existe. NOVO aprovado: o membro criado.
  membro_id             uuid references public.membros (id) on delete set null,
  casa_oracao_id        uuid not null references public.casas_oracao (id),
  -- Dados pessoais: são apagados (viram nulo) quando os arquivos são apagados de um pedido não aprovado
  nome                  text,
  cpf                   text check (cpf is null or public.cpf_valido(cpf)),
  data_nascimento       date,
  cidade                text,
  bairro                text,
  cargo_id              uuid references public.cargos (id),
  instrumento_id        uuid references public.instrumentos (id) on delete set null,
  categoria             text check (categoria is null or categoria in ('OFICIALIZADO', 'CULTO_OFICIAL', 'RJM')),
  dados                 jsonb not null default '{}'::jsonb,   -- campos de membros_cadastro (sem os caminhos dos arquivos)
  -- Menores de 18 anos
  responsavel_nome      text,
  responsavel_telefone  text,
  aceite_responsavel    boolean not null default false,
  -- Consentimento (LGPD): versão do aviso aceito e quando
  aviso_versao          text not null,
  aceite_em             timestamptz not null default now(),
  ip_hash               text,
  -- O CPF já existe no sistema, mas com outra data de nascimento: o aprovador precisa conferir com cuidado
  cpf_conflito          boolean not null default false,
  criado_em             timestamptz not null default now(),
  expira_em             timestamptz not null default (now() + interval '60 days'),
  decidido_em           timestamptz,
  decidido_por          uuid,
  motivo_rejeicao       text check (motivo_rejeicao is null or char_length(motivo_rejeicao) <= 300),
  arquivos_apagados_em  timestamptz
);
create index idx_cadastros_pendentes_status on public.cadastros_pendentes (status, criado_em);
create index idx_cadastros_pendentes_cpf on public.cadastros_pendentes (cpf) where cpf is not null;
create index idx_cadastros_pendentes_casa on public.cadastros_pendentes (casa_oracao_id);

-- Envios iniciados (o id vira o id do pedido). Serve para só aceitar dados de quem enviou arquivos antes.
create table public.cadastro_publico_uploads (
  id         uuid primary key default gen_random_uuid(),
  ip_hash    text,
  criado_em  timestamptz not null default now(),
  usado      boolean not null default false
);
create index idx_cadastro_publico_uploads_criado on public.cadastro_publico_uploads (criado_em);

-- Registro das tentativas (limite por IP, por CPF e geral). A chave é sempre um hash, nunca o IP/CPF puro.
create table public.cadastro_publico_limites (
  id         bigint generated always as identity primary key,
  tipo       text not null check (tipo in ('ip', 'cpf', 'geral')),
  chave      text not null,
  criado_em  timestamptz not null default now()
);
create index idx_cadastro_publico_limites on public.cadastro_publico_limites (tipo, chave, criado_em);

alter table public.cadastros_pendentes enable row level security;
alter table public.cadastro_publico_uploads enable row level security;
alter table public.cadastro_publico_limites enable row level security;
revoke all on public.cadastros_pendentes from public, anon, authenticated;
revoke all on public.cadastro_publico_uploads from public, anon, authenticated;
revoke all on public.cadastro_publico_limites from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 3. Armazenamento PRIVADO do cadastro público (sem políticas: só a chave de serviço do servidor acessa)
-- ---------------------------------------------------------------------------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('cadastro-publico', 'cadastro-publico', false, 3145728, array['image/jpeg'])
on conflict (id) do update
   set public = false, file_size_limit = 3145728, allowed_mime_types = array['image/jpeg'];

-- ---------------------------------------------------------------------------
-- 4. Permissões (iguais a CATALOGO_PERMISSOES em src/lib/permissoes.ts). Só o Administrador recebe.
-- ---------------------------------------------------------------------------
insert into public.permissoes (codigo, modulo, acao, descricao) values
  ('cadastros.visualizar', 'Cadastros pendentes', 'Visualizar', 'Ver os cadastros enviados pelo link público, aguardando análise'),
  ('cadastros.aprovar',    'Cadastros pendentes', 'Aprovar',    'Aprovar ou recusar os cadastros enviados pelo link público')
on conflict (codigo) do update
  set modulo = excluded.modulo, acao = excluded.acao, descricao = excluded.descricao;

insert into public.grupo_permissoes (grupo_id, permissao_codigo)
select g.id, p.codigo
  from public.grupos g
  cross join public.permissoes p
 where g.sistema and g.nome = 'Administrador'
   and p.codigo in ('cadastros.visualizar', 'cadastros.aprovar')
on conflict do nothing;

-- ---------------------------------------------------------------------------
-- 5. membros_antes_de_gravar: aceita o CPF quando a gravação vem da função de aprovação
--    (cópia da versão atual; só muda a condição do bloco do CPF)
-- ---------------------------------------------------------------------------
create or replace function public.membros_antes_de_gravar()
returns trigger
language plpgsql
set search_path to 'public'
as $$
declare
  v_logado boolean := (select auth.uid()) is not null;
  -- Ligado só dentro de aprovar_cadastro_pendente (que já exige a permissão cadastros.aprovar)
  v_aprovando boolean := coalesce(current_setting('sysmusica.aprovando_cadastro', true), '') = 'sim';
begin
  if v_logado and not v_aprovando then
    if tg_op = 'INSERT' then
      if new.cpf is not null and not public.tem_permissao('membros.cpf') then
        raise exception 'Você não tem permissão para informar o CPF.' using errcode = '42501';
      end if;
    elsif new.cpf is distinct from old.cpf and not public.tem_permissao('membros.cpf') then
      raise exception 'Você não tem permissão para alterar o CPF.' using errcode = '42501';
    end if;
  end if;

  if tg_op = 'UPDATE' then
    new.atualizado_em := now();
  end if;
  return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- 6. Função PÚBLICA: opções do formulário (qualquer pessoa, sem login)
--    Expõe só nomes de cargos, instrumentos, famílias e Casas de Oração (com o caminho na organização).
-- ---------------------------------------------------------------------------
create or replace function public.opcoes_cadastro_publico()
returns jsonb
language sql stable security definer set search_path to 'public'
as $$
  select jsonb_build_object(
    'cargos', (select coalesce(jsonb_agg(jsonb_build_object(
                  'id', c.id, 'nome', c.nome, 'permite_instrumento', c.permite_instrumento,
                  'exige_instrumento', c.exige_instrumento, 'exige_cartao', c.exige_cartao,
                  'somente_orgao', c.somente_orgao) order by c.nome), '[]'::jsonb)
                 from public.cargos c where public.cargo_aceita_cadastro_publico(c.nome)),
    'instrumentos', (select coalesce(jsonb_agg(jsonb_build_object('id', i.id, 'nome', i.nome, 'familia_id', i.familia_id)
                  order by i.nome), '[]'::jsonb) from public.instrumentos i),
    'familias', (select coalesce(jsonb_agg(jsonb_build_object('id', f.id, 'nome', f.nome) order by f.nome), '[]'::jsonb)
                 from public.familias f),
    'casas', (select coalesce(jsonb_agg(jsonb_build_object(
                  'id', ca.id, 'nome', ca.nome, 'adm', a.nome, 'ra', r.nome, 'rrm', rr.nome, 'setor', s.nome)
                  order by ca.nome), '[]'::jsonb)
                from public.casas_oracao ca
                left join public.setores s on s.id = ca.setor_id
                left join public.adms a on a.id = coalesce(ca.adm_id, s.adm_id)
                left join public.ras r on r.id = a.ra_id
                left join public.rrms rr on rr.id = r.rrm_id
               where ca.ativo)
  )
$$;

-- ---------------------------------------------------------------------------
-- 7. Funções do SERVIDOR (somente chave de serviço)
-- ---------------------------------------------------------------------------
-- Controla o limite de tentativas. Lança P0429 quando passou do limite.
create or replace function public.cadastro_publico_limite(p_tipo text, p_chave text, p_max integer, p_janela interval)
returns void
language plpgsql security definer set search_path to 'public'
as $$
declare v_qtd integer;
begin
  select count(*) into v_qtd from public.cadastro_publico_limites
   where tipo = p_tipo and chave = p_chave and criado_em > now() - p_janela;
  if v_qtd >= p_max then
    raise exception 'Muitas tentativas. Aguarde um pouco e tente novamente.' using errcode = 'P0429';
  end if;
  insert into public.cadastro_publico_limites (tipo, chave) values (p_tipo, p_chave);
end;
$$;

-- Passo 1 do envio: confere o limite e cria o id do envio (a pasta dos arquivos).
create or replace function public.iniciar_envio_publico(p_ip_hash text)
returns uuid
language plpgsql security definer set search_path to 'public'
as $$
declare v_id uuid;
begin
  perform public.cadastro_publico_limite('geral', 'todos', 600, interval '1 hour');
  if p_ip_hash is not null then
    perform public.cadastro_publico_limite('ip', p_ip_hash, 30, interval '1 hour');
  end if;
  insert into public.cadastro_publico_uploads (ip_hash) values (p_ip_hash) returning id into v_id;
  return v_id;
end;
$$;

-- Passo 2: confere TUDO de novo (a tela é só a resposta rápida) e grava o pedido. Nunca revela se o CPF já existia.
create or replace function public.registrar_cadastro_publico(p_envio uuid, p_dados jsonb, p_ip_hash text)
returns void
language plpgsql security definer set search_path to 'public'
as $$
declare
  d              jsonb;
  v_cad          jsonb;
  v_nome         text;
  v_cpf          text;
  v_nasc         date;
  v_casa         uuid;
  v_cargo        record;
  v_cargo_id     uuid;
  v_instr        uuid;
  v_instr_nome   text;
  v_categoria    text;
  v_cidade       text;
  v_bairro       text;
  v_menor        boolean;
  v_resp_nome    text;
  v_resp_tel     text;
  v_ace_resp     boolean;
  v_aviso        text;
  v_membro       uuid;
  v_membro_nasc  date;
  v_tipo         text := 'NOVO';
  v_conflito     boolean := false;
  v_usa_categ    boolean;
  v_batizado     boolean;
  v_dbat         date;
  v_demi         date;
  v_dval         date;
  v_limpo        jsonb;
  v_ec text; v_sx text; v_ddd text; v_tel text; v_wpp text; v_email text; v_cep text; v_end text; v_num text;
  v_comp text; v_uf text; v_cnum text;
begin
  if p_dados is null or jsonb_typeof(p_dados) <> 'object' then
    raise exception 'Não foi possível enviar o cadastro. Atualize a página e tente de novo.';
  end if;
  d := p_dados;

  -- O envio precisa ter sido iniciado há pouco e ainda não usado
  if not exists (select 1 from public.cadastro_publico_uploads u
                  where u.id = p_envio and not u.usado and u.criado_em > now() - interval '2 hours') then
    raise exception 'O envio expirou. Atualize a página e tente de novo.';
  end if;
  -- As três imagens precisam estar no armazenamento
  if (select count(*) from storage.objects o
       where o.bucket_id = 'cadastro-publico'
         and o.name in (p_envio::text || '/foto.jpg', p_envio::text || '/frente.jpg', p_envio::text || '/verso.jpg')) <> 3 then
    raise exception 'As imagens não foram enviadas. Tente novamente.';
  end if;

  -- Armadilha contra robôs
  if nullif(btrim(d ->> 'site'), '') is not null then
    raise exception 'Não foi possível enviar o cadastro. Atualize a página e tente de novo.';
  end if;
  if d -> 'aceite_privacidade' is distinct from 'true'::jsonb then
    raise exception 'Para enviar, é preciso concordar com o aviso de privacidade.';
  end if;
  v_aviso := nullif(btrim(d ->> 'aviso_versao'), '');
  if v_aviso is null or char_length(v_aviso) > 40 then
    raise exception 'Atualize a página e tente de novo.';
  end if;

  -- Identificação
  v_nome := public.limpar_espacos(d ->> 'nome');
  if v_nome is null or char_length(v_nome) < 5 or char_length(v_nome) > 120 or position(' ' in v_nome) = 0 then
    raise exception 'Informe o nome completo (nome e sobrenome).';
  end if;
  v_cpf := nullif(btrim(d ->> 'cpf'), '');
  if v_cpf is null or not public.cpf_valido(v_cpf) then
    raise exception 'CPF inválido. Confira os números digitados.';
  end if;
  v_nasc := public.data_ou_nula(d ->> 'data_nascimento');
  if v_nasc is null or v_nasc > current_date or v_nasc < date '1900-01-01' then
    raise exception 'Data de nascimento inválida.';
  end if;
  v_cidade := public.limpar_espacos(d ->> 'cidade');
  v_bairro := public.limpar_espacos(d ->> 'bairro');
  if v_cidade is null or v_bairro is null or char_length(v_cidade) > 80 or char_length(v_bairro) > 80 then
    raise exception 'Informe a cidade e o bairro.';
  end if;

  -- Casa de Oração
  begin v_casa := (d ->> 'casa_oracao_id')::uuid; exception when others then v_casa := null; end;
  if v_casa is null or not exists (select 1 from public.casas_oracao c where c.id = v_casa and c.ativo) then
    raise exception 'Escolha a sua Casa de Oração.';
  end if;

  -- Cargo, categoria e instrumento
  begin v_cargo_id := (d ->> 'cargo_id')::uuid; exception when others then v_cargo_id := null; end;
  select c.* into v_cargo from public.cargos c where c.id = v_cargo_id;
  if not found or not public.cargo_aceita_cadastro_publico(v_cargo.nome) then
    raise exception 'Escolha um cargo da lista.';
  end if;
  v_usa_categ := public.normalizar_texto(v_cargo.nome) ~ '^(musico|organista)';
  v_categoria := nullif(btrim(d ->> 'categoria'), '');
  if v_usa_categ then
    if v_categoria is null or v_categoria not in ('OFICIALIZADO', 'CULTO_OFICIAL', 'RJM') then
      raise exception 'Escolha a categoria.';
    end if;
  else
    v_categoria := null;
  end if;

  if v_cargo.permite_instrumento then
    begin v_instr := (d ->> 'instrumento_id')::uuid; exception when others then v_instr := null; end;
    select i.nome into v_instr_nome from public.instrumentos i where i.id = v_instr;
    if v_instr_nome is null then
      raise exception 'Informe o instrumento.';
    end if;
    if v_cargo.somente_orgao and not public.instrumento_e_orgao(v_instr_nome) then
      raise exception 'O cargo % só pode usar o instrumento Órgão.', v_cargo.nome;
    end if;
  else
    v_instr := null;
  end if;

  -- Dados pessoais (mesmas regras de salvar_cadastro_musical)
  v_cad := d -> 'cadastro';
  if v_cad is null or jsonb_typeof(v_cad) <> 'object' then
    raise exception 'Preencha os dados pessoais.';
  end if;
  v_ec    := nullif(btrim(v_cad ->> 'estado_civil'), '');
  v_sx    := nullif(btrim(v_cad ->> 'sexo'), '');
  v_ddd   := nullif(btrim(v_cad ->> 'ddd'), '');
  v_tel   := nullif(btrim(v_cad ->> 'telefone'), '');
  v_wpp   := nullif(btrim(v_cad ->> 'whatsapp'), '');
  v_email := nullif(btrim(v_cad ->> 'email'), '');
  v_cep   := nullif(btrim(v_cad ->> 'cep'), '');
  v_end   := public.limpar_espacos(v_cad ->> 'endereco');
  v_num   := public.limpar_espacos(v_cad ->> 'numero');
  v_comp  := public.limpar_espacos(v_cad ->> 'complemento');
  v_uf    := nullif(btrim(v_cad ->> 'uf'), '');
  v_cnum  := public.limpar_espacos(v_cad ->> 'cartao_numero');
  v_demi  := public.data_ou_nula(v_cad ->> 'cartao_emissao');
  v_dval  := public.data_ou_nula(v_cad ->> 'cartao_validade');
  v_dbat  := public.data_ou_nula(v_cad ->> 'data_batismo');

  if v_ec is null or v_ec not in ('Casado (a)', 'Solteiro (a)', 'Viúvo (a)') then raise exception 'Informe o estado civil.'; end if;
  if v_sx is null or v_sx not in ('Masculino', 'Feminino') then raise exception 'Informe o sexo.'; end if;
  if jsonb_typeof(v_cad -> 'batizado') <> 'boolean' then raise exception 'Informe se a pessoa é batizada.'; end if;
  v_batizado := (v_cad ->> 'batizado')::boolean;
  if v_batizado then
    if v_dbat is null then raise exception 'Informe a data do batismo.'; end if;
    if v_dbat < v_nasc or v_dbat > current_date then raise exception 'A data do batismo é inválida.'; end if;
  else
    v_dbat := null;
  end if;
  if jsonb_typeof(v_cad -> 'selado') <> 'boolean' then raise exception 'Informe se a pessoa é selada.'; end if;
  if v_ddd is null or v_ddd !~ '^[0-9]{2}$' then raise exception 'O DDD deve ter 2 números.'; end if;
  if v_tel is null or v_tel !~ '^[0-9]{8,9}$' then raise exception 'O telefone deve ter 8 ou 9 números.'; end if;
  if jsonb_typeof(v_cad -> 'tem_whatsapp') <> 'boolean' then raise exception 'Informe se o telefone tem WhatsApp.'; end if;
  if (v_cad ->> 'tem_whatsapp')::boolean then
    if v_wpp is not null and v_wpp !~ '^[0-9]{10,11}$' then raise exception 'O WhatsApp deve ter o DDD e 8 ou 9 números.'; end if;
  else
    v_wpp := null;
  end if;
  if v_email is not null and (char_length(v_email) > 120 or v_email !~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$') then
    raise exception 'O e-mail informado não é válido.';
  end if;
  if v_cep is null or v_cep !~ '^[0-9]{8}$' then raise exception 'O CEP deve ter 8 números.'; end if;
  if v_end is null or char_length(v_end) > 150 then raise exception 'Informe o endereço.'; end if;
  if v_num is null or char_length(v_num) > 20 then raise exception 'Informe o número do endereço.'; end if;
  if v_comp is not null and char_length(v_comp) > 80 then raise exception 'O complemento é longo demais.'; end if;
  if v_uf is null or v_uf !~ '^[A-Z]{2}$' then raise exception 'Informe o estado (UF).'; end if;
  if v_cnum is not null and char_length(v_cnum) > 40 then raise exception 'O número do cartão é longo demais.'; end if;
  if v_demi is not null and v_dval is not null and v_demi > v_dval then
    raise exception 'A validade do cartão não pode ser anterior à emissão.';
  end if;
  if coalesce(v_cargo.exige_cartao, false) and (v_cnum is null or v_dval is null) then
    raise exception 'Este cargo exige o número e a validade do cartão de identificação.';
  end if;

  -- Menor de 18 anos: responsável
  v_menor := v_nasc > (current_date - interval '18 years')::date;
  v_resp_nome := null; v_resp_tel := null; v_ace_resp := false;
  if v_menor then
    v_resp_nome := public.limpar_espacos(d ->> 'responsavel_nome');
    v_resp_tel  := nullif(btrim(d ->> 'responsavel_telefone'), '');
    v_ace_resp  := d -> 'aceite_responsavel' is not distinct from 'true'::jsonb;
    if v_resp_nome is null or char_length(v_resp_nome) < 3 or char_length(v_resp_nome) > 120 then
      raise exception 'Para menores de 18 anos, informe o nome do responsável.';
    end if;
    if v_resp_tel is null or v_resp_tel !~ '^[0-9]{10,11}$' then
      raise exception 'Informe o telefone do responsável com o DDD.';
    end if;
    if not v_ace_resp then raise exception 'O responsável precisa concordar com o cadastro.'; end if;
  end if;

  -- Limite por CPF (3 por dia). Só conta a quantidade: não revela se o CPF existe.
  perform public.cadastro_publico_limite('cpf', encode(sha256(convert_to(v_cpf, 'UTF8')), 'hex'), 3, interval '1 day');

  -- É alguém que já está no sistema? CPF + data de nascimento iguais = pedido de ATUALIZAÇÃO.
  select m.id, m.data_nascimento into v_membro, v_membro_nasc
    from public.membros m where m.cpf = v_cpf and m.excluido_em is null;
  if found then
    if v_membro_nasc is not distinct from v_nasc then
      v_tipo := 'ATUALIZACAO';
    else
      v_conflito := true;   -- mesmo CPF, outra data de nascimento: o aprovador confere
      v_membro := null;
    end if;
  else
    v_membro := null;
  end if;

  v_limpo := jsonb_build_object(
    'estado_civil', v_ec, 'sexo', v_sx, 'batizado', v_batizado, 'data_batismo', v_dbat,
    'selado', (v_cad ->> 'selado')::boolean, 'ddd', v_ddd, 'telefone', v_tel,
    'tem_whatsapp', (v_cad ->> 'tem_whatsapp')::boolean, 'whatsapp', v_wpp, 'email', v_email,
    'cep', v_cep, 'endereco', v_end, 'numero', v_num, 'complemento', v_comp, 'uf', v_uf,
    'cartao_numero', v_cnum, 'cartao_emissao', v_demi, 'cartao_validade', v_dval);

  insert into public.cadastros_pendentes (
    id, tipo, membro_id, casa_oracao_id, nome, cpf, data_nascimento, cidade, bairro, cargo_id, instrumento_id,
    categoria, dados, responsavel_nome, responsavel_telefone, aceite_responsavel, aviso_versao, ip_hash, cpf_conflito)
  values (
    p_envio, v_tipo, v_membro, v_casa, v_nome, v_cpf, v_nasc, v_cidade, v_bairro, v_cargo_id, v_instr,
    v_categoria, v_limpo, v_resp_nome, v_resp_tel, v_ace_resp, v_aviso, p_ip_hash, v_conflito);

  update public.cadastro_publico_uploads set usado = true where id = p_envio;
end;
$$;

-- Limpeza diária (chamada pelo cron /api/cron/conferir). Devolve as pastas cujos arquivos o servidor deve apagar.
--   * envios abandonados há mais de 24 h (as linhas só saem depois que o servidor apagar os arquivos);
--   * pendentes vencidos (60 dias) viram EXPIRADO;
--   * recusados há mais de 30 dias e expirados/substituídos: arquivos apagados e dados pessoais zerados;
--   * registros de limite e linhas antigas sem dados são removidos.
create or replace function public.limpeza_cadastro_publico()
returns jsonb
language plpgsql security definer set search_path to 'public'
as $$
declare
  v_abandonados uuid[];
  v_pastas      uuid[];
begin
  select coalesce(array_agg(u.id), '{}') into v_abandonados
    from public.cadastro_publico_uploads u
   where not u.usado and u.criado_em < now() - interval '24 hours';

  update public.cadastros_pendentes
     set status = 'EXPIRADO', decidido_em = now()
   where status = 'PENDENTE' and expira_em < now();

  select coalesce(array_agg(c.id), '{}') into v_pastas
    from public.cadastros_pendentes c
   where c.arquivos_apagados_em is null
     and ((c.status in ('EXPIRADO', 'SUBSTITUIDO'))
          or (c.status = 'REJEITADO' and c.decidido_em < now() - interval '30 days'));

  delete from public.cadastro_publico_limites where criado_em < now() - interval '2 days';
  delete from public.cadastro_publico_uploads where usado and criado_em < now() - interval '7 days';
  delete from public.cadastros_pendentes
   where status in ('REJEITADO', 'EXPIRADO', 'SUBSTITUIDO') and arquivos_apagados_em is not null
     and decidido_em < now() - interval '180 days';

  return jsonb_build_object('pastas', to_jsonb(v_abandonados || v_pastas), 'para_marcar', to_jsonb(v_pastas),
                            'abandonados', to_jsonb(v_abandonados));
end;
$$;

-- Depois que o servidor apagou os arquivos: zera os dados pessoais dos pedidos não aprovados.
create or replace function public.marcar_cadastros_limpos(p_ids uuid[], p_abandonados uuid[] default '{}')
returns integer
language plpgsql security definer set search_path to 'public'
as $$
declare v_n integer;
begin
  delete from public.cadastro_publico_uploads where id = any (p_abandonados) and not usado;
  update public.cadastros_pendentes
     set arquivos_apagados_em = now(), nome = null, cpf = null, data_nascimento = null, cidade = null, bairro = null,
         dados = '{}'::jsonb, responsavel_nome = null, responsavel_telefone = null, ip_hash = null
   where id = any (p_ids) and status in ('REJEITADO', 'EXPIRADO', 'SUBSTITUIDO') and arquivos_apagados_em is null;
  get diagnostics v_n = row_count;
  return v_n;
end;
$$;

-- ---------------------------------------------------------------------------
-- 8. Funções do PAINEL (quem tem a permissão e a abrangência)
-- ---------------------------------------------------------------------------
-- O pedido é visível se a casa pedida OU a casa atual do membro estiver na abrangência de quem consulta.
create or replace function public.cadastro_pendente_visivel(p_casa uuid, p_membro uuid)
returns boolean
language sql stable security definer set search_path to 'public'
as $$
  select public.casa_oracao_na_abrangencia(p_casa)
      or exists (select 1 from public.membros m
                  where m.id = p_membro and m.casa_oracao_id is not null
                    and public.casa_oracao_na_abrangencia(m.casa_oracao_id))
$$;

create or replace function public.contar_cadastros_pendentes()
returns integer
language plpgsql stable security definer set search_path to 'public'
as $$
declare v_qtd integer;
begin
  if not public.tem_permissao('cadastros.visualizar') then return 0; end if;
  select count(*) into v_qtd from public.cadastros_pendentes c
   where c.status = 'PENDENTE' and public.cadastro_pendente_visivel(c.casa_oracao_id, c.membro_id);
  return v_qtd;
end;
$$;

create or replace function public.listar_cadastros_pendentes(p_status text default 'PENDENTE')
returns table (
  id uuid, tipo text, status text, nome text, cpf_mascarado text, cargo_nome text, casa_nome text,
  menor boolean, cpf_conflito boolean, outros_pendentes bigint, criado_em timestamptz, expira_em timestamptz,
  decidido_em timestamptz, motivo_rejeicao text
)
language plpgsql stable security definer set search_path to 'public'
as $$
begin
  perform public.exigir_permissao('cadastros.visualizar');
  if p_status is not null and p_status not in ('PENDENTE', 'APROVADO', 'REJEITADO', 'EXPIRADO', 'TODOS') then
    raise exception 'Situação inválida.' using errcode = '22023';
  end if;
  return query
    select c.id, c.tipo, c.status, c.nome, public.cpf_escondido(c.cpf), g.nome, ca.nome,
           (c.data_nascimento is not null and c.data_nascimento > (c.criado_em::date - interval '18 years')::date),
           c.cpf_conflito,
           (select count(*) from public.cadastros_pendentes o
             where o.status = 'PENDENTE' and o.id <> c.id and c.cpf is not null and o.cpf = c.cpf),
           c.criado_em, c.expira_em, c.decidido_em, c.motivo_rejeicao
      from public.cadastros_pendentes c
      left join public.cargos g on g.id = c.cargo_id
      left join public.casas_oracao ca on ca.id = c.casa_oracao_id
     where (p_status is null or p_status = 'TODOS' or c.status = p_status)
       and public.cadastro_pendente_visivel(c.casa_oracao_id, c.membro_id)
     order by case when c.status = 'PENDENTE' then 0 else 1 end, c.criado_em desc
     limit 500;
end;
$$;

-- Tudo de UM pedido, mais (nas atualizações) os dados atuais do membro para a tela mostrar o que mudou.
create or replace function public.obter_cadastro_pendente(p_id uuid)
returns jsonb
language plpgsql stable security definer set search_path to 'public'
as $$
declare
  c      public.cadastros_pendentes%rowtype;
  v_atual jsonb := null;
  v_ver_cpf boolean;
begin
  perform public.exigir_permissao('cadastros.visualizar');
  select * into c from public.cadastros_pendentes where id = p_id;
  if not found or not public.cadastro_pendente_visivel(c.casa_oracao_id, c.membro_id) then
    raise exception 'Cadastro não encontrado.' using errcode = 'P0002';
  end if;
  v_ver_cpf := public.tem_permissao('membros.cpf');

  if c.membro_id is not null then
    select jsonb_build_object(
             'nome', m.nome, 'casa_oracao_id', m.casa_oracao_id, 'casa_nome', ca.nome,
             'cargo_id', m.cargo_id, 'cargo_nome', g.nome, 'instrumento_id', m.instrumento_id, 'instrumento_nome', i.nome,
             'categoria', m.categoria, 'cidade', m.cidade, 'bairro', m.bairro, 'data_nascimento', m.data_nascimento,
             'cadastro', (select to_jsonb(mc) - 'membro_id' - 'criado_em' - 'atualizado_em' - 'documento_frente_path'
                                 - 'documento_verso_path' - 'apresentado_em' - 'apresentado_por' - 'observacao'
                            from public.membros_cadastro mc where mc.membro_id = m.id))
      into v_atual
      from public.membros m
      left join public.casas_oracao ca on ca.id = m.casa_oracao_id
      left join public.cargos g on g.id = m.cargo_id
      left join public.instrumentos i on i.id = m.instrumento_id
     where m.id = c.membro_id and m.excluido_em is null;
  end if;

  return jsonb_build_object(
    'id', c.id, 'tipo', c.tipo, 'status', c.status, 'membro_id', c.membro_id,
    'nome', c.nome, 'data_nascimento', c.data_nascimento, 'cidade', c.cidade, 'bairro', c.bairro,
    'cpf', case when v_ver_cpf then c.cpf else public.cpf_escondido(c.cpf) end,
    'cpf_completo_visivel', v_ver_cpf,
    'casa_oracao_id', c.casa_oracao_id,
    'casa_nome', (select ca.nome from public.casas_oracao ca where ca.id = c.casa_oracao_id),
    'cargo_id', c.cargo_id, 'cargo_nome', (select g.nome from public.cargos g where g.id = c.cargo_id),
    'instrumento_id', c.instrumento_id, 'instrumento_nome', (select i.nome from public.instrumentos i where i.id = c.instrumento_id),
    'categoria', c.categoria, 'dados', c.dados,
    'menor', c.data_nascimento is not null and c.data_nascimento > (c.criado_em::date - interval '18 years')::date,
    'responsavel_nome', c.responsavel_nome, 'responsavel_telefone', c.responsavel_telefone,
    'aviso_versao', c.aviso_versao, 'aceite_em', c.aceite_em, 'cpf_conflito', c.cpf_conflito,
    'criado_em', c.criado_em, 'expira_em', c.expira_em, 'decidido_em', c.decidido_em,
    'motivo_rejeicao', c.motivo_rejeicao,
    'arquivos_disponiveis', (c.arquivos_apagados_em is null and c.status in ('PENDENTE', 'REJEITADO')),
    'outros_pendentes', (select count(*) from public.cadastros_pendentes o
                          where o.status = 'PENDENTE' and o.id <> c.id and c.cpf is not null and o.cpf = c.cpf),
    'atual', v_atual);
end;
$$;

-- Aprova. O servidor já MOVEU os arquivos para as pastas finais (p_foto / p_doc_frente / p_doc_verso) antes de chamar;
-- se esta função falhar, o servidor devolve os arquivos. Devolve os caminhos antigos para o servidor apagar.
create or replace function public.aprovar_cadastro_pendente(
  p_id uuid, p_membro uuid, p_foto text, p_doc_frente text, p_doc_verso text)
returns jsonb
language plpgsql security definer set search_path to 'public'
as $$
declare
  c         public.cadastros_pendentes%rowtype;
  v_cad     jsonb;
  v_membro  uuid;
  v_atual   public.membros%rowtype;
  v_antigos jsonb := '{}'::jsonb;
  v_obs     text;
  v_antigo_cad public.membros_cadastro%rowtype;
begin
  perform public.exigir_permissao('cadastros.aprovar');
  select * into c from public.cadastros_pendentes where id = p_id for update;
  if not found or not public.cadastro_pendente_visivel(c.casa_oracao_id, c.membro_id) then
    raise exception 'Cadastro não encontrado.' using errcode = 'P0002';
  end if;
  if c.status <> 'PENDENTE' then
    raise exception 'Este cadastro já foi analisado.' using errcode = '22023';
  end if;
  if not public.casa_oracao_na_abrangencia(c.casa_oracao_id) then
    raise exception 'A Casa de Oração do pedido está fora da sua abrangência. Peça a quem tem acesso total.' using errcode = '42501';
  end if;

  v_membro := coalesce(c.membro_id, p_membro);
  if v_membro is null then raise exception 'Identificação do membro ausente.' using errcode = '22023'; end if;
  if left(p_foto, 37) <> v_membro::text || '/' then
    raise exception 'Caminho da fotografia inválido.' using errcode = '22023';
  end if;
  if left(p_doc_frente, 37) <> v_membro::text || '/' or left(p_doc_verso, 37) <> v_membro::text || '/' then
    raise exception 'Caminho do documento inválido.' using errcode = '22023';
  end if;
  if position('..' in p_foto || p_doc_frente || p_doc_verso) > 0 then
    raise exception 'Caminho inválido.' using errcode = '22023';
  end if;
  if not exists (select 1 from storage.objects o where o.bucket_id = 'documentos-membros' and o.name = p_doc_frente)
     or not exists (select 1 from storage.objects o where o.bucket_id = 'documentos-membros' and o.name = p_doc_verso) then
    raise exception 'Os arquivos do documento não foram encontrados. Tente aprovar de novo.' using errcode = '22023';
  end if;
  perform public.validar_foto_membro(v_membro, p_foto);

  -- A partir daqui o gatilho dos membros aceita o CPF (a permissão cadastros.aprovar já foi conferida)
  perform set_config('sysmusica.aprovando_cadastro', 'sim', true);

  v_cad := c.dados;
  v_obs := null;
  if c.responsavel_nome is not null then
    v_obs := 'Menor de idade no cadastro público (' || to_char(c.criado_em at time zone 'America/Sao_Paulo', 'DD/MM/YYYY')
             || '). Responsável: ' || c.responsavel_nome || ', telefone ' || c.responsavel_telefone || '.';
  end if;

  if c.tipo = 'NOVO' then
    if c.cpf is null or exists (select 1 from public.membros m where m.cpf = c.cpf and m.excluido_em is null) then
      raise exception 'Já existe um membro com este CPF. Recuse este pedido e atualize o cadastro existente.' using errcode = '23505';
    end if;
    insert into public.membros (id, nome, congregacao, casa_oracao_id, cargo_id, data_nascimento, status,
                                instrumento_id, cpf, cidade, bairro, foto_path, categoria)
    values (v_membro, c.nome, '', c.casa_oracao_id, c.cargo_id, c.data_nascimento, 'Ativo',
            c.instrumento_id, c.cpf, c.cidade, c.bairro, p_foto, c.categoria);

    insert into public.membros_cadastro (
      membro_id, estado_civil, sexo, batizado, data_batismo, selado, ddd, telefone, tem_whatsapp, whatsapp, email,
      cep, endereco, numero, complemento, uf, cartao_numero, cartao_emissao, cartao_validade, observacao,
      documento_frente_path, documento_verso_path)
    values (
      v_membro, v_cad ->> 'estado_civil', v_cad ->> 'sexo', (v_cad ->> 'batizado')::boolean,
      public.data_ou_nula(v_cad ->> 'data_batismo'), (v_cad ->> 'selado')::boolean, v_cad ->> 'ddd', v_cad ->> 'telefone',
      (v_cad ->> 'tem_whatsapp')::boolean, v_cad ->> 'whatsapp', v_cad ->> 'email',
      v_cad ->> 'cep', v_cad ->> 'endereco', v_cad ->> 'numero', v_cad ->> 'complemento', v_cad ->> 'uf',
      v_cad ->> 'cartao_numero', public.data_ou_nula(v_cad ->> 'cartao_emissao'),
      public.data_ou_nula(v_cad ->> 'cartao_validade'), v_obs, p_doc_frente, p_doc_verso);
  else
    select * into v_atual from public.membros m where m.id = v_membro and m.excluido_em is null for update;
    if not found then
      raise exception 'O membro deste pedido foi excluído. Recuse o pedido.' using errcode = '22023';
    end if;
    if v_atual.casa_oracao_id is not null and not public.casa_oracao_na_abrangencia(v_atual.casa_oracao_id) then
      raise exception 'O membro está em uma Casa de Oração fora da sua abrangência. Peça a quem tem acesso total.' using errcode = '42501';
    end if;
    select * into v_antigo_cad from public.membros_cadastro where membro_id = v_membro;
    v_antigos := jsonb_build_object('foto', v_atual.foto_path,
                                    'doc_frente', v_antigo_cad.documento_frente_path,
                                    'doc_verso', v_antigo_cad.documento_verso_path);

    update public.membros
       set nome = c.nome, casa_oracao_id = c.casa_oracao_id, cargo_id = c.cargo_id, instrumento_id = c.instrumento_id,
           categoria = c.categoria, cidade = c.cidade, bairro = c.bairro, foto_path = p_foto
     where id = v_membro;

    insert into public.membros_cadastro as mc (
      membro_id, estado_civil, sexo, batizado, data_batismo, selado, ddd, telefone, tem_whatsapp, whatsapp, email,
      cep, endereco, numero, complemento, uf, cartao_numero, cartao_emissao, cartao_validade, observacao,
      documento_frente_path, documento_verso_path)
    values (
      v_membro, v_cad ->> 'estado_civil', v_cad ->> 'sexo', (v_cad ->> 'batizado')::boolean,
      public.data_ou_nula(v_cad ->> 'data_batismo'), (v_cad ->> 'selado')::boolean, v_cad ->> 'ddd', v_cad ->> 'telefone',
      (v_cad ->> 'tem_whatsapp')::boolean, v_cad ->> 'whatsapp', v_cad ->> 'email',
      v_cad ->> 'cep', v_cad ->> 'endereco', v_cad ->> 'numero', v_cad ->> 'complemento', v_cad ->> 'uf',
      v_cad ->> 'cartao_numero', public.data_ou_nula(v_cad ->> 'cartao_emissao'),
      public.data_ou_nula(v_cad ->> 'cartao_validade'), v_obs, p_doc_frente, p_doc_verso)
    on conflict (membro_id) do update set
      estado_civil = excluded.estado_civil, sexo = excluded.sexo, batizado = excluded.batizado,
      data_batismo = excluded.data_batismo, selado = excluded.selado, ddd = excluded.ddd, telefone = excluded.telefone,
      tem_whatsapp = excluded.tem_whatsapp, whatsapp = excluded.whatsapp, email = excluded.email, cep = excluded.cep,
      endereco = excluded.endereco, numero = excluded.numero, complemento = excluded.complemento, uf = excluded.uf,
      cartao_numero = excluded.cartao_numero, cartao_emissao = excluded.cartao_emissao,
      cartao_validade = excluded.cartao_validade,
      -- menor de idade: acrescenta a anotação do responsável sem apagar a observação que já existia
      observacao = case when excluded.observacao is null then mc.observacao
                        when mc.observacao is null then excluded.observacao
                        else mc.observacao || E'\n' || excluded.observacao end,
      documento_frente_path = excluded.documento_frente_path, documento_verso_path = excluded.documento_verso_path,
      atualizado_em = now();
  end if;

  -- O pedido vira histórico: os dados já estão no membro, então saem daqui (guardamos só quem decidiu e quando)
  update public.cadastros_pendentes
     set status = 'APROVADO', membro_id = v_membro, decidido_em = now(), decidido_por = (select auth.uid()),
         dados = '{}'::jsonb, responsavel_nome = null, responsavel_telefone = null, ip_hash = null,
         arquivos_apagados_em = now()
   where id = p_id;

  perform public.registrar_auditoria('cadastro_aprovado', 'cadastro_pendente', p_id,
            jsonb_build_object('tipo', c.tipo, 'membro_id', v_membro, 'rotulo', c.nome));
  perform set_config('sysmusica.aprovando_cadastro', '', true);
  return jsonb_build_object('membro_id', v_membro, 'tipo', c.tipo, 'antigos', v_antigos);
end;
$$;

create or replace function public.rejeitar_cadastro_pendente(p_id uuid, p_motivo text)
returns void
language plpgsql security definer set search_path to 'public'
as $$
declare
  c       public.cadastros_pendentes%rowtype;
  v_motivo text := public.limpar_espacos(p_motivo);
begin
  perform public.exigir_permissao('cadastros.aprovar');
  if v_motivo is null or char_length(v_motivo) < 5 then
    raise exception 'Informe o motivo da recusa (pelo menos 5 letras).' using errcode = '22023';
  end if;
  if char_length(v_motivo) > 300 then
    raise exception 'O motivo pode ter no máximo 300 caracteres.' using errcode = '22023';
  end if;
  select * into c from public.cadastros_pendentes where id = p_id for update;
  if not found or not public.cadastro_pendente_visivel(c.casa_oracao_id, c.membro_id) then
    raise exception 'Cadastro não encontrado.' using errcode = 'P0002';
  end if;
  if c.status <> 'PENDENTE' then
    raise exception 'Este cadastro já foi analisado.' using errcode = '22023';
  end if;
  update public.cadastros_pendentes
     set status = 'REJEITADO', motivo_rejeicao = v_motivo, decidido_em = now(), decidido_por = (select auth.uid())
   where id = p_id;
  perform public.registrar_auditoria('cadastro_rejeitado', 'cadastro_pendente', p_id,
            jsonb_build_object('tipo', c.tipo, 'motivo', v_motivo, 'rotulo', c.nome));
end;
$$;

-- ---------------------------------------------------------------------------
-- 9. Quem pode chamar
-- ---------------------------------------------------------------------------
revoke all on function public.cargo_aceita_cadastro_publico(text) from public, anon, authenticated;
revoke all on function public.data_ou_nula(text) from public, anon, authenticated;
revoke all on function public.cpf_escondido(text) from public, anon, authenticated;
revoke all on function public.cadastro_publico_limite(text, text, integer, interval) from public, anon, authenticated;
revoke all on function public.cadastro_pendente_visivel(uuid, uuid) from public, anon, authenticated;
revoke all on function public.opcoes_cadastro_publico() from public, anon, authenticated;
revoke all on function public.iniciar_envio_publico(text) from public, anon, authenticated;
revoke all on function public.registrar_cadastro_publico(uuid, jsonb, text) from public, anon, authenticated;
revoke all on function public.limpeza_cadastro_publico() from public, anon, authenticated;
revoke all on function public.marcar_cadastros_limpos(uuid[], uuid[]) from public, anon, authenticated;
revoke all on function public.contar_cadastros_pendentes() from public, anon, authenticated;
revoke all on function public.listar_cadastros_pendentes(text) from public, anon, authenticated;
revoke all on function public.obter_cadastro_pendente(uuid) from public, anon, authenticated;
revoke all on function public.aprovar_cadastro_pendente(uuid, uuid, text, text, text) from public, anon, authenticated;
revoke all on function public.rejeitar_cadastro_pendente(uuid, text) from public, anon, authenticated;

-- Funções de apoio chamadas por outras funções (security definer) não precisam de grant; a data/CPF não vazam nada.
grant execute on function public.opcoes_cadastro_publico() to anon, authenticated;
grant execute on function public.iniciar_envio_publico(text) to service_role;
grant execute on function public.registrar_cadastro_publico(uuid, jsonb, text) to service_role;
grant execute on function public.limpeza_cadastro_publico() to service_role;
grant execute on function public.marcar_cadastros_limpos(uuid[], uuid[]) to service_role;
grant execute on function public.contar_cadastros_pendentes() to authenticated;
grant execute on function public.listar_cadastros_pendentes(text) to authenticated;
grant execute on function public.obter_cadastro_pendente(uuid) to authenticated;
grant execute on function public.aprovar_cadastro_pendente(uuid, uuid, text, text, text) to authenticated;
grant execute on function public.rejeitar_cadastro_pendente(uuid, text) to authenticated;

-- ---------------------------------------------------------------------------
-- 10. Backup: a função de restauração passa a aceitar cadastros_pendentes e membros_cadastro
--     (cópia da versão da migração 0041 com duas linhas novas na lista permitida)
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
      ('cadastros_pendentes', array['id'],                              false, false, ''),
      ('membros_cadastro',    array['membro_id'],                       false, false, ''),
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
  if to_regclass('public.cadastros_pendentes') is null
     or (select count(*) from public.permissoes where codigo in ('cadastros.visualizar', 'cadastros.aprovar')) <> 2
     or not exists (select 1 from storage.buckets where id = 'cadastro-publico' and not public)
     or to_regprocedure('public.aprovar_cadastro_pendente(uuid, uuid, text, text, text)') is null
     or to_regprocedure('public.opcoes_cadastro_publico()') is null then
    raise exception 'Teste falhou: objetos da Parte 9 ausentes. Nada foi alterado.';
  end if;
  raise notice 'OK: cadastro público e fila de cadastros pendentes instalados.';
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
  if "$@" > /tmp/p9-passo.out 2>&1; then
    echo "  ok"
  else
    echo "  FALHOU: $nome"; tail -40 /tmp/p9-passo.out
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
echo "Lembrete: o SQL 0042 precisa ter sido rodado no Supabase ANTES de testar as telas (e as variáveis do Turnstile configuradas)."
echo "Depois confira as telas (passo a passo na conversa) e, se estiver tudo certo, faça o git push."
) 2>&1 | tee "$LOG"
