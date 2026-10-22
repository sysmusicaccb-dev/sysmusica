"use client";

/**
 * Sysmusica — Escolha dos hinos executados no ensaio (duas listas, como no protótipo).
 * Esquerda: hinos ativos (com busca) para marcar. Meio: botões > (adicionar marcados), >> (adicionar todos da lista),
 * < (retirar os marcados da direita) e << (retirar todos). Direita: hinos selecionados, na ordem em que foram cantados
 * (dá para subir, descer e remover). Hino não se repete e o hino de abertura fica de fora.
 */
import { useMemo, useState } from "react";
import { ArrowDown, ArrowUp, ChevronLeft, ChevronRight, ChevronsLeft, ChevronsRight, Search, Trash2 } from "lucide-react";
import { cn } from "@/lib/cn";
import { filtrarHinos, rotuloHino, type Hino } from "@/modules/hinos/regras";
import { MAXIMO_HINOS, adicionarHinos, hinosDisponiveis, moverHino, removerHinos } from "../regras";
import { partesDoHino } from "../hinosApresentacao";

interface SeletorHinosProps {
  hinos: Hino[]; // todos
  selecionados: string[];
  abertura: string; // id do hino de abertura (fora da lista)
  onChange: (ids: string[]) => void;
  disabled?: boolean;
}

const LIMITE_LISTA = 60; // quantos hinos desenhar de uma vez na coluna da esquerda
const classeCabecalho = "px-3 py-2 text-left text-xs font-semibold text-slate-700";
const classeBotaoMeio =
  "inline-flex h-10 w-10 items-center justify-center rounded-lg bg-brand-600 text-white shadow-sm transition hover:bg-brand-500 focus:outline-none focus-visible:ring-2 focus-visible:ring-brand-300 disabled:cursor-not-allowed disabled:bg-slate-200 disabled:text-slate-400";

export default function SeletorHinos({ hinos, selecionados, abertura, onChange, disabled }: SeletorHinosProps) {
  const [busca, setBusca] = useState("");
  const [marcados, setMarcados] = useState<string[]>([]); // marcados na lista da esquerda
  const [marcadosDireita, setMarcadosDireita] = useState<string[]>([]); // marcados na lista da direita

  const porId = useMemo(() => new Map(hinos.map((h) => [h.id, h] as const)), [hinos]);
  const encontrados = useMemo(
    () => filtrarHinos(hinosDisponiveis(hinos, selecionados, abertura), busca),
    [hinos, selecionados, abertura, busca]
  );
  const visiveis = encontrados.slice(0, LIMITE_LISTA);
  const marcadosValidos = marcados.filter((id) => visiveis.some((h) => h.id === id));
  const marcadosDireitaValidos = marcadosDireita.filter((id) => selecionados.includes(id));

  function alternar(lista: string[], id: string): string[] {
    return lista.includes(id) ? lista.filter((x) => x !== id) : [...lista, id];
  }
  function adicionar(ids: string[]) {
    onChange(adicionarHinos(selecionados, ids, abertura));
    setMarcados([]);
  }
  function retirar(ids: string[]) {
    onChange(removerHinos(selecionados, ids));
    setMarcadosDireita([]);
  }

  return (
    <div className="grid items-center gap-3 lg:grid-cols-[minmax(0,1fr)_auto_minmax(0,1fr)]">
      {/* Esquerda: disponíveis */}
      <div className="min-w-0 self-stretch">
        <div className="relative">
          <label htmlFor="busca-hino-ensaio" className="sr-only">
            Pesquisar hino (número ou título)
          </label>
          <Search
            className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-slate-400"
            aria-hidden="true"
          />
          <input
            id="busca-hino-ensaio"
            type="search"
            autoComplete="off"
            value={busca}
            onChange={(e) => setBusca(e.target.value)}
            disabled={disabled}
            placeholder="Pesquisar hino (número ou título)..."
            className="w-full rounded-lg border border-slate-300 bg-white py-2 pl-9 pr-3 text-sm text-slate-900 placeholder:text-slate-400 focus:border-brand-500 focus:outline-none focus:ring-2 focus:ring-brand-200 disabled:opacity-60"
          />
        </div>
        <div className="mt-2 max-h-72 overflow-y-auto rounded-lg border border-slate-200">
          <table className="min-w-full text-sm" aria-label="Hinos disponíveis">
            <thead className="sticky top-0 bg-slate-50">
              <tr>
                <th scope="col" className="w-10 px-3 py-2" />
                <th scope="col" className={cn(classeCabecalho, "w-20")}>N°</th>
                <th scope="col" className={classeCabecalho}>Título do Hino</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100">
              {visiveis.length === 0 ? (
                <tr>
                  <td colSpan={3} className="px-3 py-6 text-center text-sm text-slate-500">
                    Nenhum hino disponível.
                  </td>
                </tr>
              ) : (
                visiveis.map((hino) => {
                  const { numero, titulo } = partesDoHino(hino);
                  return (
                    <tr key={hino.id} className="hover:bg-slate-50">
                      <td className="px-3 py-1.5">
                        <input
                          type="checkbox"
                          id={`hino-esq-${hino.id}`}
                          checked={marcados.includes(hino.id)}
                          onChange={() => setMarcados((atual) => alternar(atual, hino.id))}
                          disabled={disabled}
                          aria-label={`Marcar ${rotuloHino(hino.categoria, hino.numero)}`}
                          className="h-4 w-4 rounded border-slate-300"
                        />
                      </td>
                      <td className="px-3 py-1.5 tabular-nums text-slate-600">
                        <label htmlFor={`hino-esq-${hino.id}`} className="cursor-pointer">{numero}</label>
                      </td>
                      <td className="px-3 py-1.5 text-slate-800">
                        <label htmlFor={`hino-esq-${hino.id}`} className="cursor-pointer">{titulo}</label>
                      </td>
                    </tr>
                  );
                })
              )}
            </tbody>
          </table>
        </div>
        {encontrados.length > visiveis.length && (
          <p className="mt-1 text-xs text-slate-500">
            Mostrando {visiveis.length} de {encontrados.length}. Use a busca para achar os demais.
          </p>
        )}
      </div>

      {/* Meio: botões de passar de uma lista para a outra */}
      <div className="flex justify-center gap-2 lg:flex-col" role="group" aria-label="Mover hinos entre as listas">
        <button
          type="button"
          title="Adicionar os hinos marcados"
          aria-label="Adicionar os hinos marcados"
          disabled={disabled || marcadosValidos.length === 0}
          onClick={() => adicionar(marcadosValidos)}
          className={classeBotaoMeio}
        >
          <ChevronRight className="h-5 w-5" aria-hidden="true" />
        </button>
        <button
          type="button"
          title="Adicionar todos os hinos da lista"
          aria-label="Adicionar todos os hinos da lista"
          disabled={disabled || visiveis.length === 0}
          onClick={() => adicionar(visiveis.map((h) => h.id))}
          className={classeBotaoMeio}
        >
          <ChevronsRight className="h-5 w-5" aria-hidden="true" />
        </button>
        <button
          type="button"
          title="Retirar os hinos marcados na lista da direita"
          aria-label="Retirar os hinos marcados na lista da direita"
          disabled={disabled || marcadosDireitaValidos.length === 0}
          onClick={() => retirar(marcadosDireitaValidos)}
          className={classeBotaoMeio}
        >
          <ChevronLeft className="h-5 w-5" aria-hidden="true" />
        </button>
        <button
          type="button"
          title="Retirar todos os hinos selecionados"
          aria-label="Retirar todos os hinos selecionados"
          disabled={disabled || selecionados.length === 0}
          onClick={() => retirar(selecionados)}
          className={classeBotaoMeio}
        >
          <ChevronsLeft className="h-5 w-5" aria-hidden="true" />
        </button>
      </div>

      {/* Direita: selecionados */}
      <div className="min-w-0 self-stretch">
        <h3 className="mb-2 text-sm font-semibold text-slate-800">
          Hinos selecionados ({selecionados.length}/{MAXIMO_HINOS})
        </h3>
        <div className="max-h-72 min-h-40 overflow-y-auto rounded-lg border border-slate-200">
          {selecionados.length === 0 ? (
            <p className="px-3 py-8 text-center text-sm text-slate-500">
              Nenhum hino ainda. Dá para salvar assim e completar durante o ensaio.
            </p>
          ) : (
            <table className="min-w-full text-sm" aria-label="Hinos selecionados">
              <thead className="sticky top-0 bg-slate-50">
                <tr>
                  <th scope="col" className={cn(classeCabecalho, "w-8")}>#</th>
                  <th scope="col" className={cn(classeCabecalho, "w-16")}>N°</th>
                  <th scope="col" className={classeCabecalho}>Título do Hino</th>
                  {!disabled && <th scope="col" className="w-24 px-2 py-2"><span className="sr-only">Ações</span></th>}
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-100">
                {selecionados.map((id, indice) => {
                  const hino = porId.get(id);
                  const partes = hino ? partesDoHino(hino) : { numero: "—", titulo: "Hino removido do cadastro" };
                  const nome = hino ? rotuloHino(hino.categoria, hino.numero) : "hino";
                  const marcado = marcadosDireita.includes(id);
                  return (
                    <tr
                      key={id}
                      onClick={() => !disabled && setMarcadosDireita((atual) => alternar(atual, id))}
                      aria-selected={marcado}
                      className={cn(!disabled && "cursor-pointer", marcado ? "bg-brand-50" : "hover:bg-slate-50")}
                    >
                      <td className="px-3 py-1.5 tabular-nums text-slate-500">{indice + 1}</td>
                      <td className="px-3 py-1.5 tabular-nums text-slate-600">{partes.numero}</td>
                      <td className="px-3 py-1.5 text-slate-800">{partes.titulo}</td>
                      {!disabled && (
                        <td className="px-2 py-1.5">
                          <div className="flex justify-end gap-0.5" onClick={(e) => e.stopPropagation()}>
                            <button
                              type="button"
                              title={`Subir ${nome}`}
                              aria-label={`Subir ${nome}`}
                              disabled={indice === 0}
                              onClick={() => onChange(moverHino(selecionados, indice, -1))}
                              className="inline-flex h-7 w-7 items-center justify-center rounded text-slate-500 hover:bg-slate-100 disabled:opacity-30"
                            >
                              <ArrowUp className="h-4 w-4" aria-hidden="true" />
                            </button>
                            <button
                              type="button"
                              title={`Descer ${nome}`}
                              aria-label={`Descer ${nome}`}
                              disabled={indice === selecionados.length - 1}
                              onClick={() => onChange(moverHino(selecionados, indice, 1))}
                              className="inline-flex h-7 w-7 items-center justify-center rounded text-slate-500 hover:bg-slate-100 disabled:opacity-30"
                            >
                              <ArrowDown className="h-4 w-4" aria-hidden="true" />
                            </button>
                            <button
                              type="button"
                              title={`Remover ${nome}`}
                              aria-label={`Remover ${nome}`}
                              onClick={() => retirar([id])}
                              className="inline-flex h-7 w-7 items-center justify-center rounded text-red-600 hover:bg-red-50"
                            >
                              <Trash2 className="h-4 w-4" aria-hidden="true" />
                            </button>
                          </div>
                        </td>
                      )}
                    </tr>
                  );
                })}
              </tbody>
            </table>
          )}
        </div>
        {selecionados.length > 0 && !disabled && (
          <div className="mt-2 flex justify-end">
            <button
              type="button"
              onClick={() => retirar(selecionados)}
              className="inline-flex items-center gap-2 rounded-lg bg-red-50 px-3 py-1.5 text-sm font-medium text-red-700 transition hover:bg-red-100 focus:outline-none focus-visible:ring-2 focus-visible:ring-red-300"
            >
              <Trash2 className="h-4 w-4" aria-hidden="true" />
              Limpar todos
            </button>
          </div>
        )}
        <p className="mt-1 text-xs text-slate-500">Clique em uma linha para marcá-la e use o botão &lt; para retirá-la.</p>
      </div>
    </div>
  );
}
