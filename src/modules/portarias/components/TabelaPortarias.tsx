"use client";

/**
 * SysMúsica — Tabela de portarias, com busca e filtro por situação.
 * Aprovar, rejeitar e excluir só aparecem quando o BANCO informa que o usuário pode
 * (pode_decidir / pode_excluir); o histórico está sempre disponível.
 */
import { useState } from "react";
import { Check, FileText, History, Search, Trash2, X } from "lucide-react";
import Badge from "@/components/ui/Badge";
import BotaoIcone from "@/components/ui/BotaoIcone";
import { formatarDataHora } from "@/lib/datas";
import { normalizarTexto } from "@/lib/texto";
import { ROTULO_STATUS, varianteStatus } from "../regras";
import type { PortariaDetalhada, StatusPortaria } from "../tipos";

interface TabelaPortariasProps {
  portarias: PortariaDetalhada[];
  onAprovar: (portaria: PortariaDetalhada) => void;
  onRejeitar: (portaria: PortariaDetalhada) => void;
  onHistorico: (portaria: PortariaDetalhada) => void;
  onExcluir: (portaria: PortariaDetalhada) => void;
  /** Relatório de presença (impressão): só aparece nas portarias em que {podeRelatorio} devolve verdadeiro. */
  onRelatorio?: (portaria: PortariaDetalhada) => void;
  podeRelatorio?: (portaria: PortariaDetalhada) => boolean;
}

const classeCabecalho = "px-4 py-3 text-left text-xs font-semibold uppercase tracking-wide text-slate-500";
const classeCampo =
  "rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 shadow-sm " +
  "focus:border-brand-500 focus:outline-none focus:ring-2 focus:ring-brand-200";

export default function TabelaPortarias({
  portarias,
  onAprovar,
  onRejeitar,
  onHistorico,
  onExcluir,
  onRelatorio,
  podeRelatorio,
}: TabelaPortariasProps) {
  const [busca, setBusca] = useState("");
  const [situacao, setSituacao] = useState<"" | StatusPortaria>(""); // "" = todas

  const termo = normalizarTexto(busca);
  const filtradas = portarias.filter((portaria) => {
    const texto = normalizarTexto(
      [portaria.evento_tipo, portaria.evento_local, portaria.evento_finalidade, portaria.cidade, portaria.criador_nome]
        .filter(Boolean)
        .join(" ")
    );
    return (situacao === "" || portaria.status === situacao) && (termo === "" || texto.includes(termo));
  });

  return (
    <div className="overflow-hidden rounded-2xl border border-slate-200 bg-white shadow-sm">
      <div className="flex flex-col gap-3 border-b border-slate-200 p-4 sm:flex-row sm:items-center">
        <div className="relative min-w-0 flex-1">
          <label htmlFor="busca-portaria" className="sr-only">
            Pesquisar portarias
          </label>
          <Search
            className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-slate-400"
            aria-hidden="true"
          />
          <input
            id="busca-portaria"
            type="search"
            autoComplete="off"
            value={busca}
            onChange={(e) => setBusca(e.target.value)}
            placeholder="Pesquisar por evento, local, cidade ou criador..."
            className={classeCampo + " w-full pl-9 placeholder:text-slate-400"}
          />
        </div>
        <div className="sm:w-56">
          <label htmlFor="filtro-situacao" className="sr-only">
            Filtrar por situação
          </label>
          <select
            id="filtro-situacao"
            value={situacao}
            onChange={(e) => setSituacao(e.target.value as "" | StatusPortaria)}
            className={classeCampo + " w-full"}
          >
            <option value="">Todas as situações</option>
            <option value="PENDENTE_APROVACAO">{ROTULO_STATUS.PENDENTE_APROVACAO}</option>
            <option value="APROVADA">{ROTULO_STATUS.APROVADA}</option>
            <option value="REJEITADA">{ROTULO_STATUS.REJEITADA}</option>
          </select>
        </div>
      </div>

      <div className="overflow-x-auto">
        <table className="min-w-full divide-y divide-slate-200 text-sm">
          <thead className="bg-slate-50">
            <tr>
              <th scope="col" className={classeCabecalho}>Reunião</th>
              <th scope="col" className={classeCabecalho + " hidden md:table-cell"}>Local</th>
              <th scope="col" className={classeCabecalho + " hidden lg:table-cell"}>Criada por</th>
              <th scope="col" className={classeCabecalho}>Situação</th>
              <th scope="col" className={classeCabecalho + " text-right"}>Ações</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-slate-100">
            {filtradas.length === 0 ? (
              <tr>
                <td colSpan={5} className="px-4 py-10 text-center text-sm text-slate-500">
                  Nenhuma portaria encontrada com os filtros atuais.
                </td>
              </tr>
            ) : (
              filtradas.map((portaria) => {
                const nomeLocal = portaria.evento_local ?? "evento";
                return (
                  <tr key={portaria.id} className="align-top transition hover:bg-slate-50">
                    <td className="px-4 py-3">
                      <p className="font-medium text-slate-900">
                        {portaria.evento_data ? formatarDataHora(portaria.evento_data) : "Evento removido"}
                      </p>
                      <p className="text-xs text-slate-500">
                        {[portaria.evento_tipo, portaria.evento_finalidade].filter(Boolean).join(" · ")}
                      </p>
                      {/* Telas pequenas: o local aparece aqui */}
                      <p className="text-xs text-slate-500 md:hidden">
                        {[portaria.evento_local, portaria.cidade].filter(Boolean).join(" · ")}
                      </p>
                    </td>
                    <td className="hidden px-4 py-3 text-slate-700 md:table-cell">
                      {portaria.evento_local}
                      <span className="block text-xs text-slate-500">{portaria.cidade}</span>
                    </td>
                    <td className="hidden px-4 py-3 text-slate-700 lg:table-cell">
                      {portaria.criador_nome ?? "—"}
                      <span className="block text-xs text-slate-500">{formatarDataHora(portaria.criada_em)}</span>
                    </td>
                    <td className="px-4 py-3">
                      <Badge variante={varianteStatus(portaria.status)}>{ROTULO_STATUS[portaria.status]}</Badge>
                      {portaria.decidida_em && (
                        <p className="mt-1 text-xs text-slate-500">
                          {portaria.decisor_nome ?? "—"} · {formatarDataHora(portaria.decidida_em)}
                        </p>
                      )}
                      {portaria.status === "REJEITADA" && portaria.motivo_rejeicao && (
                        <p className="mt-1 max-w-xs text-xs text-red-700">Motivo: {portaria.motivo_rejeicao}</p>
                      )}
                    </td>
                    <td className="px-4 py-3">
                      <div className="flex justify-end gap-1">
                        {portaria.pode_decidir && (
                          <>
                            <BotaoIcone
                              icone={Check}
                              rotulo={`Aprovar a portaria de ${nomeLocal}`}
                              onClick={() => onAprovar(portaria)}
                            />
                            <BotaoIcone
                              icone={X}
                              variante="perigo"
                              rotulo={`Rejeitar a portaria de ${nomeLocal}`}
                              onClick={() => onRejeitar(portaria)}
                            />
                          </>
                        )}
                        <BotaoIcone
                          icone={History}
                          rotulo={`Histórico da portaria de ${nomeLocal}`}
                          onClick={() => onHistorico(portaria)}
                        />
                        {onRelatorio && podeRelatorio?.(portaria) && (
                          <BotaoIcone
                            icone={FileText}
                            rotulo={`Relatório de presença da portaria de ${nomeLocal}`}
                            onClick={() => onRelatorio(portaria)}
                          />
                        )}
                        {portaria.pode_excluir && (
                          <BotaoIcone
                            icone={Trash2}
                              variante="perigo"
                            rotulo={`Excluir a portaria de ${nomeLocal}`}
                            onClick={() => onExcluir(portaria)}
                          />
                        )}
                      </div>
                    </td>
                  </tr>
                );
              })
            )}
          </tbody>
        </table>
      </div>

      <div className="border-t border-slate-200 bg-slate-50 px-4 py-3 text-xs text-slate-500">
        Exibindo {filtradas.length} de {portarias.length} portaria(s)
      </div>
    </div>
  );
}
