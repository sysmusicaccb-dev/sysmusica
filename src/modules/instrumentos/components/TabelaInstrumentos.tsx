"use client";

/**
 * Sysmusica — Lista de instrumentos e famílias: filtro por família (com a quantidade de cada uma), busca por nome,
 * tabela e paginação (10 por página). Ações por linha (só para quem tem a permissão): editar e excluir.
 * A família é corrigida no formulário de edição (painel lateral).
 */
import { useState } from "react";
import { ChevronLeft, ChevronRight, Guitar, Pencil, Search, Trash2 } from "lucide-react";
import Badge from "@/components/ui/Badge";
import BotaoIcone from "@/components/ui/BotaoIcone";
import { cn } from "@/lib/cn";
import { normalizarTexto } from "@/lib/texto";
import { paginar, paginasVisiveis } from "@/modules/tiposEvento/regras";
import type { Familia, Instrumento } from "@/types/database";
import IlustracaoInstrumento from "./IlustracaoInstrumento";

interface TabelaInstrumentosProps {
  instrumentos: Instrumento[];
  familias: Familia[];
  podeEditar: boolean;
  podeExcluir: boolean;
  onEditar: (instrumento: Instrumento) => void;
  onExcluir: (instrumento: Instrumento) => void;
}

const TAMANHO_PAGINA = 10;
const SEM_FAMILIA = "__sem_familia"; // filtro "Não classificada"
const classeCabecalho = "px-4 py-3 text-left text-sm font-semibold text-slate-800";
const classeBotaoPagina =
  "inline-flex h-9 min-w-9 items-center justify-center rounded-lg border border-slate-200 bg-white px-2 text-sm font-medium text-slate-600 transition hover:bg-slate-50 focus:outline-none focus-visible:ring-2 focus-visible:ring-brand-300 disabled:cursor-not-allowed disabled:opacity-40";

export default function TabelaInstrumentos({
  instrumentos,
  familias,
  podeEditar,
  podeExcluir,
  onEditar,
  onExcluir,
}: TabelaInstrumentosProps) {
  const [busca, setBusca] = useState("");
  const [filtro, setFiltro] = useState(""); // "" = todas as famílias
  const [pagina, setPagina] = useState(1);
  const mostrarAcoes = podeEditar || podeExcluir;

  // Quantidade de instrumentos de cada família (para os botões de filtro)
  const semFamilia = instrumentos.filter((i) => !familias.some((f) => f.id === i.familia_id)).length;
  const opcoesFiltro = [
    { valor: "", rotulo: "Todas", qtd: instrumentos.length },
    ...familias.map((f) => ({ valor: f.id, rotulo: f.nome, qtd: instrumentos.filter((i) => i.familia_id === f.id).length })),
    ...(semFamilia > 0 ? [{ valor: SEM_FAMILIA, rotulo: "Não classificada", qtd: semFamilia }] : []),
  ];

  const termo = normalizarTexto(busca);
  const filtrados = instrumentos.filter((instrumento) => {
    if (termo !== "" && !normalizarTexto(instrumento.nome).includes(termo)) return false;
    if (filtro === "") return true;
    if (filtro === SEM_FAMILIA) return !familias.some((f) => f.id === instrumento.familia_id);
    return instrumento.familia_id === filtro;
  });
  const pag = paginar(filtrados, pagina, TAMANHO_PAGINA);
  const inicio = (pag.pagina - 1) * TAMANHO_PAGINA;
  const colunas = mostrarAcoes ? 4 : 3;

  return (
    <section className="overflow-hidden rounded-xl border border-slate-200 bg-white shadow-sm">
      <header className="flex items-center gap-2 border-b border-slate-200 bg-brand-50 px-5 py-3.5">
        <Guitar className="h-5 w-5 text-brand-700" aria-hidden="true" />
        <h2 className="text-base font-semibold text-slate-900">Lista de Instrumentos</h2>
      </header>

      <div className="p-4">
        {/* Filtro por família */}
        <div className="mb-4 flex flex-wrap gap-2" role="group" aria-label="Filtrar por família">
          {opcoesFiltro.map((opcao) => (
            <button
              key={opcao.valor || "todas"}
              type="button"
              aria-pressed={filtro === opcao.valor}
              onClick={() => {
                setFiltro(opcao.valor);
                setPagina(1);
              }}
              className={cn(
                "inline-flex items-center gap-1.5 rounded-full border px-3 py-1 text-sm font-medium transition focus:outline-none focus-visible:ring-2 focus-visible:ring-brand-300",
                filtro === opcao.valor
                  ? "border-brand-600 bg-brand-600 text-white"
                  : "border-slate-200 bg-white text-slate-700 hover:bg-slate-50"
              )}
            >
              {opcao.rotulo}
              <span className={cn("tabular-nums", filtro === opcao.valor ? "text-white" : "text-slate-500")}>
                {opcao.qtd}
              </span>
            </button>
          ))}
        </div>

        <div className="relative">
          <label htmlFor="busca-instrumento" className="sr-only">
            Pesquisar instrumento
          </label>
          <Search
            className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-slate-400"
            aria-hidden="true"
          />
          <input
            id="busca-instrumento"
            type="search"
            autoComplete="off"
            value={busca}
            onChange={(e) => {
              setBusca(e.target.value);
              setPagina(1); // nova busca volta para a primeira página
            }}
            placeholder="Pesquisar instrumento..."
            className="w-full rounded-lg border border-slate-300 bg-white py-2.5 pl-9 pr-3 text-sm text-slate-900 placeholder:text-slate-400 focus:border-brand-500 focus:outline-none focus:ring-2 focus:ring-brand-200"
          />
        </div>

        <div className="mt-4 overflow-x-auto rounded-lg border border-slate-200">
          <table className="min-w-full divide-y divide-slate-200 text-sm">
            <thead className="bg-slate-50">
              <tr>
                <th scope="col" className={cn(classeCabecalho, "w-14")}>
                  N°
                </th>
                <th scope="col" className={classeCabecalho}>
                  Instrumento
                </th>
                <th scope="col" className={classeCabecalho}>
                  Família
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
                    Nenhum instrumento encontrado.
                  </td>
                </tr>
              ) : (
                pag.itens.map((instrumento, indice) => {
                  const familia = familias.find((item) => item.id === instrumento.familia_id);
                  return (
                    <tr key={instrumento.id} className="transition hover:bg-slate-50">
                      <td className="px-4 py-3 tabular-nums text-slate-600">{inicio + indice + 1}</td>
                      <td className="px-4 py-3 font-medium text-slate-900">
                        <div className="flex items-center gap-3">
                          {/* Ilustração pelo nome do instrumento (genérica da família quando não há desenho próprio) */}
                          <IlustracaoInstrumento nome={instrumento.nome} familia={familia?.nome} />
                          {instrumento.nome}
                        </div>
                      </td>
                      <td className="px-4 py-3">
                        {familia ? (
                          <Badge variante="marca">{familia.nome}</Badge>
                        ) : (
                          <Badge variante="alerta">Não classificada</Badge>
                        )}
                      </td>
                      {mostrarAcoes && (
                        <td className="px-4 py-3">
                          <div className="flex items-center justify-center gap-1">
                            {podeEditar && (
                              <BotaoIcone
                                icone={Pencil}
                                rotulo={`Editar ${instrumento.nome}`}
                                onClick={() => onEditar(instrumento)}
                              />
                            )}
                            {podeExcluir && (
                              <BotaoIcone
                                icone={Trash2}
                                variante="perigo"
                                rotulo={`Excluir ${instrumento.nome}`}
                                onClick={() => onExcluir(instrumento)}
                              />
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
            {busca.trim() === "" && filtro === ""
              ? `Total: ${instrumentos.length} instrumento(s)`
              : `Exibindo ${filtrados.length} de ${instrumentos.length} instrumento(s)`}
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
