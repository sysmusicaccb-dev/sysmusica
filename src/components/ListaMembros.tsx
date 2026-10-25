"use client";

/**
 * Sysmusica — Lista de membros em tabela, com barra de ferramentas de filtros.
 *
 * Não acessa o banco: recebe os dados e os estados (loading/erro) da página.
 * Os filtros (busca por nome, cargo e família) são aplicados no navegador sobre a lista recebida.
 * Cruza cada membro com seu cargo e instrumento; a FAMÍLIA do membro é a do seu instrumento
 * (instrumento -> familia_id), então corrigir a família de um instrumento atualiza todos os membros.
 *
 * Responsividade:
 *  - telas >= 768px: colunas Nome, Cargo, Instrumento, Família, Casa de Oração e Status (nível do cargo:
 *    Oficializado, Culto Oficial ou RJM; "Inativo" aparece ao lado quando a situação cadastral é Inativa);
 *  - filtro de fotografia (sem/com) e miniatura da foto no lugar da inicial do nome;
 *  - telas menores: apenas Nome (com os demais dados em uma linha abaixo) e Status.
 *
 * Trata quatro cenários: carregando, erro, nenhum membro cadastrado e tabela com dados.
 */
import { useState } from "react";
import { ChevronLeft, ChevronRight, Pencil, QrCode, Trash2, Users } from "lucide-react";
import BotaoIcone from "@/components/ui/BotaoIcone";
import { cn } from "@/lib/cn";
import { normalizarTexto } from "@/lib/texto";
import IlustracaoInstrumento from "@/modules/instrumentos/components/IlustracaoInstrumento";
import { cargoUsaCategoria, rotuloDaCategoria } from "@/modules/painel/regras";
import { paginar, paginasVisiveis } from "@/modules/tiposEvento/regras";
import type { Cargo, Familia, Instrumento, MembroPublico } from "@/types/database";

interface ListaMembrosProps {
  membros: MembroPublico[];
  cargos: Cargo[];
  instrumentos: Instrumento[];
  familias: Familia[];
  carregando: boolean;
  erro: string | null;
  onTentarNovamente: () => void;
  podeEditar: boolean; // mostra o botão Editar em cada linha
  podeExcluir: boolean; // mostra o botão Excluir em cada linha
  onEditar: (membro: MembroPublico) => void;
  onExcluir: (membro: MembroPublico) => void;
  podeQr: boolean; // mostra o botão QR Code em cada linha
  onQr: (membro: MembroPublico) => void;
  urlsFotos?: Record<string, string>; // caminho da foto -> URL temporária (miniaturas da lista)
}

// Valor especial do filtro de família: membros sem instrumento ou com instrumento não classificado
const FILTRO_SEM_FAMILIA = "sem-familia";

// Classe compartilhada pelos cabeçalhos das colunas
const TAMANHO_PAGINA = 10;
const classeCabecalho = "px-4 py-3 text-left text-sm font-semibold text-slate-800";
const classeBotaoPagina =
  "inline-flex h-9 min-w-9 items-center justify-center rounded-lg border border-slate-200 bg-white px-2 text-sm font-medium text-slate-600 transition hover:bg-slate-50 focus:outline-none focus-visible:ring-2 focus-visible:ring-brand-300 disabled:cursor-not-allowed disabled:opacity-40";

// Classe compartilhada pelos selects da barra de ferramentas
const classeSelect =
  "w-full rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 shadow-sm focus:border-brand-500 focus:outline-none focus:ring-2 focus:ring-brand-200";

export default function ListaMembros({
  membros,
  cargos,
  instrumentos,
  familias,
  carregando,
  erro,
  onTentarNovamente,
  podeEditar,
  podeExcluir,
  onEditar,
  onExcluir,
  podeQr,
  onQr,
  urlsFotos = {},
}: ListaMembrosProps) {
  const [busca, setBusca] = useState("");
  const [cargoFiltroId, setCargoFiltroId] = useState(""); // "" = todos os cargos
  const [familiaFiltroId, setFamiliaFiltroId] = useState(""); // "" = todas as famílias
  const [fotoFiltro, setFotoFiltro] = useState<"" | "sem" | "com">(""); // "" = com ou sem fotografia
  const [pagina, setPagina] = useState(1);
  const mostrarAcoes = podeEditar || podeExcluir || podeQr; // a coluna Ações só existe para quem pode algo

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
          <div className="h-10 animate-pulse rounded-lg bg-slate-200 sm:w-48" />
          <div className="h-10 animate-pulse rounded-lg bg-slate-200 sm:w-44" />
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
        <p className="mt-1 text-sm text-slate-500">Clique em “Adicionar” para cadastrar o primeiro.</p>
      </div>
    );
  }

  // Índices por id (cruzamento em memória)
  const cargoPorId = new Map(cargos.map((cargo): [string, Cargo] => [cargo.id, cargo]));
  const familiaPorId = new Map(familias.map((familia): [string, Familia] => [familia.id, familia]));
  const instrumentoPorId = new Map(
    instrumentos.map((instrumento): [string, Instrumento] => [instrumento.id, instrumento])
  );

  // Família do membro = família do instrumento dele (null se não tiver instrumento ou classificação)
  const familiaIdDoMembro = (membro: MembroPublico): string | null =>
    membro.instrumento_id
      ? (instrumentoPorId.get(membro.instrumento_id)?.familia_id ?? null)
      : null;

  // Filtros: nome (sem acento/maiúsculas, "contém"), cargo e família (igualdade)
  const termo = normalizarTexto(busca);
  const membrosFiltrados = membros.filter((membro) => {
    const familiaId = familiaIdDoMembro(membro);
    const passaNome = termo === "" || normalizarTexto(membro.nome).includes(termo);
    const passaCargo = cargoFiltroId === "" || membro.cargo_id === cargoFiltroId;
    const passaFamilia =
      familiaFiltroId === "" ||
      (familiaFiltroId === FILTRO_SEM_FAMILIA ? familiaId === null : familiaId === familiaFiltroId);
    const passaFoto = fotoFiltro === "" || (fotoFiltro === "sem" ? !membro.foto_path : !!membro.foto_path);
    return passaNome && passaCargo && passaFamilia && passaFoto;
  });
  const filtrosAtivos = termo !== "" || cargoFiltroId !== "" || familiaFiltroId !== "" || fotoFiltro !== "";
  const pag = paginar(membrosFiltrados, pagina, TAMANHO_PAGINA);
  const semFoto = membros.filter((membro) => !membro.foto_path).length;

  function limparFiltros() {
    setBusca("");
    setCargoFiltroId("");
    setFamiliaFiltroId("");
    setFotoFiltro("");
    setPagina(1);
  }

  // 4) Lista com filtros, tabela e paginação (padrão visual das demais telas)
  return (
    <section className="overflow-hidden rounded-xl border border-slate-200 bg-white shadow-sm">
      <header className="flex items-center gap-2 border-b border-slate-200 bg-brand-50 px-5 py-3.5">
        <Users className="h-5 w-5 text-brand-700" aria-hidden="true" />
        <h2 className="text-base font-semibold text-slate-900">Lista de Músicos e Organistas</h2>
      </header>

      <div className="p-4">
        {/* Filtros: pesquisa por nome + cargo + família + fotografia (qualquer mudança volta para a página 1) */}
        <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-[minmax(0,1fr)_12rem_12rem_12rem]">
          <div className="relative min-w-0">
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
              onChange={(e) => {
                setBusca(e.target.value);
                setPagina(1);
              }}
              placeholder="Pesquisar por nome..."
              className="w-full rounded-lg border border-slate-300 bg-white py-2 pl-9 pr-3 text-sm text-slate-900 placeholder:text-slate-400 shadow-sm focus:border-brand-500 focus:outline-none focus:ring-2 focus:ring-brand-200"
            />
          </div>

          <div>
            <label htmlFor="filtro-cargo" className="sr-only">
              Filtrar por cargo
            </label>
            <select
              id="filtro-cargo"
              value={cargoFiltroId}
              onChange={(e) => {
                setCargoFiltroId(e.target.value);
                setPagina(1);
              }}
              className={classeSelect}
            >
              <option value="">Todos os cargos</option>
              {cargos.map((cargo) => (
                <option key={cargo.id} value={cargo.id}>
                  {cargo.nome}
                </option>
              ))}
            </select>
          </div>

          <div>
            <label htmlFor="filtro-familia" className="sr-only">
              Filtrar por família do instrumento
            </label>
            <select
              id="filtro-familia"
              value={familiaFiltroId}
              onChange={(e) => {
                setFamiliaFiltroId(e.target.value);
                setPagina(1);
              }}
              className={classeSelect}
            >
              <option value="">Todas as famílias</option>
              {familias.map((familia) => (
                <option key={familia.id} value={familia.id}>
                  {familia.nome}
                </option>
              ))}
              <option value={FILTRO_SEM_FAMILIA}>Sem família</option>
            </select>
          </div>

          <div>
            <label htmlFor="filtro-foto" className="sr-only">
              Filtrar por fotografia
            </label>
            <select
              id="filtro-foto"
              value={fotoFiltro}
              onChange={(e) => {
                setFotoFiltro(e.target.value as "" | "sem" | "com");
                setPagina(1);
              }}
              className={classeSelect}
            >
              <option value="">Todas as fotos</option>
              <option value="sem">Sem fotografia ({semFoto})</option>
              <option value="com">Com fotografia</option>
            </select>
          </div>
        </div>

        {/* Tabela de dados (rola na horizontal só se faltar espaço) */}
        <div className="mt-4 overflow-x-auto rounded-lg border border-slate-200">
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
                  Família
                </th>
                <th scope="col" className={classeCabecalho + " hidden md:table-cell"}>
                  Casa de Oração
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
                // Filtros sem resultado
                <tr>
                  <td colSpan={mostrarAcoes ? 7 : 6} className="px-4 py-10 text-center text-sm text-slate-500">
                    Nenhum membro encontrado com os filtros atuais.
                  </td>
                </tr>
              ) : (
                pag.itens.map((membro) => {
                  const nomeCargo = cargoPorId.get(membro.cargo_id)?.nome ?? "Cargo não encontrado";
                  const nomeInstrumento = membro.instrumento_id
                    ? (instrumentoPorId.get(membro.instrumento_id)?.nome ?? null)
                    : null;
                  const familiaId = familiaIdDoMembro(membro);
                  const nomeFamilia = familiaId ? (familiaPorId.get(familiaId)?.nome ?? null) : null;
                  const urlFoto = membro.foto_path ? urlsFotos[membro.foto_path] : undefined;
                  // Status = nível do cargo: Músico e Organista informam (Oficializado, Culto Oficial, RJM);
                  // os demais cargos são Oficializado automaticamente
                  const tipoCategoria = cargoUsaCategoria(nomeCargo);
                  const nivel = tipoCategoria
                    ? { rotulo: rotuloDaCategoria(membro.categoria, tipoCategoria), definido: !!membro.categoria }
                    : { rotulo: "Oficializado", definido: true };

                  return (
                    <tr key={membro.id} className="transition hover:bg-slate-50">
                      <td className="px-4 py-3">
                        <div className="flex items-center gap-3">
                          {/* Miniatura da fotografia; sem foto, a inicial do nome */}
                          <div
                            role="img"
                            aria-label={urlFoto ? `Fotografia de ${membro.nome}` : `${membro.nome}: sem fotografia`}
                            style={urlFoto ? { backgroundImage: `url(${urlFoto})` } : undefined}
                            className={
                              "flex h-9 w-9 shrink-0 items-center justify-center rounded-full bg-cover bg-center text-sm font-bold " +
                              (urlFoto ? "bg-slate-100" : "bg-brand-100 text-brand-700")
                            }
                          >
                            {!urlFoto && membro.nome.charAt(0).toUpperCase()}
                          </div>
                          <div className="min-w-0">
                            <p className="truncate font-medium text-slate-900">{membro.nome}</p>
                            {!membro.foto_path && <p className="text-xs text-amber-700">Sem fotografia</p>}
                            {/* Telas pequenas: os dados das colunas ocultas aparecem aqui */}
                            <p className="truncate text-xs text-slate-500 md:hidden">
                              {[nomeCargo, nomeInstrumento, nomeFamilia, membro.congregacao]
                                .filter(Boolean)
                                .join(" · ")}
                            </p>
                          </div>
                        </div>
                      </td>
                      <td className="hidden px-4 py-3 text-slate-700 md:table-cell">{nomeCargo}</td>
                      <td className="hidden px-4 py-3 text-slate-700 md:table-cell">
                        {nomeInstrumento ? (
                          <div className="flex items-center gap-2">
                            <IlustracaoInstrumento nome={nomeInstrumento} familia={nomeFamilia} />
                            {nomeInstrumento}
                          </div>
                        ) : (
                          "—"
                        )}
                      </td>
                      <td className="hidden px-4 py-3 md:table-cell">
                        {nomeFamilia ? (
                          <span className="rounded-full bg-brand-50 px-2 py-0.5 text-xs font-medium text-brand-700">
                            {nomeFamilia}
                          </span>
                        ) : (
                          <span className="text-slate-400">—</span>
                        )}
                      </td>
                      <td className="hidden px-4 py-3 text-slate-700 md:table-cell">
                        {membro.congregacao}
                        {(membro.bairro || membro.cidade) && (
                          <span className="block text-xs text-slate-500">
                            {[membro.bairro, membro.cidade].filter(Boolean).join(" · ")}
                          </span>
                        )}
                      </td>
                      <td className="px-4 py-3">
                        <div className="flex flex-wrap items-center gap-1">
                          <span
                            className={
                              "rounded-full px-2 py-0.5 text-xs font-medium " +
                              (nivel.definido ? "bg-emerald-100 text-emerald-700" : "bg-amber-100 text-amber-800")
                            }
                          >
                            {nivel.rotulo}
                          </span>
                          {membro.status !== "Ativo" && (
                            <span className="rounded-full bg-slate-100 px-2 py-0.5 text-xs font-medium text-slate-600">
                              {membro.status}
                            </span>
                          )}
                        </div>
                      </td>
                      {mostrarAcoes && (
                        <td className="px-4 py-3">
                          <div className="flex items-center justify-center gap-1">
                            {podeQr && (
                              <BotaoIcone
                                icone={QrCode}
                                rotulo={`QR Code de ${membro.nome}`}
                                onClick={() => onQr(membro)}
                              />
                            )}
                            {podeEditar && (
                              <BotaoIcone
                                icone={Pencil}
                                rotulo={`Editar ${membro.nome}`}
                                onClick={() => onEditar(membro)}
                              />
                            )}
                            {podeExcluir && (
                              <BotaoIcone
                                icone={Trash2}
                                variante="perigo"
                                rotulo={`Excluir ${membro.nome}`}
                                onClick={() => onExcluir(membro)}
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

        {/* Rodapé: contagem, atalho para limpar os filtros e paginação */}
        <div className="mt-4 flex flex-wrap items-center justify-between gap-3">
          <p className="text-sm text-slate-600">
            {filtrosAtivos
              ? `Exibindo ${membrosFiltrados.length} de ${membros.length} membro(s)`
              : `Total: ${membros.length} membro(s)`}{" "}
            · {semFoto} sem fotografia
            {filtrosAtivos && (
              <button type="button" onClick={limparFiltros} className="ml-3 font-semibold text-brand-600 hover:underline">
                Limpar filtros
              </button>
            )}
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
