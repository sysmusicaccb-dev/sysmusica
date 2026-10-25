"use client";

/**
 * Sysmusica — Guias de Fichas Musicais (mesmo visual das abas de Eventos): linha de cima com
 * Músicos | Organistas | GEM | Outros e, logo abaixo, a linha das etapas (Oficialização, Culto Oficial, RJM...).
 * Componente controlado: quem decide a guia atual é a página. Não sai na impressão.
 */
import { cn } from "@/lib/cn";
import { GUIAS, acharGuia, acharSubguia } from "../abasFichas";

interface Props {
  guia: string;
  subguia: string;
  onMudar: (guia: string, subguia: string) => void;
}

const BASE = "-mb-px shrink-0 border-b-2 px-4 py-2.5 text-sm font-medium transition focus:outline-none focus-visible:ring-2 focus-visible:ring-brand-300";
const ATIVA = "border-brand-600 text-brand-700";
const INATIVA = "border-transparent text-slate-500 hover:border-slate-300 hover:text-slate-700";

export default function AbasDeFichas({ guia, subguia, onMudar }: Props) {
  const atual = acharGuia(guia);
  const subAtual = acharSubguia(guia, subguia);

  return (
    <div className="mb-6 print:hidden">
      <nav aria-label="Formulários Musicais" className="flex gap-1 overflow-x-auto border-b border-slate-200">
        {GUIAS.map((g) => {
          const ativa = g.id === atual.id;
          return (
            <button
              key={g.id}
              type="button"
              aria-current={ativa ? "page" : undefined}
              onClick={() => onMudar(g.id, g.subguias[0].id)}
              className={cn(BASE, ativa ? ATIVA : INATIVA)}
            >
              {g.rotulo}
            </button>
          );
        })}
      </nav>
      {/* Etapas da guia (a guia "Outros" tem uma só e não precisa desta linha) */}
      {atual.subguias.length > 1 && (
        <nav aria-label={`Etapas — ${atual.rotulo}`} className="mt-3 flex flex-wrap gap-2">
          {atual.subguias.map((s) => {
            const ativa = s.id === subAtual.id;
            return (
              <button
                key={s.id}
                type="button"
                aria-current={ativa ? "page" : undefined}
                onClick={() => onMudar(atual.id, s.id)}
                className={cn(
                  "rounded-full border px-3.5 py-1.5 text-xs font-semibold transition focus:outline-none focus-visible:ring-2 focus-visible:ring-brand-300",
                  ativa ? "border-brand-600 bg-brand-50 text-brand-700" : "border-slate-300 bg-white text-slate-600 hover:bg-slate-50"
                )}
              >
                {s.rotulo}
              </button>
            );
          })}
        </nav>
      )}
    </div>
  );
}
