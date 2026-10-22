"use client";

/**
 * Sysmusica — Lista de tipos de evento (cartão da esquerda): busca, tabela, ativar/desativar, editar, excluir
 * e paginação (8 por página). Tipo já usado por algum evento não pode ser excluído (só desativado);
 * o banco confere de novo.
 */
import { useState } from "react";
import { CalendarDays, ChevronLeft, ChevronRight, Pencil, Search, Trash2 } from "lucide-react";
import Badge from "@/components/ui/Badge";
import { cn } from "@/lib/cn";
import { filtrarTipos, paginar, paginasVisiveis, rotuloDoModelo, type TipoEvento } from "../regras";

interface TabelaTiposEventoProps {
  tipos: TipoEvento[];
  podeEditar: boolean;
  podeExcluir: boolean;
  alternandoId: string | null; // tipo cujo status está sendo trocado (trava o botão)
  editandoId: string | null; // tipo que está aberto no formulário (linha destacada)
  onEditar: (tipo: TipoEvento) => void;
  onExcluir: (tipo: TipoEvento) => void;
  onAlternar: (tipo: TipoEvento) => void;
}

const TAMANHO_PAGINA = 8;
const classeCabecalho = "px-4 py-3 text-left text-sm font-semibold text-slate-800";
const classeBotaoPagina =
  "inline-flex h-9 min-w-9 items-center justify-center rounded-lg border border-slate-200 bg-white px-2 text-sm font-medium text-slate-600 transition hover:bg-slate-50 focus:outline-none focus-visible:ring-2 focus-visible:ring-brand-300 disabled:cursor-not-allowed disabled:opacity-40";

export default function TabelaTiposEvento({
  tipos,
  podeEditar,
  podeExcluir,
  alternandoId,
  editandoId,
  onEditar,
  onExcluir,
  onAlternar,
}: TabelaTiposEventoProps) {
  const [busca, setBusca] = useState("");
  const [pagina, setPagina] = useState(1);
  const mostrarAcoes = podeEditar || podeExcluir;
  const filtrados = filtrarTipos(tipos, busca);
  const pag = paginar(filtrados, pagina, TAMANHO_PAGINA);
  const inicio = (pag.pagina - 1) * TAMANHO_PAGINA;
  const colunas = mostrarAcoes ? 6 : 5;

  return (
    <section className="overflow-hidden rounded-xl border border-slate-200 bg-white shadow-sm">
      <header className="flex items-center gap-2 border-b border-slate-200 bg-brand-50 px-5 py-3.5">
        <CalendarDays className="h-5 w-5 text-brand-700" aria-hidden="true" />
        <h2 className="text-base font-semibold text-slate-900">Lista de Tipos de Evento</h2>
      </header>

      <div className="p-4">
        <div className="relative">
          <label htmlFor="busca-tipo" className="sr-only">
            Pesquisar tipo de evento
          </label>
          <Search
            className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-slate-400"
            aria-hidden="true"
          />
          <input
            id="busca-tipo"
            type="search"
            autoComplete="off"
            value={busca}
            onChange={(e) => {
              setBusca(e.target.value);
              setPagina(1); // nova busca volta para a primeira página
            }}
            placeholder="Pesquisar tipo de evento..."
            className="w-full rounded-lg border border-slate-300 bg-white py-2.5 pl-9 pr-3 text-sm text-slate-900 placeholder:text-slate-400 focus:border-brand-500 focus:outline-none focus:ring-2 focus:ring-brand-200"
          />
        </div>

        <div className="mt-4 overflow-x-auto rounded-lg border border-slate-200">
          <table className="min-w-full divide-y divide-slate-200 text-sm">
            <thead className="bg-slate-50">
              <tr>
                <th scope="col" className={cn(classeCabecalho, "w-14")}>N°</th>
                <th scope="col" className={classeCabecalho}>Tipo de Evento</th>
                <th scope="col" className={classeCabecalho}>Descrição</th>
                <th scope="col" className={classeCabecalho}>Dados do Ensaio</th>
                <th scope="col" className={classeCabecalho}>Status</th>
                {mostrarAcoes && <th scope="col" className={cn(classeCabecalho, "text-center")}>Ações</th>}
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100">
              {pag.itens.length === 0 ? (
                <tr>
                  <td colSpan={colunas} className="px-4 py-10 text-center text-sm text-slate-500">
                    {tipos.length === 0 ? "Nenhum tipo de evento cadastrado." : "Nenhum tipo de evento encontrado."}
                  </td>
                </tr>
              ) : (
                pag.itens.map((tipo, indice) => (
                  <tr
                    key={tipo.id}
                    className={cn("transition hover:bg-slate-50", editandoId === tipo.id && "bg-brand-50")}
                  >
                    <td className="px-4 py-3 tabular-nums text-slate-600">{inicio + indice + 1}</td>
                    <td className="px-4 py-3 font-medium text-slate-900">{tipo.nome}</td>
                    <td className="px-4 py-3 text-slate-600">{tipo.descricao ?? "—"}</td>
                    <td className="px-4 py-3">
                      <Badge variante={tipo.modelo_ensaio ? "marca" : "neutro"}>{rotuloDoModelo(tipo.modelo_ensaio)}</Badge>
                    </td>
                    <td className="px-4 py-3">
                      <div className="flex items-center gap-2">
                        {podeEditar ? (
                          <button
                            type="button"
                            role="switch"
                            aria-checked={tipo.ativo}
                            aria-label={`${tipo.ativo ? "Desativar" : "Ativar"} ${tipo.nome}`}
                            disabled={alternandoId === tipo.id}
                            onClick={() => onAlternar(tipo)}
                            className={cn(
                              "relative inline-flex h-6 w-11 shrink-0 items-center rounded-full transition focus:outline-none focus-visible:ring-2 focus-visible:ring-brand-300 disabled:opacity-50",
                              tipo.ativo ? "bg-emerald-500" : "bg-slate-300"
                            )}
                          >
                            <span
                              className={cn(
                                "inline-block h-5 w-5 transform rounded-full bg-white shadow transition",
                                tipo.ativo ? "translate-x-5" : "translate-x-0.5"
                              )}
                            />
                          </button>
                        ) : null}
                        <span className="text-slate-700">{tipo.ativo ? "Ativo" : "Inativo"}</span>
                      </div>
                    </td>
                    {mostrarAcoes && (
                      <td className="px-4 py-3">
                        <div className="flex items-center justify-center gap-1">
                          {podeEditar && (
                            <button
                              type="button"
                              title={`Editar ${tipo.nome}`}
                              aria-label={`Editar ${tipo.nome}`}
                              onClick={() => onEditar(tipo)}
                              className="inline-flex h-8 w-8 items-center justify-center rounded-lg text-brand-600 transition hover:bg-brand-50 focus:outline-none focus-visible:ring-2 focus-visible:ring-brand-300"
                            >
                              <Pencil className="h-4 w-4" aria-hidden="true" />
                            </button>
                          )}
                          {podeExcluir && (
                            <button
                              type="button"
                              title={
                                tipo.em_uso === 0
                                  ? `Excluir ${tipo.nome}`
                                  : `${tipo.nome} é usado em ${tipo.em_uso} evento(s) e não pode ser excluído: desative-o`
                              }
                              aria-label={`Excluir ${tipo.nome}`}
                              disabled={tipo.em_uso > 0}
                              onClick={() => onExcluir(tipo)}
                              className="inline-flex h-8 w-8 items-center justify-center rounded-lg text-red-600 transition hover:bg-red-50 focus:outline-none focus-visible:ring-2 focus-visible:ring-red-300 disabled:cursor-not-allowed disabled:opacity-30 disabled:hover:bg-transparent"
                            >
                              <Trash2 className="h-4 w-4" aria-hidden="true" />
                            </button>
                          )}
                        </div>
                      </td>
                    )}
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>

        <div className="mt-4 flex flex-wrap items-center justify-between gap-3">
          <p className="text-sm text-slate-600">
            {busca.trim() === ""
              ? `Total: ${tipos.length} tipo(s) de evento`
              : `Exibindo ${filtrados.length} de ${tipos.length} tipo(s) de evento`}
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
