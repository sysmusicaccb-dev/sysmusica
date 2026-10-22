"use client";

/**
 * Sysmusica — Página /registrar-presenca: registro de presença em 3 passos (tipo de participante, categoria e
 * instrumento), com o resumo em tempo real ao lado. É a Entrada sem cadastro no visual do protótipo: a leitura
 * do QR Code e a busca pelo nome continuam em /portaria.
 */
import RegistrarPresenca from "@/modules/atendimento/components/RegistrarPresenca";

export default function RegistrarPresencaPage() {
  return (
    <main className="text-slate-900">
      <div className="mx-auto max-w-7xl px-4 py-6 sm:px-6 lg:px-8">
        <RegistrarPresenca />
      </div>
    </main>
  );
}
