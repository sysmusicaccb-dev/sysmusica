"use client";

/**
 * SysMúsica — Dashboard (página inicial "/").
 *
 * Indicadores REAIS (contagens do banco), gráficos dos cadastros (membros por cargo, família,
 * instrumento e congregação; presenças), próximos eventos e atalhos.
 * Dados: src/modules/dashboard/services (indicadores.ts e graficos.ts).
 * Trata carregamento (skeleton), erro (com "Tentar novamente") e listas vazias.
 */
import { useCallback, useEffect, useState } from "react";
import { CalendarDays, ClipboardCheck, Guitar, Users } from "lucide-react";
import {
  buscarIndicadores,
  buscarProximosEventos,
  type Indicadores,
} from "@/modules/dashboard/services/indicadores";
import { buscarDadosGraficos, type DadosGraficos } from "@/modules/dashboard/services/graficos";
import AtalhosRapidos from "@/modules/dashboard/components/AtalhosRapidos";
import PainelGraficos from "@/modules/dashboard/components/PainelGraficos";
import ProximosEventos from "@/modules/dashboard/components/ProximosEventos";
import ErrorState from "@/components/ui/ErrorState";
import PageHeader from "@/components/ui/PageHeader";
import Skeleton from "@/components/ui/Skeleton";
import StatCard from "@/components/ui/StatCard";
import type { Evento } from "@/types/database";

export default function DashboardConteudo() {
  const [indicadores, setIndicadores] = useState<Indicadores | null>(null);
  const [proximosEventos, setProximosEventos] = useState<Evento[]>([]);
  const [graficos, setGraficos] = useState<DadosGraficos | null>(null);
  const [carregando, setCarregando] = useState(true); // inicia true: primeira busca no mount
  const [erro, setErro] = useState<string | null>(null);

  // Busca indicadores, próximos eventos e dados dos gráficos em paralelo
  const carregar = useCallback(async () => {
    try {
      const [totais, proximos, dadosGraficos] = await Promise.all([
        buscarIndicadores(),
        buscarProximosEventos(5),
        buscarDadosGraficos(),
      ]);
      setIndicadores(totais);
      setProximosEventos(proximos);
      setGraficos(dadosGraficos);
      setErro(null);
    } catch (e) {
      // O detalhe técnico vai só para o console; a tela mostra uma mensagem simples
      console.error("Falha ao carregar o dashboard:", e);
      setErro("Não foi possível carregar os indicadores. Verifique a conexão e tente novamente.");
    } finally {
      setCarregando(false);
    }
  }, []);

  // Primeira carga ao abrir a página
  useEffect(() => {
    // O setState só roda DEPOIS do await (nunca de forma síncrona), então o aviso da regra
    // set-state-in-effect não se aplica a esta carga inicial. Ignorado apenas nesta linha.
    // eslint-disable-next-line react-hooks/set-state-in-effect
    void carregar();
  }, [carregar]);

  // Botão "Tentar novamente": volta ao estado de loading e busca de novo
  function tentarNovamente() {
    setCarregando(true);
    void carregar();
  }

  return (
    <main className="text-slate-900">
      <div className="mx-auto max-w-7xl px-4 py-8 sm:px-6 lg:px-8">
        <PageHeader titulo="Dashboard" descricao="Visão geral do SysMúsica." />

        {carregando ? (
          // Carregando: skeleton com o mesmo formato da tela final
          <div role="status" aria-live="polite" className="space-y-6">
            <span className="sr-only">Carregando o dashboard...</span>
            <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
              {[0, 1, 2, 3].map((i) => (
                <Skeleton key={i} className="h-28 rounded-2xl" />
              ))}
            </div>
            <div className="grid gap-6 lg:grid-cols-3">
              <Skeleton className="h-72 rounded-2xl lg:col-span-2" />
              <Skeleton className="h-72 rounded-2xl" />
            </div>
            <div className="grid gap-6 lg:grid-cols-2">
              <Skeleton className="h-64 rounded-2xl" />
              <Skeleton className="h-64 rounded-2xl" />
            </div>
          </div>
        ) : erro || !indicadores || !graficos ? (
          <ErrorState
            titulo="Não foi possível carregar o dashboard."
            mensagem={erro ?? "Tente novamente em instantes."}
            onTentarNovamente={tentarNovamente}
          />
        ) : (
          <div className="space-y-6">
            {/* Indicadores (cada cartão leva à tela correspondente) */}
            <section aria-label="Indicadores" className="grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
              <StatCard
                rotulo="Membros"
                valor={indicadores.membros}
                detalhe={`${indicadores.membrosAtivos} ativo(s)`}
                icone={Users}
                href="/membros"
              />
              <StatCard
                rotulo="Eventos"
                valor={indicadores.eventos}
                detalhe={`${indicadores.eventosFuturos} agendado(s)`}
                icone={CalendarDays}
                href="/eventos"
              />
              <StatCard
                rotulo="Presenças"
                valor={indicadores.presencas}
                detalhe="registros no total"
                icone={ClipboardCheck}
                href="/portaria"
              />
              <StatCard
                rotulo="Instrumentos"
                valor={indicadores.instrumentos}
                detalhe={`${indicadores.instrumentosSemFamilia} sem família`}
                icone={Guitar}
                href="/instrumentos"
              />
            </section>

            <PainelGraficos dados={graficos} />

            <div className="grid gap-6 lg:grid-cols-3">
              <div className="lg:col-span-2">
                <ProximosEventos eventos={proximosEventos} />
              </div>
              <AtalhosRapidos />
            </div>
          </div>
        )}
      </div>
    </main>
  );
}
