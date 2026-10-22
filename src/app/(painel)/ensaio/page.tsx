"use client";

/**
 * Sysmusica — Página /ensaio: Dados do Ensaio (Local ou Regional).
 * Escolha o ensaio na lista; o formulário aparece abaixo. Quem tem "Painel ao vivo" também vê os totais do evento.
 * Quem preenche (ensaio.registrar) edita de 2 h antes até 3 h depois do início; depois disso só o Administrador.
 */
import { useCallback, useEffect, useState } from "react";
import { formatarDiaDoEvento, formatarHoraDoEvento } from "@/modules/painel/regras";
import { buscarPainel } from "@/modules/painel/services/painel";
import type { DadosPainel } from "@/modules/painel/tipos";
import ResumoTempoReal from "@/modules/painel/components/ResumoTempoReal";
import { listarHinos } from "@/modules/hinos/services/hinos";
import type { Hino } from "@/modules/hinos/regras";
import FormularioEnsaio from "@/modules/ensaio/components/FormularioEnsaio";
import { carregarCidades } from "@/modules/ensaio/services/cidades";
import { listarEventosParaEnsaio, obterDadosEnsaio } from "@/modules/ensaio/services/ensaio";
import type { Cidade } from "@/modules/ensaio/cidades";
import type { EventoParaEnsaio, RespostaEnsaio } from "@/modules/ensaio/tipos";
import { useSessao } from "@/modules/autenticacao/SessaoProvider";
import EmptyState from "@/components/ui/EmptyState";
import ErrorState from "@/components/ui/ErrorState";
import Notificacao from "@/components/ui/Notificacao";
import PageHeader from "@/components/ui/PageHeader";
import Skeleton from "@/components/ui/Skeleton";

export default function EnsaioPage() {
  const { pode } = useSessao();
  const [eventos, setEventos] = useState<EventoParaEnsaio[]>([]);
  const [hinos, setHinos] = useState<Hino[]>([]);
  const [cidades, setCidades] = useState<Cidade[]>([]);
  const [carregando, setCarregando] = useState(true);
  const [erro, setErro] = useState<string | null>(null);

  const [eventoId, setEventoId] = useState("");
  const [resposta, setResposta] = useState<RespostaEnsaio | null>(null);
  const [totais, setTotais] = useState<DadosPainel | null>(null);
  const [carregandoEvento, setCarregandoEvento] = useState(false);
  const [erroEvento, setErroEvento] = useState<string | null>(null);
  const [versao, setVersao] = useState(0); // muda a cada gravação para recriar o formulário com os dados novos
  const [aviso, setAviso] = useState<string | null>(null);

  const verTotais = pode("painel.visualizar");

  // Lista de ensaios + hinos (as cidades do IBGE carregam em segundo plano: nunca travam a tela)
  const carregar = useCallback(async () => {
    try {
      const [lista, todosHinos] = await Promise.all([listarEventosParaEnsaio(), listarHinos()]);
      setEventos(lista);
      setHinos(todosHinos);
      setErro(null);
    } catch (e) {
      console.error("Falha ao carregar os ensaios:", e);
      setErro("Não foi possível carregar os ensaios. Verifique a conexão e tente novamente.");
    } finally {
      setCarregando(false);
    }
  }, []);

  useEffect(() => {
    // O setState só roda DEPOIS do await, então o aviso da regra set-state-in-effect não se aplica aqui.
    // eslint-disable-next-line react-hooks/set-state-in-effect
    void carregar();
    void carregarCidades().then(setCidades);
  }, [carregar]);

  // Carrega os dados do ensaio escolhido (e os totais, se a pessoa pode ver o painel)
  const carregarEvento = useCallback(
    async (id: string) => {
      setCarregandoEvento(true);
      setErroEvento(null);
      try {
        const [dados, painel] = await Promise.all([
          obterDadosEnsaio(id),
          verTotais ? buscarPainel(id).catch(() => null) : Promise.resolve(null),
        ]);
        setResposta(dados);
        setTotais(painel);
        setVersao((v) => v + 1);
      } catch (e) {
        setResposta(null);
        setErroEvento(e instanceof Error ? e.message : "Não foi possível carregar os dados do ensaio.");
      } finally {
        setCarregandoEvento(false);
      }
    },
    [verTotais]
  );

  function escolher(id: string) {
    setEventoId(id);
    setResposta(null);
    setTotais(null);
    if (id) void carregarEvento(id);
  }

  async function aoSalvar(mensagem: string) {
    await Promise.all([carregarEvento(eventoId), carregar()]);
    setAviso(mensagem);
  }

  return (
    <main className="text-slate-900">
      <div className="mx-auto max-w-7xl px-4 py-8 sm:px-6 lg:px-8">
        <PageHeader
          titulo="Dados do Ensaio"
          descricao="Registre quem atendeu, os encarregados, o hino de abertura e os hinos executados."
        />

        {carregando ? (
          <div role="status" aria-live="polite" className="space-y-3">
            <span className="sr-only">Carregando ensaios...</span>
            <Skeleton className="h-12 rounded-xl" />
            <Skeleton className="h-64 rounded-2xl" />
          </div>
        ) : erro ? (
          <ErrorState
            titulo="Não foi possível carregar os ensaios."
            mensagem={erro}
            onTentarNovamente={() => {
              setCarregando(true);
              void carregar();
            }}
          />
        ) : eventos.length === 0 ? (
          <EmptyState
            titulo="Nenhum ensaio recente ou próximo."
            descricao="Só aparecem eventos cujo tipo usa Dados do Ensaio (Ensaio Local ou Regional), de 30 dias atrás até 2 dias à frente. Confira o tipo do evento em Eventos."
          />
        ) : (
          <div className="space-y-6">
            <div className="max-w-xl space-y-1.5">
              <label htmlFor="ensaio-evento" className="text-sm font-medium text-slate-700">
                Ensaio
              </label>
              <select
                id="ensaio-evento"
                value={eventoId}
                onChange={(e) => escolher(e.target.value)}
                className="w-full rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 shadow-sm focus:border-brand-500 focus:outline-none focus:ring-2 focus:ring-brand-200"
              >
                <option value="">Selecione o ensaio...</option>
                {eventos.map((ev) => (
                  <option key={ev.id} value={ev.id}>
                    {formatarDiaDoEvento(ev.data_evento)} {formatarHoraDoEvento(ev.data_evento)} — {ev.tipo}
                    {ev.casa_oracao_nome ? ` — ${ev.casa_oracao_nome}` : ev.cidade ? ` — ${ev.cidade}` : ""}
                    {ev.preenchido ? " ✓" : ""}
                  </option>
                ))}
              </select>
              <p className="text-xs text-slate-500">✓ = dados já registrados.</p>
            </div>

            {carregandoEvento && (
              <div role="status" aria-live="polite" className="space-y-3">
                <span className="sr-only">Carregando dados do ensaio...</span>
                <Skeleton className="h-64 rounded-2xl" />
              </div>
            )}
            {erroEvento && !carregandoEvento && (
              <ErrorState titulo="Não foi possível abrir este ensaio." mensagem={erroEvento} onTentarNovamente={() => void carregarEvento(eventoId)} />
            )}
            {resposta && !carregandoEvento && (
              <FormularioEnsaio
                key={`${resposta.evento.id}-${versao}`}
                resposta={resposta}
                hinos={hinos}
                cidades={cidades}
                temPermissaoPreencher={pode("ensaio.registrar")}
                lateral={totais ? <ResumoTempoReal dados={totais} /> : undefined}
                onSalvo={aoSalvar}
              />
            )}
          </div>
        )}
      </div>

      <Notificacao mensagem={aviso} onFechar={() => setAviso(null)} />
    </main>
  );
}
