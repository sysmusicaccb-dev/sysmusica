"use client";

/**
 * SysMúsica — Barra superior: botões do menu, identificação do sistema e breadcrumbs.
 * Fase 2: o menu do usuário (perfil, sair) entrará à direita, junto com o login real.
 */
import { Menu, PanelLeftClose, PanelLeftOpen } from "lucide-react";
import { cn } from "@/lib/cn";
import Breadcrumbs from "./Breadcrumbs";

interface TopbarProps {
  recolhida: boolean;
  menuAberto: boolean;
  onAbrirMenu: () => void;
  onAlternarRecolhimento: () => void;
}

// Estilo comum dos botões de ícone da barra
const classeBotao =
  "inline-flex h-9 w-9 items-center justify-center rounded-lg text-slate-600 transition hover:bg-slate-100 hover:text-slate-900 focus:outline-none focus-visible:ring-2 focus-visible:ring-brand-300";

export default function Topbar({
  recolhida,
  menuAberto,
  onAbrirMenu,
  onAlternarRecolhimento,
}: TopbarProps) {
  return (
    <header className="sticky top-0 z-30 flex h-16 items-center gap-3 border-b border-slate-200 bg-white/90 px-4 backdrop-blur sm:px-6">
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

      {/* Desktop: recolhe/expande o menu lateral */}
      <button
        type="button"
        onClick={onAlternarRecolhimento}
        aria-label={recolhida ? "Expandir menu lateral" : "Recolher menu lateral"}
        aria-controls="menu-lateral"
        aria-expanded={!recolhida}
        className={cn(classeBotao, "hidden lg:inline-flex")}
      >
        {recolhida ? (
          <PanelLeftOpen className="h-5 w-5" aria-hidden="true" />
        ) : (
          <PanelLeftClose className="h-5 w-5" aria-hidden="true" />
        )}
      </button>

      {/* Identificação do sistema (no desktop ela já aparece no menu lateral) */}
      <span className="text-base font-bold tracking-tight text-slate-900 lg:hidden">SysMúsica</span>

      <div className="hidden min-w-0 sm:block">
        <Breadcrumbs />
      </div>
    </header>
  );
}
