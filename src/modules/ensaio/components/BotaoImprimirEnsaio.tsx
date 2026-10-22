"use client";

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
