/**
 * SysMúsica — Estado vazio (UI base): explica que não há dados e orienta a próxima ação.
 */
import type { ReactNode } from "react";

interface EmptyStateProps {
  titulo: string;
  descricao?: string;
  acao?: ReactNode; // ex: link ou botão para cadastrar o primeiro registro
}

export default function EmptyState({ titulo, descricao, acao }: EmptyStateProps) {
  return (
    <div className="rounded-xl border border-dashed border-slate-300 bg-slate-50 px-6 py-10 text-center">
      <p className="font-medium text-slate-700">{titulo}</p>
      {descricao && <p className="mt-1 text-sm text-slate-500">{descricao}</p>}
      {acao && <div className="mt-4">{acao}</div>}
    </div>
  );
}
