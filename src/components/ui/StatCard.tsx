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
  tom?: "azul" | "verde" | "roxo"; // cor do quadro do ícone (só visual)
}

const TONS = {
  azul: "bg-brand-50 text-brand-700 group-hover:bg-brand-100",
  verde: "bg-emerald-50 text-emerald-600 group-hover:bg-emerald-100",
  roxo: "bg-violet-50 text-violet-600 group-hover:bg-violet-100",
};

export default function StatCard({ rotulo, valor, detalhe, icone: Icone, href, tom = "azul" }: StatCardProps) {
  return (
    <Link
      href={href}
      className="group flex items-center gap-4 rounded-2xl border border-slate-200 bg-white p-4 shadow-sm transition hover:border-brand-200 hover:shadow-md focus:outline-none focus-visible:ring-2 focus-visible:ring-brand-300"
    >
      <span className={`flex h-14 w-14 shrink-0 items-center justify-center rounded-2xl transition ${TONS[tom]}`}>
        <Icone className="h-7 w-7" aria-hidden="true" />
      </span>
      <div className="min-w-0">
        <p className="text-sm font-semibold text-slate-900">{rotulo}</p>
        <p className="text-3xl font-bold leading-tight tracking-tight text-slate-900">
          {valor.toLocaleString("pt-BR")}
        </p>
        {detalhe && <p className="text-xs text-slate-500">{detalhe}</p>}
      </div>
    </Link>
  );
}
