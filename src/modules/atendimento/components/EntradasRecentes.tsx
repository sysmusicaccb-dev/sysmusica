/** SysMúsica — Últimas entradas registradas na portaria selecionada. */
import { horaCurta } from "../regras";
import { descreverAvulsa } from "../regrasEntrada";
import type { EntradaRecente } from "../tipos";
import type { EntradaAvulsa } from "../tiposEntrada";

interface EntradasRecentesProps {
  entradas: EntradaRecente[];
  avulsas?: EntradaAvulsa[]; // entradas sem cadastro
  onDesfazerAvulsa?: (id: string) => void;
}

export default function EntradasRecentes({ entradas, avulsas = [], onDesfazerAvulsa }: EntradasRecentesProps) {
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
                  {entrada.origem === "QR" ? "QR Code" : entrada.origem === "ANTIGO" ? "Registro antigo" : "Pelo nome"} · {entrada.status}
                </p>
              </div>
              <span className="shrink-0 text-sm tabular-nums text-slate-600">{horaCurta(entrada.hora_entrada)}</span>
            </li>
          ))}
        </ul>
      )}

      {avulsas.length > 0 && (
        <div className="mt-5 border-t border-slate-100 pt-4">
          <h3 className="text-sm font-semibold text-slate-900">Sem cadastro</h3>
          <p className="mt-1 text-xs text-slate-500">{avulsas[0]?.total ?? avulsas.length} registro(s) nesta portaria</p>
          <ul className="mt-3 divide-y divide-slate-100">
            {avulsas.map((entrada) => (
              <li key={entrada.id} className="flex items-center justify-between gap-3 py-2">
                <div className="min-w-0">
                  <p className="truncate text-sm font-medium text-slate-900">{descreverAvulsa(entrada)}</p>
                  <p className="truncate text-xs text-slate-500">{entrada.origem ?? "Localidade não informada"}</p>
                </div>
                <div className="flex shrink-0 items-center gap-3">
                  <span className="text-sm tabular-nums text-slate-600">{horaCurta(entrada.hora_entrada)}</span>
                  {onDesfazerAvulsa && (
                    <button
                      type="button"
                      onClick={() => onDesfazerAvulsa(entrada.id)}
                      className="text-xs font-semibold text-red-700 hover:underline"
                    >
                      Desfazer
                    </button>
                  )}
                </div>
              </li>
            ))}
          </ul>
        </div>
      )}
    </section>
  );
}
