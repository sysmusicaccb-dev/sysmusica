"use client";

/**
 * SysMúsica — Formulário de registro de presenças.
 *
 * Fluxo: escolher o evento -> marcar o status de cada músico -> salvar.
 * Os registros são enviados em LOTE (um único insert com vários itens) para a
 * tabela "presencas": ou salva todos, ou nenhum.
 *
 * Regras:
 *  - Só são salvos os músicos que tiverem um status marcado.
 *  - Músicos que já têm presença registrada no evento ficam travados
 *    (a tabela tem UNIQUE (musico_id, evento_id) e o RLS atual não permite UPDATE).
 */
import { useMemo, useState, type FormEvent } from "react";
import Link from "next/link";
import { supabase } from "@/lib/supabase";
import type { Evento, Musico, Presenca, PresencaInsert } from "@/types/database";

interface FormularioPresencaProps {
  eventos: Evento[];
  musicos: Musico[];
  presencas: Presenca[]; // usado para travar quem já foi registrado no evento
  carregando: boolean;
  erro: string | null;
  /** Chamado após salvar com sucesso, para a página recarregar os dados. */
  onPresencaAdicionada: () => void | Promise<void>;
}

// Opções de status e a cor de cada botão quando selecionado.
// (Classes escritas por extenso para o Tailwind conseguir detectá-las.)
const STATUS_PRESENCA = [
  {
    valor: "Presente",
    classe: "peer-checked:border-emerald-600 peer-checked:bg-emerald-600 peer-checked:text-white",
  },
  {
    valor: "Ausente",
    classe: "peer-checked:border-red-600 peer-checked:bg-red-600 peer-checked:text-white",
  },
  {
    valor: "Justificado",
    classe: "peer-checked:border-amber-500 peer-checked:bg-amber-500 peer-checked:text-white",
  },
] as const;

// Selo de status para músicos já registrados
function classeStatus(status: string): string {
  if (status === "Presente") return "bg-emerald-100 text-emerald-700";
  if (status === "Ausente") return "bg-red-100 text-red-700";
  if (status === "Justificado") return "bg-amber-100 text-amber-700";
  return "bg-slate-100 text-slate-600";
}

// Texto de cada opção do select: "Ensaio · 13/10/2026 às 19:30 · Local"
function rotuloEvento(evento: Evento): string {
  const data = new Date(evento.data_evento)
    .toLocaleString("pt-BR", {
      day: "2-digit",
      month: "2-digit",
      year: "numeric",
      hour: "2-digit",
      minute: "2-digit",
    })
    .replace(", ", " às ");
  return `${evento.tipo} · ${data} · ${evento.local}`;
}

// Mesma identidade visual dos demais módulos
const classeInput =
  "w-full rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 " +
  "shadow-sm focus:border-indigo-500 focus:outline-none focus:ring-2 focus:ring-indigo-200 " +
  "disabled:cursor-not-allowed disabled:opacity-60";

const classeBotaoSecundario =
  "rounded-lg border border-slate-300 bg-white px-2.5 py-1 text-xs font-medium text-slate-700 " +
  "transition hover:bg-slate-50 disabled:cursor-not-allowed disabled:opacity-60";

export default function FormularioPresenca({
  eventos,
  musicos,
  presencas,
  carregando,
  erro,
  onPresencaAdicionada,
}: FormularioPresencaProps) {
  const [eventoId, setEventoId] = useState("");
  // Mapa musico_id -> status marcado na tela (ainda não salvo)
  const [marcacoes, setMarcacoes] = useState<Record<string, string>>({});
  const [salvando, setSalvando] = useState(false);
  const [erroForm, setErroForm] = useState<string | null>(null);
  const [sucesso, setSucesso] = useState(false);

  // Presenças já gravadas para o evento selecionado: musico_id -> status
  const jaRegistrados = useMemo(() => {
    const mapa = new Map<string, string>();
    for (const presenca of presencas) {
      if (presenca.evento_id === eventoId) mapa.set(presenca.musico_id, presenca.status);
    }
    return mapa;
  }, [presencas, eventoId]);

  const pendentes = musicos.filter((musico) => !jaRegistrados.has(musico.id));
  const qtdMarcados = Object.keys(marcacoes).length;

  // Ao trocar de evento, zera marcações e mensagens
  function trocarEvento(novoEventoId: string) {
    setEventoId(novoEventoId);
    setMarcacoes({});
    setErroForm(null);
    setSucesso(false);
  }

  function marcar(musicoId: string, status: string) {
    setMarcacoes((anterior) => ({ ...anterior, [musicoId]: status }));
    setSucesso(false);
  }

  // Atalho: marca todos os músicos pendentes como "Presente"
  function marcarTodosPresentes() {
    const todos: Record<string, string> = {};
    for (const musico of pendentes) todos[musico.id] = "Presente";
    setMarcacoes(todos);
    setSucesso(false);
  }

  async function handleSubmit(submissao: FormEvent<HTMLFormElement>) {
    submissao.preventDefault();
    setErroForm(null);
    setSucesso(false);

    if (!eventoId) {
      setErroForm("Selecione um evento.");
      return;
    }

    // Monta o lote tipado com PresencaInsert (ignora quem já estava registrado)
    const registros: PresencaInsert[] = Object.entries(marcacoes)
      .filter(([musicoId]) => !jaRegistrados.has(musicoId))
      .map(([musicoId, status]) => ({
        musico_id: musicoId,
        evento_id: eventoId,
        status,
      }));

    if (registros.length === 0) {
      setErroForm("Marque a presença de pelo menos um músico.");
      return;
    }

    setSalvando(true);
    try {
      const { error } = await supabase.from("presencas").insert(registros);
      if (error) {
        // 23505 = violação de UNIQUE: alguém já registrou este músico neste evento
        throw new Error(
          error.code === "23505"
            ? "Alguma presença deste evento já foi registrada por outra pessoa. Recarregue a página e tente novamente."
            : error.message
        );
      }

      // Sucesso: limpa as marcações (o evento continua selecionado) e recarrega os dados
      setMarcacoes({});
      setSucesso(true);
      await onPresencaAdicionada();
    } catch (e) {
      setErroForm(
        `Não foi possível salvar as presenças: ${
          e instanceof Error ? e.message : "erro desconhecido."
        }`
      );
    } finally {
      setSalvando(false);
    }
  }

  // ---------- Estados da tela ----------

  // Carregando: skeleton
  if (carregando) {
    return (
      <div
        role="status"
        aria-live="polite"
        className="space-y-4 rounded-2xl border border-slate-200 bg-white p-6 shadow-sm"
      >
        <span className="sr-only">Carregando formulário...</span>
        <div className="h-6 w-1/2 animate-pulse rounded bg-slate-200" />
        <div className="h-10 animate-pulse rounded-lg bg-slate-200" />
        <div className="h-24 animate-pulse rounded-lg bg-slate-200" />
        <div className="h-10 animate-pulse rounded-lg bg-slate-200" />
      </div>
    );
  }

  // Erro ao buscar dados (o botão "Tentar novamente" fica na lista ao lado)
  if (erro) {
    return (
      <div className="rounded-2xl border border-slate-200 bg-white p-6 shadow-sm">
        <h2 className="text-lg font-semibold text-slate-900">Registrar presenças</h2>
        <p className="mt-2 text-sm text-slate-600">
          Formulário indisponível porque os dados não puderam ser carregados.
        </p>
      </div>
    );
  }

  // Pré-requisitos: precisa haver pelo menos um evento e um músico
  if (eventos.length === 0 || musicos.length === 0) {
    return (
      <div className="rounded-2xl border border-slate-200 bg-white p-6 shadow-sm">
        <h2 className="text-lg font-semibold text-slate-900">Registrar presenças</h2>
        <p className="mt-2 text-sm text-slate-600">
          Para registrar presenças é preciso ter ao menos um evento e um músico cadastrados.
        </p>
        <div className="mt-4 flex flex-wrap gap-2">
          {eventos.length === 0 && (
            <Link href="/eventos" className="text-sm font-semibold text-indigo-600 hover:underline">
              Cadastrar evento
            </Link>
          )}
          {musicos.length === 0 && (
            <Link href="/musicos" className="text-sm font-semibold text-indigo-600 hover:underline">
              Cadastrar músico
            </Link>
          )}
        </div>
      </div>
    );
  }

  return (
    <form
      onSubmit={handleSubmit}
      className="space-y-4 rounded-2xl border border-slate-200 bg-white p-6 shadow-sm"
    >
      <div>
        <h2 className="text-lg font-semibold text-slate-900">Registrar presenças</h2>
        <p className="text-sm text-slate-500">Escolha o evento e marque cada músico.</p>
      </div>

      <div className="space-y-1.5">
        <label htmlFor="evento" className="text-sm font-medium text-slate-700">
          Evento
        </label>
        <select
          id="evento"
          value={eventoId}
          onChange={(e) => trocarEvento(e.target.value)}
          disabled={salvando}
          className={classeInput}
        >
          <option value="">Selecione um evento</option>
          {eventos.map((evento) => (
            <option key={evento.id} value={evento.id}>
              {rotuloEvento(evento)}
            </option>
          ))}
        </select>
      </div>

      {/* Lista de músicos: aparece depois de escolher o evento */}
      {eventoId && (
        <div className="space-y-3">
          <div className="flex flex-wrap items-center justify-between gap-2">
            <p className="text-sm font-medium text-slate-700">
              Músicos ({qtdMarcados} de {pendentes.length} marcados)
            </p>
            <div className="flex gap-2">
              <button
                type="button"
                onClick={marcarTodosPresentes}
                disabled={salvando || pendentes.length === 0}
                className={classeBotaoSecundario}
              >
                Todos presentes
              </button>
              <button
                type="button"
                onClick={() => setMarcacoes({})}
                disabled={salvando || qtdMarcados === 0}
                className={classeBotaoSecundario}
              >
                Limpar
              </button>
            </div>
          </div>

          <ul className="max-h-96 space-y-2 overflow-y-auto pr-1">
            {musicos.map((musico) => {
              const statusRegistrado = jaRegistrados.get(musico.id);
              const statusAtual = marcacoes[musico.id];

              return (
                <li key={musico.id} className="rounded-xl border border-slate-200 p-3">
                  <p className="truncate text-sm font-medium text-slate-900">
                    {musico.nome}
                    <span className="ml-2 text-xs font-normal text-slate-500">
                      {musico.instrumento}
                    </span>
                  </p>

                  {statusRegistrado ? (
                    // Já registrado neste evento: somente leitura
                    <p className="mt-2 text-xs text-slate-500">
                      Já registrado:{" "}
                      <span
                        className={
                          "rounded-full px-2 py-0.5 font-medium " + classeStatus(statusRegistrado)
                        }
                      >
                        {statusRegistrado}
                      </span>
                    </p>
                  ) : (
                    // Botões de seleção (radio escondido + rótulo estilizado)
                    <div
                      role="radiogroup"
                      aria-label={`Presença de ${musico.nome}`}
                      className="mt-2 flex flex-wrap gap-1.5"
                    >
                      {STATUS_PRESENCA.map((opcao) => (
                        <label key={opcao.valor} className="cursor-pointer">
                          <input
                            type="radio"
                            name={`presenca-${musico.id}`}
                            value={opcao.valor}
                            checked={statusAtual === opcao.valor}
                            onChange={() => marcar(musico.id, opcao.valor)}
                            disabled={salvando}
                            className="peer sr-only"
                          />
                          <span
                            className={
                              "block rounded-lg border border-slate-300 bg-white px-2.5 py-1.5 " +
                              "text-xs font-medium text-slate-600 transition " +
                              "peer-focus-visible:ring-2 peer-focus-visible:ring-indigo-300 " +
                              "peer-disabled:opacity-60 " +
                              opcao.classe
                            }
                          >
                            {opcao.valor}
                          </span>
                        </label>
                      ))}
                    </div>
                  )}
                </li>
              );
            })}
          </ul>
        </div>
      )}

      {erroForm && (
        <p role="alert" className="rounded-lg bg-red-50 px-3 py-2 text-sm text-red-700">
          {erroForm}
        </p>
      )}
      {sucesso && (
        <p role="status" className="rounded-lg bg-emerald-50 px-3 py-2 text-sm text-emerald-700">
          Presenças registradas com sucesso!
        </p>
      )}

      <button
        type="submit"
        disabled={salvando || !eventoId}
        className="w-full rounded-lg bg-indigo-600 px-4 py-2.5 text-sm font-semibold text-white shadow-sm transition hover:bg-indigo-500 focus:outline-none focus:ring-2 focus:ring-indigo-300 disabled:cursor-not-allowed disabled:opacity-60"
      >
        {salvando
          ? "Salvando..."
          : qtdMarcados > 0
            ? `Salvar presenças (${qtdMarcados})`
            : "Salvar presenças"}
      </button>
    </form>
  );
}
