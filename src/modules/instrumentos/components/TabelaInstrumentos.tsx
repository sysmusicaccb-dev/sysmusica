"use client";

/**
 * SysMúsica — Tabela de instrumentos e famílias, com busca por nome.
 * Ações por linha (só aparecem para quem tem a permissão): editar e excluir.
 * A família é corrigida no formulário de edição (painel lateral).
 */
import { useState } from "react";
import { Pencil, Search, Trash2 } from "lucide-react";
import Badge from "@/components/ui/Badge";
import IlustracaoInstrumento from "./IlustracaoInstrumento";
import BotaoIcone from "@/components/ui/BotaoIcone";
import { normalizarTexto } from "@/lib/texto";
import type { Familia, Instrumento } from "@/types/database";

interface TabelaInstrumentosProps {
  instrumentos: Instrumento[];
  familias: Familia[];
  podeEditar: boolean;
  podeExcluir: boolean;
  onEditar: (instrumento: Instrumento) => void;
  onExcluir: (instrumento: Instrumento) => void;
}

const classeCabecalho =
  "px-4 py-3 text-left text-xs font-semibold uppercase tracking-wide text-slate-500";

export default function TabelaInstrumentos({
  instrumentos,
  familias,
  podeEditar,
  podeExcluir,
  onEditar,
  onExcluir,
}: TabelaInstrumentosProps) {
  const [busca, setBusca] = useState("");
  const mostrarAcoes = podeEditar || podeExcluir;

  const termo = normalizarTexto(busca);
  const filtrados = instrumentos.filter(
    (instrumento) => termo === "" || normalizarTexto(instrumento.nome).includes(termo)
  );

  return (
    <div className="overflow-hidden rounded-2xl border border-slate-200 bg-white shadow-sm">
      {/* Barra de ferramentas */}
      <div className="border-b border-slate-200 p-4">
        <div className="relative max-w-md">
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
            onChange={(e) => setBusca(e.target.value)}
            placeholder="Pesquisar instrumento..."
            className="w-full rounded-lg border border-slate-300 bg-white py-2 pl-9 pr-3 text-sm text-slate-900 placeholder:text-slate-400 shadow-sm focus:border-brand-500 focus:outline-none focus:ring-2 focus:ring-brand-200"
          />
        </div>
      </div>

      <div className="overflow-x-auto">
        <table className="min-w-full divide-y divide-slate-200 text-sm">
          <thead className="bg-slate-50">
            <tr>
              <th scope="col" className={classeCabecalho}>
                Instrumento
              </th>
              <th scope="col" className={classeCabecalho}>
                Família
              </th>
              {mostrarAcoes && (
                <th scope="col" className={classeCabecalho + " text-right"}>
                  Ações
                </th>
              )}
            </tr>
          </thead>
          <tbody className="divide-y divide-slate-100">
            {filtrados.length === 0 ? (
              <tr>
                <td colSpan={mostrarAcoes ? 3 : 2} className="px-4 py-10 text-center text-sm text-slate-500">
                  Nenhum instrumento encontrado.
                </td>
              </tr>
            ) : (
              filtrados.map((instrumento) => {
                const familia = familias.find((item) => item.id === instrumento.familia_id);

                return (
                  <tr key={instrumento.id} className="transition hover:bg-slate-50">
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
                        <div className="flex justify-end gap-1">
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

      <div className="border-t border-slate-200 bg-slate-50 px-4 py-3 text-xs text-slate-500">
        Exibindo {filtrados.length} de {instrumentos.length} instrumento(s)
      </div>
    </div>
  );
}
