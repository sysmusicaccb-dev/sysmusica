"use client";

/**
 * Sysmusica — Relógio do topo azul: dia da semana, data e hora ATUAIS (fuso da Bahia, 24h), ao lado da engrenagem.
 * Atualiza sozinho a cada 15 segundos. Aparece para todos os usuários. É só informativo.
 */
import { useEffect, useState } from "react";
import { CalendarDays, Clock } from "lucide-react";
import { formatarRelogioDoTopo } from "./topo";

export default function RelogioDoTopo() {
  // Começa vazio (o servidor não conhece o relógio do usuário) e atualiza a cada 15 segundos
  const [agora, setAgora] = useState<Date | null>(null);

  useEffect(() => {
    const primeira = setTimeout(() => setAgora(new Date()), 0);
    const temporizador = setInterval(() => setAgora(new Date()), 15_000);
    return () => {
      clearTimeout(primeira);
      clearInterval(temporizador);
    };
  }, []);

  if (!agora) return null;
  const relogio = formatarRelogioDoTopo(agora);

  return (
    <div
      className="mr-2 hidden items-center gap-3 rounded-xl bg-[rgb(255_255_255/0.10)] px-3 py-1.5 text-sm font-medium ring-1 ring-white/15 md:flex"
      aria-label="Data e hora de agora (horário da Bahia)"
      title="Horário da Bahia"
    >
      <div className="flex items-center gap-2">
        <CalendarDays className="h-4 w-4 text-white/90" aria-hidden="true" />
        <span>{relogio.dia}</span>
      </div>
      <span className="h-4 w-px bg-white/25" aria-hidden="true" />
      <div className="flex items-center gap-2">
        <Clock className="h-4 w-4 text-white/90" aria-hidden="true" />
        <span className="tabular-nums">{relogio.hora}</span>
      </div>
    </div>
  );
}
