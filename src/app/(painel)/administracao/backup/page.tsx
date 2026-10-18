"use client";

/**
 * SysMúsica — Página /administracao/backup (só o Administrador): fazer backup agora, baixar, verificar e
 * excluir. Os backups são criptografados e guardados no armazenamento privado do sistema.
 * Restauração e configuração dos avisos chegam na parte 1C; OneDrive e agendamento no bloco 2.
 */
import { useCallback, useEffect, useState } from "react";
import { Download, ShieldCheck, Trash2 } from "lucide-react";
import EmptyState from "@/components/ui/EmptyState";
import ErrorState from "@/components/ui/ErrorState";
import Notificacao from "@/components/ui/Notificacao";
import PageHeader from "@/components/ui/PageHeader";
import Skeleton from "@/components/ui/Skeleton";
import { formatarDataHora } from "@/lib/datas";
import { useSessao } from "@/modules/autenticacao/SessaoProvider";
import {
  classeIconeVerificacao,
  descreverAvisos,
  descreverVerificacao,
  formatarTamanho,
  ROTULO_TIPO,
  totalDeLinhas,
} from "@/modules/backup/regras";
import {
  excluirBackup,
  fazerBackup,
  listarBackups,
  obterUrlDeDownload,
  verificarBackup,
} from "@/modules/backup/services/backupApi";
import AbasBackup from "@/modules/backup/components/AbasBackup";
import EtiquetaVerificacao from "@/modules/backup/components/EtiquetaVerificacao";
import type { RegistroBackup } from "@/modules/backup/tipos";

const classeBotao =
  "inline-flex items-center gap-2 rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm font-medium " +
  "text-slate-700 transition hover:bg-slate-50 disabled:cursor-not-allowed disabled:opacity-60";

const classeBotaoPrimario =
  "inline-flex items-center gap-2 rounded-lg bg-brand-600 px-4 py-2 text-sm font-semibold text-white shadow-sm " +
  "transition hover:bg-brand-700 disabled:cursor-not-allowed disabled:opacity-60";

export default function BackupPage() {
  const { pode } = useSessao();

  const [backups, setBackups] = useState<RegistroBackup[]>([]);
  const [carregando, setCarregando] = useState(true); // inicia true: primeira busca no mount
  const [erro, setErro] = useState<string | null>(null);
  const [ocupado, setOcupado] = useState<string | null>(null); // "criar" ou "acao:id"
  const [erroAcao, setErroAcao] = useState<string | null>(null);
  const [aviso, setAviso] = useState<string | null>(null);
  const [observacao, setObservacao] = useState("");

  const carregar = useCallback(async () => {
    try {
      setBackups(await listarBackups());
      setErro(null);
    } catch (e) {
      setErro(e instanceof Error ? e.message : "Não foi possível carregar os backups.");
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

  // Roda uma ação mostrando "ocupado" e trata o erro; a mensagem devolvida vira o aviso da tela
  async function executar(chave: string, tarefa: () => Promise<string | void>) {
    if (ocupado) return; // evita dois cliques seguidos
    setOcupado(chave);
    setErroAcao(null);
    try {
      const mensagem = await tarefa();
      if (mensagem) setAviso(mensagem);
    } catch (e) {
      setErroAcao(e instanceof Error ? e.message : "Não foi possível concluir a operação.");
    } finally {
      setOcupado(null);
    }
  }

  function aoFazerBackup() {
    void executar("criar", async () => {
      const resposta = await fazerBackup(observacao.trim() || null);
      setObservacao("");
      await carregar();
      const titulo = resposta.verificacao.ok
        ? "Backup concluído e verificado"
        : "Atenção: o backup foi feito, mas não passou na verificação";
      const refeito = resposta.refeito ? " A primeira cópia falhou na verificação e foi refeita automaticamente." : "";
      return `${titulo} (${formatarTamanho(resposta.backup.tamanho_bytes)}).${refeito} ${descreverVerificacao(resposta.verificacao)} ${descreverAvisos(resposta.avisos)}`;
    });
  }

  function aoBaixar(id: string) {
    void executar(`baixar:${id}`, async () => {
      window.location.assign(await obterUrlDeDownload(id)); // o link temporário já baixa o arquivo
      return "Download iniciado. O arquivo é criptografado: só abre com a chave do sistema.";
    });
  }

  function aoVerificar(id: string) {
    void executar(`verificar:${id}`, async () => {
      const resultado = await verificarBackup(id);
      await carregar(); // a etiqueta e o ícone da lista mudam de cor
      return descreverVerificacao(resultado);
    });
  }

  function aoExcluir(id: string) {
    if (!window.confirm("Excluir este backup definitivamente? O arquivo será apagado do sistema.")) return;
    void executar(`excluir:${id}`, async () => {
      await excluirBackup(id);
      await carregar();
      return "Backup excluído.";
    });
  }

  return (
    <main className="text-slate-900">
      <div className="mx-auto max-w-6xl px-4 py-8 sm:px-6 lg:px-8">
        <PageHeader
          titulo="Backup"
          descricao="Cópias de segurança criptografadas dos dados do sistema. Somente o Administrador tem acesso."
          acoes={
            pode("backup.criar") ? (
              <button type="button" className={classeBotaoPrimario} onClick={aoFazerBackup} disabled={ocupado !== null}>
                {ocupado === "criar" ? "Fazendo o backup..." : "Fazer backup agora"}
              </button>
            ) : undefined
          }
        />

        <AbasBackup />

        <p className="mb-4 rounded-lg bg-slate-50 px-3 py-2 text-sm text-slate-600">
          Cada backup é comprimido, criptografado e guardado no armazenamento privado do sistema. Os links de
          download valem por 60 segundos. Guarde uma cópia da chave BACKUP_CHAVE fora do sistema: sem ela nenhum
          backup abre. Cada backup é verificado automaticamente logo depois de gravado, e o resultado aparece na
          etiqueta da lista e nos avisos.
        </p>

        {pode("backup.criar") && (
          <div className="mb-6 max-w-md space-y-1.5">
            <label htmlFor="backup-obs" className="text-xs font-medium text-slate-600">
              Observação do próximo backup <span className="font-normal text-slate-400">(opcional)</span>
            </label>
            <input
              id="backup-obs"
              type="text"
              maxLength={200}
              value={observacao}
              onChange={(e) => setObservacao(e.target.value)}
              disabled={ocupado !== null}
              placeholder="Ex: antes de importar os membros de Jequié"
              className="w-full rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 shadow-sm focus:border-brand-500 focus:outline-none focus:ring-2 focus:ring-brand-200 disabled:opacity-60"
            />
          </div>
        )}

        {erroAcao && (
          <p role="alert" className="mb-4 rounded-lg bg-red-50 px-3 py-2 text-sm text-red-700">
            {erroAcao}
          </p>
        )}

        {carregando ? (
          <div role="status" aria-live="polite" className="space-y-3">
            <span className="sr-only">Carregando os backups...</span>
            {[0, 1, 2].map((i) => (
              <Skeleton key={i} className="h-12" />
            ))}
          </div>
        ) : erro ? (
          <ErrorState
            titulo="Não foi possível carregar os backups."
            mensagem={erro}
            onTentarNovamente={() => {
              setCarregando(true);
              void carregar();
            }}
          />
        ) : backups.length === 0 ? (
          <EmptyState titulo="Nenhum backup ainda." descricao="Clique em “Fazer backup agora” para criar o primeiro." />
        ) : (
          <div className="overflow-x-auto rounded-2xl border border-slate-200 bg-white shadow-sm">
            <table className="min-w-full divide-y divide-slate-200 text-sm">
              <thead className="bg-slate-50 text-xs uppercase tracking-wide text-slate-500">
                <tr>
                  <th scope="col" className="px-4 py-3 text-left font-semibold">Quando</th>
                  <th scope="col" className="px-4 py-3 text-left font-semibold">Tipo</th>
                  <th scope="col" className="px-4 py-3 text-left font-semibold">Situação</th>
                  <th scope="col" className="px-4 py-3 text-left font-semibold">Tamanho</th>
                  <th scope="col" className="px-4 py-3 text-left font-semibold">Registros</th>
                  <th scope="col" className="px-4 py-3 text-left font-semibold">Feito por</th>
                  <th scope="col" className="px-4 py-3 text-right font-semibold">Ações</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-100">
                {backups.map((backup) => {
                  const ok = backup.situacao === "ok";
                  return (
                    <tr key={backup.id} className="align-top">
                      <td className="whitespace-nowrap px-4 py-3 text-slate-700">{formatarDataHora(backup.criado_em)}</td>
                      <td className="px-4 py-3 text-slate-700">
                        {ROTULO_TIPO[backup.tipo]}
                        {backup.observacao && <span className="block text-xs text-slate-500">{backup.observacao}</span>}
                      </td>
                      <td className="px-4 py-3">
                        <span
                          className={
                            "rounded-full px-2 py-0.5 text-xs font-medium " +
                            (ok ? "bg-emerald-50 text-emerald-700" : "bg-red-50 text-red-700")
                          }
                        >
                          {ok ? "Concluído" : "Falhou"}
                        </span>
                        {!ok && backup.erro && <span className="mt-1 block max-w-xs text-xs text-red-700">{backup.erro}</span>}
                        {ok && <EtiquetaVerificacao backup={backup} />}
                      </td>
                      <td className="whitespace-nowrap px-4 py-3 text-slate-700">{formatarTamanho(backup.tamanho_bytes)}</td>
                      <td className="whitespace-nowrap px-4 py-3 text-slate-700">
                        {ok ? totalDeLinhas(backup.contagens).toLocaleString("pt-BR") : "—"}
                      </td>
                      <td className="px-4 py-3 text-slate-700">{backup.criado_por_nome ?? "Sistema"}</td>
                      <td className="px-4 py-3">
                        <div className="flex flex-wrap justify-end gap-2">
                          {ok && (
                            <>
                              <button type="button" className={classeBotao} onClick={() => aoBaixar(backup.id)} disabled={ocupado !== null}>
                                <Download className="h-4 w-4" aria-hidden="true" />
                                {ocupado === `baixar:${backup.id}` ? "Gerando..." : "Baixar"}
                              </button>
                              <button type="button" className={classeBotao} onClick={() => aoVerificar(backup.id)} disabled={ocupado !== null}>
                                <ShieldCheck className={"h-4 w-4 " + classeIconeVerificacao(backup.verificacao)} aria-hidden="true" />
                                {ocupado === `verificar:${backup.id}` ? "Verificando..." : backup.verificacao === "pendente" ? "Verificar" : "Verificar novamente"}
                              </button>
                            </>
                          )}
                          {pode("backup.configurar") && (
                            <button type="button" className={classeBotao} onClick={() => aoExcluir(backup.id)} disabled={ocupado !== null}>
                              <Trash2 className="h-4 w-4" aria-hidden="true" />
                              Excluir
                            </button>
                          )}
                        </div>
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        )}
      </div>

      <Notificacao mensagem={aviso} onFechar={() => setAviso(null)} />
    </main>
  );
}
