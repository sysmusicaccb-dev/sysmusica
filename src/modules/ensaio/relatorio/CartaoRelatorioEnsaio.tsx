"use client";

/**
 * Sysmusica — Cartão "Relatório do Ensaio" na tela de Relatórios: escolhe o evento e abre a folha.
 * Aparece para quem tem painel.visualizar ou relatorios.visualizar; o banco ainda confere a região.
 */
import { useEffect, useState } from "react";
import { FileBarChart } from "lucide-react";
import { useSessao } from "@/modules/autenticacao/SessaoProvider";
import { formatarDiaDoEvento } from "@/modules/painel/regras";
import BotaoRelatorioEnsaio from "./BotaoRelatorioEnsaio";
import { listarEventosParaRelatorio, type EventoParaRelatorio } from "./services";

export default function CartaoRelatorioEnsaio() {
  const { pode } = useSessao();
  const permitido = pode("painel.visualizar") || pode("relatorios.visualizar");
  const [eventos, setEventos] = useState<EventoParaRelatorio[] | null>(null);
  const [eventoId, setEventoId] = useState("");
  const [erro, setErro] = useState<string | null>(null);

  useEffect(() => {
    if (!permitido) return;
    let cancelado = false;
    void listarEventosParaRelatorio()
      .then((lista) => {
        if (!cancelado) setEventos(lista);
      })
      .catch((e: unknown) => {
        if (!cancelado) setErro(e instanceof Error ? e.message : "Não foi possível carregar os eventos.");
      });
    return () => {
      cancelado = true;
    };
  }, [permitido]);

  if (!permitido) return null;

  return (
    <section className="mb-6 overflow-hidden rounded-xl border border-slate-200 bg-white p-5 shadow-sm">
      <h2 className="-mx-5 -mt-5 mb-4 flex items-center gap-3 border-b border-slate-200 bg-brand-50 px-5 py-3 text-base font-semibold text-slate-900">
        <FileBarChart className="h-5 w-5 text-brand-700" aria-hidden="true" />
        Relatório do Ensaio (folha A4 pronta para imprimir)
      </h2>
      {erro && <p role="alert" className="mb-3 rounded-lg bg-red-50 px-3 py-2 text-sm text-red-700">{erro}</p>}
      <div className="flex flex-wrap items-end gap-3">
        <label className="block min-w-[16rem] flex-1 text-sm font-medium text-slate-700">
          Evento
          <select
            value={eventoId}
            onChange={(e) => setEventoId(e.target.value)}
            className="mt-1 block w-full rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 focus:outline-none focus:ring-2 focus:ring-brand-200"
          >
            <option value="">{eventos === null ? "Carregando..." : "Escolha o evento"}</option>
            {(eventos ?? []).map((ev) => (
              <option key={ev.id} value={ev.id}>
                {formatarDiaDoEvento(ev.data_evento)} — {ev.tipo}
                {ev.local || ev.cidade ? ` — ${[ev.local, ev.cidade].filter(Boolean).join(", ")}` : ""}
              </option>
            ))}
          </select>
        </label>
        <BotaoRelatorioEnsaio eventoId={eventoId || null} />
      </div>
    </section>
  );
}
