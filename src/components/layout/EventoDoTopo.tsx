"use client";

/**
 * Sysmusica — Evento do dia no topo azul: tipo, local, data e hora do evento mais próximo de agora.
 * Só aparece para quem pode ver o Painel ao Vivo (é de onde vêm os eventos) e quando existe um evento.
 * Nenhuma escolha global: é apenas informativo.
 */
import { useEffect, useState } from "react";
import { CalendarDays, Clock } from "lucide-react";
import { useSessao } from "@/modules/autenticacao/SessaoProvider";
import { formatarDiaDoEvento, formatarHoraDoEvento } from "@/modules/painel/regras";
import { listarEventosDoPainel } from "@/modules/painel/services/painel";
import { resumoEventoDoTopo, type ResumoEventoTopo } from "./topo";

export default function EventoDoTopo() {
  const { pode } = useSessao();
  const permitido = pode("painel.visualizar");
  const [resumo, setResumo] = useState<ResumoEventoTopo | null>(null);

  useEffect(() => {
    if (!permitido) return;
    let cancelado = false;
    listarEventosDoPainel()
      .then((lista) => {
        if (!cancelado) setResumo(resumoEventoDoTopo(lista[0]));
      })
      .catch(() => {
        /* o topo é só informativo: sem evento, o bloco simplesmente não aparece */
      });
    return () => {
      cancelado = true;
    };
  }, [permitido]);

  if (!permitido || !resumo) return null;

  // Só data e hora do evento, em uma "pílula" discreta (o nome e o local do evento ficam nas telas do evento)
  return (
    <div
      className="hidden items-center gap-3 rounded-xl bg-[rgb(255_255_255/0.10)] px-4 py-2 text-sm font-medium ring-1 ring-white/15 md:flex"
      aria-label="Data e hora do evento"
    >
      <div className="flex items-center gap-2">
        <CalendarDays className="h-5 w-5 text-white/90" aria-hidden="true" />
        <span>{formatarDiaDoEvento(resumo.dataIso)}</span>
      </div>
      <span className="h-5 w-px bg-white/25" aria-hidden="true" />
      <div className="flex items-center gap-2">
        <Clock className="h-5 w-5 text-white/90" aria-hidden="true" />
        <span>{formatarHoraDoEvento(resumo.dataIso)}</span>
      </div>
    </div>
  );
}
