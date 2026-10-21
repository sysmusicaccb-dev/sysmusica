"use client";

/**
 * SysMúsica — Tabela de hinos e coros: filtro Todos | Hinos | Coros, busca (número ou título) e status.
 * Hino já usado em ensaio não pode ser excluído (só desativado).
 */
import { useMemo, useState } from "react";
import { Pencil, Search, Trash2 } from "lucide-react";
import Badge from "@/components/ui/Badge";
import BotaoIcone from "@/components/ui/BotaoIcone";
import { filtrarHinos, rotuloHino, type Hino } from "../regras";

type Filtro = "TODOS" | "HINO" | "CORO";

interface TabelaHinosProps {
  hinos: Hino[];
  podeEditar: boolean;
  podeExcluir: boolean;
  alternandoId: string | null;
  onEditar: (hino: Hino) => void;
  onExcluir: (hino: Hino) => void;
  onAlternar: (hino: Hino) => void;
}

const classeCabecalho = "px-4 py-3 text-left text-xs font-semibold uppercase tracking-wide text-slate-500";
const FILTROS: { valor: Filtro; rotulo: string }[] = [
  { valor: "TODOS", rotulo: "Todos" },
  { valor: "HINO", rotulo: "Hinos" },
  { valor: "CORO", rotulo: "Coros" },
];
const POR_PAGINA = 100; // evita desenhar milhares de linhas de uma vez

export default function TabelaHinos({ hinos, podeEditar, podeExcluir, alternandoId, onEditar, onExcluir, onAlternar }: TabelaHinosProps) {
  const [busca, setBusca] = useState("");
  const [filtro, setFiltro] = useState<Filtro>("TODOS");
  const [limite, setLimite] = useState(POR_PAGINA);
  const mostrarAcoes = podeEditar || podeExcluir;

  const filtrados = useMemo(
    () => filtrarHinos(filtro === "TODOS" ? hinos : hinos.filter((h) => h.categoria === filtro), busca),
    [hinos, filtro, busca]
  );
  const visiveis = filtrados.slice(0, limite);

  return (
    <div className="overflow-hidden rounded-2xl border border-slate-200 bg-white shadow-sm">
      <div className="flex flex-col gap-3 border-b border-slate-200 p-4 sm:flex-row sm:items-center sm:justify-between">
        <div className="relative w-full max-w-md">
          <label htmlFor="busca-hino" className="sr-only">
            Pesquisar hino por número ou título
          </label>
          <Search
            className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-slate-400"
            aria-hidden="true"
          />
          <input
            id="busca-hino"
            type="search"
            autoComplete="off"
            value={busca}
            onChange={(e) => {
              setBusca(e.target.value);
              setLimite(POR_PAGINA);
            }}
            placeholder="Pesquisar por número ou título..."
            className="w-full rounded-lg border border-slate-300 bg-white py-2 pl-9 pr-3 text-sm text-slate-900 placeholder:text-slate-400 shadow-sm focus:border-brand-500 focus:outline-none focus:ring-2 focus:ring-brand-200"
          />
        </div>
        <div role="group" aria-label="Filtrar por categoria" className="flex gap-1">
          {FILTROS.map((item) => (
            <button
              key={item.valor}
              type="button"
              aria-pressed={filtro === item.valor}
              onClick={() => {
                setFiltro(item.valor);
                setLimite(POR_PAGINA);
              }}
              className={
                "rounded-lg px-3 py-1.5 text-sm font-medium transition " +
                (filtro === item.valor ? "bg-brand-600 text-white" : "bg-slate-100 text-slate-700 hover:bg-slate-200")
              }
            >
              {item.rotulo}
            </button>
          ))}
        </div>
      </div>

      <div className="overflow-x-auto">
        <table className="min-w-full divide-y divide-slate-200 text-sm">
          <thead className="bg-slate-50">
            <tr>
              <th scope="col" className={classeCabecalho}>Nº</th>
              <th scope="col" className={classeCabecalho}>Título</th>
              <th scope="col" className={classeCabecalho + " text-right"}>Usado em</th>
              <th scope="col" className={classeCabecalho}>Status</th>
              {mostrarAcoes && <th scope="col" className={classeCabecalho + " text-right"}>Ações</th>}
            </tr>
          </thead>
          <tbody className="divide-y divide-slate-100">
            {visiveis.length === 0 ? (
              <tr>
                <td colSpan={mostrarAcoes ? 5 : 4} className="px-4 py-10 text-center text-sm text-slate-500">
                  Nenhum hino encontrado.
                </td>
              </tr>
            ) : (
              visiveis.map((hino) => {
                const rotulo = rotuloHino(hino.categoria, hino.numero);
                return (
                  <tr key={hino.id} className="transition hover:bg-slate-50">
                    <td className="whitespace-nowrap px-4 py-3 font-semibold tabular-nums text-slate-900">{rotulo}</td>
                    <td className="px-4 py-3 text-slate-800">{hino.nome}</td>
                    <td className="px-4 py-3 text-right tabular-nums text-slate-700">{hino.em_uso}</td>
                    <td className="px-4 py-3">
                      {podeEditar ? (
                        <button
                          type="button"
                          role="switch"
                          aria-checked={hino.ativo}
                          aria-label={`${hino.ativo ? "Desativar" : "Ativar"} ${rotulo}`}
                          disabled={alternandoId === hino.id}
                          onClick={() => onAlternar(hino)}
                          className={
                            "relative inline-flex h-6 w-11 items-center rounded-full transition disabled:opacity-50 " +
                            (hino.ativo ? "bg-brand-600" : "bg-slate-300")
                          }
                        >
                          <span
                            className={
                              "inline-block h-5 w-5 transform rounded-full bg-white shadow transition " +
                              (hino.ativo ? "translate-x-5" : "translate-x-0.5")
                            }
                          />
                        </button>
                      ) : (
                        <Badge variante={hino.ativo ? "sucesso" : "neutro"}>{hino.ativo ? "Ativo" : "Inativo"}</Badge>
                      )}
                    </td>
                    {mostrarAcoes && (
                      <td className="px-4 py-3">
                        <div className="flex justify-end gap-1">
                          {podeEditar && <BotaoIcone icone={Pencil} rotulo={`Editar ${rotulo}`} onClick={() => onEditar(hino)} />}
                          {podeExcluir && hino.em_uso === 0 && (
                            <BotaoIcone icone={Trash2} variante="perigo" rotulo={`Excluir ${rotulo}`} onClick={() => onExcluir(hino)} />
                          )}
                        </div>
                      </td>
                    )}
                  </tr>
                );
              })
            )}
          </tbody>
        </table>
      </div>

      <div className="flex items-center justify-between border-t border-slate-200 bg-slate-50 px-4 py-3 text-xs text-slate-500">
        <span>
          Exibindo {visiveis.length} de {filtrados.length} ({hinos.length} no total)
        </span>
        {filtrados.length > visiveis.length && (
          <button type="button" onClick={() => setLimite((l) => l + POR_PAGINA)} className="font-medium text-brand-700 hover:underline">
            Mostrar mais
          </button>
        )}
      </div>
    </div>
  );
}
