"use client";

/**
 * Sysmusica — Painel de aparência (dentro do botão de Configurações): modo, cor principal e tamanho da
 * letra. Cada escolha vale na hora e é salva na conta (e neste aparelho).
 */
import { CORES, FONTES, TEMAS } from "../regras";
import { usePreferencias, type EstadoSalvamento } from "./PreferenciasProvider";

const MENSAGEM_SALVAMENTO: Record<EstadoSalvamento, string> = {
  ocioso: "",
  salvando: "Salvando...",
  conta: "Salvo na sua conta: vale em qualquer aparelho.",
  aparelho: "Salvo só neste aparelho (não foi possível salvar na sua conta).",
};

// Aparência dos cartões de escolha (o escolhido ganha borda e fundo na cor principal)
const classeCartao =
  "block rounded-xl border border-slate-300 bg-white px-3 py-2 text-sm text-slate-700 transition " +
  "peer-checked:border-brand-600 peer-checked:bg-brand-50 peer-checked:ring-2 peer-checked:ring-brand-200 " +
  "peer-focus-visible:ring-2 peer-focus-visible:ring-brand-300";

export default function PainelAparencia() {
  const { preferencias, salvamento, definir, restaurarPadrao } = usePreferencias();

  return (
    <div className="space-y-7">
      {/* Modo */}
      <fieldset className="space-y-2">
        <legend className="text-sm font-medium text-slate-700">Modo</legend>
        <div className="grid gap-2 sm:grid-cols-3">
          {TEMAS.map((tema) => (
            <label key={tema.id} className="cursor-pointer">
              <input
                type="radio"
                name="pref-tema"
                checked={preferencias.tema === tema.id}
                onChange={() => void definir({ ...preferencias, tema: tema.id })}
                className="peer sr-only"
              />
              <span className={classeCartao}>
                <span className="block font-medium text-slate-900">{tema.rotulo}</span>
                <span className="block text-xs text-slate-500">{tema.descricao}</span>
              </span>
            </label>
          ))}
        </div>
      </fieldset>

      {/* Cor principal */}
      <fieldset className="space-y-2">
        <legend className="text-sm font-medium text-slate-700">Cor principal</legend>
        <div className="flex flex-wrap gap-2">
          {CORES.map((cor) => (
            <label key={cor.id} className="cursor-pointer">
              <input
                type="radio"
                name="pref-cor"
                checked={preferencias.cor === cor.id}
                onChange={() => void definir({ ...preferencias, cor: cor.id })}
                className="peer sr-only"
              />
              <span className={classeCartao + " flex items-center gap-2"}>
                <span
                  aria-hidden="true"
                  className="h-5 w-5 rounded-full border border-black/10"
                  style={{ backgroundColor: cor.amostra }}
                />
                {cor.rotulo}
              </span>
            </label>
          ))}
        </div>
      </fieldset>

      {/* Tamanho da letra */}
      <fieldset className="space-y-2">
        <legend className="text-sm font-medium text-slate-700">Tamanho da letra</legend>
        <div className="grid gap-2 sm:grid-cols-3">
          {FONTES.map((fonte) => (
            <label key={fonte.id} className="cursor-pointer">
              <input
                type="radio"
                name="pref-fonte"
                checked={preferencias.fonte === fonte.id}
                onChange={() => void definir({ ...preferencias, fonte: fonte.id })}
                className="peer sr-only"
              />
              <span className={classeCartao}>
                <span className="block font-medium text-slate-900">{fonte.rotulo}</span>
                <span className="block text-xs text-slate-500">{fonte.descricao}</span>
              </span>
            </label>
          ))}
        </div>
      </fieldset>

      <div className="flex flex-wrap items-center justify-between gap-3">
        <p className="text-xs text-slate-500" aria-live="polite">
          {MENSAGEM_SALVAMENTO[salvamento]}
        </p>
        <button
          type="button"
          onClick={() => void restaurarPadrao()}
          className="rounded-lg border border-slate-300 bg-white px-3 py-1.5 text-xs font-medium text-slate-700 transition hover:bg-slate-50"
        >
          Restaurar o padrão
        </button>
      </div>
    </div>
  );
}
