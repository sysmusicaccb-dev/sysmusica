/**
 * Sysmusica — Cabeçalho padrão das abas de Eventos (UI base): cartão claro com ícone grande, título, descrição
 * e, à direita, as ações da tela (ex.: o botão "+ Adicionar"). Mesmo visual de Tipo do Evento.
 */
import type { ReactNode } from "react";
import type { LucideIcon } from "lucide-react";

interface CabecalhoDeAbaProps {
  icone: LucideIcon;
  titulo: string;
  descricao: string;
  acoes?: ReactNode;
}

export default function CabecalhoDeAba({ icone: Icone, titulo, descricao, acoes }: CabecalhoDeAbaProps) {
  return (
    <header className="flex flex-wrap items-center gap-4 rounded-xl border border-slate-200 bg-brand-50 px-5 py-4 shadow-sm">
      <Icone className="h-10 w-10 shrink-0 text-brand-700" aria-hidden="true" />
      <div className="min-w-0 flex-1">
        <h1 className="text-2xl font-bold tracking-tight text-slate-900">{titulo}</h1>
        <p className="text-sm text-slate-600">{descricao}</p>
      </div>
      {acoes && <div className="flex shrink-0 items-center gap-2">{acoes}</div>}
    </header>
  );
}
