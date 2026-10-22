"use client";

/**
 * Sysmusica — Página /administracao/auditoria: tudo o que foi feito no sistema (quem, quando, o quê e
 * o antes e o depois), com filtros, impressão e exportação CSV. Imprimir e exportar ficam registrados
 * na própria auditoria. Só quem tem a permissão auditoria.visualizar entra (o banco confere).
 */
import { useCallback, useEffect, useState, type FormEvent } from "react";
import { Download, Printer } from "lucide-react";
import { useSessao } from "@/modules/autenticacao/SessaoProvider";
import DetalheAuditoria from "@/modules/auditoria/components/DetalheAuditoria";
import TabelaAuditoria from "@/modules/auditoria/components/TabelaAuditoria";
import {
  resumoAlteracoes,
  rotuloAcao,
  rotuloDoItem,
  rotuloEntidade,
} from "@/modules/auditoria/regras";
import { listarAuditoria, listarOpcoesAuditoria, registrarUso } from "@/modules/auditoria/services/auditoria";
import type { FiltrosAuditoria, LinhaAuditoria, OpcoesAuditoria } from "@/modules/auditoria/tipos";
import Drawer from "@/components/ui/Drawer";
import EmptyState from "@/components/ui/EmptyState";
import ErrorState from "@/components/ui/ErrorState";
import Notificacao from "@/components/ui/Notificacao";
import PageHeader from "@/components/ui/PageHeader";
import Skeleton from "@/components/ui/Skeleton";
import { formatarDataHora } from "@/lib/datas";
import { baixarCsv, gerarCsv, imprimirTabela } from "@/lib/exportacao";

const TAMANHO_PAGINA = 50;
const LIMITE_SAIDA = 2000; // máximo de registros por impressão ou exportação

// Data de hoje (ou deslocada em dias) no formato AAAA-MM-DD, no fuso do navegador
function dataIso(deslocamentoDias = 0): string {
  return new Date(Date.now() + deslocamentoDias * 86_400_000).toLocaleDateString("sv-SE");
}

const filtrosIniciais = (): FiltrosAuditoria => ({
  inicio: dataIso(-6),
  fim: dataIso(0),
  usuarioId: "",
  entidade: "",
  acao: "",
  busca: "",
});

const classeCampo =
  "w-full rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 shadow-sm " +
  "focus:border-brand-500 focus:outline-none focus:ring-2 focus:ring-brand-200 [color-scheme:light]";

const classeBotao =
  "inline-flex items-center gap-2 rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm font-medium " +
  "text-slate-700 transition hover:bg-slate-50 disabled:cursor-not-allowed disabled:opacity-60";

export default function AuditoriaPage() {
  const { conta } = useSessao();

  const [formulario, setFormulario] = useState<FiltrosAuditoria>(filtrosIniciais);
  const [aplicados, setAplicados] = useState<FiltrosAuditoria>(filtrosIniciais);
  const [pagina, setPagina] = useState(0);
  const [opcoes, setOpcoes] = useState<OpcoesAuditoria | null>(null);
  const [linhas, setLinhas] = useState<LinhaAuditoria[]>([]);
  const [total, setTotal] = useState(0);
  const [carregando, setCarregando] = useState(true); // inicia true: primeira busca no mount
  const [erro, setErro] = useState<string | null>(null);
  const [erroFiltro, setErroFiltro] = useState<string | null>(null);
  const [selecionada, setSelecionada] = useState<LinhaAuditoria | null>(null);
  const [saindo, setSaindo] = useState(false);
  const [erroSaida, setErroSaida] = useState<string | null>(null);
  const [aviso, setAviso] = useState<string | null>(null);

  // Busca a página atual do filtro aplicado
  const carregar = useCallback(async () => {
    try {
      const resultado = await listarAuditoria(aplicados, TAMANHO_PAGINA, pagina * TAMANHO_PAGINA);
      setLinhas(resultado.linhas);
      setTotal(resultado.total);
      setErro(null);
    } catch (e) {
      console.error("Falha ao carregar a auditoria:", e);
      setErro(e instanceof Error ? e.message : "Não foi possível carregar a auditoria.");
    } finally {
      setCarregando(false);
    }
  }, [aplicados, pagina]);

  // Primeira carga e recarga quando o filtro ou a página mudam
  useEffect(() => {
    // O setState só roda DEPOIS do await (nunca de forma síncrona). Ignorado apenas nesta linha.
    // eslint-disable-next-line react-hooks/set-state-in-effect
    void carregar();
  }, [carregar]);

  // Opções dos filtros (uma vez)
  useEffect(() => {
    let cancelado = false;
    void listarOpcoesAuditoria()
      .then((lista) => {
        if (!cancelado) setOpcoes(lista);
      })
      .catch(() => {
        if (!cancelado) setOpcoes({ usuarios: [], entidades: [], acoes: [] });
      });
    return () => {
      cancelado = true;
    };
  }, []);

  function aplicarFiltros(submissao: FormEvent<HTMLFormElement>) {
    submissao.preventDefault();
    setErroFiltro(null);
    if (formulario.inicio && formulario.fim && formulario.inicio > formulario.fim) {
      return setErroFiltro("A data inicial não pode ser depois da data final.");
    }
    setCarregando(true);
    setPagina(0);
    setAplicados(formulario);
  }

  function limparFiltros() {
    const novos = filtrosIniciais();
    setErroFiltro(null);
    setFormulario(novos);
    setCarregando(true);
    setPagina(0);
    setAplicados(novos);
  }

  function irParaPagina(nova: number) {
    setCarregando(true);
    setPagina(nova);
  }

  // Imprime ou exporta TODOS os registros do filtro (até o limite). Antes, registra o uso na auditoria.
  async function gerarSaida(tipo: "impressao" | "csv") {
    if (saindo) return;
    setSaindo(true);
    setErroSaida(null);
    try {
      const { linhas: todas, total: totalGeral } = await listarAuditoria(aplicados, LIMITE_SAIDA, 0);
      if (todas.length === 0) {
        setErroSaida("Não há registros para este filtro.");
        return;
      }

      await registrarUso(tipo === "impressao" ? "auditoria_impressa" : "auditoria_exportada", {
        filtros: aplicados,
        quantidade: todas.length,
      });

      const colunas = ["Data e hora", "Usuário", "Ação", "Item", "Alterações"];
      const dados = todas.map((linha) => [
        formatarDataHora(linha.ocorrido_em),
        linha.usuario_nome ?? "Sistema",
        rotuloAcao(linha.acao),
        rotuloDoItem(linha),
        resumoAlteracoes(linha.detalhes),
      ]);

      if (tipo === "csv") {
        baixarCsv(`auditoria-${dataIso(0)}.csv`, gerarCsv(colunas, dados));
      } else {
        const periodo = `${aplicados.inicio || "início"} a ${aplicados.fim || "hoje"}`;
        const aberta = imprimirTabela({
          titulo: "Auditoria do sistema",
          subtitulo: `Período: ${periodo} · emitido por ${conta?.nome ?? "usuário"}`,
          colunas,
          linhas: dados,
          orientacao: "paisagem",
        });
        if (!aberta) {
          setErroSaida("O navegador bloqueou a janela de impressão. Libere os pop-ups deste site e tente de novo.");
          return;
        }
      }

      setAviso(
        totalGeral > todas.length
          ? `Foram incluídos os ${todas.length} registros mais recentes de ${totalGeral}. Refine o período para ver o restante.`
          : "Pronto. Esta ação ficou registrada na auditoria."
      );
    } catch (e) {
      setErroSaida(e instanceof Error ? e.message : "Não foi possível gerar a saída.");
    } finally {
      setSaindo(false);
    }
  }

  const totalPaginas = Math.max(1, Math.ceil(total / TAMANHO_PAGINA));

  const entidadesOrdenadas = [...(opcoes?.entidades ?? [])].sort((a, b) =>
    rotuloEntidade(a).localeCompare(rotuloEntidade(b), "pt-BR")
  );
  const acoesOrdenadas = [...(opcoes?.acoes ?? [])].sort((a, b) => rotuloAcao(a).localeCompare(rotuloAcao(b), "pt-BR"));
  const usuariosOrdenados = [...(opcoes?.usuarios ?? [])].sort((a, b) => a.nome.localeCompare(b.nome, "pt-BR"));

  return (
    <main className="text-slate-900">
      <div className="mx-auto max-w-7xl px-4 py-8 sm:px-6 lg:px-8">
        <PageHeader
          titulo="Auditoria"
          descricao={`Tudo o que foi feito no sistema: quem, quando e o quê.${
            !carregando && !erro ? ` ${total} registro(s) neste filtro.` : ""
          }`}
          acoes={
            <>
              <button type="button" className={classeBotao} onClick={() => void gerarSaida("impressao")} disabled={saindo || carregando || !!erro}>
                <Printer className="h-4 w-4" aria-hidden="true" />
                Imprimir
              </button>
              <button type="button" className={classeBotao} onClick={() => void gerarSaida("csv")} disabled={saindo || carregando || !!erro}>
                <Download className="h-4 w-4" aria-hidden="true" />
                Exportar CSV
              </button>
            </>
          }
        />

        {/* Filtros */}
        <form onSubmit={aplicarFiltros} className="mb-6 rounded-2xl border border-slate-200 bg-white p-4 shadow-sm">
          <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
            <div className="space-y-1.5">
              <label htmlFor="filtro-inicio" className="text-xs font-medium text-slate-600">De</label>
              <input
                id="filtro-inicio"
                type="date"
                value={formulario.inicio}
                onChange={(e) => setFormulario({ ...formulario, inicio: e.target.value })}
                className={classeCampo}
              />
            </div>
            <div className="space-y-1.5">
              <label htmlFor="filtro-fim" className="text-xs font-medium text-slate-600">Até</label>
              <input
                id="filtro-fim"
                type="date"
                value={formulario.fim}
                onChange={(e) => setFormulario({ ...formulario, fim: e.target.value })}
                className={classeCampo}
              />
            </div>
            <div className="space-y-1.5">
              <label htmlFor="filtro-usuario" className="text-xs font-medium text-slate-600">Usuário</label>
              <select
                id="filtro-usuario"
                value={formulario.usuarioId}
                onChange={(e) => setFormulario({ ...formulario, usuarioId: e.target.value })}
                className={classeCampo}
              >
                <option value="">Todos</option>
                {usuariosOrdenados.map((usuario) => (
                  <option key={usuario.id} value={usuario.id}>{usuario.nome}</option>
                ))}
              </select>
            </div>
            <div className="space-y-1.5">
              <label htmlFor="filtro-entidade" className="text-xs font-medium text-slate-600">Tipo de item</label>
              <select
                id="filtro-entidade"
                value={formulario.entidade}
                onChange={(e) => setFormulario({ ...formulario, entidade: e.target.value })}
                className={classeCampo}
              >
                <option value="">Todos</option>
                {entidadesOrdenadas.map((entidade) => (
                  <option key={entidade} value={entidade}>{rotuloEntidade(entidade)}</option>
                ))}
              </select>
            </div>
            <div className="space-y-1.5">
              <label htmlFor="filtro-acao" className="text-xs font-medium text-slate-600">Ação</label>
              <select
                id="filtro-acao"
                value={formulario.acao}
                onChange={(e) => setFormulario({ ...formulario, acao: e.target.value })}
                className={classeCampo}
              >
                <option value="">Todas</option>
                {acoesOrdenadas.map((acao) => (
                  <option key={acao} value={acao}>{rotuloAcao(acao)}</option>
                ))}
              </select>
            </div>
            <div className="space-y-1.5">
              <label htmlFor="filtro-busca" className="text-xs font-medium text-slate-600">Buscar no texto</label>
              <input
                id="filtro-busca"
                type="search"
                autoComplete="off"
                value={formulario.busca}
                onChange={(e) => setFormulario({ ...formulario, busca: e.target.value })}
                placeholder="Nome, valor alterado..."
                className={classeCampo}
              />
            </div>
          </div>

          {erroFiltro && (
            <p role="alert" className="mt-3 rounded-lg bg-red-50 px-3 py-2 text-sm text-red-700">{erroFiltro}</p>
          )}

          <div className="mt-4 flex flex-wrap gap-2">
            <button
              type="submit"
              className="rounded-lg bg-brand-600 px-4 py-2 text-sm font-semibold text-white shadow-sm transition hover:bg-brand-700"
            >
              Aplicar filtros
            </button>
            <button type="button" className={classeBotao} onClick={limparFiltros}>
              Últimos 7 dias
            </button>
          </div>
        </form>

        {erroSaida && (
          <p role="alert" className="mb-4 rounded-lg bg-red-50 px-3 py-2 text-sm text-red-700">{erroSaida}</p>
        )}

        {carregando ? (
          <div role="status" aria-live="polite" className="space-y-3">
            <span className="sr-only">Carregando a auditoria...</span>
            {[0, 1, 2, 3, 4].map((i) => (
              <Skeleton key={i} className="h-12" />
            ))}
          </div>
        ) : erro ? (
          <ErrorState
            titulo="Não foi possível carregar a auditoria."
            mensagem={erro}
            onTentarNovamente={() => {
              setCarregando(true);
              void carregar();
            }}
          />
        ) : linhas.length === 0 ? (
          <EmptyState titulo="Nenhum registro neste filtro." descricao="Mude o período ou os filtros e aplique de novo." />
        ) : (
          <>
            <TabelaAuditoria linhas={linhas} onDetalhes={setSelecionada} />

            <div className="mt-4 flex flex-wrap items-center justify-between gap-3 text-sm text-slate-600">
              <span>
                Página {pagina + 1} de {totalPaginas}
              </span>
              <div className="flex gap-2">
                <button type="button" className={classeBotao} onClick={() => irParaPagina(pagina - 1)} disabled={pagina === 0}>
                  Anterior
                </button>
                <button
                  type="button"
                  className={classeBotao}
                  onClick={() => irParaPagina(pagina + 1)}
                  disabled={pagina + 1 >= totalPaginas}
                >
                  Próxima
                </button>
              </div>
            </div>
          </>
        )}
      </div>

      <Drawer
        aberto={selecionada !== null}
        onFechar={() => setSelecionada(null)}
        titulo="Detalhes do registro"
        descricao={selecionada ? rotuloAcao(selecionada.acao) : undefined}
      >
        {selecionada && <DetalheAuditoria linha={selecionada} />}
      </Drawer>

      <Notificacao mensagem={aviso} onFechar={() => setAviso(null)} />
    </main>
  );
}
