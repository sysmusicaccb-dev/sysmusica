/**
 * SysMúsica — Motor de avisos do Backup: Telegram e e-mail (SMTP ou Resend).
 * A configuração fica na tabela backup_configuracao e em backup_destinatarios; o token e a senha estão
 * criptografados com a BACKUP_CHAVE. Os avisos NUNCA derrubam o backup: qualquer falha vira um resultado
 * "erro" que a tela mostra. As mensagens não trazem nome de membro, CPF nem foto.
 * (A tela para cadastrar a configuração chega na parte 1C.)
 */
import type { SupabaseClient } from "@supabase/supabase-js";
import nodemailer from "nodemailer";
import { abrirSegredo, lerChave } from "../cripto";
import { lerConfigResend, lerConfigSmtp, type ConfigResend, type ConfigSmtp, type ResultadoCanal } from "../regras";
import { clienteAdmin } from "./clienteAdmin";

export type EventoNotificacao = "sucesso" | "falha" | "restauracao";

interface Configuracao {
  notificar_sucesso: boolean;
  notificar_falha: boolean;
  notificar_restauracao: boolean;
  telegram_ativo: boolean;
  telegram_token_cifrado: string | null;
  telegram_chat_id: string | null;
  email_ativo: boolean;
  email_provedor: "smtp" | "resend" | null;
  email_config_cifrado: string | null;
}

export type ConfigEmail =
  | { provedor: "smtp"; config: ConfigSmtp }
  | { provedor: "resend"; config: ConfigResend };

// Mensagem de erro sem nenhum segredo dentro (o token nunca pode aparecer na tela)
function mensagemSegura(erro: unknown, segredos: string[]): string {
  let mensagem = erro instanceof Error ? erro.message : "erro desconhecido";
  for (const segredo of segredos) {
    if (segredo) mensagem = mensagem.split(segredo).join("***");
  }
  return mensagem.slice(0, 200);
}

/** Envia uma mensagem de texto para um chat do Telegram. */
export async function enviarTelegram(token: string, chatId: string, texto: string): Promise<void> {
  const resposta = await fetch(`https://api.telegram.org/bot${token}/sendMessage`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ chat_id: chatId, text: texto.slice(0, 4000) }),
    signal: AbortSignal.timeout(10_000),
  });
  if (!resposta.ok) {
    const corpo = (await resposta.json().catch(() => null)) as { description?: string } | null;
    throw new Error(`O Telegram recusou a mensagem: ${corpo?.description ?? `código ${resposta.status}`}`);
  }
}

/** Envia um e-mail de texto simples pelo provedor escolhido (SMTP ou Resend). */
export async function enviarEmail(configuracao: ConfigEmail, destinos: string[], assunto: string, texto: string): Promise<void> {
  if (destinos.length === 0) throw new Error("Nenhum destinatário de e-mail ativo.");

  if (configuracao.provedor === "resend") {
    const resposta = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: { Authorization: `Bearer ${configuracao.config.chave}`, "Content-Type": "application/json" },
      body: JSON.stringify({ from: configuracao.config.remetente, to: destinos, subject: assunto, text: texto }),
      signal: AbortSignal.timeout(15_000),
    });
    if (!resposta.ok) {
      const corpo = (await resposta.json().catch(() => null)) as { message?: string } | null;
      throw new Error(`O Resend recusou o e-mail: ${corpo?.message ?? `código ${resposta.status}`}`);
    }
    return;
  }

  const smtp = configuracao.config;
  const transporte = nodemailer.createTransport({
    host: smtp.host,
    port: smtp.porta,
    secure: smtp.seguro,
    auth: smtp.usuario ? { user: smtp.usuario, pass: smtp.senha } : undefined,
    connectionTimeout: 10_000,
    greetingTimeout: 10_000,
    socketTimeout: 15_000,
  });
  await transporte.sendMail({ from: smtp.remetente, to: destinos, subject: assunto, text: texto });
}

async function canalTelegram(configuracao: Configuracao, chave: Buffer, texto: string): Promise<ResultadoCanal> {
  if (!configuracao.telegram_ativo) return { canal: "telegram", estado: "desligado" };
  let token = "";
  try {
    if (!configuracao.telegram_token_cifrado || !configuracao.telegram_chat_id) {
      throw new Error("falta o token ou o ID do chat");
    }
    token = abrirSegredo(configuracao.telegram_token_cifrado, chave);
    await enviarTelegram(token, configuracao.telegram_chat_id, texto);
    return { canal: "telegram", estado: "enviado" };
  } catch (e) {
    return { canal: "telegram", estado: "erro", detalhe: mensagemSegura(e, [token]) };
  }
}

async function canalEmail(
  admin: SupabaseClient,
  configuracao: Configuracao,
  chave: Buffer,
  mensagem: { assunto: string; texto: string }
): Promise<ResultadoCanal> {
  if (!configuracao.email_ativo) return { canal: "email", estado: "desligado" };
  let aberto = "";
  try {
    if (!configuracao.email_provedor || !configuracao.email_config_cifrado) {
      throw new Error("o provedor de e-mail não foi configurado");
    }
    aberto = abrirSegredo(configuracao.email_config_cifrado, chave);
    const bruto: unknown = JSON.parse(aberto);

    let envio: ConfigEmail | null = null;
    if (configuracao.email_provedor === "smtp") {
      const config = lerConfigSmtp(bruto);
      if (config) envio = { provedor: "smtp", config };
    } else {
      const config = lerConfigResend(bruto);
      if (config) envio = { provedor: "resend", config };
    }
    if (!envio) throw new Error("a configuração de e-mail está incompleta");

    const { data } = await admin.from("backup_destinatarios").select("email").eq("ativo", true);
    const destinos = ((data ?? []) as { email: string }[]).map((linha) => linha.email);
    await enviarEmail(envio, destinos, mensagem.assunto, mensagem.texto);
    return { canal: "email", estado: "enviado" };
  } catch (e) {
    return { canal: "email", estado: "erro", detalhe: mensagemSegura(e, [aberto]) };
  }
}

/**
 * Avisa pelos canais ligados. Devolve o resultado de cada canal (lista vazia = esse tipo de aviso está
 * desligado ou ainda não há configuração). Nunca lança erro.
 */
export async function notificar(
  evento: EventoNotificacao,
  mensagem: { assunto: string; texto: string }
): Promise<ResultadoCanal[]> {
  try {
    const admin = clienteAdmin();
    const { data } = await admin.from("backup_configuracao").select("*").eq("id", 1).maybeSingle();
    if (!data) return [];

    const configuracao = data as Configuracao;
    const ligado =
      evento === "sucesso"
        ? configuracao.notificar_sucesso
        : evento === "falha"
          ? configuracao.notificar_falha
          : configuracao.notificar_restauracao;
    if (!ligado) return [];

    const chave = lerChave(process.env.BACKUP_CHAVE);
    return [
      await canalTelegram(configuracao, chave, `${mensagem.assunto}\n\n${mensagem.texto}`),
      await canalEmail(admin, configuracao, chave, mensagem),
    ];
  } catch (e) {
    console.error("Falha ao enviar os avisos do backup:", e);
    return [{ canal: "geral", estado: "erro", detalhe: mensagemSegura(e, []) }];
  }
}
