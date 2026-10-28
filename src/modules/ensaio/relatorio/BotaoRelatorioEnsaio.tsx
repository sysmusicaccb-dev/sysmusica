"use client";

/**
 * Sysmusica — Botão "Relatório do Ensaio": abre a folha (A4 paisagem) num painel, com os dados reais do banco,
 * e imprime exatamente o que está na tela. Imprimir fica registrado na Auditoria.
 * A janela de impressão é aberta já no clique (antes das esperas), para o navegador não bloqueá-la.
 */
import { useRef, useState } from "react";
import { FileBarChart, Printer } from "lucide-react";
import Drawer from "@/components/ui/Drawer";
import { abrirJanelaImpressao } from "@/lib/exportacao";
import { MARCA } from "@/lib/marca";
import { registrarUso } from "@/modules/auditoria/services/auditoria";
import { useSessao } from "@/modules/autenticacao/SessaoProvider";
import { agoraEmSalvador } from "@/modules/relatorios/regras";
import { montarHtmlRelatorio } from "./impressaoFolha";
import { montarModeloRelatorio, type ModeloRelatorio } from "./modelo";
import RelatorioEnsaioFolha, { ALTURA_FOLHA, LARGURA_FOLHA } from "./RelatorioEnsaioFolha";
import { buscarRelatorioEnsaio } from "./services";

interface Props {
  eventoId: string | null;
  className?: string;
}

const ESCALA_TELA = 0.78; // a folha de 1280 px cabe no painel largo

const classePadrao =
  "inline-flex items-center gap-1.5 rounded-lg border border-slate-300 bg-white px-3 py-1.5 text-sm font-medium text-slate-700 shadow-sm hover:bg-slate-50 focus:outline-none focus:ring-2 focus:ring-brand-200 disabled:cursor-not-allowed disabled:opacity-60";

export default function BotaoRelatorioEnsaio({ eventoId, className }: Props) {
  const { conta, pode } = useSessao();
  const [aberto, setAberto] = useState(false);
  const [carregando, setCarregando] = useState(false);
  const [imprimindo, setImprimindo] = useState(false);
  const [modelo, setModelo] = useState<ModeloRelatorio | null>(null);
  const [erro, setErro] = useState<string | null>(null);
  const folhaRef = useRef<HTMLDivElement>(null);

  async function abrir() {
    if (!eventoId) return;
    setAberto(true);
    setCarregando(true);
    setErro(null);
    setModelo(null);
    try {
      const resposta = await buscarRelatorioEnsaio(eventoId);
      setModelo(montarModeloRelatorio(resposta, { emitidoPor: conta?.nome ?? "usuário", geradoEm: agoraEmSalvador(), marca: MARCA.nome }));
    } catch (e) {
      setErro(e instanceof Error ? e.message : "Não foi possível montar o relatório.");
    } finally {
      setCarregando(false);
    }
  }

  async function imprimir() {
    const folha = folhaRef.current?.querySelector("[data-folha-relatorio]");
    if (!folha || !modelo || !eventoId || imprimindo) return;
    const janela = abrirJanelaImpressao(); // no clique, antes das esperas
    if (!janela) {
      setErro("O navegador bloqueou a janela de impressão. Permita pop-ups para este site e tente de novo.");
      return;
    }
    setImprimindo(true);
    setErro(null);
    try {
      await registrarUso("relatorio_impresso", { tipo: "relatorio_ensaio", evento_id: eventoId });
      janela.document.open();
      janela.document.write(montarHtmlRelatorio(`${modelo.titulo} — ${modelo.subtitulo}`, folha.outerHTML));
      janela.document.close();
      // O opener chama a impressão (a página impressa não tem script); espera o desenho terminar
      window.setTimeout(() => {
        janela.focus();
        janela.print();
      }, 400);
    } catch (e) {
      janela.close();
      setErro(e instanceof Error ? e.message : "Não foi possível imprimir.");
    } finally {
      setImprimindo(false);
    }
  }

  // Só quem pode ver o Painel ou os Relatórios (o banco confere de novo, inclusive a região)
  if (!pode("painel.visualizar") && !pode("relatorios.visualizar")) return null;

  return (
    <>
      <button type="button" onClick={() => void abrir()} disabled={!eventoId} className={className ?? classePadrao}>
        <FileBarChart className="h-4 w-4" aria-hidden="true" />
        Relatório do Ensaio
      </button>

      <Drawer
        aberto={aberto}
        titulo="Relatório do Ensaio"
        descricao="Folha A4 paisagem com os números reais do ensaio. A impressão sai igual a esta tela."
        onFechar={() => setAberto(false)}
        larguraMaxima="max-w-6xl"
      >
        <div className="space-y-4 p-4">
          {carregando && <p className="text-sm text-slate-500">Montando o relatório...</p>}
          {erro && (
            <p role="alert" className="rounded-lg bg-red-50 px-3 py-2 text-sm text-red-700">
              {erro}
            </p>
          )}
          {modelo && (
            <>
              <div className="flex flex-wrap items-center gap-2">
                <button
                  type="button"
                  onClick={() => void imprimir()}
                  disabled={imprimindo}
                  className="inline-flex items-center gap-2 rounded-lg bg-brand-600 px-4 py-2 text-sm font-semibold text-white shadow-sm transition hover:bg-brand-700 disabled:opacity-60"
                >
                  <Printer className="h-4 w-4" aria-hidden="true" />
                  {imprimindo ? "Abrindo..." : "Imprimir"}
                </button>
                <span className="text-xs text-slate-500">Para PDF, escolha “Salvar como PDF” no destino da impressão. Esta ação fica na Auditoria.</span>
              </div>
              <div className="overflow-x-auto">
                <div style={{ width: LARGURA_FOLHA * ESCALA_TELA, height: ALTURA_FOLHA * ESCALA_TELA }}>
                  <div ref={folhaRef} style={{ width: LARGURA_FOLHA, height: ALTURA_FOLHA, transform: `scale(${ESCALA_TELA})`, transformOrigin: "top left" }}>
                    <RelatorioEnsaioFolha m={modelo} />
                  </div>
                </div>
              </div>
            </>
          )}
        </div>
      </Drawer>
    </>
  );
}
