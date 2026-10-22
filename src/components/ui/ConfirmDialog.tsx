"use client";

/**
 * Sysmusica — Janela de confirmação (UI base), para ações críticas (excluir, desativar...).
 * Usa o <dialog> nativo: foco preso na janela, Esc cancela e clicar fora também cancela.
 * Enquanto "processando" é verdadeiro, os botões ficam bloqueados (evita clique duplo).
 */
import { useEffect, useRef, type ReactNode } from "react";
import Button from "./Button";

interface ConfirmDialogProps {
  aberto: boolean;
  titulo: string;
  mensagem: ReactNode;
  textoConfirmar: string;
  variante?: "perigo" | "primario";
  processando?: boolean;
  onConfirmar: () => void;
  onCancelar: () => void;
}

export default function ConfirmDialog({
  aberto,
  titulo,
  mensagem,
  textoConfirmar,
  variante = "perigo",
  processando = false,
  onConfirmar,
  onCancelar,
}: ConfirmDialogProps) {
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
      onClose={onCancelar} // disparado ao fechar, inclusive pela tecla Esc
      onClick={(evento) => {
        // Clique no fundo escurecido (o alvo é o próprio <dialog>) cancela
        if (evento.target === evento.currentTarget && !processando) onCancelar();
      }}
      aria-labelledby="titulo-confirmacao"
      className="m-auto w-full max-w-md rounded-2xl bg-white p-0 text-slate-900 shadow-2xl backdrop:bg-slate-900/50"
    >
      <div className="p-6">
        <h2 id="titulo-confirmacao" className="text-lg font-semibold text-slate-900">
          {titulo}
        </h2>
        <div className="mt-2 text-sm text-slate-600">{mensagem}</div>
        <div className="mt-6 flex justify-end gap-2">
          <Button variante="secundario" onClick={onCancelar} disabled={processando}>
            Cancelar
          </Button>
          <Button variante={variante} onClick={onConfirmar} disabled={processando}>
            {processando ? "Aguarde..." : textoConfirmar}
          </Button>
        </div>
      </div>
    </dialog>
  );
}
