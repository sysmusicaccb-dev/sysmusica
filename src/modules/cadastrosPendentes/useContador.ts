"use client";

/**
 * Sysmusica — Contador de cadastros aguardando análise (selo no menu lateral).
 * Só consulta para quem tem cadastros.visualizar; atualiza a cada 60 s, ao voltar para a aba e quando a tela
 * "Cadastros pendentes" aprova ou recusa alguém.
 */
import { useCallback, useEffect, useState } from "react";
import { useSessao } from "@/modules/autenticacao/SessaoProvider";
import { EVENTO_FILA_MUDOU, contarPendentes } from "./services/cadastrosPendentes";

const INTERVALO_MS = 60_000;

export function useContadorCadastros(): number {
  const { pode } = useSessao();
  const permitido = pode("cadastros.visualizar");
  const [quantidade, setQuantidade] = useState(0);

  const atualizar = useCallback(async () => {
    if (!permitido) return;
    setQuantidade(await contarPendentes());
  }, [permitido]);

  useEffect(() => {
    if (!permitido) return;
    // O setState acontece DEPOIS do await (assíncrono), então o aviso set-state-in-effect não se aplica.
    // eslint-disable-next-line react-hooks/set-state-in-effect
    void atualizar();
    const relogio = setInterval(() => void atualizar(), INTERVALO_MS);
    const aoVoltar = () => {
      if (document.visibilityState === "visible") void atualizar();
    };
    window.addEventListener(EVENTO_FILA_MUDOU, aoVoltar);
    document.addEventListener("visibilitychange", aoVoltar);
    return () => {
      clearInterval(relogio);
      window.removeEventListener(EVENTO_FILA_MUDOU, aoVoltar);
      document.removeEventListener("visibilitychange", aoVoltar);
    };
  }, [permitido, atualizar]);

  return permitido ? quantidade : 0;
}
