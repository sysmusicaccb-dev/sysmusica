"use client";

/**
 * SysMúsica — Página /administracao/backup/agendamento (só o Administrador): backups automáticos diário, semanal,
 * quinzenal e mensal, com a retenção (quantos guardar de cada tipo). A tarefa roda uma vez por dia às 03:00 em
 * Salvador e escolhe o tipo do dia (mensal > quinzenal > semanal > diário). Os botões usam a configuração JÁ SALVA.
 */
import { useCallback, useEffect, useState, type ReactNode } from "react";
import ErrorState from "@/components/ui/ErrorState";
import PageHeader from "@/components/ui/PageHeader";
import Skeleton from "@/components/ui/Skeleton";
import {
  NOMES_DIA_SEMANA,
  descreverTipoDoDia,
  type AgendamentoPublico,
  type ConfigAgendamento,
} from "@/modules/backup/agendamento";
import AbasBackup from "@/modules/backup/components/AbasBackup";
import { dataHoraSalvador } from "@/modules/backup/regras";
import { executarRotinaAgora, obterAgendamento, salvarAgendamento } from "@/modules/backup/services/agendamentoApi";

const classeCampo =
  "rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 shadow-sm " +
  "focus:border-brand-500 focus:outline-none focus:ring-2 focus:ring-brand-200 disabled:opacity-60";
const classeBotao =
  "inline-flex items-center gap-2 rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm font-medium " +
  "text-slate-700 transition hover:bg-slate-50 disabled:cursor-not-allowed disabled:opacity-60";
const classeBotaoPrimario =
  "inline-flex items-center gap-2 rounded-lg bg-brand-600 px-4 py-2 text-sm font-semibold text-white shadow-sm " +
  "transition hover:bg-brand-700 disabled:cursor-not-allowed disabled:opacity-60";
const classeCaixa = "h-4 w-4 rounded border-slate-300 text-brand-600 focus:ring-brand-300";

function Secao({ titulo, children }: { titulo: string; children: ReactNode }) {
  return (
    <section className="rounded-2xl border border-slate-200 bg-white p-5 shadow-sm">
      <h2 className="mb-4 text-sm font-semibold text-slate-900">{titulo}</h2>
      <div className="space-y-4">{children}</div>
    </section>
  );
}

type TipoComCampos = "diario" | "semanal" | "quinzenal" | "mensal";

const LINHAS: { tipo: TipoComCampos; titulo: string; quando: string }[] = [
  { tipo: "diario", titulo: "Diário", quando: "Todos os dias em que não vale outro tipo." },
  { tipo: "semanal", titulo: "Semanal", quando: "Uma vez por semana, no dia escolhido." },
  { tipo: "quinzenal", titulo: "Quinzenal", quando: "Nos dias 1 e 16 de cada mês." },
  { tipo: "mensal", titulo: "Mensal", quando: "Uma vez por mês, no dia escolhido." },
];

export default function AgendamentoBackupPage() {
  const [dados, setDados] = useState<AgendamentoPublico | null>(null);
  const [form, setForm] = useState<ConfigAgendamento | null>(null);
  const [alterado, setAlterado] = useState(false); // há mudanças ainda não salvas
  const [carregando, setCarregando] = useState(true); // inicia true: primeira busca no mount
  const [erro, setErro] = useState<string | null>(null);
  const [ocupado, setOcupado] = useState<string | null>(null);
  const [erroAcao, setErroAcao] = useState<string | null>(null);
  const [aviso, setAviso] = useState<string | null>(null);

  const carregar = useCallback(async () => {
    try {
      const resposta = await obterAgendamento();
      setDados(resposta);
      setForm(resposta.config);
      setAlterado(false);
      setErro(null);
    } catch (e) {
      setErro(e instanceof Error ? e.message : "Não foi possível carregar o agendamento.");
    } finally {
      setCarregando(false);
    }
  }, []);

  // Primeira carga
  useEffect(() => {
    // O setState só roda DEPOIS do await (nunca de forma síncrona). Ignorado apenas nesta linha.
    // eslint-disable-next-line react-hooks/set-state-in-effect
    void carregar();
  }, [carregar]);

  function mudar(parcial: Partial<ConfigAgendamento>) {
    setForm((atual) => (atual ? { ...atual, ...parcial } : atual));
    setAlterado(true);
  }

  // Número inteiro dentro do intervalo; texto vazio ou inválido volta para o mínimo
  function numero(texto: string, min: number, max: number): number {
    const n = Number.parseInt(texto, 10);
    return Number.isNaN(n) ? min : Math.min(max, Math.max(min, n));
  }

  // Roda uma ação mostrando "ocupado" e trata o erro; a mensagem devolvida vira o aviso da tela
  async function executar(chave: string, tarefa: () => Promise<string | void>) {
    if (ocupado) return; // evita dois cliques seguidos
    setOcupado(chave);
    setErroAcao(null);
    setAviso(null);
    try {
      const mensagem = await tarefa();
      if (mensagem) setAviso(mensagem);
    } catch (e) {
      setErroAcao(e instanceof Error ? e.message : "Não foi possível concluir a operação.");
    } finally {
      setOcupado(null);
    }
  }

  function aoSalvar() {
    if (!form) return;
    void executar("salvar", async () => {
      const novo = await salvarAgendamento(form);
      setDados(novo);
      setForm(novo.config);
      setAlterado(false);
      return "Agendamento salvo.";
    });
  }

  function aoExecutar() {
    if (!window.confirm("Isto faz um backup de verdade agora, do tipo que vale para hoje, e aplica a retenção. Continuar?")) return;
    void executar("executar", async () => {
      const resposta = await executarRotinaAgora();
      await carregar(); // atualiza "última execução" e "próximo backup"
      return resposta.mensagem;
    });
  }

  const desabilitado = ocupado !== null;

  return (
    <main className="text-slate-900">
      <div className="mx-auto max-w-6xl px-4 py-8 sm:px-6 lg:px-8">
        <PageHeader
          titulo="Backup"
          descricao="Backups automáticos e quantos guardar de cada tipo. Somente o Administrador tem acesso."
          acoes={
            <button type="button" className={classeBotaoPrimario} onClick={aoSalvar} disabled={desabilitado || !alterado || !form}>
              {ocupado === "salvar" ? "Salvando..." : "Salvar agendamento"}
            </button>
          }
        />

        <AbasBackup />

        {erroAcao && (
          <p role="alert" className="mb-4 rounded-lg bg-red-50 px-3 py-2 text-sm text-red-700">
            {erroAcao}
          </p>
        )}
        {aviso && (
          <p role="status" className="mb-4 rounded-lg bg-emerald-50 px-3 py-2 text-sm text-emerald-700">
            {aviso}
          </p>
        )}

        {carregando ? (
          <div role="status" aria-live="polite" className="space-y-3">
            <span className="sr-only">Carregando o agendamento...</span>
            {[0, 1, 2].map((i) => (
              <Skeleton key={i} className="h-24" />
            ))}
          </div>
        ) : erro || !dados || !form ? (
          <ErrorState
            titulo="Não foi possível carregar o agendamento."
            mensagem={erro ?? "Tente novamente."}
            onTentarNovamente={() => {
              setCarregando(true);
              void carregar();
            }}
          />
        ) : (
          <div className="space-y-6">
            {alterado && (
              <p className="rounded-lg bg-slate-50 px-3 py-2 text-sm text-slate-600">
                Há mudanças não salvas. Salve antes de usar o botão de executar, que usa o agendamento salvo.
              </p>
            )}

            <Secao titulo="Backup automático">
              <label className="flex items-center gap-2 text-sm text-slate-700">
                <input type="checkbox" className={classeCaixa} checked={form.ativo} onChange={(e) => mudar({ ativo: e.target.checked })} />
                Fazer backups automáticos
              </label>
              <p className="text-xs text-slate-500">
                A rotina roda uma vez por dia, às 03:00 (horário de Salvador). No plano gratuito do Vercel o horário pode variar até uma hora. Em cada dia
                é feito um único backup, do tipo de maior prioridade que valer: mensal, quinzenal, semanal ou diário. Cada backup é verificado, copiado para o
                servidor local (se ligado em Destinos) e avisado por Telegram e e-mail.
              </p>
              <p className="text-sm text-slate-700">
                {dados.proximo
                  ? `Próximo backup automático: ${dataHoraSalvador(new Date(dados.proximo.quando))} (${descreverTipoDoDia(dados.proximo.tipo)}).`
                  : dados.config.ativo
                    ? "Nenhum backup automático previsto: confira os tipos ligados."
                    : "O backup automático está desligado."}
              </p>
            </Secao>

            <Secao titulo="Tipos de backup e retenção">
              <div className="divide-y divide-slate-100 rounded-xl border border-slate-200">
                {LINHAS.map((linha) => {
                  const campoAtivo = `${linha.tipo}_ativo` as const;
                  const campoRetencao = `${linha.tipo}_retencao` as const;
                  return (
                    <div key={linha.tipo} className="flex flex-wrap items-center justify-between gap-3 px-4 py-3">
                      <label className="flex min-w-[14rem] items-start gap-2 text-sm text-slate-700">
                        <input
                          type="checkbox"
                          className={`${classeCaixa} mt-0.5`}
                          checked={form[campoAtivo]}
                          onChange={(e) => mudar({ [campoAtivo]: e.target.checked } as Partial<ConfigAgendamento>)}
                        />
                        <span>
                          <span className="block font-medium text-slate-900">{linha.titulo}</span>
                          <span className="block text-xs text-slate-500">{linha.quando}</span>
                        </span>
                      </label>

                      <div className="flex flex-wrap items-center gap-3 text-sm text-slate-700">
                        {linha.tipo === "semanal" && (
                          <label className="flex items-center gap-2">
                            Dia
                            <select
                              className={classeCampo}
                              value={form.semanal_dia}
                              onChange={(e) => mudar({ semanal_dia: numero(e.target.value, 0, 6) })}
                            >
                              {NOMES_DIA_SEMANA.map((nome, indice) => (
                                <option key={nome} value={indice}>
                                  {nome}
                                </option>
                              ))}
                            </select>
                          </label>
                        )}
                        {linha.tipo === "mensal" && (
                          <label className="flex items-center gap-2">
                            Dia do mês
                            <input
                              type="number"
                              min={1}
                              max={28}
                              className={`${classeCampo} w-20`}
                              value={form.mensal_dia}
                              onChange={(e) => mudar({ mensal_dia: numero(e.target.value, 1, 28) })}
                            />
                          </label>
                        )}
                        <label className="flex items-center gap-2">
                          Guardar os últimos
                          <input
                            type="number"
                            min={1}
                            max={90}
                            className={`${classeCampo} w-20`}
                            value={form[campoRetencao]}
                            onChange={(e) => mudar({ [campoRetencao]: numero(e.target.value, 1, 90) } as Partial<ConfigAgendamento>)}
                          />
                        </label>
                      </div>
                    </div>
                  );
                })}
              </div>
              <p className="text-xs text-slate-500">
                A retenção apaga sozinha os backups antigos de cada tipo, mas só os que já foram verificados, e sempre deixa pelo menos um. Backups manuais e de
                segurança nunca são apagados automaticamente. Os arquivos já copiados para o servidor local não são apagados por aqui.
              </p>
            </Secao>

            <Secao titulo="Conferência e última execução">
              <ul className="list-disc space-y-1 pl-5 text-sm text-slate-700">
                <li>Às 15:00 o sistema confere se o backup do dia foi feito. Se não foi, avisa o atraso por Telegram e e-mail.</li>
                <li>Toda segunda-feira, reverifica os 3 backups mais recentes e manda um resumo.</li>
              </ul>
              <p className="text-sm text-slate-700">
                {dados.ultimo_em
                  ? `Última execução: ${dataHoraSalvador(new Date(dados.ultimo_em))}, ${dados.ultimo_resultado === "ok" ? "concluída" : dados.ultimo_resultado === "pulado" ? "não necessária" : "COM PROBLEMA"}${dados.ultimo_detalhe ? ` (${dados.ultimo_detalhe})` : ""}.`
                  : "Nenhuma execução automática ainda."}
              </p>
              {dados.ultima_verificacao_em && (
                <p className="text-sm text-slate-700">Última verificação semanal: {dataHoraSalvador(new Date(dados.ultima_verificacao_em))}.</p>
              )}
              <div>
                <button type="button" className={classeBotao} onClick={aoExecutar} disabled={desabilitado || alterado}>
                  {ocupado === "executar" ? "Executando..." : "Executar a rotina de hoje agora"}
                </button>
              </div>
            </Secao>
          </div>
        )}
      </div>
    </main>
  );
}
