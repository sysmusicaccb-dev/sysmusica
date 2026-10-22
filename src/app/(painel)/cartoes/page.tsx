"use client";

/**
 * Sysmusica — Cadastros > Cartões a Vencer: lista dos cartões de identificação vencidos, a vencer no
 * prazo escolhido (30, 60 ou 90 dias) e dos cargos que exigem cartão mas estão sem validade informada.
 * Só mostra membros ativos da abrangência de quem consulta (o banco confere a permissão e a abrangência).
 * Para corrigir uma validade: Músicos e Organistas > editar o cadastro, ou aprovar a atualização
 * enviada pelo link público em Cadastros Pendentes.
 */
import { useCallback, useEffect, useMemo, useState } from "react";
import EmptyState from "@/components/ui/EmptyState";
import ErrorState from "@/components/ui/ErrorState";
import PageHeader from "@/components/ui/PageHeader";
import Skeleton from "@/components/ui/Skeleton";
import { cn } from "@/lib/cn";
import TabelaCartoes from "@/modules/cartoes/components/TabelaCartoes";
import { PRAZOS_DIAS, PRAZO_PADRAO_DIAS, ROTULO_SITUACAO, contarSituacoes, filtrarCartoes } from "@/modules/cartoes/regras";
import { listarCartoes } from "@/modules/cartoes/services/cartoes";
import type { FiltroCartao, LinhaCartao } from "@/modules/cartoes/tipos";

const FILTROS: { valor: FiltroCartao; rotulo: string }[] = [
  { valor: "TODOS", rotulo: "Todos" },
  { valor: "VENCIDO", rotulo: ROTULO_SITUACAO.VENCIDO },
  { valor: "A_VENCER", rotulo: ROTULO_SITUACAO.A_VENCER },
  { valor: "SEM_VALIDADE", rotulo: ROTULO_SITUACAO.SEM_VALIDADE },
];

export default function CartoesPage() {
  const [dias, setDias] = useState<number>(PRAZO_PADRAO_DIAS);
  const [filtro, setFiltro] = useState<FiltroCartao>("TODOS");
  const [itens, setItens] = useState<LinhaCartao[]>([]);
  const [carregando, setCarregando] = useState(true); // inicia true: primeira busca no mount
  const [erro, setErro] = useState<string | null>(null);

  // Busca a lista no banco para o prazo escolhido
  const carregar = useCallback(async (prazo: number) => {
    try {
      setItens(await listarCartoes(prazo));
      setErro(null);
    } catch (e) {
      console.error("Falha ao carregar os cartões:", e);
      setErro(e instanceof Error ? e.message : "Não foi possível carregar os cartões.");
    } finally {
      setCarregando(false);
    }
  }, []);

  // Carrega ao abrir a página e sempre que o prazo mudar
  useEffect(() => {
    // O setState só roda DEPOIS do await (nunca de forma síncrona), então o aviso da regra
    // set-state-in-effect não se aplica a esta carga. Ignorado apenas nesta linha.
    // eslint-disable-next-line react-hooks/set-state-in-effect
    void carregar(dias);
  }, [carregar, dias]);

  function trocarPrazo(novo: number) {
    setCarregando(true);
    setDias(novo);
  }

  function tentarNovamente() {
    setCarregando(true);
    void carregar(dias);
  }

  const contagem = useMemo(() => contarSituacoes(itens), [itens]);
  const visiveis = useMemo(() => filtrarCartoes(itens, filtro), [itens, filtro]);

  return (
    <main className="text-slate-900">
      <div className="mx-auto max-w-7xl px-4 py-8 sm:px-6 lg:px-8">
        <PageHeader
          titulo="Cartões a Vencer"
          descricao="Cartões de identificação vencidos, a vencer no prazo escolhido e cargos que exigem cartão sem validade informada."
        />

        <div className="mb-4 flex flex-wrap items-center gap-3">
          <div role="group" aria-label="Filtrar por situação" className="flex flex-wrap gap-2">
            {FILTROS.map(({ valor, rotulo }) => (
              <button
                key={valor}
                type="button"
                aria-pressed={filtro === valor}
                onClick={() => setFiltro(valor)}
                className={cn(
                  "rounded-full border px-3 py-1.5 text-sm font-medium transition focus:outline-none focus-visible:ring-2 focus-visible:ring-brand-300",
                  filtro === valor
                    ? "border-brand-600 bg-brand-50 text-brand-700"
                    : "border-slate-200 bg-white text-slate-600 hover:border-slate-300"
                )}
              >
                {rotulo} <span className="tabular-nums">({contagem[valor]})</span>
              </button>
            ))}
          </div>

          <div className="ml-auto flex items-center gap-2 text-sm text-slate-600">
            <label htmlFor="prazo-cartoes">Vencem em até</label>
            <select
              id="prazo-cartoes"
              value={dias}
              onChange={(evento) => trocarPrazo(Number(evento.target.value))}
              className="rounded-lg border border-slate-300 bg-white px-3 py-1.5 text-sm text-slate-800 focus:outline-none focus-visible:ring-2 focus-visible:ring-brand-300"
            >
              {PRAZOS_DIAS.map((prazo) => (
                <option key={prazo} value={prazo}>
                  {prazo} dias
                </option>
              ))}
            </select>
          </div>
        </div>

        {carregando ? (
          <div role="status" aria-live="polite" className="space-y-3">
            <span className="sr-only">Carregando os cartões...</span>
            <Skeleton className="h-14 rounded-2xl" />
            {[0, 1, 2, 3].map((i) => (
              <Skeleton key={i} className="h-12" />
            ))}
          </div>
        ) : erro ? (
          <ErrorState titulo="Não foi possível carregar os cartões." mensagem={erro} onTentarNovamente={tentarNovamente} />
        ) : itens.length === 0 ? (
          <EmptyState
            titulo="Nenhum cartão vencido ou a vencer."
            descricao={`Nenhum cartão vence nos próximos ${dias} dias e nenhum cargo que exige cartão está sem validade.`}
          />
        ) : visiveis.length === 0 ? (
          <EmptyState titulo="Nenhum cartão nesta situação." descricao="Escolha outro filtro para ver os demais." />
        ) : (
          <TabelaCartoes itens={visiveis} />
        )}
      </div>
    </main>
  );
}
