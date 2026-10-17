/**
 * SysMúsica — Cabeçalho de página (UI base): título, descrição e ações (ex: botão "Novo ...").
 */
import type { ReactNode } from "react";

interface PageHeaderProps {
  titulo: string;
  descricao?: string;
  acoes?: ReactNode;
}

export default function PageHeader({ titulo, descricao, acoes }: PageHeaderProps) {
  return (
    <header className="mb-6 flex flex-col gap-4 sm:flex-row sm:items-start sm:justify-between">
      <div className="min-w-0">
        <h1 className="text-2xl font-bold tracking-tight text-slate-900 sm:text-3xl">{titulo}</h1>
        {descricao && <p className="mt-1 text-sm text-slate-600">{descricao}</p>}
      </div>
      {acoes && <div className="flex shrink-0 items-center gap-2">{acoes}</div>}
    </header>
  );
}
