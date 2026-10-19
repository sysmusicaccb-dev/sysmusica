"use client";

/**
 * SysMúsica — Página /administracao/backup/notificacoes (só o Administrador): avisos do backup por Telegram e
 * e-mail. Token e senhas são enviados ao servidor só ao salvar, ficam criptografados e nunca voltam para a tela.
 * Campo de segredo em branco = manter o valor atual. Os testes usam a configuração JÁ SALVA.
 */
import { useCallback, useEffect, useState, type ReactNode } from "react";
import ErrorState from "@/components/ui/ErrorState";
import Notificacao from "@/components/ui/Notificacao";
import PageHeader from "@/components/ui/PageHeader";
import Skeleton from "@/components/ui/Skeleton";
import AbasBackup from "@/modules/backup/components/AbasBackup";
import {
  formularioInicial,
  type ChatTelegram,
  type ConfiguracaoPublica,
  type EntradaConfiguracao,
  type ProvedorEmail,
} from "@/modules/backup/configuracao";
import {
  adicionarDestinatario,
  alterarDestinatario,
  buscarChats,
  obterConfiguracao,
  removerDestinatario,
  salvarConfiguracao,
  testarAviso,
} from "@/modules/backup/services/configuracaoApi";

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

function Secao({ titulo, children }: { titulo: string; children: ReactNode }) {
  return (
    <section className="rounded-2xl border border-slate-200 bg-white p-5 shadow-sm">
      <h2 className="mb-4 text-sm font-semibold text-slate-900">{titulo}</h2>
      <div className="space-y-4">{children}</div>
    </section>
  );
}

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

export default function NotificacoesBackupPage() {
  const [config, setConfig] = useState<ConfiguracaoPublica | null>(null);
  const [form, setForm] = useState<EntradaConfiguracao | null>(null);
  const [alterado, setAlterado] = useState(false); // há mudanças ainda não salvas
  const [carregando, setCarregando] = useState(true); // inicia true: primeira busca no mount
  const [erro, setErro] = useState<string | null>(null);
  const [ocupado, setOcupado] = useState<string | null>(null);
  const [erroAcao, setErroAcao] = useState<string | null>(null);
  const [aviso, setAviso] = useState<string | null>(null);
  const [chats, setChats] = useState<ChatTelegram[] | null>(null);
  const [novoEmail, setNovoEmail] = useState("");

  const carregar = useCallback(async () => {
    try {
      const dados = await obterConfiguracao();
      setConfig(dados);
      setForm(formularioInicial(dados));
      setAlterado(false);
      setErro(null);
    } catch (e) {
      setErro(e instanceof Error ? e.message : "Não foi possível carregar a configuração.");
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

  // Muda campos do formulário e marca que há algo para salvar
  function mudar(parcial: Partial<EntradaConfiguracao>) {
    setForm((atual) => (atual ? { ...atual, ...parcial } : atual));
    setAlterado(true);
  }
  function mudarSmtp(parcial: Partial<EntradaConfiguracao["smtp"]>) {
    setForm((atual) => (atual ? { ...atual, smtp: { ...atual.smtp, ...parcial } } : atual));
    setAlterado(true);
  }
  function mudarResend(parcial: Partial<EntradaConfiguracao["resend"]>) {
    setForm((atual) => (atual ? { ...atual, resend: { ...atual.resend, ...parcial } } : atual));
    setAlterado(true);
  }

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

  function aoSalvar() {
    if (!form) return;
    void executar("salvar", async () => {
      const nova = await salvarConfiguracao(form);
      setConfig(nova);
      setForm(formularioInicial(nova)); // os campos de segredo voltam em branco
      setAlterado(false);
      return "Configuração salva. Use os botões de teste para conferir.";
    });
  }

  function aoTestar(canal: "telegram" | "email") {
    void executar(`testar:${canal}`, async () => (await testarAviso(canal)).detalhe);
  }

  function aoBuscarChats() {
    void executar("chats", async () => {
      const lista = await buscarChats();
      setChats(lista);
      return lista.length === 0
        ? "Nenhuma conversa encontrada. Escreva uma mensagem no grupo (ou /start para o bot) e tente de novo."
        : `${lista.length} conversa(s) encontrada(s). Escolha a que deve receber os avisos.`;
    });
  }

  function aoAdicionarEmail() {
    void executar("adicionar", async () => {
      const lista = await adicionarDestinatario(novoEmail);
      setConfig((atual) => (atual ? { ...atual, destinatarios: lista } : atual));
      setNovoEmail("");
      return "E-mail adicionado.";
    });
  }

  function aoLigarEmail(id: string, ativo: boolean) {
    void executar(`ligar:${id}`, async () => {
      const lista = await alterarDestinatario(id, ativo);
      setConfig((atual) => (atual ? { ...atual, destinatarios: lista } : atual));
    });
  }

  function aoRemoverEmail(id: string) {
    if (!window.confirm("Remover este e-mail da lista de avisos?")) return;
    void executar(`remover:${id}`, async () => {
      const lista = await removerDestinatario(id);
      setConfig((atual) => (atual ? { ...atual, destinatarios: lista } : atual));
      return "E-mail removido.";
    });
  }

  const desabilitado = ocupado !== null;
  const testesBloqueados = desabilitado || alterado;

  return (
    <main className="text-slate-900">
      <div className="mx-auto max-w-6xl px-4 py-8 sm:px-6 lg:px-8">
        <PageHeader
          titulo="Backup"
          descricao="Avisos por Telegram e e-mail. Somente o Administrador tem acesso."
          acoes={
            <button type="button" className={classeBotaoPrimario} onClick={aoSalvar} disabled={desabilitado || !alterado || !form}>
              {ocupado === "salvar" ? "Salvando..." : "Salvar configuração"}
            </button>
          }
        />

        <AbasBackup />

        {erroAcao && (
          <p role="alert" className="mb-4 rounded-lg bg-red-50 px-3 py-2 text-sm text-red-700">
            {erroAcao}
          </p>
        )}

        {carregando ? (
          <div role="status" aria-live="polite" className="space-y-3">
            <span className="sr-only">Carregando a configuração...</span>
            {[0, 1, 2].map((i) => (
              <Skeleton key={i} className="h-24" />
            ))}
          </div>
        ) : erro || !config || !form ? (
          <ErrorState
            titulo="Não foi possível carregar a configuração."
            mensagem={erro ?? "Tente novamente."}
            onTentarNovamente={() => {
              setCarregando(true);
              void carregar();
            }}
          />
        ) : (
          <div className="space-y-6">
            {config.aviso_segredos && (
              <p role="alert" className="rounded-lg bg-amber-50 px-3 py-2 text-sm text-amber-700">
                {config.aviso_segredos}
              </p>
            )}
            {alterado && (
              <p className="rounded-lg bg-slate-50 px-3 py-2 text-sm text-slate-600">
                Há mudanças não salvas. Salve antes de usar os botões de teste, que usam a configuração salva.
              </p>
            )}

            {/* Quando avisar */}
            <Secao titulo="Quando avisar">
              <div className="grid gap-2 sm:grid-cols-3">
                <label className="flex items-center gap-2 text-sm text-slate-700">
                  <input type="checkbox" className={classeCaixa} checked={form.notificar_sucesso} onChange={(e) => mudar({ notificar_sucesso: e.target.checked })} />
                  Backup concluído e verificado
                </label>
                <label className="flex items-center gap-2 text-sm text-slate-700">
                  <input type="checkbox" className={classeCaixa} checked={form.notificar_falha} onChange={(e) => mudar({ notificar_falha: e.target.checked })} />
                  Falha ou alerta
                </label>
                <label className="flex items-center gap-2 text-sm text-slate-700">
                  <input type="checkbox" className={classeCaixa} checked={form.notificar_restauracao} onChange={(e) => mudar({ notificar_restauracao: e.target.checked })} />
                  Restauração de dados
                </label>
              </div>
              <p className="text-xs text-slate-500">As mensagens trazem só data, tamanho, quantidades e quem fez. Nunca nome de membro, CPF ou foto.</p>
            </Secao>

            {/* Telegram */}
            <Secao titulo="Telegram">
              <label className="flex items-center gap-2 text-sm text-slate-700">
                <input type="checkbox" className={classeCaixa} checked={form.telegram_ativo} onChange={(e) => mudar({ telegram_ativo: e.target.checked })} />
                Enviar avisos pelo Telegram
              </label>

              <Campo
                id="tg-token"
                rotulo="Token do bot"
                dica={
                  config.telegram_token_final
                    ? `Configurado (${config.telegram_token_final}). Deixe em branco para manter, ou digite outro para trocar.`
                    : "Crie o bot no Telegram com o @BotFather (/newbot) e cole aqui o token que ele devolver."
                }
              >
                <input
                  id="tg-token"
                  type="password"
                  autoComplete="new-password"
                  value={form.telegram_token}
                  onChange={(e) => mudar({ telegram_token: e.target.value })}
                  placeholder={config.telegram_token_final ? "••••••••••••" : "123456789:AAH..."}
                  className={classeCampo}
                />
              </Campo>

              <Campo id="tg-chat" rotulo="ID do chat" dica="Número do grupo (começa com -) ou da conversa. Use o botão abaixo para descobrir.">
                <input
                  id="tg-chat"
                  type="text"
                  autoComplete="off"
                  value={form.telegram_chat_id}
                  onChange={(e) => mudar({ telegram_chat_id: e.target.value })}
                  placeholder="-1001234567890"
                  className={classeCampo}
                />
              </Campo>

              <div className="flex flex-wrap gap-2">
                <button type="button" className={classeBotao} onClick={aoBuscarChats} disabled={testesBloqueados || !config.telegram_token_final}>
                  {ocupado === "chats" ? "Buscando..." : "Buscar chats do bot"}
                </button>
                <button type="button" className={classeBotao} onClick={() => aoTestar("telegram")} disabled={testesBloqueados || !config.telegram_token_final || config.telegram_chat_id === ""}>
                  {ocupado === "testar:telegram" ? "Enviando..." : "Enviar mensagem de teste"}
                </button>
              </div>

              {chats !== null && chats.length > 0 && (
                <ul className="space-y-2 rounded-xl border border-slate-200 p-3">
                  {chats.map((chat) => (
                    <li key={chat.id} className="flex flex-wrap items-center justify-between gap-2 text-sm text-slate-700">
                      <span>
                        {chat.rotulo} <span className="text-xs text-slate-500">ID {chat.id}</span>
                      </span>
                      <button type="button" className={classeBotao} onClick={() => mudar({ telegram_chat_id: chat.id })}>
                        Usar este
                      </button>
                    </li>
                  ))}
                </ul>
              )}
              <p className="text-xs text-slate-500">
                Para descobrir o ID: salve o token, adicione o bot ao grupo, escreva uma mensagem nele (se não aparecer, envie /start) e clique em Buscar chats do bot.
              </p>
            </Secao>

            {/* E-mail */}
            <Secao titulo="E-mail">
              <label className="flex items-center gap-2 text-sm text-slate-700">
                <input type="checkbox" className={classeCaixa} checked={form.email_ativo} onChange={(e) => mudar({ email_ativo: e.target.checked })} />
                Enviar avisos por e-mail
              </label>

              <Campo id="em-provedor" rotulo="Provedor de envio">
                <select
                  id="em-provedor"
                  value={form.email_provedor ?? "smtp"}
                  onChange={(e) => mudar({ email_provedor: e.target.value as ProvedorEmail })}
                  className={classeCampo}
                >
                  <option value="smtp">SMTP (qualquer servidor de e-mail)</option>
                  <option value="resend">Resend (serviço de envio)</option>
                </select>
              </Campo>

              {form.email_provedor === "resend" ? (
                <>
                  <Campo
                    id="rs-chave"
                    rotulo="Chave de API do Resend"
                    dica={config.resend?.chave_final ? `Configurada (${config.resend.chave_final}). Deixe em branco para manter.` : "Gere a chave no painel do Resend."}
                  >
                    <input id="rs-chave" type="password" autoComplete="new-password" value={form.resend.chave} onChange={(e) => mudarResend({ chave: e.target.value })} placeholder={config.resend?.chave_final ? "••••••••••••" : "re_..."} className={classeCampo} />
                  </Campo>
                  <Campo id="rs-remetente" rotulo="E-mail do remetente" dica="Precisa ser de um domínio verificado no Resend.">
                    <input id="rs-remetente" type="text" value={form.resend.remetente} onChange={(e) => mudarResend({ remetente: e.target.value })} placeholder="SysMúsica <backup@seudominio.com>" className={classeCampo} />
                  </Campo>
                </>
              ) : (
                <>
                  <div className="grid gap-4 sm:grid-cols-3">
                    <div className="sm:col-span-2">
                      <Campo id="sm-host" rotulo="Servidor SMTP">
                        <input id="sm-host" type="text" autoComplete="off" value={form.smtp.host} onChange={(e) => mudarSmtp({ host: e.target.value })} placeholder="smtp.exemplo.com" className={classeCampo} />
                      </Campo>
                    </div>
                    <Campo id="sm-porta" rotulo="Porta">
                      <input id="sm-porta" type="text" inputMode="numeric" value={form.smtp.porta} onChange={(e) => mudarSmtp({ porta: e.target.value })} className={classeCampo} />
                    </Campo>
                  </div>
                  <label className="flex items-center gap-2 text-sm text-slate-700">
                    <input type="checkbox" className={classeCaixa} checked={form.smtp.seguro} onChange={(e) => mudarSmtp({ seguro: e.target.checked })} />
                    Conexão segura direta (SSL, normalmente porta 465). Deixe desmarcado para a porta 587.
                  </label>
                  <div className="grid gap-4 sm:grid-cols-2">
                    <Campo id="sm-usuario" rotulo="Usuário (opcional)">
                      <input id="sm-usuario" type="text" autoComplete="off" value={form.smtp.usuario} onChange={(e) => mudarSmtp({ usuario: e.target.value })} className={classeCampo} />
                    </Campo>
                    <Campo id="sm-senha" rotulo="Senha" dica={config.smtp?.senha_configurada ? "Configurada. Deixe em branco para manter." : undefined}>
                      <input id="sm-senha" type="password" autoComplete="new-password" value={form.smtp.senha} onChange={(e) => mudarSmtp({ senha: e.target.value })} placeholder={config.smtp?.senha_configurada ? "••••••••••••" : ""} className={classeCampo} />
                    </Campo>
                  </div>
                  <Campo id="sm-remetente" rotulo="E-mail do remetente">
                    <input id="sm-remetente" type="text" value={form.smtp.remetente} onChange={(e) => mudarSmtp({ remetente: e.target.value })} placeholder="SysMúsica <backup@exemplo.com>" className={classeCampo} />
                  </Campo>
                  <p className="text-xs text-slate-500">
                    Se a sua organização usa o Microsoft 365, o envio por SMTP com senha costuma estar bloqueado. Nesse caso, use outro servidor SMTP ou o Resend.
                  </p>
                </>
              )}

              <div>
                <button type="button" className={classeBotao} onClick={() => aoTestar("email")} disabled={testesBloqueados || !config.email_provedor}>
                  {ocupado === "testar:email" ? "Enviando..." : "Enviar e-mail de teste"}
                </button>
              </div>
            </Secao>

            {/* Destinatários */}
            <Secao titulo="Quem recebe os e-mails">
              {config.destinatarios.length === 0 ? (
                <p className="text-sm text-slate-500">Nenhum destinatário ainda. Adicione abaixo.</p>
              ) : (
                <ul className="divide-y divide-slate-100 rounded-xl border border-slate-200">
                  {config.destinatarios.map((item) => (
                    <li key={item.id} className="flex flex-wrap items-center justify-between gap-2 px-3 py-2">
                      <label className="flex items-center gap-2 text-sm text-slate-700">
                        <input type="checkbox" className={classeCaixa} checked={item.ativo} disabled={desabilitado} onChange={(e) => aoLigarEmail(item.id, e.target.checked)} />
                        {item.email}
                      </label>
                      <button type="button" className={classeBotao} onClick={() => aoRemoverEmail(item.id)} disabled={desabilitado}>
                        Remover
                      </button>
                    </li>
                  ))}
                </ul>
              )}
              <div className="flex flex-wrap items-end gap-2">
                <div className="min-w-0 flex-1">
                  <Campo id="novo-email" rotulo="Adicionar e-mail">
                    <input
                      id="novo-email"
                      type="email"
                      autoComplete="off"
                      value={novoEmail}
                      onChange={(e) => setNovoEmail(e.target.value)}
                      onKeyDown={(e) => {
                        if (e.key === "Enter") {
                          e.preventDefault();
                          if (novoEmail.trim() !== "") aoAdicionarEmail();
                        }
                      }}
                      placeholder="nome@exemplo.com"
                      className={classeCampo}
                    />
                  </Campo>
                </div>
                <button type="button" className={classeBotao} onClick={aoAdicionarEmail} disabled={desabilitado || novoEmail.trim() === ""}>
                  Adicionar
                </button>
              </div>
              <p className="text-xs text-slate-500">Adicionar, ligar, desligar e remover valem na hora, sem precisar salvar.</p>
            </Secao>
          </div>
        )}
      </div>

      <Notificacao mensagem={aviso} onFechar={() => setAviso(null)} />
    </main>
  );
}
