"use client";

/**
 * SysMúsica — Página /relatorios: monta, visualiza, imprime e exporta relatórios.
 * Passos: 1) tipo, 2) filtros, 3) colunas e ordem, 4) página (orientação e ajuste automático ou manual),
 * 5) resultado com prévia, pré-visualização da página, impressão (ou PDF pelo navegador) e CSV.
 *
 * O banco entrega só o que a REGIÃO do usuário permite. Imprimir e exportar ficam registrados na Auditoria.
 * A janela de impressão é aberta já no clique, antes das esperas, para o navegador não bloqueá-la.
 */
import { useEffect, useMemo, useState } from "react";
import { Download, Eye, Printer } from "lucide-react";
import Notificacao from "@/components/ui/Notificacao";
import PageHeader from "@/components/ui/PageHeader";
import { abrirJanelaImpressao, baixarCsv, escreverImpressao, gerarCsv } from "@/lib/exportacao";
import { useSessao } from "@/modules/autenticacao/SessaoProvider";
import { registrarUso } from "@/modules/auditoria/services/auditoria";
import { DEFINICOES_RELATORIO } from "@/modules/relatorios/catalogo";
import FiltrosDoRelatorio from "@/modules/relatorios/components/FiltrosDoRelatorio";
import OpcoesDaPagina from "@/modules/relatorios/components/OpcoesDaPagina";
import PreviaRelatorio from "@/modules/relatorios/components/PreviaRelatorio";
import SelecaoColunas from "@/modules/relatorios/components/SelecaoColunas";
import {
  colunasEscolhidas,
  colunasVisiveis,
  FILTROS_VAZIOS,
  agoraEmSalvador,
  itensCabecalhoDisponiveis,
  lerAjusteManual,
  lerAssinaturas,
  margemEmMm,
  montarInformacoes,
  montarItensRodape,
  NOME_DO_SISTEMA,
  marcadasIniciais,
  montarTabela,
  moverColuna,
  nomeDoArquivo,
  PAGINA_INICIAL,
  // (o resumo dos filtros agora vem de montarInformacoes)
  rotulosDosFiltros,
  tiposDisponiveis,
  validarAjusteManual,
  validarFiltros,
} from "@/modules/relatorios/regras";
import { buscarRelatorio, carregarOpcoesRelatorio, LIMITE_LINHAS } from "@/modules/relatorios/services/relatorios";
import type {
  DefinicaoRelatorio,
  FiltrosRelatorio,
  OpcoesFiltros,
  OpcoesPagina,
  ResultadoRelatorio,
  TipoRelatorioId,
} from "@/modules/relatorios/tipos";

type ResultadoGerado = ResultadoRelatorio & { tipo: TipoRelatorioId; filtros: FiltrosRelatorio };

// Data de hoje (ou deslocada em dias) no formato AAAA-MM-DD, no fuso do navegador
function dataIso(deslocamentoDias = 0): string {
  return new Date(Date.now() + deslocamentoDias * 86_400_000).toLocaleDateString("sv-SE");
}

const classeBotao =
  "inline-flex items-center gap-2 rounded-lg border border-slate-300 bg-white px-4 py-2 text-sm font-medium " +
  "text-slate-700 transition hover:bg-slate-50 disabled:cursor-not-allowed disabled:opacity-60";

const classeBotaoPrimario =
  "inline-flex items-center gap-2 rounded-lg bg-brand-600 px-4 py-2 text-sm font-semibold text-white shadow-sm " +
  "transition hover:bg-brand-700 disabled:cursor-not-allowed disabled:opacity-60";

const classeSecao = "rounded-2xl border border-slate-200 bg-white p-5 shadow-sm";

export default function RelatoriosPage() {
  const { pode, conta } = useSessao();

  const [tipoId, setTipoId] = useState<TipoRelatorioId | "">("");
  const [filtros, setFiltros] = useState<FiltrosRelatorio>(FILTROS_VAZIOS);
  const [opcoes, setOpcoes] = useState<OpcoesFiltros | null>(null);
  const [ordem, setOrdem] = useState<string[]>([]);
  const [marcadas, setMarcadas] = useState<Set<string>>(new Set());
  const [pagina, setPagina] = useState<OpcoesPagina>(PAGINA_INICIAL);
  const [resultado, setResultado] = useState<ResultadoGerado | null>(null);
  const [gerando, setGerando] = useState(false);
  const [saindo, setSaindo] = useState(false);
  const [erro, setErro] = useState<string | null>(null);
  const [aviso, setAviso] = useState<string | null>(null);

  // Listas dos filtros (uma vez): organização, cargos, instrumentos e eventos que o usuário pode ver
  /* eslint-disable react-hooks/set-state-in-effect */
  useEffect(() => {
    let cancelado = false;
    void carregarOpcoesRelatorio()
      .then((lista) => {
        if (!cancelado) setOpcoes(lista);
      })
      .catch(() => {
        if (!cancelado) setOpcoes({ organizacao: [], cargos: [], instrumentos: [], eventos: [] });
      });
    return () => {
      cancelado = true;
    };
  }, []);
  /* eslint-enable react-hooks/set-state-in-effect */

  const disponiveis = useMemo(() => tiposDisponiveis(DEFINICOES_RELATORIO, pode), [pode]);
  const definicao = useMemo(
    () => disponiveis.find((item) => item.id === tipoId) ?? null,
    [disponiveis, tipoId]
  );
  const colunasVis = useMemo(() => (definicao ? colunasVisiveis(definicao, pode) : []), [definicao, pode]);
  const escolhidas = useMemo(
    () => colunasEscolhidas(ordem, marcadas).filter((id) => colunasVis.some((coluna) => coluna.id === id)),
    [ordem, marcadas, colunasVis]
  );
  const tabela = useMemo(
    () => (resultado && definicao && escolhidas.length > 0 ? montarTabela(definicao, escolhidas, resultado.linhas) : null),
    [resultado, definicao, escolhidas]
  );

  // Escolher o tipo: zera filtros, resultado e colunas (marca as padrão) e sugere o título
  function escolherTipo(nova: DefinicaoRelatorio) {
    const visiveis = colunasVisiveis(nova, pode);
    // Tipos com período começam nos últimos 30 dias, para não trazer tudo de uma vez
    const inicial: FiltrosRelatorio = nova.filtros.includes("periodo")
      ? { ...FILTROS_VAZIOS, inicio: dataIso(-30), fim: dataIso(0) }
      : FILTROS_VAZIOS;

    setTipoId(nova.id);
    setFiltros(inicial);
    setOrdem(visiveis.map((coluna) => coluna.id));
    setMarcadas(marcadasIniciais(visiveis));
    setPagina((atual) => ({ ...atual, titulo: nova.titulo }));
    setResultado(null);
    setErro(null);
  }

  // Mudar um filtro invalida o resultado já gerado (é preciso gerar de novo)
  function mudarFiltros(novos: FiltrosRelatorio) {
    setFiltros(novos);
    setResultado(null);
  }

  function alternarColuna(id: string) {
    setMarcadas((anterior) => {
      const novas = new Set(anterior);
      if (novas.has(id)) novas.delete(id);
      else novas.add(id);
      return novas;
    });
  }

  async function gerar() {
    if (!definicao || gerando) return;
    setErro(null);

    const erroFiltro = validarFiltros(definicao, filtros);
    if (erroFiltro) return setErro(erroFiltro);

    setGerando(true);
    try {
      const dados = await buscarRelatorio(definicao.id, filtros);
      setResultado({ ...dados, tipo: definicao.id, filtros });
    } catch (e) {
      setResultado(null);
      setErro(e instanceof Error ? e.message : "Não foi possível gerar o relatório.");
    } finally {
      setGerando(false);
    }
  }

  // Pré-visualizar a página, imprimir ou exportar CSV
  async function gerarSaida(modo: "previa" | "impressao" | "csv") {
    if (!resultado || !definicao || !tabela || saindo) return;
    setErro(null);

    if (escolhidas.length === 0) return setErro("Marque pelo menos uma coluna.");
    if (pagina.ajuste === "manual") {
      const erroManual = validarAjusteManual(pagina.escala, pagina.fonte);
      if (erroManual) return setErro(erroManual);
    }

    // A janela é aberta já no clique, antes das esperas, para o navegador não bloqueá-la como pop-up
    const janela = modo === "csv" ? null : abrirJanelaImpressao();
    if (modo !== "csv" && !janela) {
      return setErro("O navegador bloqueou a janela. Libere os pop-ups deste site e tente de novo.");
    }

    setSaindo(true);
    try {
      // Imprimir e exportar ficam registrados na auditoria (a pré-visualização não)
      if (modo !== "previa") {
        await registrarUso(modo === "impressao" ? "relatorio_impresso" : "relatorio_exportado", {
          tipo: definicao.id,
          filtros: resultado.filtros,
          colunas: escolhidas,
          quantidade: tabela.linhas.length,
        });
      }

      const titulo = pagina.titulo.trim() || definicao.titulo;

      if (modo === "csv") {
        baixarCsv(`${nomeDoArquivo(titulo, dataIso(0))}.csv`, gerarCsv(tabela.colunas, tabela.linhas));
        setAviso("Arquivo baixado. Esta ação ficou registrada na auditoria.");
      } else if (janela) {
        const geradoEm = agoraEmSalvador();
        const emitidoPor = conta?.nome ?? "usuário";
        const informacoes = montarInformacoes({
          definicao,
          filtros: resultado.filtros,
          rotulos: rotulosDosFiltros(resultado.filtros, opcoes),
          itens: pagina.cabecalho,
          emitidoPor,
          geradoEm,
          linhas: resultado.linhas,
          total: tabela.linhas.length,
        });
        const rodapeItens = montarItensRodape({
          itens: pagina.rodapeMarcado,
          textoLivre: pagina.rodape,
          emitidoPor,
          geradoEm,
          total: tabela.linhas.length,
        });
        const manual = pagina.ajuste === "manual" ? lerAjusteManual(pagina.escala, pagina.fonte) : null;
        escreverImpressao(janela, {
          titulo,
          subtitulo: pagina.subtitulo.trim() || undefined,
          informacoes,
          rodapeItens,
          marca: pagina.cabecalho.marca ? NOME_DO_SISTEMA : undefined,
          paginacao: pagina.rodapeMarcado.paginacao,
          assinaturas: lerAssinaturas(pagina.assinaturas, pagina.nomesAssinaturas),
          margem: margemEmMm(pagina.margem),
          geradoEm,
          colunas: tabela.colunas,
          linhas: tabela.linhas,
          orientacao: pagina.orientacao,
          escala: manual?.escala,
          tamanhoFonte: manual?.tamanhoFonte,
          // (o texto livre do rodapé entra em rodapeItens)
          abrirImpressao: modo === "impressao",
        });
        setAviso(
          modo === "impressao"
            ? "Janela de impressão aberta. Esta ação ficou registrada na auditoria."
            : "Pré-visualização aberta em outra janela. Use o botão Imprimir dela quando estiver certo."
        );
      }
    } catch (e) {
      janela?.close();
      setErro(e instanceof Error ? e.message : "Não foi possível gerar a saída.");
    } finally {
      setSaindo(false);
    }
  }

  const truncado = resultado !== null && resultado.total > resultado.linhas.length;

  return (
    <main className="text-slate-900">
      <div className="mx-auto max-w-6xl px-4 py-8 sm:px-6 lg:px-8">
        <PageHeader
          titulo="Relatórios"
          descricao="Monte, visualize, imprima ou exporte. Cada pessoa recebe só o que a sua região permite."
        />

        {erro && (
          <p role="alert" className="mb-4 rounded-lg bg-red-50 px-3 py-2 text-sm text-red-700">
            {erro}
          </p>
        )}

        {disponiveis.length === 0 ? (
          <p className="rounded-lg bg-amber-50 px-3 py-2 text-sm text-amber-700">
            Você não tem acesso a nenhum tipo de relatório. Peça a um administrador para liberar a permissão de
            ver os dados correspondentes.
          </p>
        ) : (
          <div className="space-y-6">
            {/* 1) Tipo */}
            <section className={classeSecao}>
              <h2 className="text-sm font-semibold text-slate-900">1. Tipo de relatório</h2>
              <ul className="mt-3 grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
                {disponiveis.map((item) => (
                  <li key={item.id}>
                    <button
                      type="button"
                      onClick={() => escolherTipo(item)}
                      aria-pressed={item.id === tipoId}
                      className={
                        "h-full w-full rounded-xl border p-3 text-left transition focus:outline-none focus-visible:ring-2 focus-visible:ring-brand-300 " +
                        (item.id === tipoId
                          ? "border-brand-500 bg-brand-50"
                          : "border-slate-200 bg-white hover:bg-slate-50")
                      }
                    >
                      <span className="block text-sm font-semibold text-slate-900">{item.titulo}</span>
                      <span className="mt-1 block text-xs text-slate-500">{item.descricao}</span>
                    </button>
                  </li>
                ))}
              </ul>
            </section>

            {definicao && (
              <>
                {/* 2) Filtros */}
                <section className={classeSecao}>
                  <h2 className="mb-3 text-sm font-semibold text-slate-900">2. Filtros</h2>
                  <FiltrosDoRelatorio
                    campos={definicao.filtros}
                    valores={filtros}
                    onChange={mudarFiltros}
                    opcoes={opcoes}
                    desabilitado={gerando}
                  />
                  <div className="mt-4">
                    <button type="button" className={classeBotaoPrimario} onClick={() => void gerar()} disabled={gerando}>
                      {gerando ? "Gerando..." : "Gerar relatório"}
                    </button>
                  </div>
                </section>

                {/* 3) Colunas */}
                <section className={classeSecao}>
                  <h2 className="mb-3 text-sm font-semibold text-slate-900">3. Colunas e ordem</h2>
                  <SelecaoColunas
                    colunas={colunasVis}
                    ordem={ordem}
                    marcadas={marcadas}
                    onAlternar={alternarColuna}
                    onMover={(id, direcao) => setOrdem((atual) => moverColuna(atual, id, direcao))}
                    onPadrao={() => setMarcadas(marcadasIniciais(colunasVis))}
                    onTodas={() => setMarcadas(new Set(colunasVis.map((coluna) => coluna.id)))}
                    onNenhuma={() => setMarcadas(new Set())}
                  />
                </section>

                {/* 4) Página */}
                <section className={classeSecao}>
                  <h2 className="mb-3 text-sm font-semibold text-slate-900">4. Página</h2>
                  <OpcoesDaPagina
                    valores={pagina}
                    onChange={setPagina}
                    itensCabecalho={itensCabecalhoDisponiveis(definicao)}
                  />
                </section>

                {/* 5) Resultado */}
                <section className={classeSecao}>
                  <h2 className="mb-3 text-sm font-semibold text-slate-900">5. Resultado</h2>

                  {!resultado ? (
                    <p className="text-sm text-slate-500">
                      Escolha os filtros e clique em “Gerar relatório” para buscar os dados.
                    </p>
                  ) : (
                    <div className="space-y-4">
                      <p className="text-sm text-slate-600">
                        {resultado.total} registro(s) neste filtro.
                        {truncado && (
                          <span className="ml-1 text-amber-700">
                            Foram trazidos os {LIMITE_LINHAS} primeiros: refine o período ou os filtros para ver o
                            restante.
                          </span>
                        )}
                      </p>

                      {escolhidas.length === 0 ? (
                        <p className="rounded-lg bg-amber-50 px-3 py-2 text-sm text-amber-700">
                          Marque pelo menos uma coluna no passo 3.
                        </p>
                      ) : (
                        tabela && <PreviaRelatorio colunas={tabela.colunas} linhas={tabela.linhas} />
                      )}

                      <div className="flex flex-wrap gap-2">
                        <button
                          type="button"
                          className={classeBotao}
                          onClick={() => void gerarSaida("previa")}
                          disabled={saindo || !tabela || resultado.linhas.length === 0}
                        >
                          <Eye className="h-4 w-4" aria-hidden="true" />
                          Pré-visualizar página
                        </button>
                        <button
                          type="button"
                          className={classeBotaoPrimario}
                          onClick={() => void gerarSaida("impressao")}
                          disabled={saindo || !tabela || resultado.linhas.length === 0}
                        >
                          <Printer className="h-4 w-4" aria-hidden="true" />
                          Imprimir
                        </button>
                        <button
                          type="button"
                          className={classeBotao}
                          onClick={() => void gerarSaida("csv")}
                          disabled={saindo || !tabela || resultado.linhas.length === 0}
                        >
                          <Download className="h-4 w-4" aria-hidden="true" />
                          Exportar CSV
                        </button>
                      </div>
                      <p className="text-xs text-slate-500">
                        Para gerar PDF, clique em Imprimir e, em Destino, escolha “Salvar como PDF”.
                      </p>
                    </div>
                  )}
                </section>
              </>
            )}
          </div>
        )}
      </div>

      <Notificacao mensagem={aviso} onFechar={() => setAviso(null)} />
    </main>
  );
}
