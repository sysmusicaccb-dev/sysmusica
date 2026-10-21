"use client";

/**
 * SysMúsica — Barra de abas da Administração de acesso: Usuários | Grupos e Permissões.
 * Cada aba leva para a tela que já existe (mesma rota e mesma permissão). A barra é exibida pelos layouts
 * dessas duas telas e só aparece para quem vê as duas abas (regra em ./abasAdministracao.ts).
 */
import Link from "next/link";
import { usePathname } from "next/navigation";
import { cn } from "@/lib/cn";
import { useSessao } from "@/modules/autenticacao/SessaoProvider";
import { abasDeAdministracao } from "./abasAdministracao";
import { itemAtivo } from "./navegacao";

export default function AbasDeAdministracao() {
  const caminho = usePathname() ?? "";
  const { pode } = useSessao();
  const abas = abasDeAdministracao(pode);

  if (abas.length === 0) return null;

  return (
    // Mesma largura do conteúdo das telas de Usuários e Grupos (max-w-7xl); não sai na impressão
    <div className="mx-auto max-w-7xl px-4 pt-6 sm:px-6 lg:px-8 print:hidden">
      <nav aria-label="Seções de Usuários e Grupos" className="flex gap-1 overflow-x-auto border-b border-slate-200">
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
