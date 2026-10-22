"use client";

/**
 * Sysmusica — Formulário de nova portaria (painel lateral). Escolhe-se um EVENTO existente (data,
 * hora e local vêm dele). A portaria nasce PENDENTE: criar não autoriza o uso. O banco confere
 * permissão, cota de 4 por dia, cidade do evento e duplicidade; a mensagem dele aparece aqui.
 */
import { useState, type FormEvent } from "react";
import Button from "@/components/ui/Button";
import { formatarDataHora } from "@/lib/datas";
import { descreverCota } from "../regras";
import { criarPortaria } from "../services/portarias";
import type { CotaPortarias, EventoParaPortaria } from "../tipos";

interface FormularioNovaPortariaProps {
  eventos: EventoParaPortaria[]; // já sem os que têm portaria pendente ou aprovada
  cota: CotaPortarias | null;
  onSalvo: (mensagem: string) => void | Promise<void>;
}

const classeInput =
  "w-full rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 shadow-sm " +
  "focus:border-brand-500 focus:outline-none focus:ring-2 focus:ring-brand-200 disabled:cursor-not-allowed disabled:opacity-60";

export default function FormularioNovaPortaria({ eventos, cota, onSalvo }: FormularioNovaPortariaProps) {
  const [eventoId, setEventoId] = useState("");
  const [salvando, setSalvando] = useState(false);
  const [erro, setErro] = useState<string | null>(null);

  const evento = eventos.find((item) => item.id === eventoId);
  const semCota = cota !== null && cota.restantes === 0;

  async function salvar(submissao: FormEvent<HTMLFormElement>) {
    submissao.preventDefault();
    if (salvando) return; // evita envio duplicado
    setErro(null);
    if (!eventoId) return setErro("Escolha o evento da portaria.");

    setSalvando(true);
    try {
      await criarPortaria(eventoId);
      await onSalvo("Portaria criada e enviada para aprovação.");
    } catch (e) {
      setErro(e instanceof Error ? e.message : "Não foi possível criar a portaria.");
    } finally {
      setSalvando(false);
    }
  }

  return (
    <form onSubmit={salvar} className="space-y-5">
      {cota && (
        <p className={"rounded-lg px-3 py-2 text-sm " + (semCota ? "bg-amber-50 text-amber-700" : "bg-slate-50 text-slate-600")}>
          {descreverCota(cota)}. {semCota && "Novas criações estarão disponíveis no próximo dia."}
        </p>
      )}

      <div className="space-y-1.5">
        <label htmlFor="evento-portaria" className="text-sm font-medium text-slate-700">
          Evento
        </label>
        <select
          id="evento-portaria"
          value={eventoId}
          onChange={(e) => setEventoId(e.target.value)}
          disabled={salvando || semCota}
          className={classeInput}
        >
          <option value="">Selecione um evento</option>
          {eventos.map((item) => (
            <option key={item.id} value={item.id} disabled={!item.cidade}>
              {formatarDataHora(item.data_evento)} · {item.tipo} · {item.local}
              {item.cidade ? ` (${item.cidade})` : " — casa de oração sem setor"}
            </option>
          ))}
        </select>
        <p className="text-xs text-slate-500">
          Aparecem só os eventos que têm uma casa de oração escolhida (na tela de Eventos, botão Editar) dentro da sua abrangência. Os de casa de oração sem setor ficam desabilitados (peça a um administrador para vincular a casa de oração a um setor). Eventos que já têm
          portaria pendente ou aprovada não aparecem.
        </p>
      </div>

      {evento && (
        <dl className="space-y-1 rounded-xl bg-slate-50 px-4 py-3 text-sm">
          <div className="flex justify-between gap-3">
            <dt className="text-slate-500">Data e hora</dt>
            <dd className="text-right text-slate-900">{formatarDataHora(evento.data_evento)}</dd>
          </div>
          <div className="flex justify-between gap-3">
            <dt className="text-slate-500">Local</dt>
            <dd className="text-right text-slate-900">{evento.local}</dd>
          </div>
          <div className="flex justify-between gap-3">
            <dt className="text-slate-500">Cidade</dt>
            <dd className="text-right text-slate-900">{evento.cidade}</dd>
          </div>
        </dl>
      )}

      {erro && (
        <p role="alert" className="rounded-lg bg-red-50 px-3 py-2 text-sm text-red-700">
          {erro}
        </p>
      )}

      <Button type="submit" disabled={salvando || semCota} className="w-full">
        {salvando ? "Criando..." : "Criar portaria"}
      </Button>
    </form>
  );
}
