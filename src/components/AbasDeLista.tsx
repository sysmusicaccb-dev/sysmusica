"use client";

/**
 * Sysmusica — Abas simples para separar uma lista (ex.: Próximos / Encerrados / Arquivo), com contagem.
 * Só apresentação: quem usa decide o que cada aba mostra.
 */
export interface AbaDeLista<Id extends string> {
  id: Id;
  rotulo: string;
  total: number;
}

interface AbasDeListaProps<Id extends string> {
  abas: AbaDeLista<Id>[];
  atual: Id;
  onTrocar: (id: Id) => void;
  descricao?: string;
}

export default function AbasDeLista<Id extends string>({ abas, atual, onTrocar, descricao }: AbasDeListaProps<Id>) {
  return (
    <div role="tablist" aria-label={descricao} className="mb-4 flex gap-1 overflow-x-auto border-b border-slate-200">
      {abas.map((aba) => {
        const ativa = aba.id === atual;
        return (
          <button
            key={aba.id}
            type="button"
            role="tab"
            aria-selected={ativa}
            onClick={() => onTrocar(aba.id)}
            className={
              "-mb-px flex shrink-0 items-center gap-2 border-b-2 px-4 py-2.5 text-sm font-medium transition " +
              (ativa
                ? "border-brand-600 text-brand-700"
                : "border-transparent text-slate-500 hover:border-slate-300 hover:text-slate-700")
            }
          >
            {aba.rotulo}
            <span
              className={
                "rounded-full px-2 py-0.5 text-xs " + (ativa ? "bg-brand-50 text-brand-700" : "bg-slate-100 text-slate-600")
              }
            >
              {aba.total}
            </span>
          </button>
        );
      })}
    </div>
  );
}
