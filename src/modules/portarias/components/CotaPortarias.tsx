/** SysMúsica — Indicador da cota diária de criação de portarias (âmbar quando resta uma ou nenhuma). */
import { cn } from "@/lib/cn";
import { descreverCota } from "../regras";
import type { CotaPortarias } from "../tipos";

export default function CotaPortariasIndicador({ cota }: { cota: CotaPortarias }) {
  return (
    <span
      className={cn(
        "inline-flex items-center rounded-full px-3 py-1 text-xs font-medium",
        !cota.ilimitada && cota.restantes <= 1 ? "bg-amber-100 text-amber-700" : "bg-slate-100 text-slate-600"
      )}
      title="Limite de portarias que você pode criar por dia (horário de Salvador)"
    >
      {descreverCota(cota)}
    </span>
  );
}
