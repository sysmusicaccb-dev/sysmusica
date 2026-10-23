"use client";

/**
 * Sysmusica — Topo azul: dia da semana, data e hora ATUAIS (fuso da Bahia, 24h, atualiza sozinho) e,
 * para quem pode ver o Painel ao Vivo, o rótulo "Próximo evento" com a data e a hora do evento mais próximo.
 * Nenhuma escolha global: é apenas informativo.
 */
import { useEffect, useState } from "react";
import { CalendarDays, Clock } from "lucide-react";
import { useSessao } from "@/modules/autenticacao/SessaoProvider";
import { formatarDiaDoEvento, formatarHoraDoEvento } from "@/modules/painel/regras";
import { listarEventosDoPainel } from "@/modules/painel/services/painel";
import { formatarRelogioDoTopo, resumoEventoDoTopo, type ResumoEventoTopo } from "./topo";

export default function EventoDoTopo() {
  const { pode } = useSessao();
  const permitido = pode("painel.visualizar");
  const [resumo, setResumo] = useState<ResumoEventoTopo | null>(null);
  // Hora atual: começa vazia (o servidor não conhece o relógio do usuário) e atualiza a cada 15 segundos
  const [agora, setAgora] = useState<Date | null>(null);

  useEffect(() => {
    const primeira = setTimeout(() => setAgora(new Date()), 0);
    const temporizador = setInterval(() => setAgora(new Date()), 15_000);
    return () => {
      clearTimeout(primeira);
      clearInterval(temporizador);
    };
  }, []);

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

  if (!agora) return null;
  const relogio = formatarRelogioDoTopo(agora);

  return (
    <div className="hidden items-center gap-4 md:flex">
      {/* Dia da semana, data e hora de agora (horário da Bahia, 24h) */}
      <div
        className="flex items-center gap-3 rounded-xl bg-[rgb(255_255_255/0.10)] px-4 py-2 text-sm font-medium ring-1 ring-white/15"
        aria-label="Data e hora de agora (horário da Bahia)"
        title="Horário da Bahia"
      >
        <div className="flex items-center gap-2">
          <CalendarDays className="h-5 w-5 text-white/90" aria-hidden="true" />
          <span>{relogio.dia}</span>
        </div>
        <span className="h-5 w-px bg-white/25" aria-hidden="true" />
        <div className="flex items-center gap-2">
          <Clock className="h-5 w-5 text-white/90" aria-hidden="true" />
          <span className="tabular-nums">{relogio.hora}</span>
        </div>
      </div>

      {/* Evento mais próximo, com rótulo (para não ser confundido com a hora atual) */}
      {permitido && resumo && (
        <p className="hidden text-xs font-medium text-blue-100 xl:block">
          Próximo evento: {formatarDiaDoEvento(resumo.dataIso)} às {formatarHoraDoEvento(resumo.dataIso)}
        </p>
      )}
    </div>
  );
}
