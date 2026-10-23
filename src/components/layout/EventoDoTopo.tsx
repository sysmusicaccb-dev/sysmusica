"use client";

/**
 * Sysmusica — Topo azul (centro): "Próximo evento" com a data e a hora do evento mais próximo de agora.
 * Só aparece para quem pode ver o Painel ao Vivo (é de onde vêm os eventos) e quando existe um evento.
 * (O relógio com a data e a hora atuais é o RelogioDoTopo, ao lado da engrenagem.)
 * Nenhuma escolha global: é apenas informativo.
 */
import { useEffect, useState } from "react";
import { useSessao } from "@/modules/autenticacao/SessaoProvider";
import { formatarDiaDoEvento, formatarHoraDoEvento } from "@/modules/painel/regras";
import { listarEventosDoPainel } from "@/modules/painel/services/painel";
import { proximoEventoDoTopo, resumosDosEventos, type ResumoEventoTopo } from "./topo";

export default function EventoDoTopo() {
  const { pode } = useSessao();
  const permitido = pode("painel.visualizar");
  const [resumos, setResumos] = useState<ResumoEventoTopo[]>([]);
  // Hora atual (para esconder o evento assim que ele passa): começa vazia e confere a cada minuto
  const [agora, setAgora] = useState<Date | null>(null);

  useEffect(() => {
    const primeira = setTimeout(() => setAgora(new Date()), 0);
    const temporizador = setInterval(() => setAgora(new Date()), 60_000);
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
        if (!cancelado) setResumos(resumosDosEventos(lista));
      })
      .catch(() => {
        /* o topo é só informativo: sem evento, o bloco simplesmente não aparece */
      });
    return () => {
      cancelado = true;
    };
  }, [permitido]);

  // Só mostra um evento que ainda vai acontecer; passou da hora, o bloco some sozinho
  const resumo = agora ? proximoEventoDoTopo(resumos, agora) : null;
  if (!permitido || !resumo) return null;

  // Texto maior e em destaque, com o rótulo para não ser confundido com a hora atual
  return (
    <p className="hidden truncate text-lg font-semibold tracking-wide md:block" aria-label="Próximo evento">
      <span className="font-medium text-blue-100">Próximo evento:</span>{" "}
      {formatarDiaDoEvento(resumo.dataIso)} às {formatarHoraDoEvento(resumo.dataIso)}
    </p>
  );
}
