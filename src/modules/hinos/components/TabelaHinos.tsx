"use client";

/**
 * Sysmusica — Lista de hinos e coros: filtro Todos | Hinos | Coros (com a quantidade de cada um), busca (número ou
 * título), status e paginação (15 por página). Hino já usado em ensaio não pode ser excluído (só desativado).
 */
import { useMemo, useState } from "react";
import { BookOpen, ChevronLeft, ChevronRight, Pencil, Search, Trash2 } from "lucide-react";
import Badge from "@/components/ui/Badge";
import BotaoIcone from "@/components/ui/BotaoIcone";
import { cn } from "@/lib/cn";
import { paginar, paginasVisiveis } from "@/modules/tiposEvento/regras";
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

const TAMANHO_PAGINA = 15;
const classeCabecalho = "px-4 py-3 text-left text-sm font-semibold text-slate-800";
const classeBotaoPagina =
  "inline-flex h-9 min-w-9 items-center justify-center rounded-lg border border-slate-200 bg-white px-2 text-sm font-medium text-slate-600 transition hover:bg-slate-50 focus:outline-none focus-visible:ring-2 focus-visible:ring-brand-300 disabled:cursor-not-allowed disabled:opacity-40";

export default function TabelaHinos({ hinos, podeEditar, podeExcluir, alternandoId, onEditar, onExcluir, onAlternar }: TabelaHinosProps) {
  const [busca, setBusca] = useState("");
  const [filtro, setFiltro] = useState<Filtro>("TODOS");
  const [pagina, setPagina] = useState(1);
  const mostrarAcoes = podeEditar || podeExcluir;

  const qtdHinos = hinos.filter((h) => h.categoria === "HINO").length;
  const qtdCoros = hinos.filter((h) => h.categoria === "CORO").length;
  const filtros: { valor: Filtro; rotulo: string; qtd: number }[] = [
    { valor: "TODOS", rotulo: "Todos", qtd: hinos.length },
    { valor: "HINO", rotulo: "Hinos", qtd: qtdHinos },
    { valor: "CORO", rotulo: "Coros", qtd: qtdCoros },
  ];

  const filtrados = useMemo(
    () => filtrarHinos(filtro === "TODOS" ? hinos : hinos.filter((h) => h.categoria === filtro), busca),
    [hinos, filtro, busca]
  );
  const pag = paginar(filtrados, pagina, TAMANHO_PAGINA);
  const colunas = mostrarAcoes ? 5 : 4;

  return (
    <section className="overflow-hidden rounded-xl border border-slate-200 bg-white shadow-sm">
      <header className="flex items-center gap-2 border-b border-slate-200 bg-brand-50 px-5 py-3.5">
        <BookOpen className="h-5 w-5 text-brand-700" aria-hidden="true" />
        <h2 className="text-base font-semibold text-slate-900">Lista de Hinos e Coros</h2>
      </header>

      <div className="p-4">
        <div role="group" aria-label="Filtrar por categoria" className="mb-4 flex flex-wrap gap-2">
          {filtros.map((item) => (
            <button
              key={item.valor}
              type="button"
              aria-pressed={filtro === item.valor}
              onClick={() => {
                setFiltro(item.valor);
                setPagina(1);
              }}
              className={cn(
                "inline-flex items-center gap-1.5 rounded-full border px-3 py-1 text-sm font-medium transition focus:outline-none focus-visible:ring-2 focus-visible:ring-brand-300",
                filtro === item.valor
                  ? "border-brand-600 bg-brand-600 text-white"
                  : "border-slate-200 bg-white text-slate-700 hover:bg-slate-50"
              )}
            >
              {item.rotulo}
              <span className={cn("tabular-nums", filtro === item.valor ? "text-white" : "text-slate-500")}>{item.qtd}</span>
            </button>
          ))}
        </div>

        <div className="relative">
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
              setPagina(1); // nova busca volta para a primeira página
            }}
            placeholder="Pesquisar por número ou título..."
            className="w-full rounded-lg border border-slate-300 bg-white py-2.5 pl-9 pr-3 text-sm text-slate-900 placeholder:text-slate-400 focus:border-brand-500 focus:outline-none focus:ring-2 focus:ring-brand-200"
          />
        </div>

        <div className="mt-4 overflow-x-auto rounded-lg border border-slate-200">
          <table className="min-w-full divide-y divide-slate-200 text-sm">
            <thead className="bg-slate-50">
              <tr>
                <th scope="col" className={classeCabecalho}>
                  Nº
                </th>
                <th scope="col" className={classeCabecalho}>
                  Título
                </th>
                <th scope="col" className={cn(classeCabecalho, "text-right")}>
                  Usado em
                </th>
                <th scope="col" className={classeCabecalho}>
                  Status
                </th>
                {mostrarAcoes && (
                  <th scope="col" className={cn(classeCabecalho, "text-center")}>
                    Ações
                  </th>
                )}
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100">
              {pag.itens.length === 0 ? (
                <tr>
                  <td colSpan={colunas} className="px-4 py-10 text-center text-sm text-slate-500">
                    Nenhum hino encontrado.
                  </td>
                </tr>
              ) : (
                pag.itens.map((hino) => {
                  const rotulo = rotuloHino(hino.categoria, hino.numero);
                  return (
                    <tr key={hino.id} className="transition hover:bg-slate-50">
                      <td className="whitespace-nowrap px-4 py-3 font-semibold tabular-nums text-slate-900">{rotulo}</td>
                      <td className="px-4 py-3 text-slate-800">{hino.nome}</td>
                      <td className="px-4 py-3 text-right tabular-nums text-slate-700">{hino.em_uso}</td>
                      <td className="px-4 py-3">
                        <div className="flex items-center gap-2">
                          {podeEditar ? (
                            <button
                              type="button"
                              role="switch"
                              aria-checked={hino.ativo}
                              aria-label={`${hino.ativo ? "Desativar" : "Ativar"} ${rotulo}`}
                              disabled={alternandoId === hino.id}
                              onClick={() => onAlternar(hino)}
                              className={cn(
                                "relative inline-flex h-6 w-11 shrink-0 items-center rounded-full transition focus:outline-none focus-visible:ring-2 focus-visible:ring-brand-300 disabled:opacity-50",
                                hino.ativo ? "bg-emerald-500" : "bg-slate-300"
                              )}
                            >
                              <span
                                className={cn(
                                  "inline-block h-5 w-5 transform rounded-full bg-white shadow transition",
                                  hino.ativo ? "translate-x-5" : "translate-x-0.5"
                                )}
                              />
                            </button>
                          ) : null}
                          {podeEditar ? (
                            <span className="text-slate-700">{hino.ativo ? "Ativo" : "Inativo"}</span>
                          ) : (
                            <Badge variante={hino.ativo ? "sucesso" : "neutro"}>{hino.ativo ? "Ativo" : "Inativo"}</Badge>
                          )}
                        </div>
                      </td>
                      {mostrarAcoes && (
                        <td className="px-4 py-3">
                          <div className="flex items-center justify-center gap-1">
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

        <div className="mt-4 flex flex-wrap items-center justify-between gap-3">
          <p className="text-sm text-slate-600">
            {busca.trim() === "" && filtro === "TODOS"
              ? `Total: ${hinos.length} hino(s) e coro(s)`
              : `Exibindo ${filtrados.length} de ${hinos.length} cadastrado(s)`}
          </p>
          {pag.totalPaginas > 1 && (
            <nav aria-label="Páginas da lista" className="flex items-center gap-1">
              <button
                type="button"
                aria-label="Página anterior"
                disabled={pag.pagina === 1}
                onClick={() => setPagina(pag.pagina - 1)}
                className={classeBotaoPagina}
              >
                <ChevronLeft className="h-4 w-4" aria-hidden="true" />
              </button>
              {paginasVisiveis(pag.pagina, pag.totalPaginas).map((numero, i) =>
                numero === null ? (
                  <span key={`reticencias-${i}`} className="px-1 text-slate-400" aria-hidden="true">
                    …
                  </span>
                ) : (
                  <button
                    key={numero}
                    type="button"
                    aria-label={`Página ${numero}`}
                    aria-current={numero === pag.pagina ? "page" : undefined}
                    onClick={() => setPagina(numero)}
                    className={cn(
                      classeBotaoPagina,
                      numero === pag.pagina && "border-brand-600 bg-brand-600 text-white hover:bg-brand-600"
                    )}
                  >
                    {numero}
                  </button>
                )
              )}
              <button
                type="button"
                aria-label="Próxima página"
                disabled={pag.pagina === pag.totalPaginas}
                onClick={() => setPagina(pag.pagina + 1)}
                className={classeBotaoPagina}
              >
                <ChevronRight className="h-4 w-4" aria-hidden="true" />
              </button>
            </nav>
          )}
        </div>
      </div>
    </section>
  );
}
