"use client";

/**
 * Sysmusica — Aviso de sucesso no canto da tela (UI base).
 * Aparece quando "mensagem" tem texto e some sozinho em 5 segundos (ou ao clicar no X).
 */
import { useEffect, useRef } from "react";
import { Check, X } from "lucide-react";

interface NotificacaoProps {
  mensagem: string | null;
  onFechar: () => void;
}

export default function Notificacao({ mensagem, onFechar }: NotificacaoProps) {
  // Guarda a versão mais recente de onFechar sem reiniciar o temporizador a cada renderização
  const aoFechar = useRef(onFechar);
  useEffect(() => {
    aoFechar.current = onFechar;
  }, [onFechar]);

  // Some sozinho depois de 5 segundos
  useEffect(() => {
    if (!mensagem) return;
    const temporizador = window.setTimeout(() => aoFechar.current(), 5000);
    return () => window.clearTimeout(temporizador);
  }, [mensagem]);

  if (!mensagem) return null;

  return (
    <div
      role="status"
      aria-live="polite"
      className="fixed right-4 top-20 z-[70] flex max-w-sm items-start gap-3 rounded-xl border border-emerald-200 bg-white p-4 shadow-lg"
    >
      <span className="mt-0.5 flex h-5 w-5 shrink-0 items-center justify-center rounded-full bg-emerald-100 text-emerald-700">
        <Check className="h-3.5 w-3.5" aria-hidden="true" />
      </span>
      <p className="flex-1 text-sm text-slate-700">{mensagem}</p>
      <button
        type="button"
        onClick={onFechar}
        aria-label="Fechar aviso"
        className="rounded p-0.5 text-slate-400 transition hover:text-slate-700"
      >
        <X className="h-4 w-4" aria-hidden="true" />
      </button>
    </div>
  );
}
