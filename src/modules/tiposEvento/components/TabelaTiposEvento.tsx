"use client";

/**
 * SysMúsica — Tabela de tipos de evento, com busca e botão de ativar/desativar.
 * Tipo já usado por algum evento não pode ser excluído (só desativado); o banco confere de novo.
 */
import { useState } from "react";
import { Pencil, Search, Trash2 } from "lucide-react";
import Badge from "@/components/ui/Badge";
import BotaoIcone from "@/components/ui/BotaoIcone";
import { filtrarTipos, rotuloDoModelo, type TipoEvento } from "../regras";

interface TabelaTiposEventoProps {
  tipos: TipoEvento[];
  podeEditar: boolean;
  podeExcluir: boolean;
  alternandoId: string | null; // tipo cujo status está sendo trocado (trava o botão)
  onEditar: (tipo: TipoEvento) => void;
  onExcluir: (tipo: TipoEvento) => void;
  onAlternar: (tipo: TipoEvento) => void;
}

const classeCabecalho = "px-4 py-3 text-left text-xs font-semibold uppercase tracking-wide text-slate-500";

export default function TabelaTiposEvento({
  tipos,
  podeEditar,
  podeExcluir,
  alternandoId,
  onEditar,
  onExcluir,
  onAlternar,
}: TabelaTiposEventoProps) {
  const [busca, setBusca] = useState("");
  const mostrarAcoes = podeEditar || podeExcluir;
  const filtrados = filtrarTipos(tipos, busca);

  return (
    <div className="overflow-hidden rounded-2xl border border-slate-200 bg-white shadow-sm">
      <div className="border-b border-slate-200 p-4">
        <div className="relative max-w-md">
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
            onChange={(e) => setBusca(e.target.value)}
            placeholder="Pesquisar tipo de evento..."
            className="w-full rounded-lg border border-slate-300 bg-white py-2 pl-9 pr-3 text-sm text-slate-900 placeholder:text-slate-400 shadow-sm focus:border-brand-500 focus:outline-none focus:ring-2 focus:ring-brand-200"
          />
        </div>
      </div>

      <div className="overflow-x-auto">
        <table className="min-w-full divide-y divide-slate-200 text-sm">
          <thead className="bg-slate-50">
            <tr>
              <th scope="col" className={classeCabecalho}>Tipo</th>
              <th scope="col" className={classeCabecalho}>Dados do Ensaio</th>
              <th scope="col" className={classeCabecalho + " text-right"}>Eventos</th>
              <th scope="col" className={classeCabecalho}>Status</th>
              {mostrarAcoes && <th scope="col" className={classeCabecalho + " text-right"}>Ações</th>}
            </tr>
          </thead>
          <tbody className="divide-y divide-slate-100">
            {filtrados.length === 0 ? (
              <tr>
                <td colSpan={mostrarAcoes ? 5 : 4} className="px-4 py-10 text-center text-sm text-slate-500">
                  Nenhum tipo de evento encontrado.
                </td>
              </tr>
            ) : (
              filtrados.map((tipo) => (
                <tr key={tipo.id} className="transition hover:bg-slate-50">
                  <td className="px-4 py-3">
                    <p className="font-medium text-slate-900">{tipo.nome}</p>
                    {tipo.descricao && <p className="text-xs text-slate-500">{tipo.descricao}</p>}
                  </td>
                  <td className="px-4 py-3">
                    <Badge variante={tipo.modelo_ensaio ? "marca" : "neutro"}>{rotuloDoModelo(tipo.modelo_ensaio)}</Badge>
                  </td>
                  <td className="px-4 py-3 text-right tabular-nums text-slate-700">{tipo.em_uso}</td>
                  <td className="px-4 py-3">
                    {podeEditar ? (
                      <button
                        type="button"
                        role="switch"
                        aria-checked={tipo.ativo}
                        aria-label={`${tipo.ativo ? "Desativar" : "Ativar"} ${tipo.nome}`}
                        disabled={alternandoId === tipo.id}
                        onClick={() => onAlternar(tipo)}
                        className={
                          "relative inline-flex h-6 w-11 items-center rounded-full transition disabled:opacity-50 " +
                          (tipo.ativo ? "bg-brand-600" : "bg-slate-300")
                        }
                      >
                        <span
                          className={
                            "inline-block h-5 w-5 transform rounded-full bg-white shadow transition " +
                            (tipo.ativo ? "translate-x-5" : "translate-x-0.5")
                          }
                        />
                      </button>
                    ) : (
                      <Badge variante={tipo.ativo ? "sucesso" : "neutro"}>{tipo.ativo ? "Ativo" : "Inativo"}</Badge>
                    )}
                  </td>
                  {mostrarAcoes && (
                    <td className="px-4 py-3">
                      <div className="flex justify-end gap-1">
                        {podeEditar && (
                          <BotaoIcone icone={Pencil} rotulo={`Editar ${tipo.nome}`} onClick={() => onEditar(tipo)} />
                        )}
                        {podeExcluir && tipo.em_uso === 0 && (
                          <BotaoIcone
                            icone={Trash2}
                            variante="perigo"
                            rotulo={`Excluir ${tipo.nome}`}
                            onClick={() => onExcluir(tipo)}
                          />
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

      <div className="border-t border-slate-200 bg-slate-50 px-4 py-3 text-xs text-slate-500">
        Exibindo {filtrados.length} de {tipos.length} tipo(s)
      </div>
    </div>
  );
}
