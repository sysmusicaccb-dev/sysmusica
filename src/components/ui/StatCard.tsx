/**
 * Sysmusica — Cartão de indicador (UI base): número em destaque que leva a uma tela.
 */
import Link from "next/link";
import type { LucideIcon } from "lucide-react";

interface StatCardProps {
  rotulo: string;
  valor: number;
  detalhe?: string;
  icone: LucideIcon;
  href: string;
}

export default function StatCard({ rotulo, valor, detalhe, icone: Icone, href }: StatCardProps) {
  return (
    <Link
      href={href}
      className="group flex items-start justify-between rounded-2xl border border-slate-200 bg-white p-5 shadow-sm transition hover:border-brand-200 hover:shadow-md focus:outline-none focus-visible:ring-2 focus-visible:ring-brand-300"
    >
      <div>
        <p className="text-sm font-medium text-slate-500">{rotulo}</p>
        <p className="mt-1 text-3xl font-bold tracking-tight text-slate-900">
          {valor.toLocaleString("pt-BR")}
        </p>
        {detalhe && <p className="mt-1 text-xs text-slate-500">{detalhe}</p>}
      </div>
      <span className="flex h-10 w-10 items-center justify-center rounded-xl bg-brand-50 text-brand-700 transition group-hover:bg-brand-100">
        <Icone className="h-5 w-5" aria-hidden="true" />
      </span>
    </Link>
  );
}
