"use client";

/**
 * Sysmusica — Página /administracao/backup/destinos (só o Administrador): para onde vai a cópia dos backups.
 * Cada destino é um cartão que se abre ao clicar (evita poluir a tela). Hoje o único ativo é o "Servidor local",
 * alcançado por um túnel da Cloudflare. Segredos só são enviados ao servidor ao salvar, ficam criptografados e
 * nunca voltam para a tela. Campo secreto em branco = manter o valor atual. Os botões usam a configuração JÁ SALVA.
 */
import { useCallback, useEffect, useState, type ReactNode } from "react";
import ErrorState from "@/components/ui/ErrorState";
import PageHeader from "@/components/ui/PageHeader";
import Skeleton from "@/components/ui/Skeleton";
import AbasBackup from "@/modules/backup/components/AbasBackup";
import { formularioInicialDestino, type DestinoPublico, type EntradaDestino } from "@/modules/backup/destinos";
import { dataHoraSalvador } from "@/modules/backup/regras";
import { enviarMaisRecente, obterDestino, salvarDestino, testarDestino } from "@/modules/backup/services/destinosApi";

const classeCampo =
  "w-full rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 shadow-sm placeholder:text-slate-400 " +
  "focus:border-brand-500 focus:outline-none focus:ring-2 focus:ring-brand-200 disabled:opacity-60";
const classeBotao =
  "inline-flex items-center gap-2 rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm font-medium " +
  "text-slate-700 transition hover:bg-slate-50 disabled:cursor-not-allowed disabled:opacity-60";
const classeBotaoPrimario =
  "inline-flex items-center gap-2 rounded-lg bg-brand-600 px-4 py-2 text-sm font-semibold text-white shadow-sm " +
  "transition hover:bg-brand-700 disabled:cursor-not-allowed disabled:opacity-60";
const classeCaixa = "h-4 w-4 rounded border-slate-300 text-brand-600 focus:ring-brand-300";

function Campo({ id, rotulo, dica, children }: { id: string; rotulo: string; dica?: string; children: ReactNode }) {
  return (
    <div className="space-y-1.5">
      <label htmlFor={id} className="text-xs font-medium text-slate-600">
        {rotulo}
      </label>
      {children}
      {dica && <p className="text-xs text-slate-500">{dica}</p>}
    </div>
  );
}

function Selo({ cor, children }: { cor: "verde" | "cinza" | "ambar"; children: ReactNode }) {
  const classes = {
    verde: "bg-emerald-50 text-emerald-700",
    cinza: "bg-slate-100 text-slate-600",
    ambar: "bg-amber-50 text-amber-700",
  }[cor];
  return <span className={`rounded-full px-2.5 py-0.5 text-xs font-medium ${classes}`}>{children}</span>;
}

// Destinos que ainda não existem: aparecem desabilitados para o administrador saber o que vem por aí
const EM_BREVE: { titulo: string; texto: string }[] = [
  {
    titulo: "OneDrive (API da Microsoft)",
    texto: "Indisponível nesta organização: exige autorização do administrador do Microsoft 365. O OneDrive já é alcançado pelo Servidor local.",
  },
  { titulo: "FTP / SFTP", texto: "Envio para um servidor de arquivos próprio ou contratado." },
  { titulo: "Google Drive", texto: "Envio para uma pasta do Google Drive." },
  { titulo: "Armazenamento S3 (Cloudflare R2, Backblaze B2)", texto: "Cópia em nuvem de baixo custo, independente do servidor da casa." },
];

export default function DestinosBackupPage() {
  const [destino, setDestino] = useState<DestinoPublico | null>(null);
  const [form, setForm] = useState<EntradaDestino | null>(null);
  const [alterado, setAlterado] = useState(false); // há mudanças ainda não salvas
  const [carregando, setCarregando] = useState(true); // inicia true: primeira busca no mount
  const [erro, setErro] = useState<string | null>(null);
  const [ocupado, setOcupado] = useState<string | null>(null);
  const [erroAcao, setErroAcao] = useState<string | null>(null);
  const [aviso, setAviso] = useState<string | null>(null);
  const [aberto, setAberto] = useState(true);

  const carregar = useCallback(async () => {
    try {
      const dados = await obterDestino();
      setDestino(dados);
      setForm(formularioInicialDestino(dados));
      setAlterado(false);
      setErro(null);
    } catch (e) {
      setErro(e instanceof Error ? e.message : "Não foi possível carregar o destino.");
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

  function mudar(parcial: Partial<EntradaDestino>) {
    setForm((atual) => (atual ? { ...atual, ...parcial } : atual));
    setAlterado(true);
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
      const novo = await salvarDestino(form);
      setDestino(novo);
      setForm(formularioInicialDestino(novo)); // os campos secretos voltam em branco
      setAlterado(false);
      return "Destino salvo. Use \"Testar conexão\" para conferir.";
    });
  }

  function aoTestar() {
    void executar("testar", async () => (await testarDestino()).detalhe);
  }

  function aoEnviar() {
    void executar("enviar", async () => {
      const resposta = await enviarMaisRecente();
      await carregar(); // atualiza o "último envio"
      return resposta.detalhe;
    });
  }

  const desabilitado = ocupado !== null;
  const acoesBloqueadas = desabilitado || alterado || !destino?.configurado;

  return (
    <main className="text-slate-900">
      <div className="mx-auto max-w-6xl px-4 py-8 sm:px-6 lg:px-8">
        <PageHeader
          titulo="Backup"
          descricao="Para onde vai a cópia dos backups, além do armazenamento do sistema. Somente o Administrador tem acesso."
          acoes={
            <button type="button" className={classeBotaoPrimario} onClick={aoSalvar} disabled={desabilitado || !alterado || !form}>
              {ocupado === "salvar" ? "Salvando..." : "Salvar destino"}
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
            <span className="sr-only">Carregando o destino...</span>
            {[0, 1].map((i) => (
              <Skeleton key={i} className="h-24" />
            ))}
          </div>
        ) : erro || !destino || !form ? (
          <ErrorState
            titulo="Não foi possível carregar o destino."
            mensagem={erro ?? "Tente novamente."}
            onTentarNovamente={() => {
              setCarregando(true);
              void carregar();
            }}
          />
        ) : (
          <div className="space-y-4">
            {destino.aviso_segredos && (
              <p role="alert" className="rounded-lg bg-amber-50 px-3 py-2 text-sm text-amber-700">
                {destino.aviso_segredos}
              </p>
            )}
            {alterado && (
              <p className="rounded-lg bg-slate-50 px-3 py-2 text-sm text-slate-600">
                Há mudanças não salvas. Salve antes de usar os botões de teste e de envio, que usam o destino salvo.
              </p>
            )}

            {/* Cartão: Servidor local */}
            <section className="rounded-2xl border border-slate-200 bg-white shadow-sm">
              <button
                type="button"
                onClick={() => setAberto((valor) => !valor)}
                aria-expanded={aberto}
                aria-controls="cartao-servidor-local"
                className="flex w-full flex-wrap items-center justify-between gap-2 rounded-2xl px-5 py-4 text-left"
              >
                <span>
                  <span className="block text-sm font-semibold text-slate-900">Servidor local (túnel Cloudflare)</span>
                  <span className="block text-xs text-slate-500">
                    Copia o backup, já criptografado, para o servidor de casa. O OneDrive dele leva o arquivo para a nuvem.
                  </span>
                </span>
                <span className="flex items-center gap-2">
                  {!destino.configurado ? <Selo cor="cinza">Não configurado</Selo> : destino.ativo ? <Selo cor="verde">Envio automático ligado</Selo> : <Selo cor="ambar">Envio automático desligado</Selo>}
                  <span aria-hidden="true" className="text-slate-400">
                    {aberto ? "▲" : "▼"}
                  </span>
                </span>
              </button>

              {aberto && (
                <div id="cartao-servidor-local" className="space-y-4 border-t border-slate-100 px-5 py-4">
                  <label className="flex items-center gap-2 text-sm text-slate-700">
                    <input type="checkbox" className={classeCaixa} checked={form.ativo} onChange={(e) => mudar({ ativo: e.target.checked })} />
                    Enviar automaticamente depois de cada backup verificado
                  </label>

                  <Campo id="ds-endereco" rotulo="Endereço do servidor" dica="O endereço do túnel, começando com https:// e sem barra no final.">
                    <input
                      id="ds-endereco"
                      type="text"
                      autoComplete="off"
                      value={form.endereco}
                      onChange={(e) => mudar({ endereco: e.target.value })}
                      placeholder="https://bkp-sysmusicaccb.2atelecom.net.br"
                      className={classeCampo}
                    />
                  </Campo>

                  <div className="grid gap-4 sm:grid-cols-2">
                    <Campo
                      id="ds-client-id"
                      rotulo="Client ID (token de serviço da Cloudflare)"
                      dica={destino.client_id_final ? `Configurado (${destino.client_id_final}). Deixe em branco para manter.` : undefined}
                    >
                      <input
                        id="ds-client-id"
                        type="password"
                        autoComplete="new-password"
                        value={form.client_id}
                        onChange={(e) => mudar({ client_id: e.target.value })}
                        placeholder={destino.client_id_final ? "••••••••••••" : "xxxxxxxx.access"}
                        className={classeCampo}
                      />
                    </Campo>
                    <Campo
                      id="ds-client-secret"
                      rotulo="Client Secret"
                      dica={destino.client_secret_final ? `Configurado (${destino.client_secret_final}). Deixe em branco para manter.` : undefined}
                    >
                      <input
                        id="ds-client-secret"
                        type="password"
                        autoComplete="new-password"
                        value={form.client_secret}
                        onChange={(e) => mudar({ client_secret: e.target.value })}
                        placeholder={destino.client_secret_final ? "••••••••••••" : ""}
                        className={classeCampo}
                      />
                    </Campo>
                  </div>

                  <Campo
                    id="ds-chave"
                    rotulo="Chave de assinatura"
                    dica={
                      destino.chave_final
                        ? `Configurada (${destino.chave_final}). Deixe em branco para manter.`
                        : "Está no servidor, no arquivo C:\\SysMusicaReceptor\\segredo.txt. Copie o texto inteiro."
                    }
                  >
                    <input
                      id="ds-chave"
                      type="password"
                      autoComplete="new-password"
                      value={form.chave_assinatura}
                      onChange={(e) => mudar({ chave_assinatura: e.target.value })}
                      placeholder={destino.chave_final ? "••••••••••••" : ""}
                      className={classeCampo}
                    />
                  </Campo>

                  <div className="flex flex-wrap gap-2">
                    <button type="button" className={classeBotao} onClick={aoTestar} disabled={acoesBloqueadas}>
                      {ocupado === "testar" ? "Testando..." : "Testar conexão"}
                    </button>
                    <button type="button" className={classeBotao} onClick={aoEnviar} disabled={acoesBloqueadas}>
                      {ocupado === "enviar" ? "Enviando..." : "Enviar o backup mais recente agora"}
                    </button>
                  </div>

                  <p className="text-xs text-slate-500">
                    {destino.ultimo_envio_em
                      ? destino.ultimo_envio_situacao === "ok"
                        ? `Último envio: ${dataHoraSalvador(new Date(destino.ultimo_envio_em))}, concluído e conferido.`
                        : `Último envio: ${dataHoraSalvador(new Date(destino.ultimo_envio_em))}, FALHOU${destino.ultimo_envio_detalhe ? ` (${destino.ultimo_envio_detalhe})` : ""}.`
                      : "Nenhum envio feito ainda."}
                  </p>
                  <p className="text-xs text-slate-500">
                    O sistema confirma que o servidor recebeu o arquivo íntegro. A sincronização com o OneDrive é feita pelo próprio servidor e não é vista daqui.
                  </p>
                </div>
              )}
            </section>

            {/* Destinos futuros */}
            {EM_BREVE.map((item) => (
              <section key={item.titulo} className="flex flex-wrap items-center justify-between gap-2 rounded-2xl border border-dashed border-slate-200 bg-slate-50 px-5 py-4 opacity-80">
                <span>
                  <span className="block text-sm font-semibold text-slate-700">{item.titulo}</span>
                  <span className="block text-xs text-slate-500">{item.texto}</span>
                </span>
                <Selo cor="cinza">Em breve</Selo>
              </section>
            ))}
          </div>
        )}
      </div>
    </main>
  );
}
