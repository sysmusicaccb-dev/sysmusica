"use client";

/**
 * SysMúsica — Formulário de rejeição de portaria (painel lateral). O motivo é obrigatório e fica
 * no histórico. O banco confere permissão, abrangência e que a portaria não é de quem rejeita.
 */
import { useState, type FormEvent } from "react";
import Button from "@/components/ui/Button";
import { formatarDataHora } from "@/lib/datas";
import { MOTIVO_MAXIMO, validarMotivoRejeicao } from "../regras";
import { decidirPortaria } from "../services/portarias";
import type { PortariaDetalhada } from "../tipos";

interface FormularioRejeicaoProps {
  portaria: PortariaDetalhada;
  onSalvo: (mensagem: string) => void | Promise<void>;
}

export default function FormularioRejeicao({ portaria, onSalvo }: FormularioRejeicaoProps) {
  const [motivo, setMotivo] = useState("");
  const [salvando, setSalvando] = useState(false);
  const [erro, setErro] = useState<string | null>(null);

  async function salvar(submissao: FormEvent<HTMLFormElement>) {
    submissao.preventDefault();
    if (salvando) return; // evita envio duplicado
    setErro(null);

    const erroMotivo = validarMotivoRejeicao(motivo);
    if (erroMotivo) return setErro(erroMotivo);

    setSalvando(true);
    try {
      await decidirPortaria(portaria.id, false, motivo.trim());
      await onSalvo("Portaria rejeitada. O motivo ficou registrado no histórico.");
    } catch (e) {
      setErro(e instanceof Error ? e.message : "Não foi possível rejeitar a portaria.");
    } finally {
      setSalvando(false);
    }
  }

  return (
    <form onSubmit={salvar} className="space-y-5">
      <div className="rounded-xl bg-slate-50 px-4 py-3 text-sm">
        <p className="font-medium text-slate-900">
          {portaria.evento_data ? formatarDataHora(portaria.evento_data) : "Evento removido"}
        </p>
        <p className="text-slate-600">
          {[portaria.evento_tipo, portaria.evento_local, portaria.cidade].filter(Boolean).join(" · ")}
        </p>
        <p className="mt-1 text-xs text-slate-500">Criada por {portaria.criador_nome ?? "—"}</p>
      </div>

      <div className="space-y-1.5">
        <label htmlFor="motivo-rejeicao" className="text-sm font-medium text-slate-700">
          Motivo da rejeição
        </label>
        <textarea
          id="motivo-rejeicao"
          rows={4}
          required
          maxLength={MOTIVO_MAXIMO}
          value={motivo}
          onChange={(e) => setMotivo(e.target.value)}
          disabled={salvando}
          placeholder="Explique por que a portaria não foi autorizada"
          className="w-full rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 placeholder:text-slate-400 shadow-sm focus:border-brand-500 focus:outline-none focus:ring-2 focus:ring-brand-200 disabled:opacity-60"
        />
        <p className="text-xs text-slate-500">
          Uma portaria rejeitada não registra presenças e a decisão não pode ser desfeita.
        </p>
      </div>

      {erro && (
        <p role="alert" className="rounded-lg bg-red-50 px-3 py-2 text-sm text-red-700">
          {erro}
        </p>
      )}

      <Button type="submit" variante="perigo" disabled={salvando} className="w-full">
        {salvando ? "Rejeitando..." : "Rejeitar portaria"}
      </Button>
    </form>
  );
}
