"use client";

/**
 * SysMúsica — Opções da página do relatório: título, rodapé, retrato ou paisagem e o ajuste à página.
 *  - Automático: a letra diminui conforme o número de colunas, para a tabela caber na largura.
 *  - Manual: você escolhe o zoom (%) e o tamanho da letra (pt).
 */
import { ESCALA_MAX, ESCALA_MIN, FONTE_MAX, FONTE_MIN } from "../regras";
import type { OpcoesPagina } from "../tipos";

interface OpcoesDaPaginaProps {
  valores: OpcoesPagina;
  onChange: (novos: OpcoesPagina) => void;
}

const classeCampo =
  "w-full rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 shadow-sm " +
  "focus:border-brand-500 focus:outline-none focus:ring-2 focus:ring-brand-200";

export default function OpcoesDaPagina({ valores, onChange }: OpcoesDaPaginaProps) {
  const mudar = (parcial: Partial<OpcoesPagina>) => onChange({ ...valores, ...parcial });

  return (
    <div className="space-y-5">
      <div className="grid gap-4 sm:grid-cols-2">
        <div className="space-y-1.5">
          <label htmlFor="pag-titulo" className="text-xs font-medium text-slate-600">
            Título do relatório
          </label>
          <input
            id="pag-titulo"
            type="text"
            maxLength={120}
            value={valores.titulo}
            onChange={(e) => mudar({ titulo: e.target.value })}
            className={classeCampo}
          />
        </div>
        <div className="space-y-1.5">
          <label htmlFor="pag-rodape" className="text-xs font-medium text-slate-600">
            Rodapé <span className="font-normal text-slate-400">(opcional)</span>
          </label>
          <input
            id="pag-rodape"
            type="text"
            maxLength={160}
            value={valores.rodape}
            onChange={(e) => mudar({ rodape: e.target.value })}
            className={classeCampo}
          />
        </div>
      </div>

      <fieldset className="space-y-2">
        <legend className="text-xs font-medium text-slate-600">Orientação da página</legend>
        <div className="flex flex-wrap gap-4 text-sm text-slate-700">
          <label className="flex items-center gap-2">
            <input
              type="radio"
              name="pag-orientacao"
              checked={valores.orientacao === "paisagem"}
              onChange={() => mudar({ orientacao: "paisagem" })}
              className="h-4 w-4 border-slate-300 text-brand-600 focus:ring-brand-300"
            />
            Paisagem (deitada)
          </label>
          <label className="flex items-center gap-2">
            <input
              type="radio"
              name="pag-orientacao"
              checked={valores.orientacao === "retrato"}
              onChange={() => mudar({ orientacao: "retrato" })}
              className="h-4 w-4 border-slate-300 text-brand-600 focus:ring-brand-300"
            />
            Retrato (em pé)
          </label>
        </div>
      </fieldset>

      <fieldset className="space-y-2">
        <legend className="text-xs font-medium text-slate-600">Ajuste à página</legend>
        <div className="flex flex-wrap gap-4 text-sm text-slate-700">
          <label className="flex items-center gap-2">
            <input
              type="radio"
              name="pag-ajuste"
              checked={valores.ajuste === "automatico"}
              onChange={() => mudar({ ajuste: "automatico" })}
              className="h-4 w-4 border-slate-300 text-brand-600 focus:ring-brand-300"
            />
            Automático (cabe na largura da página)
          </label>
          <label className="flex items-center gap-2">
            <input
              type="radio"
              name="pag-ajuste"
              checked={valores.ajuste === "manual"}
              onChange={() => mudar({ ajuste: "manual" })}
              className="h-4 w-4 border-slate-300 text-brand-600 focus:ring-brand-300"
            />
            Manual
          </label>
        </div>

        {valores.ajuste === "manual" && (
          <div className="grid gap-4 pt-2 sm:grid-cols-2">
            <div className="space-y-1.5">
              <label htmlFor="pag-escala" className="text-xs font-medium text-slate-600">
                Zoom (%) — de {ESCALA_MIN} a {ESCALA_MAX}
              </label>
              <input
                id="pag-escala"
                type="text"
                inputMode="decimal"
                value={valores.escala}
                onChange={(e) => mudar({ escala: e.target.value })}
                className={classeCampo}
              />
            </div>
            <div className="space-y-1.5">
              <label htmlFor="pag-fonte" className="text-xs font-medium text-slate-600">
                Tamanho da letra (pt) — de {FONTE_MIN} a {FONTE_MAX}
              </label>
              <input
                id="pag-fonte"
                type="text"
                inputMode="decimal"
                value={valores.fonte}
                onChange={(e) => mudar({ fonte: e.target.value })}
                className={classeCampo}
              />
            </div>
          </div>
        )}
      </fieldset>
    </div>
  );
}
