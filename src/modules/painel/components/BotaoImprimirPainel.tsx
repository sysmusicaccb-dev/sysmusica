"use client";

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
