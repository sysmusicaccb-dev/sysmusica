"use client";

/**
 * Sysmusica — Painel lateral (UI base), usado para os formulários de cadastro.
 *
 * Usa o elemento <dialog> nativo do navegador, que já cuida de: foco preso dentro do painel,
 * tecla Esc para fechar e fundo escurecido. Clicar fora do painel também fecha.
 * O conteúdo só existe enquanto o painel está aberto: ao fechar, o formulário é descartado
 * e abre limpo da próxima vez.
 */
import { useEffect, useRef, type ReactNode } from "react";
import { X } from "lucide-react";

interface DrawerProps {
  aberto: boolean;
  titulo: string;
  descricao?: string;
  onFechar: () => void;
  larguraMaxima?: string; // classe de largura máxima (padrão: max-w-lg)
  children: ReactNode;
}

export default function Drawer({ aberto, titulo, descricao, onFechar, larguraMaxima = "max-w-lg", children }: DrawerProps) {
  const dialogoRef = useRef<HTMLDialogElement>(null);

  // Abre/fecha o <dialog> conforme a propriedade "aberto"
  useEffect(() => {
    const dialogo = dialogoRef.current;
    if (!dialogo) return;
    if (aberto && !dialogo.open) dialogo.showModal();
    if (!aberto && dialogo.open) dialogo.close();
  }, [aberto]);

  return (
    <dialog
      ref={dialogoRef}
      onClose={onFechar} // disparado ao fechar, inclusive pela tecla Esc
      onClick={(evento) => {
        // Clique no fundo escurecido (o alvo é o próprio <dialog>) fecha o painel
        if (evento.target === evento.currentTarget) onFechar();
      }}
      aria-labelledby="titulo-painel"
      className={`fixed inset-y-0 left-auto right-0 m-0 h-full max-h-none w-full ${larguraMaxima} overflow-y-auto bg-white p-0 text-slate-900 shadow-2xl backdrop:bg-slate-900/50`}
    >
      {/* Este contêiner ocupa todo o painel: assim só o fundo escurecido gera o clique "fora" */}
      <div className="flex min-h-full flex-col">
        <header className="sticky top-0 z-10 flex items-start justify-between gap-4 border-b border-slate-200 bg-white px-6 py-4">
          <div className="min-w-0">
            <h2 id="titulo-painel" className="text-lg font-semibold text-slate-900">
              {titulo}
            </h2>
            {descricao && <p className="mt-0.5 text-sm text-slate-500">{descricao}</p>}
          </div>
          <button
            type="button"
            onClick={onFechar}
            aria-label="Fechar painel"
            className="rounded-lg p-2 text-slate-500 transition hover:bg-slate-100 hover:text-slate-900 focus:outline-none focus-visible:ring-2 focus-visible:ring-brand-300"
          >
            <X className="h-5 w-5" aria-hidden="true" />
          </button>
        </header>
        <div className="flex-1 px-6 py-5">{aberto && children}</div>
      </div>
    </dialog>
  );
}
