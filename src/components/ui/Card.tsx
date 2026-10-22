/**
 * Sysmusica — Cartão (UI base): contêiner branco com borda, título e descrição opcionais.
 */
import type { ReactNode } from "react";
import { cn } from "@/lib/cn";

interface CardProps {
  titulo?: string;
  descricao?: string;
  className?: string;
  children: ReactNode;
}

export default function Card({ titulo, descricao, className, children }: CardProps) {
  return (
    <section className={cn("rounded-2xl border border-slate-200 bg-white shadow-sm", className)}>
      {titulo && (
        <header className="border-b border-slate-100 px-6 py-4">
          <h2 className="text-base font-semibold text-slate-900">{titulo}</h2>
          {descricao && <p className="mt-0.5 text-sm text-slate-500">{descricao}</p>}
        </header>
      )}
      <div className="p-6">{children}</div>
    </section>
  );
}
