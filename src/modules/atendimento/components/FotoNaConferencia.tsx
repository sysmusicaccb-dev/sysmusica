"use client";

/**
 * Sysmusica — Foto na hora, dentro da conferência da portaria: para o membro que ainda não tem fotografia.
 * Só aparece para quem tem a permissão Fotografia (o banco confere, inclusive a região). Depois de salvar,
 * a conferência é atualizada e a foto passa a identificar o membro nas próximas vezes.
 */
import { useState } from "react";
import Button from "@/components/ui/Button";
import CampoFoto from "@/modules/membros/components/CampoFoto";
import { enviarFoto } from "@/modules/membros/services/fotos";

interface FotoNaConferenciaProps {
  membroId: string;
  nome: string;
  onSalva: () => Promise<void>;
}

export default function FotoNaConferencia({ membroId, nome, onSalva }: FotoNaConferenciaProps) {
  const [foto, setFoto] = useState<Blob | null>(null);
  const [salvando, setSalvando] = useState(false);
  const [erro, setErro] = useState<string | null>(null);

  async function salvar() {
    if (!foto || salvando) return; // evita envio duplicado
    setSalvando(true);
    setErro(null);
    try {
      await enviarFoto(membroId, foto);
      await onSalva();
    } catch (e) {
      setErro(e instanceof Error ? e.message : "Não foi possível salvar a fotografia.");
    } finally {
      setSalvando(false);
    }
  }

  return (
    <div className="space-y-3 rounded-lg border border-amber-200 bg-amber-50/60 p-3">
      <p className="text-sm text-slate-700">
        Este membro ainda não tem fotografia. Tire a foto agora para identificá-lo nas próximas vezes.
      </p>
      <CampoFoto nome={nome} onChange={setFoto} disabled={salvando} />
      {erro && (
        <p role="alert" className="rounded-lg bg-red-50 px-3 py-2 text-sm text-red-700">
          {erro}
        </p>
      )}
      <Button type="button" onClick={() => void salvar()} disabled={!foto || salvando} className="w-full">
        {salvando ? "Salvando a foto..." : "Salvar foto"}
      </Button>
    </div>
  );
}
