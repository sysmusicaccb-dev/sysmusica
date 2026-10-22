/**
 * Sysmusica — Botão só com ícone (UI base), para as ações de cada linha das tabelas.
 * O "rotulo" vira dica (title) e nome acessível (aria-label): descreva a ação e o alvo,
 * ex: "Editar Maria". Se o botão estiver desabilitado, explique o motivo no rótulo.
 */
import type { ButtonHTMLAttributes } from "react";
import type { LucideIcon } from "lucide-react";
import { cn } from "@/lib/cn";

interface BotaoIconeProps extends ButtonHTMLAttributes<HTMLButtonElement> {
  icone: LucideIcon;
  rotulo: string;
  variante?: "padrao" | "perigo";
}

export default function BotaoIcone({
  icone: Icone,
  rotulo,
  variante = "padrao",
  className,
  type = "button",
  ...resto
}: BotaoIconeProps) {
  return (
    <button
      type={type}
      title={rotulo}
      aria-label={rotulo}
      className={cn(
        "inline-flex h-8 w-8 items-center justify-center rounded-lg text-slate-500 transition focus:outline-none focus-visible:ring-2 focus-visible:ring-brand-300 disabled:cursor-not-allowed disabled:opacity-40",
        variante === "perigo"
          ? "hover:bg-red-50 hover:text-red-600"
          : "hover:bg-slate-100 hover:text-slate-900",
        className
      )}
      {...resto}
    >
      <Icone className="h-4 w-4" aria-hidden="true" />
    </button>
  );
}
