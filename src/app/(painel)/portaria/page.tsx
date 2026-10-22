"use client";

/**
 * Sysmusica — Página /portaria: atendimento da portaria (QR Code, busca pelo nome, fotografia).
 * A tela antiga (histórico por evento, lançamento em lote, editar e excluir) está em /portaria/registros.
 */
import AtendimentoPortaria from "@/modules/atendimento/components/AtendimentoPortaria";
import PageHeader from "@/components/ui/PageHeader";

export default function PortariaPage() {
  return (
    <main className="text-slate-900">
      <div className="mx-auto max-w-6xl px-4 py-8 sm:px-6 lg:px-8">
        <PageHeader
          titulo="Portaria"
          descricao="Atendimento: leia o QR Code do membro, confira a foto e registre a entrada."
        />
        <AtendimentoPortaria />
      </div>
    </main>
  );
}
