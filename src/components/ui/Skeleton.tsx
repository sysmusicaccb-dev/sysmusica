/**
 * SysMúsica — Placeholder animado de carregamento (UI base).
 * Use className para definir tamanho (ex: "h-28 rounded-2xl").
 */
import { cn } from "@/lib/cn";

export default function Skeleton({ className }: { className?: string }) {
  return <div aria-hidden="true" className={cn("animate-pulse rounded-lg bg-slate-200", className)} />;
}
