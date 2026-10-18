"use client";

/**
 * SysMúsica — Escolha das colunas do relatório: marcar o que aparece e mudar a ordem com as setas.
 * A impressão e o CSV seguem exatamente a ordem mostrada aqui.
 */
import { ArrowDown, ArrowUp } from "lucide-react";
import type { ColunaRelatorio } from "../tipos";

interface SelecaoColunasProps {
  colunas: ColunaRelatorio[]; // as que o usuário pode ver
  ordem: string[];
  marcadas: Set<string>;
  onAlternar: (id: string) => void;
  onMover: (id: string, direcao: -1 | 1) => void;
  onPadrao: () => void;
  onTodas: () => void;
  onNenhuma: () => void;
}

const classeBotaoPequeno =
  "rounded-lg border border-slate-300 bg-white px-2.5 py-1 text-xs font-medium text-slate-700 transition " +
  "hover:bg-slate-50 disabled:cursor-not-allowed disabled:opacity-40";

export default function SelecaoColunas({
  colunas,
  ordem,
  marcadas,
  onAlternar,
  onMover,
  onPadrao,
  onTodas,
  onNenhuma,
}: SelecaoColunasProps) {
  // Colunas na ordem escolhida (só as que o usuário pode ver)
  const ordenadas = ordem.flatMap((id) => {
    const coluna = colunas.find((item) => item.id === id);
    return coluna ? [coluna] : [];
  });

  return (
    <div className="space-y-3">
      <div className="flex flex-wrap items-center justify-between gap-2">
        <p className="text-sm text-slate-600">
          {marcadas.size} de {ordenadas.length} coluna(s) marcada(s). Use as setas para mudar a ordem.
        </p>
        <div className="flex flex-wrap gap-2">
          <button type="button" className={classeBotaoPequeno} onClick={onPadrao}>
            Padrão
          </button>
          <button type="button" className={classeBotaoPequeno} onClick={onTodas}>
            Todas
          </button>
          <button type="button" className={classeBotaoPequeno} onClick={onNenhuma}>
            Nenhuma
          </button>
        </div>
      </div>

      <ul className="grid gap-2 sm:grid-cols-2">
        {ordenadas.map((coluna, indice) => (
          <li
            key={coluna.id}
            className="flex items-center justify-between gap-2 rounded-lg border border-slate-200 bg-white px-3 py-2"
          >
            <label className="flex min-w-0 flex-1 items-center gap-2 text-sm text-slate-700">
              <input
                type="checkbox"
                checked={marcadas.has(coluna.id)}
                onChange={() => onAlternar(coluna.id)}
                className="h-4 w-4 rounded border-slate-300 text-brand-600 focus:ring-brand-300"
              />
              <span className="truncate">{coluna.rotulo}</span>
            </label>
            <div className="flex shrink-0 gap-1">
              <button
                type="button"
                className={classeBotaoPequeno}
                onClick={() => onMover(coluna.id, -1)}
                disabled={indice === 0}
                aria-label={`Subir a coluna ${coluna.rotulo}`}
              >
                <ArrowUp className="h-3.5 w-3.5" aria-hidden="true" />
              </button>
              <button
                type="button"
                className={classeBotaoPequeno}
                onClick={() => onMover(coluna.id, 1)}
                disabled={indice === ordenadas.length - 1}
                aria-label={`Descer a coluna ${coluna.rotulo}`}
              >
                <ArrowDown className="h-3.5 w-3.5" aria-hidden="true" />
              </button>
            </div>
          </li>
        ))}
      </ul>
    </div>
  );
}
