/** SysMúsica — Últimas entradas registradas na portaria selecionada. */
import { horaCurta } from "../regras";
import type { EntradaRecente } from "../tipos";

export default function EntradasRecentes({ entradas }: { entradas: EntradaRecente[] }) {
  const total = entradas[0]?.total ?? 0;

  return (
    <section className="rounded-2xl border border-slate-200 bg-white p-4 shadow-sm">
      <h2 className="text-sm font-semibold text-slate-900">Últimas entradas</h2>
      <p className="mt-1 text-xs text-slate-500">{total} registro(s) nesta portaria</p>

      {entradas.length === 0 ? (
        <p className="mt-4 text-sm text-slate-500">Nenhuma entrada registrada ainda.</p>
      ) : (
        <ul className="mt-3 divide-y divide-slate-100">
          {entradas.map((entrada) => (
            <li key={entrada.presenca_id} className="flex items-center justify-between gap-3 py-2">
              <div className="min-w-0">
                <p className="truncate text-sm font-medium text-slate-900">{entrada.membro_nome}</p>
                <p className="text-xs text-slate-500">
                  {entrada.origem === "QR" ? "QR Code" : "Pelo nome"} · {entrada.status}
                </p>
              </div>
              <span className="shrink-0 text-sm tabular-nums text-slate-600">{horaCurta(entrada.hora_entrada)}</span>
            </li>
          ))}
        </ul>
      )}
    </section>
  );
}
