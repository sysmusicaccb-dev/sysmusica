"use client";

/**
 * Sysmusica — Logo do sistema carregada do banco (uma busca só, compartilhada por topo, menu e tela de entrada).
 * A última logo conhecida fica guardada neste navegador para a tela não "piscar" a clave de sol ao abrir.
 * Se a busca falhar (ou a migração 0067 ainda não foi rodada), o sistema segue com a clave de sol padrão.
 */
import { useEffect, useSyncExternalStore } from "react";
import type { MarcaSalva } from "./regras";
import { buscarMarca } from "./services/marca";

interface EstadoMarca {
  marca: MarcaSalva | null;
  carregado: boolean;
}

const CHAVE_CACHE = "sysmusica.logo";
const ESTADO_DO_SERVIDOR: EstadoMarca = { marca: null, carregado: false };

let estado: EstadoMarca | null = null;
const ouvintes = new Set<() => void>();
let emAndamento: Promise<void> | null = null;

function lerCache(): MarcaSalva | null {
  try {
    const texto = window.localStorage.getItem(CHAVE_CACHE);
    return texto ? (JSON.parse(texto) as MarcaSalva) : null;
  } catch {
    return null; // navegador sem armazenamento: sem cache
  }
}

function gravarCache(marca: MarcaSalva | null) {
  try {
    if (marca) window.localStorage.setItem(CHAVE_CACHE, JSON.stringify(marca));
    else window.localStorage.removeItem(CHAVE_CACHE);
  } catch {
    /* sem armazenamento: segue sem cache */
  }
}

function atual(): EstadoMarca {
  if (!estado) estado = { marca: lerCache(), carregado: false };
  return estado;
}

function definir(proximo: EstadoMarca) {
  estado = proximo;
  ouvintes.forEach((avisar) => avisar());
}

/** Busca a logo no banco. forcar=true refaz a busca (ex.: depois de trocar a logo). */
export function carregarMarca(forcar = false): Promise<void> {
  if (emAndamento) return emAndamento;
  if (atual().carregado && !forcar) return Promise.resolve();
  emAndamento = (async () => {
    try {
      const marca = await buscarMarca();
      gravarCache(marca);
      definir({ marca, carregado: true });
    } catch {
      definir({ ...atual(), carregado: true }); // sem resposta: mantém o que já estava
    } finally {
      emAndamento = null;
    }
  })();
  return emAndamento;
}

export function useMarca(): EstadoMarca {
  const valor = useSyncExternalStore(
    (avisar) => {
      ouvintes.add(avisar);
      return () => ouvintes.delete(avisar);
    },
    atual,
    () => ESTADO_DO_SERVIDOR
  );
  useEffect(() => {
    void carregarMarca();
  }, []);
  return valor;
}
