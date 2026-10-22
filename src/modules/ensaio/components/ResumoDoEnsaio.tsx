"use client";

/**
 * Sysmusica — Resumo lateral do ensaio: o que já foi preenchido, em tempo real, conforme a pessoa digita.
 */
import { rotuloCompleto, type Hino } from "@/modules/hinos/regras";
import { rotuloDoCargo, rotuloEncarregado, type EstadoEnsaio } from "../regras";
import type { ModeloEnsaio } from "@/modules/tiposEvento/regras";

interface ResumoDoEnsaioProps {
  estado: EstadoEnsaio;
  modelo: ModeloEnsaio;
  hinos: Hino[];
}

export default function ResumoDoEnsaio({ estado, modelo, hinos }: ResumoDoEnsaioProps) {
  const abertura = hinos.find((h) => h.id === estado.hinoAberturaId);
  const preenchidos = estado.encarregados.filter((e) => e.nome.trim() !== "");

  return (
    <section aria-label="Resumo do ensaio" className="rounded-2xl border border-slate-200 bg-white p-4 shadow-sm">
      <h2 className="text-lg font-bold text-slate-900">Resumo do ensaio</h2>
      <dl className="mt-3 space-y-3 text-sm">
        <div>
          <dt className="text-xs font-semibold uppercase tracking-wide text-slate-500">Quem atende</dt>
          <dd className="text-slate-800">
            {estado.atendeNome.trim() ? `${estado.atendeNome.trim()} — ${rotuloDoCargo(estado.atendeCargo)}` : "—"}
          </dd>
        </div>
        <div>
          <dt className="text-xs font-semibold uppercase tracking-wide text-slate-500">
            {rotuloEncarregado(modelo)} ({preenchidos.length})
          </dt>
          <dd className="text-slate-800">
            {preenchidos.length === 0 ? "—" : preenchidos.map((e) => e.nome.trim() + (e.cidadeUf ? ` (${e.cidadeUf})` : "")).join("; ")}
          </dd>
        </div>
        <div>
          <dt className="text-xs font-semibold uppercase tracking-wide text-slate-500">Hino de abertura</dt>
          <dd className="text-slate-800">{abertura ? rotuloCompleto(abertura) : "—"}</dd>
        </div>
        <div>
          <dt className="text-xs font-semibold uppercase tracking-wide text-slate-500">Hinos executados</dt>
          <dd className="text-2xl font-bold tabular-nums text-slate-900">{estado.hinosIds.length}</dd>
        </div>
      </dl>
    </section>
  );
}
