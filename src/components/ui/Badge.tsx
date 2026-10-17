/**
 * SysMúsica — Selo de status (UI base).
 * Cores semânticas: sucesso (verde), alerta (âmbar), perigo (vermelho), marca (índigo), neutro (cinza).
 */
import type { ReactNode } from "react";
import { cn } from "@/lib/cn";

export type VarianteBadge = "neutro" | "sucesso" | "alerta" | "perigo" | "marca";

const ESTILOS: Record<VarianteBadge, string> = {
  neutro: "bg-slate-100 text-slate-600",
  sucesso: "bg-emerald-100 text-emerald-700",
  alerta: "bg-amber-100 text-amber-700",
  perigo: "bg-red-100 text-red-700",
  marca: "bg-brand-50 text-brand-700",
};

interface BadgeProps {
  variante?: VarianteBadge;
  children: ReactNode;
}

export default function Badge({ variante = "neutro", children }: BadgeProps) {
  return (
    <span
      className={cn(
        "inline-flex shrink-0 items-center rounded-full px-2 py-0.5 text-xs font-medium",
        ESTILOS[variante]
      )}
    >
      {children}
    </span>
  );
}
