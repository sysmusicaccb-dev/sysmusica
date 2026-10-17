"use client";

/**
 * SysMúsica — Tabela de instrumentos e famílias, com busca por nome.
 *
 * Qualquer pessoa vê a classificação. Só quem tem "podeEditar" (administrador) vê o select para
 * corrigir a família; o banco impõe a regra de verdade (política admin_update_instrumentos).
 */
import { useState } from "react";
import { Search } from "lucide-react";
import Badge from "@/components/ui/Badge";
import { normalizarTexto } from "@/lib/texto";
import type { Familia, Instrumento } from "@/types/database";

interface TabelaInstrumentosProps {
  instrumentos: Instrumento[];
  familias: Familia[];
  podeEditar: boolean;
  salvandoId: string | null; // instrumento sendo salvo agora (desabilita o select dele)
  erroEdicao: string | null;
  onAlterarFamilia: (instrumento: Instrumento, novaFamiliaId: string) => void;
}

const classeCabecalho =
  "px-4 py-3 text-left text-xs font-semibold uppercase tracking-wide text-slate-500";

export default function TabelaInstrumentos({
  instrumentos,
  familias,
  podeEditar,
  salvandoId,
  erroEdicao,
  onAlterarFamilia,
}: TabelaInstrumentosProps) {
  const [busca, setBusca] = useState("");

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

      {erroEdicao && (
        <p role="alert" className="border-b border-red-100 bg-red-50 px-4 py-3 text-sm text-red-700">
          {erroEdicao}
        </p>
      )}

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
            </tr>
          </thead>
          <tbody className="divide-y divide-slate-100">
            {filtrados.length === 0 ? (
              <tr>
                <td colSpan={2} className="px-4 py-10 text-center text-sm text-slate-500">
                  Nenhum instrumento encontrado.
                </td>
              </tr>
            ) : (
              filtrados.map((instrumento) => {
                const familia = familias.find((item) => item.id === instrumento.familia_id);

                return (
                  <tr key={instrumento.id} className="transition hover:bg-slate-50">
                    <td className="px-4 py-3 font-medium text-slate-900">{instrumento.nome}</td>
                    <td className="px-4 py-3">
                      {podeEditar ? (
                        // Administrador: pode corrigir a família
                        <select
                          aria-label={`Família de ${instrumento.nome}`}
                          value={instrumento.familia_id ?? ""}
                          onChange={(e) => onAlterarFamilia(instrumento, e.target.value)}
                          disabled={salvandoId === instrumento.id}
                          className="w-full max-w-[14rem] rounded-lg border border-slate-300 bg-white px-3 py-1.5 text-sm text-slate-900 shadow-sm focus:border-brand-500 focus:outline-none focus:ring-2 focus:ring-brand-200 disabled:opacity-60"
                        >
                          <option value="">Não classificada</option>
                          {familias.map((item) => (
                            <option key={item.id} value={item.id}>
                              {item.nome}
                            </option>
                          ))}
                        </select>
                      ) : familia ? (
                        <Badge variante="marca">{familia.nome}</Badge>
                      ) : (
                        <Badge variante="alerta">Não classificada</Badge>
                      )}
                    </td>
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
