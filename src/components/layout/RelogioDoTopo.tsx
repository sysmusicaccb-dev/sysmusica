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
      className="mr-3 hidden items-center gap-5 text-sm font-medium md:flex"
      aria-label="Data e hora de agora (horário da Bahia)"
      title="Horário da Bahia"
    >
      <div className="flex items-center gap-2">
        <CalendarDays className="h-4 w-4 text-white/90" aria-hidden="true" />
        <span>{relogio.dia}</span>
      </div>
      <div className="flex items-center gap-2">
        <Clock className="h-4 w-4 text-white/90" aria-hidden="true" />
        <span className="tabular-nums">{relogio.hora}</span>
      </div>
    </div>
  );
}
