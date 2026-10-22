/**
 * Sysmusica — Gráfico de barras horizontais (SVG/CSS próprio, sem biblioteca).
 * Cada linha mostra o rótulo, o valor e uma barra proporcional ao maior valor.
 */
import { cn } from "@/lib/cn";
import { corDoItem } from "./paleta";
import type { ItemGrafico } from "./tipos";

interface GraficoBarrasProps {
  dados: ItemGrafico[];
  vazio?: string; // texto exibido quando não há dados
}

export default function GraficoBarras({ dados, vazio = "Sem dados ainda." }: GraficoBarrasProps) {
  if (dados.length === 0) {
    return <p className="py-8 text-center text-sm text-slate-500">{vazio}</p>;
  }

  const maximo = Math.max(...dados.map((item) => item.valor), 1);

  return (
    <ul className="space-y-3">
      {dados.map((item, indice) => {
        const cor = corDoItem(item, indice);

        return (
          <li key={item.rotulo}>
            <div className="mb-1 flex items-center justify-between gap-3 text-sm">
              <span className="truncate text-slate-700" title={item.rotulo}>
                {item.rotulo}
              </span>
              <span className="shrink-0 font-semibold text-slate-900">
                {item.valor.toLocaleString("pt-BR")}
              </span>
            </div>
            <div className="h-2.5 overflow-hidden rounded-full bg-slate-100" aria-hidden="true">
              <div
                className={cn("h-full rounded-full", cor.fundo)}
                style={{ width: `${(item.valor / maximo) * 100}%` }}
              />
            </div>
          </li>
        );
      })}
    </ul>
  );
}
