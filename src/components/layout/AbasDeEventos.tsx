"use client";

/**
 * SysMúsica — Barra de abas da tela de Eventos: Eventos | Gestão de portarias | Portaria.
 * Cada aba leva para a tela que já existe (mesma rota e mesma permissão). A barra é exibida pelos layouts
 * dessas três telas e só aparece para quem vê mais de uma aba (regra em ./abasEventos.ts).
 */
import Link from "next/link";
import { usePathname } from "next/navigation";
import { cn } from "@/lib/cn";
import { useSessao } from "@/modules/autenticacao/SessaoProvider";
import { abasDeEventos } from "./abasEventos";
import { itemAtivo } from "./navegacao";

export default function AbasDeEventos() {
  const caminho = usePathname() ?? "";
  const { pode } = useSessao();
  const abas = abasDeEventos(pode);

  if (abas.length === 0) return null;

  return (
    // Mesma largura do conteúdo das telas (max-w-6xl); não sai na impressão
    <div className="mx-auto max-w-6xl px-4 pt-6 sm:px-6 lg:px-8 print:hidden">
      <nav aria-label="Seções de Eventos" className="flex gap-1 overflow-x-auto border-b border-slate-200">
        {abas.map((aba) => {
          const ativa = itemAtivo(aba.href, caminho);
          return (
            <Link
              key={aba.href}
              href={aba.href}
              aria-current={ativa ? "page" : undefined}
              className={cn(
                "-mb-px shrink-0 border-b-2 px-4 py-2.5 text-sm font-medium transition focus:outline-none focus-visible:ring-2 focus-visible:ring-brand-300",
                ativa
                  ? "border-brand-600 text-brand-700"
                  : "border-transparent text-slate-500 hover:border-slate-300 hover:text-slate-700"
              )}
            >
              {aba.rotulo}
            </Link>
          );
        })}
      </nav>
    </div>
  );
}
