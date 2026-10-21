"use client";

/**
 * SysMúsica — Lista de eventos em tabela (largura total), com busca por finalidade, local ou tipo.
 *
 * Não acessa o banco: recebe os dados e os estados (loading/erro) da página.
 * Os eventos chegam ordenados do mais recente para o mais antigo.
 * Ações por linha (só aparecem para quem tem a permissão): editar e excluir.
 * Trata quatro cenários: carregando, erro, nenhum evento e tabela com dados.
 */
import { useState } from "react";
import { Ban, Pencil, Search, Trash2 } from "lucide-react";
import Badge from "@/components/ui/Badge";
import BotaoIcone from "@/components/ui/BotaoIcone";
import EmptyState from "@/components/ui/EmptyState";
import ErrorState from "@/components/ui/ErrorState";
import Skeleton from "@/components/ui/Skeleton";
import { formatarDataHora, partesDaData } from "@/lib/datas";
import { normalizarTexto } from "@/lib/texto";
import {
  eventoAberto,
  ROTULO_SITUACAO_EVENTO,
  situacaoDoEvento,
  varianteSituacaoEvento,
} from "@/modules/eventos/ciclo";
import type { Evento, FinalidadeEvento } from "@/types/database";

interface ListaEventosProps {
  eventos: Evento[];
  finalidades: FinalidadeEvento[];
  carregando: boolean;
  erro: string | null;
  onTentarNovamente: () => void;
  podeEditar: boolean;
  podeExcluir: boolean;
  podeCancelar: boolean; // só o Administrador (eventos.cancelar): cancela e corrige evento encerrado
  agora: number; // instante atual (ms), para calcular a situação de cada evento
  tituloVazio?: string;
  descricaoVazia?: string;
  onEditar: (evento: Evento) => void;
  onExcluir: (evento: Evento) => void;
  onCancelar: (evento: Evento) => void;
}

// Cor do selo conforme o tipo do evento (tipos desconhecidos usam o neutro)
function varianteTipo(tipo: string): "marca" | "alerta" | "neutro" {
  const normalizado = tipo.trim().toLowerCase();
  if (normalizado === "ensaio") return "marca";
  if (normalizado === "culto") return "alerta";
  return "neutro";
}

const classeCabecalho =
  "px-4 py-3 text-left text-xs font-semibold uppercase tracking-wide text-slate-500";

export default function ListaEventos({
  eventos,
  finalidades,
  carregando,
  erro,
  onTentarNovamente,
  podeEditar,
  podeExcluir,
  podeCancelar,
  agora,
  tituloVazio,
  descricaoVazia,
  onEditar,
  onExcluir,
  onCancelar,
}: ListaEventosProps) {
  const [busca, setBusca] = useState("");
  const mostrarAcoes = podeEditar || podeExcluir || podeCancelar;

  // 1) Carregando: skeleton (barra de ferramentas + linhas)
  if (carregando) {
    return (
      <div
        role="status"
        aria-live="polite"
        className="overflow-hidden rounded-2xl border border-slate-200 bg-white shadow-sm"
      >
        <span className="sr-only">Carregando eventos...</span>
        <div className="border-b border-slate-200 p-4">
          <Skeleton className="h-10 max-w-md" />
        </div>
        <div className="space-y-3 p-4">
          {[0, 1, 2, 3, 4].map((i) => (
            <Skeleton key={i} className="h-10" />
          ))}
        </div>
      </div>
    );
  }

  // 2) Erro na comunicação com o banco
  if (erro) {
    return (
      <ErrorState
        titulo="Não foi possível carregar os eventos."
        mensagem={erro}
        onTentarNovamente={onTentarNovamente}
      />
    );
  }

  // 3) Nenhum evento cadastrado
  if (eventos.length === 0) {
    return (
      <EmptyState
        titulo={tituloVazio ?? "Nenhum evento cadastrado ainda."}
        descricao={descricaoVazia ?? "Clique em “Adicionar” para cadastrar o primeiro."}
      />
    );
  }

  const finalidadePorId = new Map(
    finalidades.map((finalidade): [string, FinalidadeEvento] => [finalidade.id, finalidade])
  );
  const nomeDaFinalidade = (evento: Evento): string | null =>
    evento.finalidade_id ? (finalidadePorId.get(evento.finalidade_id)?.nome ?? null) : null;

  // Busca por finalidade, local ou tipo (sem acento e sem diferenciar maiúsculas)
  const termo = normalizarTexto(busca);
  const filtrados = eventos.filter(
    (evento) =>
      termo === "" ||
      normalizarTexto(evento.local).includes(termo) ||
      normalizarTexto(evento.tipo).includes(termo) ||
      normalizarTexto(nomeDaFinalidade(evento) ?? "").includes(termo)
  );

  // 4) Tabela
  return (
    <div className="overflow-hidden rounded-2xl border border-slate-200 bg-white shadow-sm">
      {/* Barra de ferramentas */}
      <div className="border-b border-slate-200 p-4">
        <div className="relative max-w-md">
          <label htmlFor="busca-evento" className="sr-only">
            Pesquisar por descrição ou Casa de Oração
          </label>
          <Search
            className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-slate-400"
            aria-hidden="true"
          />
          <input
            id="busca-evento"
            type="search"
            autoComplete="off"
            value={busca}
            onChange={(e) => setBusca(e.target.value)}
            placeholder="Pesquisar por descrição ou Casa de Oração..."
            className="w-full rounded-lg border border-slate-300 bg-white py-2 pl-9 pr-3 text-sm text-slate-900 placeholder:text-slate-400 shadow-sm focus:border-brand-500 focus:outline-none focus:ring-2 focus:ring-brand-200"
          />
        </div>
      </div>

      <div className="overflow-x-auto">
        <table className="min-w-full divide-y divide-slate-200 text-sm">
          <thead className="bg-slate-50">
            <tr>
              <th scope="col" className={classeCabecalho}>
                Data e hora
              </th>
              <th scope="col" className={classeCabecalho}>
                Descrição do evento
              </th>
              <th scope="col" className={classeCabecalho}>
                Situação
              </th>
              <th scope="col" className={classeCabecalho + " hidden md:table-cell"}>
                Casa de Oração
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
                <td
                  colSpan={mostrarAcoes ? 5 : 4}
                  className="px-4 py-10 text-center text-sm text-slate-500"
                >
                  Nenhum evento encontrado com a pesquisa atual.
                </td>
              </tr>
            ) : (
              filtrados.map((evento) => {
                const { dia, mes } = partesDaData(evento.data_evento);
                const finalidade = nomeDaFinalidade(evento);
                const cancelado = Boolean(evento.cancelado_em);
                const situacao = situacaoDoEvento(evento.data_evento, cancelado, agora);
                // Evento encerrado ou cancelado é só leitura; o Administrador (podeCancelar) ainda corrige encerrados
                const podeAlterar = !cancelado && (eventoAberto(evento.data_evento, cancelado, agora) || podeCancelar);

                return (
                  <tr key={evento.id} className="transition hover:bg-slate-50">
                    <td className="px-4 py-3">
                      <div className="flex items-center gap-3">
                        {/* Bloco de data: dia e mês abreviado */}
                        <div className="flex h-11 w-11 shrink-0 flex-col items-center justify-center rounded-xl bg-brand-50 text-brand-700">
                          <span className="text-sm font-bold leading-none">{dia}</span>
                          <span className="mt-0.5 text-[10px] font-medium uppercase">{mes}</span>
                        </div>
                        <div className="min-w-0">
                          <p className="text-slate-700">{formatarDataHora(evento.data_evento)}</p>
                          {/* Telas pequenas: finalidade e local aparecem aqui */}
                          <p className="line-clamp-2 text-xs text-slate-500 md:hidden">
                            {[finalidade, evento.local, evento.cidade].filter(Boolean).join(" · ")}
                          </p>
                        </div>
                      </div>
                    </td>
                    <td className="px-4 py-3">
                      <Badge variante={varianteTipo(evento.tipo)}>{evento.tipo}</Badge>
                    </td>
                    <td className="px-4 py-3">
                      <Badge variante={varianteSituacaoEvento(situacao)}>{ROTULO_SITUACAO_EVENTO[situacao]}</Badge>
                      {cancelado && evento.motivo_cancelamento && (
                        <span className="mt-1 block max-w-xs text-xs text-slate-500">
                          Motivo: {evento.motivo_cancelamento}
                        </span>
                      )}
                    </td>
                    <td className="hidden px-4 py-3 font-medium text-slate-900 md:table-cell">
                      {evento.local}
                        {evento.cidade && (
                          <span className="block text-xs font-normal text-slate-500">{evento.cidade}</span>
                        )}
                    </td>
                    {mostrarAcoes && (
                      <td className="px-4 py-3">
                        <div className="flex justify-end gap-1">
                          {podeEditar && podeAlterar && (
                            <BotaoIcone
                              icone={Pencil}
                              rotulo={`Editar o evento de ${formatarDataHora(evento.data_evento)}`}
                              onClick={() => onEditar(evento)}
                            />
                          )}
                          {podeExcluir && podeAlterar && (
                            <BotaoIcone
                              icone={Trash2}
                              variante="perigo"
                              rotulo={`Excluir o evento de ${formatarDataHora(evento.data_evento)}`}
                              onClick={() => onExcluir(evento)}
                            />
                          )}
                          {podeCancelar && !cancelado && (
                            <BotaoIcone
                              icone={Ban}
                              variante="perigo"
                              rotulo={`Cancelar o evento de ${formatarDataHora(evento.data_evento)}`}
                              onClick={() => onCancelar(evento)}
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
        Exibindo {filtrados.length} de {eventos.length} evento(s)
      </div>
    </div>
  );
}
