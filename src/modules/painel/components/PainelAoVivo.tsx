"use client";

/**
 * Sysmusica — Painel ao vivo: acompanha, em tempo real, quantos já entraram no evento e a contagem por
 * Ministério, Músicos, Organistas e Instrumentos, enquanto a Portaria registra as entradas.
 *
 * Atualização automática: a tela pergunta ao banco de tempos em tempos (padrão 10 s; o usuário escolhe
 * 5, 10, 15, 30 ou 60 s ou pausa). A escolha do intervalo fica guardada neste navegador. Com a aba em segundo
 * plano a tela não consulta, e ao voltar atualiza na hora. Se a internet cair, mostra os últimos números e
 * tenta de novo no próximo ciclo. O banco entrega só contagens e respeita a abrangência de cada usuário.
 */
import { useEffect, useState } from "react";
import { Pause, Play, RefreshCw } from "lucide-react";
import EmptyState from "@/components/ui/EmptyState";
import ErrorState from "@/components/ui/ErrorState";
import Skeleton from "@/components/ui/Skeleton";
import {
  INTERVALOS_SEGUNDOS,
  INTERVALO_PADRAO,
  formatarDiaDoEvento,
  formatarHoraDaAtualizacao,
  formatarHoraDoEvento,
  intervaloValido,
} from "../regras";
import { buscarPainel, listarEventosDoPainel } from "../services/painel";
import type { DadosPainel, EventoParaEscolher } from "../tipos";
import PainelTotais from "./PainelTotais";

// Guarda o intervalo escolhido só neste navegador (se o armazenamento não estiver disponível, apenas não lembra)
const CHAVE_INTERVALO = "sysmusica.painel.intervalo";

function lerIntervaloGuardado(): number {
  try {
    return intervaloValido(window.localStorage.getItem(CHAVE_INTERVALO));
  } catch {
    return INTERVALO_PADRAO;
  }
}

function guardarIntervalo(segundos: number) {
  try {
    window.localStorage.setItem(CHAVE_INTERVALO, String(segundos));
  } catch {
    // sem armazenamento disponível: apenas não lembra a escolha
  }
}

const classeCampo =
  "w-full rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 shadow-sm " +
  "focus:border-brand-500 focus:outline-none focus:ring-2 focus:ring-brand-200 [color-scheme:light]";

const classeBotao =
  "inline-flex items-center gap-2 rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm font-medium " +
  "text-slate-700 transition hover:bg-slate-50 disabled:cursor-not-allowed disabled:opacity-60";

function rotuloDoEvento(evento: EventoParaEscolher): string {
  const quando = `${formatarDiaDoEvento(evento.data_evento)} ${formatarHoraDoEvento(evento.data_evento)}`;
  return [quando, evento.tipo, evento.local_evento].filter(Boolean).join(" · ");
}

export default function PainelAoVivo() {
  const [eventos, setEventos] = useState<EventoParaEscolher[] | null>(null); // nulo = carregando a lista
  const [erroEventos, setErroEventos] = useState<string | null>(null);
  const [eventoId, setEventoId] = useState("");
  const [dados, setDados] = useState<DadosPainel | null>(null);
  const [erro, setErro] = useState<string | null>(null);
  const [intervalo, setIntervalo] = useState(INTERVALO_PADRAO);
  const [pausado, setPausado] = useState(false);
  const [atualizadoEm, setAtualizadoEm] = useState<Date | null>(null);
  const [atualizando, setAtualizando] = useState(false);
  const [rodada, setRodada] = useState(0); // muda quando o usuário pede "Atualizar agora"

  /* eslint-disable react-hooks/set-state-in-effect */
  // Intervalo guardado neste navegador
  useEffect(() => {
    setIntervalo(lerIntervaloGuardado());
  }, []);

  // Lista de eventos: já abre no mais próximo de agora
  useEffect(() => {
    let cancelado = false;
    void listarEventosDoPainel()
      .then((lista) => {
        if (cancelado) return;
        setEventos(lista);
        setEventoId(lista[0]?.id ?? "");
      })
      .catch((e: unknown) => {
        if (cancelado) return;
        setEventos([]);
        setErroEventos(e instanceof Error ? e.message : "Não foi possível carregar os eventos.");
      });
    return () => {
      cancelado = true;
    };
  }, []);

  // Atualização automática do evento escolhido
  useEffect(() => {
    if (!eventoId) return;
    let ativo = true;

    const buscar = async () => {
      if (document.hidden) return; // aba em segundo plano: não consulta
      setAtualizando(true);
      try {
        const resposta = await buscarPainel(eventoId);
        if (!ativo) return;
        setDados(resposta);
        setErro(null);
        setAtualizadoEm(new Date());
      } catch (e) {
        if (!ativo) return;
        setErro(e instanceof Error ? e.message : "Não foi possível atualizar o painel.");
      } finally {
        if (ativo) setAtualizando(false);
      }
    };

    void buscar();
    const temporizador = pausado ? null : setInterval(() => void buscar(), intervalo * 1000);
    const aoVoltarParaAAba = () => {
      if (!document.hidden) void buscar();
    };
    document.addEventListener("visibilitychange", aoVoltarParaAAba);

    return () => {
      ativo = false;
      if (temporizador) clearInterval(temporizador);
      document.removeEventListener("visibilitychange", aoVoltarParaAAba);
    };
  }, [eventoId, intervalo, pausado, rodada]);
  /* eslint-enable react-hooks/set-state-in-effect */

  function trocarEvento(id: string) {
    setDados(null);
    setErro(null);
    setAtualizadoEm(null);
    setPausado(false);
    setEventoId(id);
  }

  function trocarIntervalo(valor: string) {
    const segundos = intervaloValido(valor);
    setIntervalo(segundos);
    guardarIntervalo(segundos);
  }

  // ---------- Estados da tela ----------

  if (eventos === null) {
    return (
      <div role="status" aria-live="polite" className="space-y-3">
        <span className="sr-only">Carregando o painel...</span>
        <Skeleton className="h-20 rounded-2xl" />
        <Skeleton className="h-96 rounded-2xl" />
      </div>
    );
  }

  if (erroEventos) {
    return (
      <ErrorState
        titulo="Não foi possível carregar o painel."
        mensagem={erroEventos}
        onTentarNovamente={() => window.location.reload()}
      />
    );
  }

  if (eventos.length === 0) {
    return (
      <EmptyState
        titulo="Nenhum evento por perto"
        descricao="O painel mostra os eventos dos últimos e dos próximos 30 dias dentro da sua abrangência. Cadastre o evento e a portaria para acompanhar a entrada."
      />
    );
  }

  return (
    <div className="space-y-4">
      {/* Controles: evento, intervalo, pausar e atualizar */}
      <section className="rounded-2xl border border-slate-200 bg-white p-4 shadow-sm">
        <div className="flex flex-wrap items-end gap-3">
          {eventos.length > 1 && (
            <div className="min-w-0 flex-1 basis-64 space-y-1.5">
              <label htmlFor="painel-evento" className="text-xs font-medium text-slate-600">
                Evento
              </label>
              <select
                id="painel-evento"
                value={eventoId}
                onChange={(e) => trocarEvento(e.target.value)}
                className={classeCampo}
              >
                {eventos.map((item) => (
                  <option key={item.id} value={item.id}>
                    {rotuloDoEvento(item)}
                  </option>
                ))}
              </select>
            </div>
          )}

          <div className="space-y-1.5">
            <label htmlFor="painel-intervalo" className="text-xs font-medium text-slate-600">
              Atualizar a cada
            </label>
            <select
              id="painel-intervalo"
              value={intervalo}
              onChange={(e) => trocarIntervalo(e.target.value)}
              className={classeCampo}
            >
              {INTERVALOS_SEGUNDOS.map((segundos) => (
                <option key={segundos} value={segundos}>
                  {segundos} segundos
                </option>
              ))}
            </select>
          </div>

          <button type="button" className={classeBotao} onClick={() => setPausado((valor) => !valor)}>
            {pausado ? (
              <Play className="h-4 w-4" aria-hidden="true" />
            ) : (
              <Pause className="h-4 w-4" aria-hidden="true" />
            )}
            {pausado ? "Retomar" : "Pausar"}
          </button>

          <button
            type="button"
            className={classeBotao}
            onClick={() => setRodada((valor) => valor + 1)}
            disabled={atualizando}
          >
            <RefreshCw className={"h-4 w-4" + (atualizando ? " animate-spin" : "")} aria-hidden="true" />
            Atualizar agora
          </button>
        </div>

        <p className="mt-3 flex flex-wrap items-center gap-x-3 gap-y-1 text-xs text-slate-500" role="status">
          <span className="inline-flex items-center gap-1.5 font-medium text-slate-700">
            <span
              className={
                "h-2 w-2 rounded-full " + (pausado || erro ? "bg-slate-400" : "animate-pulse bg-emerald-500")
              }
              aria-hidden="true"
            />
            {pausado ? "Atualização pausada" : erro ? "Sem atualização" : `Ao vivo · a cada ${intervalo} s`}
          </span>
          {atualizadoEm && <span>Atualizado às {formatarHoraDaAtualizacao(atualizadoEm)}</span>}
        </p>
      </section>

      {erro && dados && (
        <p role="alert" className="rounded-lg bg-amber-50 px-3 py-2 text-sm text-amber-800">
          Não foi possível atualizar agora ({erro}). Estes são os últimos números recebidos; a tela tenta de novo sozinha.
        </p>
      )}

      {!dados ? (
        erro ? (
          <ErrorState
            titulo="Não foi possível carregar o painel."
            mensagem={erro}
            onTentarNovamente={() => setRodada((valor) => valor + 1)}
          />
        ) : (
          <div role="status" aria-live="polite" className="space-y-3">
            <span className="sr-only">Carregando o painel...</span>
            <Skeleton className="h-20 rounded-2xl" />
            <Skeleton className="h-96 rounded-2xl" />
          </div>
        )
      ) : (
        <>
          {/* Painel de Totais: cabeçalho do evento, cartões, gráficos e tabelas */}
          <PainelTotais dados={dados} />
        </>
      )}
    </div>
  );
}
