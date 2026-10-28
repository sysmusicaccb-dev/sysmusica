"use client";

/**
 * Sysmusica — Eventos > Configurações: se o evento encerra sozinho e depois de quantas horas (contadas a partir do
 * horário de INÍCIO do evento). Encerrar o evento encerra também a portaria dele.
 * Com "encerrar sozinho" desligado, o evento só termina quando alguém o encerra (botão Encerrar em Eventos):
 * Secretário da Música no Ensaio Regional, Instrutor no Ensaio Local, e administradores em qualquer evento.
 */
import { useEffect, useState } from "react";
import Notificacao from "@/components/ui/Notificacao";
import PageHeader from "@/components/ui/PageHeader";
import Skeleton from "@/components/ui/Skeleton";
import { definirRegraEncerramento } from "@/modules/portarias/janela";
import { obterConfigEventos, salvarConfigEventos } from "@/modules/eventos/services/configEventos";

const CAMPO =
  "mt-1 w-32 rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 shadow-sm focus:border-brand-500 focus:outline-none focus:ring-2 focus:ring-brand-200 disabled:cursor-not-allowed disabled:bg-slate-100";

export default function ConfiguracaoEventosPage() {
  const [carregando, setCarregando] = useState(true);
  const [sozinho, setSozinho] = useState(true);
  const [horas, setHoras] = useState("24");
  const [salvando, setSalvando] = useState(false);
  const [erro, setErro] = useState<string | null>(null);
  const [aviso, setAviso] = useState<string | null>(null);

  useEffect(() => {
    let ativo = true;
    obterConfigEventos()
      .then((config) => {
        if (!ativo) return;
        setSozinho(config.encerra_sozinho);
        setHoras(String(config.horas_apos_inicio));
      })
      .catch((e: unknown) => {
        if (ativo) setErro(e instanceof Error ? e.message : "Não foi possível carregar a configuração.");
      })
      .finally(() => {
        if (ativo) setCarregando(false);
      });
    return () => {
      ativo = false;
    };
  }, []);

  async function salvar() {
    const numero = Number(horas);
    if (!Number.isInteger(numero) || numero < 1 || numero > 720) {
      setErro("Informe um número inteiro de horas, de 1 a 720.");
      return;
    }
    setSalvando(true);
    setErro(null);
    try {
      await salvarConfigEventos({ encerra_sozinho: sozinho, horas_apos_inicio: numero });
      definirRegraEncerramento(sozinho, numero); // vale já nesta tela; as demais pegam ao recarregar
      setAviso("Configuração salva.");
    } catch (e) {
      setErro(e instanceof Error ? e.message : "Não foi possível salvar a configuração.");
    } finally {
      setSalvando(false);
    }
  }

  return (
    <main className="text-slate-900">
      <div className="mx-auto max-w-3xl px-4 py-8 sm:px-6 lg:px-8">
        <PageHeader titulo="Configurações de Eventos" descricao="Encerramento do evento e da portaria." />

        {carregando ? (
          <Skeleton className="h-40 rounded-2xl" />
        ) : (
          <form
            className="space-y-5 rounded-2xl border border-slate-200 bg-white p-5 shadow-sm"
            onSubmit={(ev) => {
              ev.preventDefault();
              void salvar();
            }}
          >
            <div>
              <label className="flex items-start gap-3 text-sm font-medium text-slate-800">
                <input type="checkbox" checked={sozinho} onChange={(ev) => setSozinho(ev.target.checked)} className="mt-0.5 h-4 w-4" />
                <span>
                  Encerrar o evento sozinho, caso ninguém o encerre
                  <span className="mt-0.5 block text-xs font-normal text-slate-500">
                    Desligado: o evento e a portaria ficam abertos até alguém clicar em Encerrar.
                  </span>
                </span>
              </label>
            </div>

            <div>
              <label htmlFor="cfg-horas" className="text-sm font-medium text-slate-700">Horas depois do horário de início</label>
              <input
                id="cfg-horas"
                type="number"
                min={1}
                max={720}
                value={horas}
                onChange={(ev) => setHoras(ev.target.value)}
                disabled={!sozinho}
                className={CAMPO}
              />
              <p className="mt-1 text-xs text-slate-500">
                Ex.: evento às 19h com 24 horas encerra sozinho às 19h do dia seguinte. A portaria abre 2 horas antes do início.
              </p>
            </div>

            <div className="rounded-lg bg-slate-50 p-3 text-xs text-slate-600">
              <p className="font-semibold text-slate-700">Quem encerra manualmente (botão Encerrar, em Eventos)</p>
              <ul className="mt-1 list-disc space-y-0.5 pl-4">
                <li>Ensaio Local: Instrutor.</li>
                <li>Ensaio Técnico de Famílias (Cordas, Madeiras e Metais): Secretário da Música.</li>
                <li>Secretário da Música: qualquer evento (todas as opções).</li>
                <li>Administrador e Administrador Regional: qualquer evento.</li>
              </ul>
            </div>

            {erro && <p role="alert" className="rounded-lg bg-red-50 px-3 py-2 text-sm text-red-700">{erro}</p>}

            <button
              type="submit"
              disabled={salvando}
              className="rounded-lg bg-brand-600 px-4 py-2 text-sm font-semibold text-white shadow-sm hover:bg-brand-500 disabled:opacity-60"
            >
              {salvando ? "Salvando..." : "Salvar"}
            </button>
          </form>
        )}
      </div>
      <Notificacao mensagem={aviso} onFechar={() => setAviso(null)} />
    </main>
  );
}
