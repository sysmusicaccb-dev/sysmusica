/**
 * Sysmusica — Regras puras da configuração dos avisos do Backup (sem banco nem rede): tipos, validação do
 * que o administrador digita, leitura segura do corpo da requisição e leitura dos chats do Telegram.
 * Roda no servidor e no navegador. Testadas em configuracao.test.ts.
 * Segredos (token, senhas, chaves) só existem na ENTRADA; na saída para a tela aparecem mascarados.
 */
import { emailValido } from "./regras";

export type ProvedorEmail = "smtp" | "resend";

export interface Destinatario {
  id: string;
  email: string;
  ativo: boolean;
}

/** O que a tela recebe: nunca traz token, senha ou chave, só se estão configurados e o final deles. */
export interface ConfiguracaoPublica {
  notificar_sucesso: boolean;
  notificar_falha: boolean;
  notificar_restauracao: boolean;
  telegram_ativo: boolean;
  telegram_chat_id: string;
  telegram_token_final: string | null; // "…abcd"; nulo = não configurado
  email_ativo: boolean;
  email_provedor: ProvedorEmail | null;
  smtp: {
    host: string;
    porta: number;
    seguro: boolean;
    usuario: string;
    remetente: string;
    senha_configurada: boolean;
  } | null;
  resend: { remetente: string; chave_final: string | null } | null;
  destinatarios: Destinatario[];
  atualizado_em: string | null;
  /** Mensagem quando os segredos guardados não abrem com a BACKUP_CHAVE atual. */
  aviso_segredos: string | null;
}

/** O que a tela envia ao salvar. Campo de segredo vazio = manter o valor atual. */
export interface EntradaConfiguracao {
  notificar_sucesso: boolean;
  notificar_falha: boolean;
  notificar_restauracao: boolean;
  telegram_ativo: boolean;
  telegram_token: string;
  telegram_chat_id: string;
  email_ativo: boolean;
  email_provedor: ProvedorEmail | null;
  smtp: { host: string; porta: string; seguro: boolean; usuario: string; senha: string; remetente: string };
  resend: { chave: string; remetente: string };
}

/** O que já existe guardado: serve para aceitar campo de segredo em branco. */
export interface ContextoValidacao {
  tokenJaConfigurado: boolean;
  senhaSmtpJaConfigurada: boolean;
  chaveResendJaConfigurada: boolean;
}

export interface ChatTelegram {
  id: string;
  rotulo: string;
}

// ---------- Validações de formato ----------

/** Token do BotFather: número, dois-pontos e uma sequência de letras, números, "_" e "-". */
export function tokenTelegramValido(texto: string): boolean {
  return /^\d{5,}:[A-Za-z0-9_-]{20,}$/.test(texto.trim());
}

/** ID do chat: número (grupos começam com "-") ou @nome de canal público. */
export function chatIdValido(texto: string): boolean {
  const limpo = texto.trim();
  return /^-?\d{1,20}$/.test(limpo) || /^@[A-Za-z][A-Za-z0-9_]{4,31}$/.test(limpo);
}

/** Remetente: "backup@exemplo.com" ou "Sysmusica <backup@exemplo.com>". */
export function remetenteValido(texto: string): boolean {
  const limpo = texto.trim();
  if (emailValido(limpo)) return true;
  const achado = /^[^<>@]{1,80}<([^<>\s]+)>$/.exec(limpo);
  return achado !== null && emailValido(achado[1]);
}

function hostValido(texto: string): boolean {
  return /^[A-Za-z0-9]([A-Za-z0-9.-]{0,251}[A-Za-z0-9])?$/.test(texto);
}

function portaValida(texto: string): boolean {
  if (!/^\d{1,5}$/.test(texto)) return false;
  const numero = Number(texto);
  return numero >= 1 && numero <= 65535;
}

/** Tira espaços sobrando (a senha do SMTP é mantida exatamente como digitada). */
export function normalizarEntrada(entrada: EntradaConfiguracao): EntradaConfiguracao {
  return {
    ...entrada,
    telegram_token: entrada.telegram_token.trim(),
    telegram_chat_id: entrada.telegram_chat_id.trim(),
    smtp: {
      ...entrada.smtp,
      host: entrada.smtp.host.trim(),
      porta: entrada.smtp.porta.trim(),
      usuario: entrada.smtp.usuario.trim(),
      remetente: entrada.smtp.remetente.trim(),
    },
    resend: { chave: entrada.resend.chave.trim(), remetente: entrada.resend.remetente.trim() },
  };
}

/** Confere o que foi digitado; devolve a mensagem de erro ou null. Os avisos ligados exigem tudo preenchido. */
export function validarEntrada(entrada: EntradaConfiguracao, contexto: ContextoValidacao): string | null {
  // Telegram
  if (entrada.telegram_token !== "" && !tokenTelegramValido(entrada.telegram_token)) {
    return "O token do Telegram parece inválido. Ele tem o formato 123456789:AAH... (copie inteiro do BotFather).";
  }
  if (entrada.telegram_chat_id !== "" && !chatIdValido(entrada.telegram_chat_id)) {
    return "O ID do chat do Telegram é inválido. Use o número (grupos começam com -) ou clique em Buscar chats do bot.";
  }
  if (entrada.telegram_ativo) {
    if (entrada.telegram_chat_id === "") return "Informe o ID do chat do Telegram.";
    if (entrada.telegram_token === "" && !contexto.tokenJaConfigurado) return "Informe o token do bot do Telegram.";
  }

  // E-mail: campos já preenchidos precisam estar certos, mesmo com o aviso desligado
  if (entrada.email_provedor === "smtp") {
    const smtp = entrada.smtp;
    if (smtp.host !== "" && !hostValido(smtp.host)) return "O servidor SMTP é inválido (exemplo: smtp.exemplo.com).";
    if (smtp.porta !== "" && !portaValida(smtp.porta)) return "A porta do SMTP é inválida (de 1 a 65535).";
    if (smtp.remetente !== "" && !remetenteValido(smtp.remetente)) {
      return "O remetente é inválido. Use um e-mail, como backup@exemplo.com.";
    }
  }
  if (entrada.email_provedor === "resend" && entrada.resend.remetente !== "" && !remetenteValido(entrada.resend.remetente)) {
    return "O remetente é inválido. Use um e-mail, como backup@exemplo.com.";
  }

  if (entrada.email_ativo) {
    if (entrada.email_provedor === null) return "Escolha o provedor de e-mail (SMTP ou Resend).";
    if (entrada.email_provedor === "smtp") {
      const smtp = entrada.smtp;
      if (smtp.host === "") return "Informe o servidor SMTP.";
      if (smtp.porta === "") return "Informe a porta do SMTP.";
      if (smtp.remetente === "") return "Informe o e-mail do remetente.";
      if (smtp.usuario !== "" && smtp.senha === "" && !contexto.senhaSmtpJaConfigurada) return "Informe a senha do SMTP.";
    } else {
      if (entrada.resend.remetente === "") return "Informe o e-mail do remetente.";
      if (entrada.resend.chave === "" && !contexto.chaveResendJaConfigurada) return "Informe a chave de API do Resend.";
    }
  }
  return null;
}

/** Valores iniciais do formulário a partir do que está salvo (segredos sempre em branco). */
export function formularioInicial(config: ConfiguracaoPublica): EntradaConfiguracao {
  return {
    notificar_sucesso: config.notificar_sucesso,
    notificar_falha: config.notificar_falha,
    notificar_restauracao: config.notificar_restauracao,
    telegram_ativo: config.telegram_ativo,
    telegram_token: "",
    telegram_chat_id: config.telegram_chat_id,
    email_ativo: config.email_ativo,
    email_provedor: config.email_provedor ?? "smtp",
    smtp: {
      host: config.smtp?.host ?? "",
      porta: String(config.smtp?.porta ?? 587),
      seguro: config.smtp?.seguro ?? false,
      usuario: config.smtp?.usuario ?? "",
      senha: "",
      remetente: config.smtp?.remetente ?? "",
    },
    resend: { chave: "", remetente: config.resend?.remetente ?? "" },
  };
}

// ---------- Leitura segura do que chega pela rede ----------

function objeto(valor: unknown): Record<string, unknown> | null {
  return valor !== null && typeof valor === "object" && !Array.isArray(valor) ? (valor as Record<string, unknown>) : null;
}

const LIMITE_TEXTO = 300;

/** Lê o corpo da requisição de salvar; qualquer campo com tipo errado devolve nulo (nada é salvo). */
export function lerEntradaConfiguracao(valor: unknown): EntradaConfiguracao | null {
  const bruto = objeto(valor);
  const smtp = objeto(bruto?.smtp);
  const resend = objeto(bruto?.resend);
  if (!bruto || !smtp || !resend) return null;

  const provedor = bruto.email_provedor;
  if (provedor !== null && provedor !== "smtp" && provedor !== "resend") return null;

  const booleanos = [
    bruto.notificar_sucesso,
    bruto.notificar_falha,
    bruto.notificar_restauracao,
    bruto.telegram_ativo,
    bruto.email_ativo,
    smtp.seguro,
  ];
  if (!booleanos.every((item) => typeof item === "boolean")) return null;

  const textos = [
    bruto.telegram_token,
    bruto.telegram_chat_id,
    smtp.host,
    smtp.porta,
    smtp.usuario,
    smtp.senha,
    smtp.remetente,
    resend.chave,
    resend.remetente,
  ];
  if (!textos.every((item) => typeof item === "string" && item.length <= LIMITE_TEXTO)) return null;

  return normalizarEntrada({
    notificar_sucesso: bruto.notificar_sucesso as boolean,
    notificar_falha: bruto.notificar_falha as boolean,
    notificar_restauracao: bruto.notificar_restauracao as boolean,
    telegram_ativo: bruto.telegram_ativo as boolean,
    telegram_token: bruto.telegram_token as string,
    telegram_chat_id: bruto.telegram_chat_id as string,
    email_ativo: bruto.email_ativo as boolean,
    email_provedor: provedor,
    smtp: {
      host: smtp.host as string,
      porta: smtp.porta as string,
      seguro: smtp.seguro as boolean,
      usuario: smtp.usuario as string,
      senha: smtp.senha as string,
      remetente: smtp.remetente as string,
    },
    resend: { chave: resend.chave as string, remetente: resend.remetente as string },
  });
}

/** Lê a resposta do Telegram (getUpdates) e devolve as conversas e grupos que falaram com o bot, sem repetir. */
export function extrairChats(resultado: unknown): ChatTelegram[] {
  if (!Array.isArray(resultado)) return [];
  const vistos = new Map<string, ChatTelegram>();

  for (const atualizacao of resultado) {
    const item = objeto(atualizacao);
    if (!item) continue;

    for (const campo of ["message", "edited_message", "channel_post", "edited_channel_post", "my_chat_member"]) {
      const chat = objeto(objeto(item[campo])?.chat);
      if (!chat) continue;

      const id = typeof chat.id === "number" || typeof chat.id === "string" ? String(chat.id) : "";
      if (!/^-?\d+$/.test(id) || vistos.has(id)) continue;

      const tipo = typeof chat.type === "string" ? chat.type : "";
      const rotuloTipo =
        tipo === "private" ? "conversa privada" : tipo === "group" || tipo === "supergroup" ? "grupo" : tipo === "channel" ? "canal" : tipo;
      const nomes = [chat.first_name, chat.last_name].filter((parte): parte is string => typeof parte === "string" && parte !== "");
      const nome =
        (typeof chat.title === "string" && chat.title) ||
        nomes.join(" ") ||
        (typeof chat.username === "string" && chat.username ? `@${chat.username}` : "") ||
        id;

      vistos.set(id, { id, rotulo: rotuloTipo ? `${nome} (${rotuloTipo})` : nome });
    }
  }
  return [...vistos.values()];
}
