"use client";

/**
 * SysMúsica — Breadcrumbs (indicam onde o usuário está): Início > Grupo > Página.
 * Gerados pela rota atual a partir de ./navegacao.ts.
 */
import Link from "next/link";
import { usePathname } from "next/navigation";
import { ChevronRight } from "lucide-react";
import { cn } from "@/lib/cn";
import { useSessao } from "@/modules/autenticacao/SessaoProvider";
import { migalhasVisiveis, montarMigalhas } from "./navegacao";

export default function Breadcrumbs() {
  const caminho = usePathname() ?? "";
  const { pode } = useSessao();
  // Quem não acessa o dashboard (ex: grupo Portaria) não vê o "Início" nos breadcrumbs
  const migalhas = migalhasVisiveis(montarMigalhas(caminho), pode);

  return (
    <nav aria-label="Você está em" className="min-w-0">
      <ol className="flex items-center gap-1.5 text-sm text-slate-500">
        {migalhas.map((migalha, indice) => {
          const ultima = indice === migalhas.length - 1;

          return (
            <li key={`${migalha.rotulo}-${indice}`} className="flex min-w-0 items-center gap-1.5">
              {indice > 0 && (
                <ChevronRight className="h-4 w-4 shrink-0 text-slate-400" aria-hidden="true" />
              )}
              {migalha.href && !ultima ? (
                <Link href={migalha.href} className="truncate hover:text-slate-900">
                  {migalha.rotulo}
                </Link>
              ) : (
                <span
                  aria-current={ultima ? "page" : undefined}
                  className={cn("truncate", ultima && "font-medium text-slate-900")}
                >
                  {migalha.rotulo}
                </span>
              )}
            </li>
          );
        })}
      </ol>
    </nav>
  );
}
