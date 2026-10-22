"use client";

/**
 * Sysmusica — Evento do dia no topo azul: tipo, local, data e hora do evento mais próximo de agora.
 * Só aparece para quem pode ver o Painel ao Vivo (é de onde vêm os eventos) e quando existe um evento.
 * Nenhuma escolha global: é apenas informativo.
 */
import { useEffect, useState } from "react";
import { CalendarDays, CalendarRange, Clock } from "lucide-react";
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

  return (
    <div className="hidden min-w-0 items-center gap-4 xl:flex" aria-label="Evento do dia">
      <div className="flex min-w-0 items-center gap-3">
        <CalendarRange className="h-8 w-8 shrink-0 text-white/90" aria-hidden="true" />
        <div className="min-w-0 leading-tight">
          <p className="truncate text-base font-semibold">{resumo.titulo}</p>
          {resumo.local && <p className="truncate text-xs font-medium tracking-wide text-blue-100">{resumo.local}</p>}
        </div>
      </div>
      <div className="flex items-center gap-2 text-sm">
        <CalendarDays className="h-5 w-5 text-white/90" aria-hidden="true" />
        <span>{formatarDiaDoEvento(resumo.dataIso)}</span>
      </div>
      <div className="flex items-center gap-2 border-l border-white/20 pl-4 text-sm">
        <Clock className="h-5 w-5 text-white/90" aria-hidden="true" />
        <span>{formatarHoraDoEvento(resumo.dataIso)}</span>
      </div>
    </div>
  );
}
