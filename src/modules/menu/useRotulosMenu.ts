"use client";

/**
 * Sysmusica — Nomes do menu carregados do banco (uma busca só, compartilhada por menu lateral e breadcrumbs).
 * Se a busca falhar (ou o SQL 0053 ainda não foi rodado), o sistema segue com os nomes padrão.
 */
import { useEffect, useSyncExternalStore } from "react";
import { listarRotulosMenu, souMaster } from "./services/rotulos";

interface EstadoRotulos {
  rotulos: Record<string, string>;
  master: boolean;
  carregado: boolean;
}

let estado: EstadoRotulos = { rotulos: {}, master: false, carregado: false };
const ouvintes = new Set<() => void>();
let emAndamento: Promise<void> | null = null;

function definir(parte: Partial<EstadoRotulos>) {
  estado = { ...estado, ...parte };
  ouvintes.forEach((avisar) => avisar());
}

/** Busca os nomes e o papel de Master. forcar=true refaz a busca (ex.: ao abrir a tela de edição). */
export function carregarRotulos(forcar = false): Promise<void> {
  if (emAndamento) return emAndamento;
  if (estado.carregado && !forcar) return Promise.resolve();
  emAndamento = (async () => {
    try {
      const [rotulos, master] = await Promise.all([listarRotulosMenu(), souMaster()]);
      definir({ rotulos, master, carregado: true });
    } catch {
      definir({ carregado: true }); // sem nomes personalizados: vale o padrão
    } finally {
      emAndamento = null;
    }
  })();
  return emAndamento;
}

/** Atualiza um nome na memória (depois de salvar/restaurar), sem nova busca. */
export function definirRotuloLocal(href: string, rotulo: string | null) {
  const proximo = { ...estado.rotulos };
  if (rotulo === null) delete proximo[href];
  else proximo[href] = rotulo;
  definir({ rotulos: proximo });
}

export function useRotulosMenu(): EstadoRotulos {
  const atual = useSyncExternalStore(
    (avisar) => {
      ouvintes.add(avisar);
      return () => ouvintes.delete(avisar);
    },
    () => estado,
    () => estado
  );
  useEffect(() => {
    void carregarRotulos();
  }, []);
  return atual;
}
