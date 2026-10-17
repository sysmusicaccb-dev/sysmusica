/**
 * SysMúsica — Gráfico de rosca (donut) em SVG próprio, com legenda e percentuais.
 * O total aparece no centro. Itens com valor zero não geram fatia.
 */
import { cn } from "@/lib/cn";
import { corDoItem } from "./paleta";
import type { CorGrafico, ItemGrafico } from "./tipos";

const RAIO = 40;
const CIRCUNFERENCIA = 2 * Math.PI * RAIO;

interface Segmento {
  item: ItemGrafico;
  cor: CorGrafico;
  comprimento: number; // tamanho da fatia ao longo da circunferência
  inicio: number; // onde a fatia começa
}

// Calcula tamanho e posição de cada fatia (função pura, fora do componente)
function calcularSegmentos(dados: ItemGrafico[], total: number): Segmento[] {
  const segmentos: Segmento[] = [];
  let inicio = 0;
  dados.forEach((item, indice) => {
    if (item.valor <= 0) return;
    const comprimento = (item.valor / total) * CIRCUNFERENCIA;
    segmentos.push({ item, cor: corDoItem(item, indice), comprimento, inicio });
    inicio += comprimento;
  });
  return segmentos;
}

interface GraficoRoscaProps {
  dados: ItemGrafico[];
  rotuloCentro: string; // texto abaixo do total, ex: "membros"
  vazio?: string;
}

export default function GraficoRosca({
  dados,
  rotuloCentro,
  vazio = "Sem dados ainda.",
}: GraficoRoscaProps) {
  const total = dados.reduce((soma, item) => soma + item.valor, 0);
  if (total === 0) {
    return <p className="py-8 text-center text-sm text-slate-500">{vazio}</p>;
  }

  const segmentos = calcularSegmentos(dados, total);
  const resumo = segmentos.map(({ item }) => `${item.rotulo}: ${item.valor}`).join("; ");

  return (
    <div className="flex flex-col items-center gap-6 sm:flex-row">
      <div className="relative h-40 w-40 shrink-0">
        {/* A rotação de -90° faz a primeira fatia começar no topo */}
        <svg
          viewBox="0 0 100 100"
          className="h-full w-full -rotate-90"
          role="img"
          aria-label={`${total} ${rotuloCentro}. ${resumo}`}
        >
          <circle
            cx="50"
            cy="50"
            r={RAIO}
            fill="none"
            stroke="currentColor"
            strokeWidth="14"
            className="text-slate-100"
          />
          {segmentos.map(({ item, cor, comprimento, inicio }) => (
            <circle
              key={item.rotulo}
              cx="50"
              cy="50"
              r={RAIO}
              fill="none"
              stroke="currentColor"
              strokeWidth="14"
              className={cor.texto}
              strokeDasharray={`${comprimento} ${CIRCUNFERENCIA - comprimento}`}
              strokeDashoffset={-inicio}
            />
          ))}
        </svg>
        <div className="absolute inset-0 flex flex-col items-center justify-center">
          <span className="text-2xl font-bold text-slate-900">{total.toLocaleString("pt-BR")}</span>
          <span className="text-xs text-slate-500">{rotuloCentro}</span>
        </div>
      </div>

      {/* Legenda com valores e percentuais */}
      <ul className="w-full min-w-0 flex-1 space-y-2 text-sm">
        {segmentos.map(({ item, cor }) => (
          <li key={item.rotulo} className="flex items-center justify-between gap-3">
            <span className="flex min-w-0 items-center gap-2">
              <span
                className={cn("h-2.5 w-2.5 shrink-0 rounded-full", cor.fundo)}
                aria-hidden="true"
              />
              <span className="truncate text-slate-700" title={item.rotulo}>
                {item.rotulo}
              </span>
            </span>
            <span className="shrink-0">
              <span className="font-semibold text-slate-900">
                {item.valor.toLocaleString("pt-BR")}
              </span>{" "}
              <span className="text-slate-500">({Math.round((item.valor / total) * 100)}%)</span>
            </span>
          </li>
        ))}
      </ul>
    </div>
  );
}
