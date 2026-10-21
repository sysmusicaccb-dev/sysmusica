import type { ReactNode } from "react";

/** Estilo único dos campos do formulário público (igual ao do cadastro interno). */
export const classeInput =
  "w-full rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 " +
  "placeholder:text-slate-400 shadow-sm focus:border-brand-500 focus:outline-none " +
  "focus:ring-2 focus:ring-brand-200 disabled:cursor-not-allowed disabled:opacity-60 " +
  "[color-scheme:light]";

/** Bloco com título (ex.: "Identificação"). */
export function Secao({ titulo, children }: { titulo: string; children: ReactNode }) {
  return (
    <section className="space-y-4">
      <h2 className="border-b border-slate-200 pb-1 text-xs font-semibold uppercase tracking-wide text-slate-500">
        {titulo}
      </h2>
      {children}
    </section>
  );
}

/** Campo com rótulo, marcação de obrigatório (*) ou (opcional) e dica opcional. */
export function Campo({
  id,
  rotulo,
  obrigatorio = false,
  dica,
  children,
}: {
  id: string;
  rotulo: string;
  obrigatorio?: boolean;
  dica?: string;
  children: ReactNode;
}) {
  return (
    <div className="space-y-1.5">
      <label htmlFor={id} className="text-sm font-medium text-slate-700">
        {rotulo}{" "}
        {obrigatorio ? (
          <span className="font-normal text-red-600" aria-hidden="true">
            *
          </span>
        ) : (
          <span className="font-normal text-slate-400">(opcional)</span>
        )}
      </label>
      {children}
      {dica && <p className="text-xs text-slate-500">{dica}</p>}
    </div>
  );
}
