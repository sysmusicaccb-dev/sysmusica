/**
 * Sysmusica — Botão padrão (UI base).
 * Variantes: primario (ação principal), secundario (ação neutra), perigo (ação destrutiva).
 * O ícone é opcional e sempre decorativo (o texto do botão descreve a ação).
 */
import type { ButtonHTMLAttributes, ReactNode } from "react";
import type { LucideIcon } from "lucide-react";
import { cn } from "@/lib/cn";

type VarianteBotao = "primario" | "secundario" | "perigo";

const ESTILOS: Record<VarianteBotao, string> = {
  primario: "bg-brand-600 text-white shadow-sm hover:bg-brand-500 focus-visible:ring-brand-300",
  secundario:
    "border border-slate-300 bg-white text-slate-700 hover:bg-slate-50 focus-visible:ring-brand-300",
  perigo: "bg-red-600 text-white shadow-sm hover:bg-red-500 focus-visible:ring-red-300",
};

interface ButtonProps extends ButtonHTMLAttributes<HTMLButtonElement> {
  variante?: VarianteBotao;
  icone?: LucideIcon;
  children: ReactNode;
}

export default function Button({
  variante = "primario",
  icone: Icone,
  className,
  children,
  type = "button",
  ...resto
}: ButtonProps) {
  return (
    <button
      type={type}
      className={cn(
        "inline-flex items-center justify-center gap-2 rounded-lg px-4 py-2 text-sm font-semibold transition focus:outline-none focus-visible:ring-2 disabled:cursor-not-allowed disabled:opacity-60",
        ESTILOS[variante],
        className
      )}
      {...resto}
    >
      {Icone && <Icone className="h-4 w-4" aria-hidden="true" />}
      {children}
    </button>
  );
}
