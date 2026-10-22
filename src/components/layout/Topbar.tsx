"use client";

/**
 * Sysmusica — Topo azul: marca do sistema, botões do menu, evento do dia, atalhos (Portaria, Relatório),
 * Configurações (aparência) e o menu do usuário.
 */
import Link from "next/link";
import { usePathname } from "next/navigation";
import { Menu, PanelLeftClose, PanelLeftOpen, Settings } from "lucide-react";
import LogoMarca from "@/components/ui/LogoMarca";
import { cn } from "@/lib/cn";
import { useSessao } from "@/modules/autenticacao/SessaoProvider";
import { itemAtivo } from "./navegacao";
import EventoDoTopo from "./EventoDoTopo";
import { atalhosDoTopo } from "./topo";
import UserMenu from "./UserMenu";

interface TopbarProps {
  recolhida: boolean;
  menuAberto: boolean;
  onAbrirMenu: () => void;
  onAlternarRecolhimento: () => void;
  onAbrirConfiguracoes: () => void;
}

// Botões de ícone sobre o fundo azul
const classeBotao =
  "inline-flex h-9 w-9 items-center justify-center rounded-lg text-white/90 transition hover:bg-[rgb(255_255_255/0.12)] hover:text-white focus:outline-none focus-visible:ring-2 focus-visible:ring-white/70";

// Atalhos de texto (Portaria, Relatório, Configurações)
const classeAtalho =
  "inline-flex h-10 items-center gap-2 rounded-lg px-3 text-sm font-medium text-white/90 transition hover:bg-[rgb(255_255_255/0.12)] hover:text-white focus:outline-none focus-visible:ring-2 focus-visible:ring-white/70";

export default function Topbar({
  recolhida,
  menuAberto,
  onAbrirMenu,
  onAlternarRecolhimento,
  onAbrirConfiguracoes,
}: TopbarProps) {
  const caminho = usePathname() ?? "";
  const { pode } = useSessao();
  const atalhos = atalhosDoTopo(pode);

  return (
    <header className="sticky top-0 z-30 flex h-16 items-center bg-[linear-gradient(90deg,var(--color-topo),var(--color-topo-fim))] text-white shadow-sm print:hidden">
      {/* Marca do sistema (no desktop ocupa a largura do menu lateral) */}
      <div className="flex h-full min-w-0 items-center gap-2 bg-black/10 px-3 sm:px-4 lg:w-64 lg:shrink-0">
        {/* Celular/tablet: abre a gaveta do menu */}
        <button
          type="button"
          onClick={onAbrirMenu}
          aria-label="Abrir menu"
          aria-controls="menu-lateral"
          aria-expanded={menuAberto}
          className={cn(classeBotao, "lg:hidden")}
        >
          <Menu className="h-5 w-5" aria-hidden="true" />
        </button>
        <Link href="/" title="Sysmusica — Dashboard" className="flex min-w-0 items-center gap-3">
          <LogoMarca altura={34} comFundoBranco className="hidden lg:block" />
          <span className="min-w-0 leading-tight">
            <span className="block truncate text-lg font-bold tracking-tight">Sysmusica</span>
          </span>
        </Link>
      </div>

      {/* Desktop: recolhe/expande o menu lateral */}
      <button
        type="button"
        onClick={onAlternarRecolhimento}
        aria-label={recolhida ? "Expandir menu lateral" : "Recolher menu lateral"}
        aria-controls="menu-lateral"
        aria-expanded={!recolhida}
        className={cn(classeBotao, "ml-3 hidden lg:inline-flex")}
      >
        {recolhida ? (
          <PanelLeftOpen className="h-5 w-5" aria-hidden="true" />
        ) : (
          <PanelLeftClose className="h-5 w-5" aria-hidden="true" />
        )}
      </button>

      <div className="ml-4 min-w-0">
        <EventoDoTopo />
      </div>

      {/* Atalhos, Configurações (aparência) e menu do usuário */}
      <div className="ml-auto flex items-center gap-1 pr-3 sm:pr-4">
        {atalhos.map((atalho) => {
          const Icone = atalho.icone;
          const ativo = itemAtivo(atalho.href, caminho);
          return (
            <Link
              key={atalho.href}
              href={atalho.href}
              title={atalho.rotulo}
              aria-current={ativo ? "page" : undefined}
              className={cn(classeAtalho, ativo && "bg-[rgb(255_255_255/0.12)] ring-1 ring-white/70")}
            >
              <Icone className="h-5 w-5" aria-hidden="true" />
              <span className="hidden xl:inline">{atalho.rotulo}</span>
            </Link>
          );
        })}
        <button
          type="button"
          onClick={onAbrirConfiguracoes}
          aria-label="Abrir as configurações de aparência"
          aria-haspopup="dialog"
          title="Configurações"
          className={classeAtalho}
        >
          <Settings className="h-5 w-5" aria-hidden="true" />
          <span className="hidden xl:inline">Configurações</span>
        </button>
        <div className="ml-1 border-l border-white/20 pl-2">
          <UserMenu noTopo />
        </div>
      </div>
    </header>
  );
}
