"use client";

/**
 * Sysmusica — Painel de aparência (dentro do botão de Configurações): modo, cor principal e tamanho da
 * letra. Cada escolha vale na hora e é salva na conta (e neste aparelho).
 */
import { Monitor, Moon, Sun } from "lucide-react";
import LogoDoSistema from "@/modules/marca/components/LogoDoSistema";
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
  "flex h-full w-full rounded-xl border border-slate-200 bg-white p-3.5 text-sm text-slate-700 transition " +
  "hover:border-slate-300 peer-checked:border-brand-500 peer-checked:bg-brand-50 peer-checked:ring-1 peer-checked:ring-brand-500 " +
  "peer-focus-visible:ring-2 peer-focus-visible:ring-brand-300";

// Bolinha de marcação no canto do cartão (só visual: quem escolhe é o campo de rádio escondido)
function Bolinha({ marcada }: { marcada: boolean }) {
  return (
    <span
      aria-hidden="true"
      className={
        "flex h-5 w-5 shrink-0 items-center justify-center rounded-full border-2 " +
        (marcada ? "border-brand-600 bg-brand-600" : "border-slate-300 bg-white")
      }
    >
      {marcada && <span className="h-1.5 w-1.5 rounded-full bg-white" />}
    </span>
  );
}

// Ícone de cada modo (Claro, Escuro e Automático)
function IconeDoModo({ id }: { id: string }) {
  const classe = "mb-2 h-6 w-6 text-slate-900";
  if (id === "claro") return <Sun className={classe} aria-hidden="true" />;
  if (id === "escuro") return <Moon className={classe} aria-hidden="true" />;
  return <Monitor className={classe} aria-hidden="true" />;
}

export default function PainelAparencia() {
  const { preferencias, salvamento, definir, restaurarPadrao } = usePreferencias();

  return (
    <div className="space-y-7">
      {/* Modo */}
      <fieldset className="space-y-2">
        <legend className="text-base font-semibold text-slate-900">Modo</legend>
        <div className="grid gap-2 sm:grid-cols-3">
          {TEMAS.map((tema) => (
            <label key={tema.id} className="block cursor-pointer">
              <input
                type="radio"
                name="pref-tema"
                checked={preferencias.tema === tema.id}
                onChange={() => void definir({ ...preferencias, tema: tema.id })}
                className="peer sr-only"
              />
              <span className={classeCartao}>
                <span className="flex w-full items-end justify-between gap-2">
                  <span className="block">
                    <IconeDoModo id={tema.id} />
                    <span className="block font-semibold text-slate-900">{tema.rotulo}</span>
                    <span className="block text-xs text-slate-500">{tema.descricao}</span>
                  </span>
                  <Bolinha marcada={preferencias.tema === tema.id} />
                </span>
              </span>
            </label>
          ))}
        </div>
      </fieldset>

      {/* Cor principal */}
      <fieldset className="space-y-2">
        <legend className="text-base font-semibold text-slate-900">Cor principal</legend>
        <div className="grid grid-cols-2 gap-2 sm:grid-cols-4">
          {CORES.map((cor) => (
            <label key={cor.id} className="block cursor-pointer">
              <input
                type="radio"
                name="pref-cor"
                checked={preferencias.cor === cor.id}
                onChange={() => void definir({ ...preferencias, cor: cor.id })}
                className="peer sr-only"
              />
              <span className={classeCartao + " items-center gap-3 py-3 font-medium text-slate-900"}>
                <span
                  aria-hidden="true"
                  className="h-7 w-7 shrink-0 rounded-full border border-black/10"
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
        <legend className="text-base font-semibold text-slate-900">Tamanho da letra</legend>
        <div className="grid gap-2 sm:grid-cols-3">
          {FONTES.map((fonte) => (
            <label key={fonte.id} className="block cursor-pointer">
              <input
                type="radio"
                name="pref-fonte"
                checked={preferencias.fonte === fonte.id}
                onChange={() => void definir({ ...preferencias, fonte: fonte.id })}
                className="peer sr-only"
              />
              <span className={classeCartao}>
                <span className="flex w-full items-center justify-between gap-2">
                  <span className="block">
                    <span className="block font-semibold text-slate-900">{fonte.rotulo}</span>
                    <span className="block text-xs text-slate-500">{fonte.descricao}</span>
                  </span>
                  <Bolinha marcada={preferencias.fonte === fonte.id} />
                </span>
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
          className="rounded-lg border border-slate-300 bg-white px-4 py-2 text-sm font-medium text-slate-800 shadow-sm transition hover:bg-slate-50"
        >
          Restaurar o padrão
        </button>
      </div>

      {/* Logo do sistema: só o administrador Master vê esta parte */}
      <LogoDoSistema />
    </div>
  );
}
