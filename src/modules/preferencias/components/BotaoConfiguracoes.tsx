"use client";

/**
 * SysMúsica — Botão de Configurações (engrenagem no canto da tela): abre o painel de aparência.
 * Só aparece depois do login. Fica no canto inferior direito por enquanto; depois passa para o topo do sistema.
 */
import { useState } from "react";
import { Settings } from "lucide-react";
import Drawer from "@/components/ui/Drawer";
import PainelAparencia from "./PainelAparencia";

export default function BotaoConfiguracoes() {
  const [aberto, setAberto] = useState(false);

  return (
    <>
      <button
        type="button"
        onClick={() => setAberto(true)}
        aria-label="Abrir as configurações de aparência"
        title="Configurações"
        className="fixed bottom-4 right-4 z-40 flex h-11 w-11 items-center justify-center rounded-full bg-brand-600 text-white shadow-lg transition hover:bg-brand-700 focus:outline-none focus-visible:ring-2 focus-visible:ring-brand-300 print:hidden"
      >
        <Settings className="h-5 w-5" aria-hidden="true" />
      </button>

      <Drawer
        aberto={aberto}
        onFechar={() => setAberto(false)}
        titulo="Configurações"
        descricao="Aparência do sistema: modo, cor e tamanho da letra. As mudanças valem na hora."
      >
        {aberto && <PainelAparencia />}
      </Drawer>
    </>
  );
}
