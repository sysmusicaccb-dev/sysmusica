"use client";

/**
 * Sysmusica — Carrega, uma vez por entrada no painel, a regra de encerramento dos eventos (Eventos > Configurações)
 * e entrega ao cálculo da janela da portaria. Só mostra as telas depois de carregar (é uma consulta rápida); se falhar,
 * segue com a regra padrão (24 h) e registra o erro no console.
 */
import { useEffect, useState, type ReactNode } from "react";
import { definirRegraEncerramento } from "@/modules/portarias/janela";
import { obterConfigEventos } from "../services/configEventos";

export default function CarregarRegraEncerramento({ children }: { children: ReactNode }) {
  const [pronto, setPronto] = useState(false);

  useEffect(() => {
    let ativo = true;
    obterConfigEventos()
      .then((config) => definirRegraEncerramento(config.encerra_sozinho, config.horas_apos_inicio))
      .catch((e: unknown) => console.error("Falha ao carregar a regra de encerramento dos eventos:", e))
      .finally(() => {
        if (ativo) setPronto(true);
      });
    return () => {
      ativo = false;
    };
  }, []);

  return pronto ? <>{children}</> : null;
}
