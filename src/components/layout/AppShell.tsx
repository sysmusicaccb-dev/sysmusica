"use client";

/**
 * Sysmusica — Estrutura do painel: menu lateral + topo + área de conteúdo.
 *
 * Guarda o estado do menu:
 *  - recolhida: no desktop, o menu fica só com ícones;
 *  - menuAberto: no celular/tablet, o menu vira uma gaveta sobre a tela.
 * Guarda também se a janela de Configurações (aparência) está aberta: ela fica aqui, fora da barra do
 * topo, e o botão que a abre fica na barra.
 * O fundo claro fica neste wrapper (e não no <body>) para a interface continuar legível
 * mesmo com o navegador em tema escuro.
 * As páginas internas trazem o próprio <main>, por isso a área de conteúdo é um <div>.
 */
import { useEffect, useState, type ReactNode } from "react";
import { cn } from "@/lib/cn";
import JanelaConfiguracoes from "@/modules/preferencias/components/JanelaConfiguracoes";
import Sidebar from "./Sidebar";
import Topbar from "./Topbar";

export default function AppShell({ children }: { children: ReactNode }) {
  const [recolhida, setRecolhida] = useState(false);
  const [menuAberto, setMenuAberto] = useState(false);
  const [configuracoesAbertas, setConfiguracoesAbertas] = useState(false);

  // A tecla Esc fecha a gaveta do menu (só enquanto ela está aberta)
  useEffect(() => {
    if (!menuAberto) return;
    function aoPressionar(evento: KeyboardEvent) {
      if (evento.key === "Escape") setMenuAberto(false);
    }
    window.addEventListener("keydown", aoPressionar);
    return () => window.removeEventListener("keydown", aoPressionar);
  }, [menuAberto]);

  return (
    <div className="min-h-screen bg-slate-50 text-slate-900">
      {/* Atalho de acessibilidade: aparece ao navegar com Tab e pula o menu */}
      <a
        href="#conteudo"
        className="sr-only focus:not-sr-only focus:fixed focus:left-4 focus:top-4 focus:z-[60] focus:rounded-lg focus:bg-white focus:px-4 focus:py-2 focus:text-sm focus:font-medium focus:text-brand-700 focus:shadow-lg"
      >
        Pular para o conteúdo
      </a>

      <Sidebar recolhida={recolhida} aberta={menuAberto} onFechar={() => setMenuAberto(false)} />

      {/* O espaço à esquerda acompanha a largura do menu fixo (só no desktop) */}
      <div
        className={cn(
          "flex min-h-screen flex-col transition-[padding] duration-200",
          recolhida ? "lg:pl-[4.5rem]" : "lg:pl-64"
        )}
      >
        <Topbar
          recolhida={recolhida}
          menuAberto={menuAberto}
          onAbrirMenu={() => setMenuAberto(true)}
          onAlternarRecolhimento={() => setRecolhida((atual) => !atual)}
          onAbrirConfiguracoes={() => setConfiguracoesAbertas(true)}
        />
        <div id="conteudo" className="flex-1">
          {children}
        </div>
      </div>

      <JanelaConfiguracoes aberto={configuracoesAbertas} onFechar={() => setConfiguracoesAbertas(false)} />
    </div>
  );
}
