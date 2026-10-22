/**
 * Sysmusica — Histórico de uma portaria (painel lateral): criação, decisões e exclusão, com quem
 * fez, quando e o motivo (nas rejeições). O histórico só tem acréscimos: ninguém o edita.
 */
import { formatarDataHora } from "@/lib/datas";
import { ROTULO_ACAO } from "../regras";
import type { HistoricoPortaria as Item } from "../tipos";

export default function HistoricoPortaria({ itens }: { itens: Item[] }) {
  if (itens.length === 0) return <p className="text-sm text-slate-500">Nenhum registro no histórico.</p>;

  return (
    <ol className="space-y-4">
      {itens.map((item, indice) => (
        <li key={`${item.ocorrido_em}-${indice}`} className="border-l-2 border-slate-200 pl-4">
          <p className="text-sm font-medium text-slate-900">{ROTULO_ACAO[item.acao] ?? item.acao}</p>
          <p className="text-xs text-slate-500">
            {item.usuario_nome ?? "Sistema"} · {formatarDataHora(item.ocorrido_em)}
          </p>
          {item.motivo && <p className="mt-1 text-sm text-slate-700">Motivo: {item.motivo}</p>}
        </li>
      ))}
    </ol>
  );
}
