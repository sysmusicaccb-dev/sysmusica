"use client";

/**
 * SysMúsica — Cancelamento de evento (só o Administrador). O motivo é obrigatório e fica no histórico.
 * As portarias pendentes ou aprovadas do evento são rejeitadas automaticamente pelo banco.
 */
import { useState, type FormEvent } from "react";
import Button from "@/components/ui/Button";
import { formatarDataHora } from "@/lib/datas";
import { cancelarEvento } from "@/modules/eventos/services/eventos";
import { MOTIVO_CANCELAMENTO_MAXIMO, validarMotivoCancelamento } from "@/modules/eventos/ciclo";
import type { Evento } from "@/types/database";

interface FormularioCancelamentoProps {
  evento: Evento;
  onSalvo: (mensagem: string) => void | Promise<void>;
}

export default function FormularioCancelamento({ evento, onSalvo }: FormularioCancelamentoProps) {
  const [motivo, setMotivo] = useState("");
  const [salvando, setSalvando] = useState(false);
  const [erro, setErro] = useState<string | null>(null);

  async function enviar(e: FormEvent<HTMLFormElement>) {
    e.preventDefault();
    const invalido = validarMotivoCancelamento(motivo);
    if (invalido) {
      setErro(invalido);
      return;
    }
    setSalvando(true);
    setErro(null);
    try {
      await cancelarEvento(evento.id, motivo.trim());
      await onSalvo("Evento cancelado. As portarias dele foram rejeitadas e o histórico foi mantido.");
    } catch (falha) {
      setErro(falha instanceof Error ? falha.message : "Não foi possível cancelar o evento.");
      setSalvando(false);
    }
  }

  return (
    <form onSubmit={(e) => void enviar(e)} className="space-y-5">
      <div className="rounded-lg bg-slate-50 px-3 py-2 text-sm">
        <p className="font-medium text-slate-900">{formatarDataHora(evento.data_evento)}</p>
        <p className="text-slate-600">{[evento.tipo, evento.local, evento.cidade].filter(Boolean).join(" · ")}</p>
      </div>

      <div className="space-y-1.5">
        <label htmlFor="motivo-cancelamento" className="text-sm font-medium text-slate-700">
          Motivo do cancelamento
        </label>
        <textarea
          id="motivo-cancelamento"
          rows={4}
          required
          maxLength={MOTIVO_CANCELAMENTO_MAXIMO}
          value={motivo}
          onChange={(e) => setMotivo(e.target.value)}
          disabled={salvando}
          placeholder="Explique por que o evento foi cancelado"
          className="w-full rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 placeholder:text-slate-400 shadow-sm focus:border-brand-500 focus:outline-none focus:ring-2 focus:ring-brand-200 disabled:opacity-60"
        />
        <p className="text-xs text-slate-500">
          O evento sai de “Próximos” e vai para o histórico. Portarias pendentes ou aprovadas dele são rejeitadas. A
          decisão não pode ser desfeita.
        </p>
      </div>

      {erro && (
        <p role="alert" className="rounded-lg bg-red-50 px-3 py-2 text-sm text-red-700">
          {erro}
        </p>
      )}

      <Button type="submit" variante="perigo" disabled={salvando} className="w-full">
        {salvando ? "Cancelando..." : "Cancelar evento"}
      </Button>
    </form>
  );
}
