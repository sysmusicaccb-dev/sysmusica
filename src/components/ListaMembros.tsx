"use client";

/**
 * SysMúsica — Lista de membros em tabela, com barra de ferramentas de filtros.
 *
 * Não acessa o banco: recebe os dados e os estados (loading/erro) da página.
 * Os filtros (busca por nome e cargo) são aplicados no navegador sobre a lista recebida.
 * Cruza cada membro com seu cargo e instrumento (cargo_id / instrumento_id) para exibir os nomes.
 *
 * Responsividade:
 *  - telas >= 768px: colunas Nome, Cargo, Instrumento, Congregação e Status;
 *  - telas menores: apenas Nome (com cargo, instrumento e congregação em uma linha abaixo) e Status.
 *
 * Trata quatro cenários: carregando, erro, nenhum membro cadastrado e tabela com dados.
 */
import { useState } from "react";
import { normalizarTexto } from "@/lib/texto";
import type { Cargo, Instrumento, MembroPublico } from "@/types/database";

interface ListaMembrosProps {
  membros: MembroPublico[];
  cargos: Cargo[];
  instrumentos: Instrumento[];
  carregando: boolean;
  erro: string | null;
  onTentarNovamente: () => void;
}

// Classe compartilhada pelos cabeçalhos das colunas
const classeCabecalho =
  "px-4 py-3 text-left text-xs font-semibold uppercase tracking-wide text-slate-500";

export default function ListaMembros({
  membros,
  cargos,
  instrumentos,
  carregando,
  erro,
  onTentarNovamente,
}: ListaMembrosProps) {
  const [busca, setBusca] = useState("");
  const [cargoFiltroId, setCargoFiltroId] = useState(""); // "" = todos os cargos

  // 1) Carregando: skeleton (barra de ferramentas + linhas)
  if (carregando) {
    return (
      <div
        role="status"
        aria-live="polite"
        className="overflow-hidden rounded-2xl border border-slate-200 bg-white shadow-sm"
      >
        <span className="sr-only">Carregando membros...</span>
        <div className="flex flex-col gap-3 border-b border-slate-200 p-4 sm:flex-row">
          <div className="h-10 flex-1 animate-pulse rounded-lg bg-slate-200" />
          <div className="h-10 animate-pulse rounded-lg bg-slate-200 sm:w-56" />
        </div>
        <div className="space-y-3 p-4">
          {[0, 1, 2, 3, 4].map((i) => (
            <div key={i} className="h-10 animate-pulse rounded bg-slate-100" />
          ))}
        </div>
      </div>
    );
  }

  // 2) Erro na comunicação com o banco
  if (erro) {
    return (
      <div role="alert" className="rounded-2xl border border-red-200 bg-red-50 p-6">
        <p className="font-semibold text-red-800">Não foi possível carregar os membros.</p>
        <p className="mt-1 text-sm text-red-700">{erro}</p>
        <button
          type="button"
          onClick={onTentarNovamente}
          className="mt-4 rounded-lg bg-red-600 px-4 py-2 text-sm font-semibold text-white transition hover:bg-red-500"
        >
          Tentar novamente
        </button>
      </div>
    );
  }

  // 3) Nenhum membro cadastrado
  if (membros.length === 0) {
    return (
      <div className="rounded-2xl border border-dashed border-slate-300 bg-white p-10 text-center">
        <p className="font-medium text-slate-700">Nenhum membro cadastrado ainda.</p>
        <p className="mt-1 text-sm text-slate-500">Use o formulário para cadastrar o primeiro.</p>
      </div>
    );
  }

  // Índices por id (cruzamento em memória)
  const cargoPorId = new Map(cargos.map((cargo): [string, Cargo] => [cargo.id, cargo]));
  const instrumentoPorId = new Map(
    instrumentos.map((instrumento): [string, Instrumento] => [instrumento.id, instrumento])
  );

  // Filtros: nome (sem acento/maiúsculas, "contém") e cargo (igualdade)
  const termo = normalizarTexto(busca);
  const membrosFiltrados = membros.filter(
    (membro) =>
      (termo === "" || normalizarTexto(membro.nome).includes(termo)) &&
      (cargoFiltroId === "" || membro.cargo_id === cargoFiltroId)
  );
  const filtrosAtivos = termo !== "" || cargoFiltroId !== "";

  function limparFiltros() {
    setBusca("");
    setCargoFiltroId("");
  }

  // 4) Tabela com barra de ferramentas
  return (
    <div className="overflow-hidden rounded-2xl border border-slate-200 bg-white shadow-sm">
      {/* Barra de ferramentas: pesquisa por nome + filtro por cargo */}
      <div className="flex flex-col gap-3 border-b border-slate-200 p-4 sm:flex-row sm:items-center">
        <div className="relative flex-1">
          <label htmlFor="busca-nome" className="sr-only">
            Pesquisar por nome
          </label>
          <svg
            className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-slate-400"
            viewBox="0 0 20 20"
            fill="currentColor"
            aria-hidden="true"
          >
            <path
              fillRule="evenodd"
              d="M8 4a4 4 0 100 8 4 4 0 000-8zM2 8a6 6 0 1110.89 3.476l4.817 4.817a1 1 0 01-1.414 1.414l-4.816-4.816A6 6 0 012 8z"
              clipRule="evenodd"
            />
          </svg>
          <input
            id="busca-nome"
            type="search"
            autoComplete="off"
            value={busca}
            onChange={(e) => setBusca(e.target.value)}
            placeholder="Pesquisar por nome..."
            className="w-full rounded-lg border border-slate-300 bg-white py-2 pl-9 pr-3 text-sm text-slate-900 placeholder:text-slate-400 shadow-sm focus:border-indigo-500 focus:outline-none focus:ring-2 focus:ring-indigo-200"
          />
        </div>

        <div className="sm:w-56">
          <label htmlFor="filtro-cargo" className="sr-only">
            Filtrar por cargo
          </label>
          <select
            id="filtro-cargo"
            value={cargoFiltroId}
            onChange={(e) => setCargoFiltroId(e.target.value)}
            className="w-full rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 shadow-sm focus:border-indigo-500 focus:outline-none focus:ring-2 focus:ring-indigo-200"
          >
            <option value="">Todos os cargos</option>
            {cargos.map((cargo) => (
              <option key={cargo.id} value={cargo.id}>
                {cargo.nome}
              </option>
            ))}
          </select>
        </div>
      </div>

      {/* Tabela de dados (rola na horizontal só se faltar espaço) */}
      <div className="overflow-x-auto">
        <table className="min-w-full divide-y divide-slate-200 text-sm">
          <thead className="bg-slate-50">
            <tr>
              <th scope="col" className={classeCabecalho}>
                Nome
              </th>
              <th scope="col" className={classeCabecalho + " hidden md:table-cell"}>
                Cargo
              </th>
              <th scope="col" className={classeCabecalho + " hidden md:table-cell"}>
                Instrumento
              </th>
              <th scope="col" className={classeCabecalho + " hidden md:table-cell"}>
                Congregação
              </th>
              <th scope="col" className={classeCabecalho}>
                Status
              </th>
            </tr>
          </thead>

          <tbody className="divide-y divide-slate-100">
            {membrosFiltrados.length === 0 ? (
              // Filtros sem resultado
              <tr>
                <td colSpan={5} className="px-4 py-10 text-center text-sm text-slate-500">
                  Nenhum membro encontrado com os filtros atuais.
                </td>
              </tr>
            ) : (
              membrosFiltrados.map((membro) => {
                const nomeCargo = cargoPorId.get(membro.cargo_id)?.nome ?? "Cargo não encontrado";
                const nomeInstrumento = membro.instrumento_id
                  ? (instrumentoPorId.get(membro.instrumento_id)?.nome ?? null)
                  : null;

                return (
                  <tr key={membro.id} className="transition hover:bg-slate-50">
                    <td className="px-4 py-3">
                      <div className="flex items-center gap-3">
                        {/* Avatar com a inicial do nome */}
                        <div className="flex h-9 w-9 shrink-0 items-center justify-center rounded-full bg-indigo-100 text-sm font-bold text-indigo-700">
                          {membro.nome.charAt(0).toUpperCase()}
                        </div>
                        <div className="min-w-0">
                          <p className="truncate font-medium text-slate-900">{membro.nome}</p>
                          {/* Telas pequenas: os dados das colunas ocultas aparecem aqui */}
                          <p className="truncate text-xs text-slate-500 md:hidden">
                            {[nomeCargo, nomeInstrumento, membro.congregacao]
                              .filter(Boolean)
                              .join(" · ")}
                          </p>
                        </div>
                      </div>
                    </td>
                    <td className="hidden px-4 py-3 text-slate-700 md:table-cell">{nomeCargo}</td>
                    <td className="hidden px-4 py-3 text-slate-700 md:table-cell">
                      {nomeInstrumento ?? "—"}
                    </td>
                    <td className="hidden px-4 py-3 text-slate-700 md:table-cell">
                      {membro.congregacao}
                    </td>
                    <td className="px-4 py-3">
                      <span
                        className={
                          "rounded-full px-2 py-0.5 text-xs font-medium " +
                          (membro.status === "Ativo"
                            ? "bg-emerald-100 text-emerald-700"
                            : "bg-slate-100 text-slate-600")
                        }
                      >
                        {membro.status}
                      </span>
                    </td>
                  </tr>
                );
              })
            )}
          </tbody>
        </table>
      </div>

      {/* Rodapé: contagem e atalho para limpar os filtros */}
      <div className="flex items-center justify-between gap-2 border-t border-slate-200 bg-slate-50 px-4 py-3 text-xs text-slate-500">
        <span>
          Exibindo {membrosFiltrados.length} de {membros.length} membro(s)
        </span>
        {filtrosAtivos && (
          <button
            type="button"
            onClick={limparFiltros}
            className="font-semibold text-indigo-600 hover:underline"
          >
            Limpar filtros
          </button>
        )}
      </div>
    </div>
  );
}
