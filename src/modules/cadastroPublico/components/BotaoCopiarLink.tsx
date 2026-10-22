"use client";

/**
 * Sysmusica — Botão "Copiar link do cadastro" (Músicos / Organistas).
 * O link é o endereço do próprio sistema + /cadastro: o mesmo para todo mundo. Quem receber preenche o formulário
 * público; o cadastro cai em "Cadastros pendentes" para aprovação.
 */
import { useState } from "react";
import { Check, Link2 } from "lucide-react";

export default function BotaoCopiarLinkCadastro() {
  const [copiado, setCopiado] = useState(false);
  const [falhou, setFalhou] = useState(false);

  async function copiar() {
    const link = `${window.location.origin}/cadastro`;
    setFalhou(false);
    try {
      await navigator.clipboard.writeText(link);
      setCopiado(true);
      setTimeout(() => setCopiado(false), 2500);
    } catch {
      // Sem permissão para a área de transferência: mostra o link para copiar à mão
      setFalhou(true);
      window.prompt("Copie o link do cadastro:", link);
    }
  }

  return (
    <button
      type="button"
      onClick={() => void copiar()}
      title="Copia o link do formulário público de cadastro, para enviar às pessoas"
      className="inline-flex items-center gap-2 rounded-lg border border-slate-300 bg-white px-4 py-2 text-sm font-medium text-slate-700 shadow-sm transition hover:bg-slate-50"
    >
      {copiado ? <Check className="h-4 w-4 text-emerald-600" aria-hidden="true" /> : <Link2 className="h-4 w-4" aria-hidden="true" />}
      {copiado ? "Link copiado!" : falhou ? "Copiar link" : "Copiar link do cadastro"}
    </button>
  );
}
