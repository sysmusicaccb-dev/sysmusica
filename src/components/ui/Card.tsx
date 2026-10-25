/**
 * Sysmusica — Cartão (UI base): contêiner branco com borda, título e descrição opcionais.
 */
import type { ReactNode } from "react";
import type { LucideIcon } from "lucide-react";
import { cn } from "@/lib/cn";

interface CardProps {
  titulo?: string;
  descricao?: string;
  icone?: LucideIcon; // com ícone, o cabeçalho fica compacto, sem divisória
  acao?: ReactNode; // ex.: link "Ver a lista completa", à direita do cabeçalho
  className?: string;
  children: ReactNode;
}

export default function Card({ titulo, descricao, icone: Icone, acao, className, children }: CardProps) {
  // Com ícone: cabeçalho compacto como no desenho. Sem ícone: o formato de sempre.
  const compacto = Boolean(Icone);

  return (
    <section className={cn("rounded-2xl border border-slate-200 bg-white shadow-sm", className)}>
      {titulo && (
        <header className={compacto ? "flex items-center gap-3 px-5 pt-5" : "border-b border-slate-100 px-6 py-4"}>
          {Icone && (
            <span className="flex h-10 w-10 shrink-0 items-center justify-center rounded-xl bg-brand-50 text-brand-700">
              <Icone className="h-5 w-5" aria-hidden="true" />
            </span>
          )}
          <div className="min-w-0 flex-1">
            <h2 className={cn("text-slate-900", compacto ? "text-[15px] font-bold" : "text-base font-semibold")}>
              {titulo}
            </h2>
            {descricao && <p className={cn("text-slate-500", compacto ? "text-xs" : "mt-0.5 text-sm")}>{descricao}</p>}
          </div>
          {acao}
        </header>
      )}
      <div className={compacto ? "p-5 pt-4" : "p-6"}>{children}</div>
    </section>
  );
}
