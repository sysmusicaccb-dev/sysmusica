"use client";

/**
 * SysMúsica — Menu de navegação principal.
 *
 * Client Component porque precisa saber a rota atual (usePathname)
 * para destacar o item ativo. É usado dentro do cabeçalho do layout.tsx.
 */
import Link from "next/link";
import { usePathname } from "next/navigation";

// Itens do menu: para incluir uma nova tela, basta adicionar uma linha aqui
const ITENS_MENU = [
  { href: "/membros", rotulo: "Membros" },
  { href: "/eventos", rotulo: "Eventos" },
  { href: "/presencas", rotulo: "Presenças" },
  { href: "/instrumentos", rotulo: "Instrumentos" },
] as const;

export default function MenuNavegacao() {
  const caminhoAtual = usePathname() ?? "";

  return (
    <nav aria-label="Navegação principal" className="-mx-1 flex gap-1 overflow-x-auto px-1">
      {ITENS_MENU.map((item) => {
        // Ativo na própria rota ou em subrotas (ex: /membros/123)
        const ativo = caminhoAtual === item.href || caminhoAtual.startsWith(`${item.href}/`);

        return (
          <Link
            key={item.href}
            href={item.href}
            aria-current={ativo ? "page" : undefined}
            className={
              "whitespace-nowrap rounded-lg px-3 py-2 text-sm font-medium transition " +
              (ativo
                ? "bg-indigo-50 text-indigo-700"
                : "text-slate-600 hover:bg-slate-100 hover:text-slate-900")
            }
          >
            {item.rotulo}
          </Link>
        );
      })}
    </nav>
  );
}
