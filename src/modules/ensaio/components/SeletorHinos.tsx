"use client";

/**
 * Sysmusica — Escolha dos hinos executados no ensaio.
 * Esquerda: lista de hinos ativos (com busca) para marcar e adicionar. Direita: hinos já escolhidos, na ordem
 * em que foram cantados (dá para subir, descer e remover). Hino não se repete e o hino de abertura fica de fora.
 */
import { useMemo, useState } from "react";
import { ArrowDown, ArrowUp, X } from "lucide-react";
import BotaoIcone from "@/components/ui/BotaoIcone";
import { filtrarHinos, rotuloCompleto, rotuloHino, type Hino } from "@/modules/hinos/regras";
import { MAXIMO_HINOS, adicionarHinos, hinosDisponiveis, moverHino, removerHinos } from "../regras";

interface SeletorHinosProps {
  hinos: Hino[]; // todos
  selecionados: string[];
  abertura: string; // id do hino de abertura (fora da lista)
  onChange: (ids: string[]) => void;
  disabled?: boolean;
}

const LIMITE_LISTA = 60; // quantos hinos desenhar de uma vez na coluna da esquerda

export default function SeletorHinos({ hinos, selecionados, abertura, onChange, disabled }: SeletorHinosProps) {
  const [busca, setBusca] = useState("");
  const [marcados, setMarcados] = useState<string[]>([]);

  const porId = useMemo(() => new Map(hinos.map((h) => [h.id, h] as const)), [hinos]);
  const encontrados = useMemo(
    () => filtrarHinos(hinosDisponiveis(hinos, selecionados, abertura), busca),
    [hinos, selecionados, abertura, busca]
  );
  const visiveis = encontrados.slice(0, LIMITE_LISTA);
  const marcadosValidos = marcados.filter((id) => visiveis.some((h) => h.id === id));

  function alternarMarca(id: string) {
    setMarcados((atual) => (atual.includes(id) ? atual.filter((x) => x !== id) : [...atual, id]));
  }
  function adicionar(ids: string[]) {
    onChange(adicionarHinos(selecionados, ids, abertura));
    setMarcados([]);
  }

  return (
    <div className="grid gap-4 lg:grid-cols-2">
      {/* Esquerda: disponíveis */}
      <div className="rounded-xl border border-slate-200 p-3">
        <label htmlFor="busca-hino-ensaio" className="text-sm font-medium text-slate-700">
          Buscar hino (número ou título)
        </label>
        <input
          id="busca-hino-ensaio"
          type="search"
          autoComplete="off"
          value={busca}
          onChange={(e) => setBusca(e.target.value)}
          disabled={disabled}
          placeholder="Ex: 12, coro 3, suave"
          className="mt-1 w-full rounded-lg border border-slate-300 px-3 py-2 text-sm shadow-sm focus:border-brand-500 focus:outline-none focus:ring-2 focus:ring-brand-200 disabled:opacity-60"
        />
        <ul className="mt-2 max-h-64 divide-y divide-slate-100 overflow-y-auto rounded-lg border border-slate-100" aria-label="Hinos disponíveis">
          {visiveis.length === 0 ? (
            <li className="px-3 py-6 text-center text-sm text-slate-500">Nenhum hino disponível.</li>
          ) : (
            visiveis.map((hino) => (
              <li key={hino.id}>
                <label className="flex cursor-pointer items-center gap-2 px-3 py-1.5 text-sm hover:bg-slate-50">
                  <input
                    type="checkbox"
                    checked={marcados.includes(hino.id)}
                    onChange={() => alternarMarca(hino.id)}
                    disabled={disabled}
                    className="h-4 w-4 rounded border-slate-300"
                  />
                  <span className="text-slate-800">{rotuloCompleto(hino)}</span>
                </label>
              </li>
            ))
          )}
        </ul>
        {encontrados.length > visiveis.length && (
          <p className="mt-1 text-xs text-slate-500">
            Mostrando {visiveis.length} de {encontrados.length}. Use a busca para achar os demais.
          </p>
        )}
        <div className="mt-3 flex flex-wrap gap-2">
          <button
            type="button"
            disabled={disabled || marcadosValidos.length === 0}
            onClick={() => adicionar(marcadosValidos)}
            className="rounded-lg bg-brand-600 px-3 py-1.5 text-sm font-medium text-white transition hover:bg-brand-700 disabled:cursor-not-allowed disabled:opacity-50"
          >
            Adicionar marcados ({marcadosValidos.length})
          </button>
          <button
            type="button"
            disabled={disabled || visiveis.length === 0}
            onClick={() => adicionar(visiveis.map((h) => h.id))}
            className="rounded-lg border border-slate-300 bg-white px-3 py-1.5 text-sm font-medium text-slate-700 transition hover:bg-slate-50 disabled:cursor-not-allowed disabled:opacity-50"
          >
            Adicionar todos da lista
          </button>
        </div>
      </div>

      {/* Direita: escolhidos */}
      <div className="rounded-xl border border-slate-200 p-3">
        <div className="flex items-center justify-between">
          <h3 className="text-sm font-medium text-slate-700">
            Hinos executados ({selecionados.length}/{MAXIMO_HINOS})
          </h3>
          {selecionados.length > 0 && !disabled && (
            <button type="button" onClick={() => onChange([])} className="text-xs font-medium text-red-700 hover:underline">
              Limpar lista
            </button>
          )}
        </div>
        {selecionados.length === 0 ? (
          <p className="mt-3 rounded-lg bg-slate-50 px-3 py-6 text-center text-sm text-slate-500">
            Nenhum hino ainda. Dá para salvar assim e completar durante o ensaio.
          </p>
        ) : (
          <ol className="mt-2 max-h-80 divide-y divide-slate-100 overflow-y-auto rounded-lg border border-slate-100">
            {selecionados.map((id, indice) => {
              const hino = porId.get(id);
              const texto = hino ? rotuloCompleto(hino) : "Hino removido do cadastro";
              return (
                <li key={id} className="flex items-center gap-2 px-3 py-1.5 text-sm">
                  <span className="w-6 shrink-0 text-right tabular-nums text-slate-400">{indice + 1}.</span>
                  <span className="min-w-0 flex-1 truncate text-slate-800">{texto}</span>
                  {!disabled && (
                    <span className="flex shrink-0">
                      <BotaoIcone
                        icone={ArrowUp}
                        rotulo={`Subir ${hino ? rotuloHino(hino.categoria, hino.numero) : "hino"}`}
                        onClick={() => onChange(moverHino(selecionados, indice, -1))}
                      />
                      <BotaoIcone
                        icone={ArrowDown}
                        rotulo={`Descer ${hino ? rotuloHino(hino.categoria, hino.numero) : "hino"}`}
                        onClick={() => onChange(moverHino(selecionados, indice, 1))}
                      />
                      <BotaoIcone
                        icone={X}
                        variante="perigo"
                        rotulo={`Remover ${hino ? rotuloHino(hino.categoria, hino.numero) : "hino"}`}
                        onClick={() => onChange(removerHinos(selecionados, [id]))}
                      />
                    </span>
                  )}
                </li>
              );
            })}
          </ol>
        )}
      </div>
    </div>
  );
}
