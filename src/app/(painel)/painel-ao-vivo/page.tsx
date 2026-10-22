"use client";

/**
 * Sysmusica — Página /painel-ao-vivo: contagens do evento em tempo real (ministério, músicos, organistas e
 * instrumentos), atualizadas sozinhas enquanto a Portaria registra as entradas.
 * Só entra quem tem a permissão painel.visualizar (o banco também confere).
 */
import PageHeader from "@/components/ui/PageHeader";
import PainelAoVivo from "@/modules/painel/components/PainelAoVivo";

export default function PainelAoVivoPage() {
  return (
    <main className="text-slate-900">
      <div className="mx-auto max-w-7xl px-4 py-8 sm:px-6 lg:px-8">
        <PageHeader
          titulo="Painel ao Vivo"
          descricao="Resumo da presença no evento selecionado, atualizado em tempo real enquanto a Portaria registra as entradas."
        />
        <PainelAoVivo />
      </div>
    </main>
  );
}
