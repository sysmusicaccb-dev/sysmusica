"use client";

/**
 * Sysmusica — Menu lateral.
 *
 * Os itens vêm de ./navegacao.ts. No desktop (>= lg) é fixo e pode ser recolhido (só ícones);
 * no celular/tablet é uma gaveta que abre sobre a tela e fecha ao navegar, tocar fora ou apertar Esc.
 * No canto de cima fica a logomarca (emblema da CCB, em uma plaquinha branca por causa do fundo escuro) e o
 * nome do sistema; com o menu recolhido, aparece só o ícone compacto.
 */
import Link from "next/link";
import { usePathname } from "next/navigation";
import { Music, X } from "lucide-react";
import LogoMarca from "@/components/ui/LogoMarca";
import { cn } from "@/lib/cn";
import { useSessao } from "@/modules/autenticacao/SessaoProvider";
import { useContadorCadastros } from "@/modules/cadastrosPendentes/useContador";
import { GRUPOS_MENU, filtrarMenu, itemMenuAtivo } from "./navegacao";

interface SidebarProps {
  recolhida: boolean; // desktop: mostra só os ícones
  aberta: boolean; // celular/tablet: gaveta aberta
  onFechar: () => void; // fecha a gaveta (também chamado ao clicar em um item)
}

export default function Sidebar({ recolhida, aberta, onFechar }: SidebarProps) {
  const caminho = usePathname() ?? "";
  const { pode } = useSessao();
  const gruposVisiveis = filtrarMenu(GRUPOS_MENU, pode); // só o que o grupo do usuário pode ver
  // Quantos cadastros públicos aguardam análise (0 para quem não tem a permissão); vira um selo no menu
  const pendentes = useContadorCadastros();

  return (
    <>
      {/* Fundo escurecido atrás da gaveta (só celular/tablet) */}
      {aberta && (
        <div
          className="fixed inset-0 z-40 bg-slate-900/50 lg:hidden"
          aria-hidden="true"
          onClick={onFechar}
        />
      )}

      <aside
        id="menu-lateral"
        aria-label="Menu lateral"
        className={cn(
          "fixed inset-y-0 left-0 z-50 flex w-64 flex-col bg-sidebar text-sidebar-fg shadow-xl transition-all duration-200 lg:shadow-none print:hidden",
          aberta ? "translate-x-0" : "-translate-x-full lg:translate-x-0",
          recolhida ? "lg:w-[4.5rem]" : "lg:w-64"
        )}
      >
        {/* Marca do sistema */}
        <div className="flex h-16 shrink-0 items-center justify-between px-4">
          <Link
            href="/"
            onClick={onFechar}
            title="Sysmusica — Dashboard"
            className="flex min-w-0 items-center gap-3"
          >
            {/* Menu aberto: logomarca da CCB; recolhido (só no desktop): o ícone compacto */}
            <LogoMarca altura={30} comFundoBranco className={cn(recolhida && "lg:hidden")} />
            <span
              aria-hidden="true"
              className={cn(
                "hidden h-9 w-9 shrink-0 items-center justify-center rounded-lg bg-brand-600 text-white shadow-sm",
                recolhida && "lg:flex"
              )}
            >
              <Music className="h-5 w-5" />
            </span>
            <span
              className={cn(
                "truncate text-lg font-bold tracking-tight text-white",
                recolhida && "lg:hidden"
              )}
            >
              Sysmusica
            </span>
          </Link>

          {/* Botão de fechar a gaveta (só celular/tablet) */}
          <button
            type="button"
            onClick={onFechar}
            aria-label="Fechar menu"
            className="rounded-lg p-2 text-sidebar-fg transition hover:bg-sidebar-hover hover:text-white lg:hidden"
          >
            <X className="h-5 w-5" aria-hidden="true" />
          </button>
        </div>

        {/* Itens agrupados por categoria */}
        <nav aria-label="Principal" className="flex-1 space-y-6 overflow-y-auto px-3 py-4">
          {gruposVisiveis.map((grupo) => (
            <div key={grupo.titulo ?? "principal"}>
              {grupo.titulo && (
                <p
                  className={cn(
                    "mb-2 px-3 text-xs font-semibold uppercase tracking-wider text-slate-500",
                    recolhida && "lg:sr-only"
                  )}
                >
                  {grupo.titulo}
                </p>
              )}
              <ul className="space-y-1">
                {grupo.itens.map((item) => {
                  const ativo = itemMenuAtivo(item, caminho);
                  const Icone = item.icone;

                  return (
                    <li key={item.href}>
                      <Link
                        href={item.href}
                        onClick={onFechar}
                        aria-current={ativo ? "page" : undefined}
                        title={recolhida ? item.rotulo : undefined}
                        className={cn(
                          "flex items-center gap-3 rounded-lg px-3 py-2.5 text-sm font-medium transition focus:outline-none focus-visible:ring-2 focus-visible:ring-brand-300",
                          ativo
                            ? "bg-brand-600 text-white"
                            : "hover:bg-sidebar-hover hover:text-white",
                          recolhida && "lg:justify-center lg:px-0"
                        )}
                      >
                        <Icone className="h-5 w-5 shrink-0" aria-hidden="true" />
                        {/* Recolhido: o texto continua disponível para leitores de tela */}
                        <span className={cn("truncate", recolhida && "lg:sr-only")}>
                          {item.rotulo}
                        </span>
                        {item.href === "/cadastros-pendentes" && pendentes > 0 && (
                          <span
                            className={cn(
                              "ml-auto rounded-full bg-amber-500 px-2 py-0.5 text-xs font-semibold text-white",
                              recolhida && "lg:hidden"
                            )}
                            aria-label={`${pendentes} aguardando análise`}
                          >
                            {pendentes > 99 ? "99+" : pendentes}
                          </span>
                        )}
                      </Link>
                    </li>
                  );
                })}
              </ul>
            </div>
          ))}
        </nav>
      </aside>
    </>
  );
}
