"use client";

/**
 * SysMúsica — Lista de eventos em tabela (largura total), com busca por local ou tipo.
 *
 * Não acessa o banco: recebe os dados e os estados (loading/erro) da página.
 * Os eventos chegam ordenados do mais recente para o mais antigo.
 * Trata quatro cenários: carregando, erro, nenhum evento e tabela com dados.
 */
import { useState } from "react";
import { Search } from "lucide-react";
import Badge from "@/components/ui/Badge";
import EmptyState from "@/components/ui/EmptyState";
import ErrorState from "@/components/ui/ErrorState";
import Skeleton from "@/components/ui/Skeleton";
import { formatarDataHora, partesDaData } from "@/lib/datas";
import { normalizarTexto } from "@/lib/texto";
import type { Evento } from "@/types/database";

interface ListaEventosProps {
  eventos: Evento[];
  carregando: boolean;
  erro: string | null;
  onTentarNovamente: () => void;
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
  carregando,
  erro,
  onTentarNovamente,
}: ListaEventosProps) {
  const [busca, setBusca] = useState("");

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
        titulo="Nenhum evento cadastrado ainda."
        descricao="Clique em “Novo evento” para cadastrar o primeiro."
      />
    );
  }

  // Busca por local ou tipo (sem acento e sem diferenciar maiúsculas)
  const termo = normalizarTexto(busca);
  const filtrados = eventos.filter(
    (evento) =>
      termo === "" ||
      normalizarTexto(evento.local).includes(termo) ||
      normalizarTexto(evento.tipo).includes(termo)
  );

  // 4) Tabela
  return (
    <div className="overflow-hidden rounded-2xl border border-slate-200 bg-white shadow-sm">
      {/* Barra de ferramentas */}
      <div className="border-b border-slate-200 p-4">
        <div className="relative max-w-md">
          <label htmlFor="busca-evento" className="sr-only">
            Pesquisar por local ou tipo
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
            placeholder="Pesquisar por local ou tipo..."
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
                Tipo
              </th>
              <th scope="col" className={classeCabecalho}>
                Local
              </th>
            </tr>
          </thead>
          <tbody className="divide-y divide-slate-100">
            {filtrados.length === 0 ? (
              <tr>
                <td colSpan={3} className="px-4 py-10 text-center text-sm text-slate-500">
                  Nenhum evento encontrado com a pesquisa atual.
                </td>
              </tr>
            ) : (
              filtrados.map((evento) => {
                const { dia, mes } = partesDaData(evento.data_evento);

                return (
                  <tr key={evento.id} className="transition hover:bg-slate-50">
                    <td className="px-4 py-3">
                      <div className="flex items-center gap-3">
                        {/* Bloco de data: dia e mês abreviado */}
                        <div className="flex h-11 w-11 shrink-0 flex-col items-center justify-center rounded-xl bg-brand-50 text-brand-700">
                          <span className="text-sm font-bold leading-none">{dia}</span>
                          <span className="mt-0.5 text-[10px] font-medium uppercase">{mes}</span>
                        </div>
                        <span className="text-slate-700">{formatarDataHora(evento.data_evento)}</span>
                      </div>
                    </td>
                    <td className="px-4 py-3">
                      <Badge variante={varianteTipo(evento.tipo)}>{evento.tipo}</Badge>
                    </td>
                    <td className="px-4 py-3 font-medium text-slate-900">{evento.local}</td>
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
