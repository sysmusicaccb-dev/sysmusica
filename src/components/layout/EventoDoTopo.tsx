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

  // Texto maior e em destaque, com o rótulo para não ser confundido com a hora atual
  return (
    <p className="hidden truncate text-lg font-semibold tracking-wide md:block" aria-label="Próximo evento">
      <span className="font-medium text-blue-100">Próximo evento:</span>{" "}
      {formatarDiaDoEvento(resumo.dataIso)} às {formatarHoraDoEvento(resumo.dataIso)}
    </p>
  );
}
