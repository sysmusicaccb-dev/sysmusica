/**
 * Sysmusica — Configuração dos avisos do Backup no servidor: ler, salvar, destinatários, testes e busca de
 * chats do Telegram. Usa a chave secreta do Supabase: quem chama já foi autenticado pela rota (permissão
 * backup.configurar). Token, senhas e chaves ficam criptografados com a BACKUP_CHAVE e NUNCA voltam para a tela
 * (só o final mascarado). Toda alteração e todo teste vão para a Auditoria, sem nenhum segredo.
 */
import type { SupabaseClient } from "@supabase/supabase-js";
import { abrirSegredo, cifrarSegredo, lerChave, mascararSegredo } from "../cripto";
import {
  extrairChats,
  validarEntrada,
  type ChatTelegram,
  type ConfiguracaoPublica,
  type ContextoValidacao,
  type Destinatario,
  type EntradaConfiguracao,
  type ProvedorEmail,
} from "../configuracao";
import { dataHoraSalvador, emailValido, idValido, lerConfigResend, lerConfigSmtp } from "../regras";
import type { UsuarioAutenticado } from "./autorizacao";
import { clienteAdmin } from "./clienteAdmin";
import { ErroBackup } from "./erros";
import { enviarEmail, enviarTelegram, type ConfigEmail } from "./notificar";

const COLUNAS =
  "notificar_sucesso, notificar_falha, notificar_restauracao, telegram_ativo, telegram_token_cifrado, " +
  "telegram_chat_id, email_ativo, email_provedor, email_config_cifrado, atualizado_em";

interface LinhaConfig {
  notificar_sucesso: boolean;
  notificar_falha: boolean;
  notificar_restauracao: boolean;
  telegram_ativo: boolean;
  telegram_token_cifrado: string | null;
  telegram_chat_id: string | null;
  email_ativo: boolean;
  email_provedor: ProvedorEmail | null;
  email_config_cifrado: string | null;
  atualizado_em: string | null;
}

const PADRAO: LinhaConfig = {
  notificar_sucesso: true,
  notificar_falha: true,
  notificar_restauracao: true,
  telegram_ativo: false,
  telegram_token_cifrado: null,
  telegram_chat_id: null,
  email_ativo: false,
  email_provedor: null,
  email_config_cifrado: null,
  atualizado_em: null,
};

const texto = (valor: unknown): string => (typeof valor === "string" ? valor : "");

function chaveDoAmbiente(): Buffer {
  try {
    return lerChave(process.env.BACKUP_CHAVE);
  } catch (e) {
    throw new ErroBackup(500, e instanceof Error ? e.message : "A chave dos backups não está configurada.");
  }
}

async function lerLinha(admin: SupabaseClient): Promise<LinhaConfig> {
  const { data, error } = await admin.from("backup_configuracao").select(COLUNAS).eq("id", 1).maybeSingle();
  if (error) throw new ErroBackup(500, "Não foi possível ler a configuração dos avisos.");
  return data ? (data as unknown as LinhaConfig) : PADRAO;
}

// ---------- Segredos guardados ----------

interface Segredos {
  token: string;
  provedor: ProvedorEmail | null;
  bruto: Record<string, unknown> | null; // configuração do e-mail já aberta
  ilegivel: boolean; // algum segredo não abriu com a chave atual
}

function abrirSegredos(linha: LinhaConfig, chave: Buffer): Segredos {
  let ilegivel = false;
  let token = "";
  if (linha.telegram_token_cifrado) {
    try {
      token = abrirSegredo(linha.telegram_token_cifrado, chave);
    } catch {
      ilegivel = true;
    }
  }

  let bruto: Record<string, unknown> | null = null;
  if (linha.email_config_cifrado) {
    try {
      const valor: unknown = JSON.parse(abrirSegredo(linha.email_config_cifrado, chave));
      if (valor !== null && typeof valor === "object" && !Array.isArray(valor)) bruto = valor as Record<string, unknown>;
    } catch {
      ilegivel = true;
    }
  }
  return { token, provedor: linha.email_provedor, bruto, ilegivel };
}

// Mensagem de erro sem nenhum segredo dentro
function mensagemSegura(erro: unknown, segredos: string[]): string {
  let mensagem = erro instanceof Error ? erro.message : "erro desconhecido";
  for (const segredo of segredos) {
    if (segredo.length >= 4) mensagem = mensagem.split(segredo).join("***");
  }
  return mensagem.slice(0, 200);
}

function listaDeSegredos(segredos: Segredos): string[] {
  return [segredos.token, texto(segredos.bruto?.senha), texto(segredos.bruto?.chave)];
}

// Registra a ação na Auditoria; uma falha aqui nunca derruba a operação
async function auditar(
  admin: SupabaseClient,
  usuarioId: string,
  acao: string,
  detalhes: Record<string, unknown>
): Promise<void> {
  const { error } = await admin
    .from("auditoria")
    .insert({ usuario_id: usuarioId, acao, entidade: "backup", entidade_id: null, detalhes });
  if (error) console.error("Falha ao registrar a auditoria da configuração do backup:", error.message);
}

// ---------- Destinatários ----------

async function listarDestinatarios(admin: SupabaseClient): Promise<Destinatario[]> {
  const { data, error } = await admin.from("backup_destinatarios").select("id, email, ativo").order("email", { ascending: true });
  if (error) throw new ErroBackup(500, "Não foi possível listar os destinatários.");
  return (data ?? []) as Destinatario[];
}

export async function adicionarDestinatario(email: string, usuario: UsuarioAutenticado): Promise<Destinatario[]> {
  const admin = clienteAdmin();
  const limpo = email.trim();
  if (!emailValido(limpo)) throw new ErroBackup(400, "Digite um e-mail válido.");

  const { error } = await admin.from("backup_destinatarios").insert({ email: limpo, ativo: true });
  if (error) {
    if (error.code === "23505") throw new ErroBackup(409, "Este e-mail já está na lista.");
    throw new ErroBackup(500, "Não foi possível adicionar o e-mail.");
  }
  await auditar(admin, usuario.id, "backup_configuracao_alterada", { alterados: ["destinatario_adicionado"] });
  return listarDestinatarios(admin);
}

export async function alterarDestinatario(id: string, ativo: boolean, usuario: UsuarioAutenticado): Promise<Destinatario[]> {
  if (!idValido(id)) throw new ErroBackup(400, "Identificador inválido.");
  const admin = clienteAdmin();

  const { data, error } = await admin.from("backup_destinatarios").update({ ativo }).eq("id", id).select("id");
  if (error) throw new ErroBackup(500, "Não foi possível alterar o destinatário.");
  if (!data || data.length === 0) throw new ErroBackup(404, "Destinatário não encontrado.");

  await auditar(admin, usuario.id, "backup_configuracao_alterada", {
    alterados: [ativo ? "destinatario_ligado" : "destinatario_desligado"],
  });
  return listarDestinatarios(admin);
}

export async function removerDestinatario(id: string, usuario: UsuarioAutenticado): Promise<Destinatario[]> {
  if (!idValido(id)) throw new ErroBackup(400, "Identificador inválido.");
  const admin = clienteAdmin();

  const { data, error } = await admin.from("backup_destinatarios").delete().eq("id", id).select("id");
  if (error) throw new ErroBackup(500, "Não foi possível remover o destinatário.");
  if (!data || data.length === 0) throw new ErroBackup(404, "Destinatário não encontrado.");

  await auditar(admin, usuario.id, "backup_configuracao_alterada", { alterados: ["destinatario_removido"] });
  return listarDestinatarios(admin);
}

// ---------- Ler e salvar ----------

function paraPublica(linha: LinhaConfig, segredos: Segredos, destinatarios: Destinatario[]): ConfiguracaoPublica {
  const bruto = segredos.bruto;
  const smtp =
    segredos.provedor === "smtp" && bruto
      ? {
          host: texto(bruto.host).trim(),
          porta: Number(bruto.porta) || 587,
          seguro: bruto.seguro === true,
          usuario: texto(bruto.usuario).trim(),
          remetente: texto(bruto.remetente).trim(),
          senha_configurada: texto(bruto.senha) !== "",
        }
      : null;
  const resend =
    segredos.provedor === "resend" && bruto
      ? {
          remetente: texto(bruto.remetente).trim(),
          chave_final: texto(bruto.chave) !== "" ? mascararSegredo(texto(bruto.chave)) : null,
        }
      : null;

  return {
    notificar_sucesso: linha.notificar_sucesso,
    notificar_falha: linha.notificar_falha,
    notificar_restauracao: linha.notificar_restauracao,
    telegram_ativo: linha.telegram_ativo,
    telegram_chat_id: texto(linha.telegram_chat_id),
    telegram_token_final: segredos.token !== "" ? mascararSegredo(segredos.token) : null,
    email_ativo: linha.email_ativo,
    email_provedor: linha.email_provedor,
    smtp,
    resend,
    destinatarios,
    atualizado_em: linha.atualizado_em,
    aviso_segredos: segredos.ilegivel
      ? "Os segredos guardados não abrem com a BACKUP_CHAVE atual. Digite de novo o token e as senhas e salve."
      : null,
  };
}

/** A configuração para a tela: sem token, senha ou chave. */
export async function lerConfiguracaoPublica(): Promise<ConfiguracaoPublica> {
  const admin = clienteAdmin();
  const chave = chaveDoAmbiente();
  const linha = await lerLinha(admin);
  return paraPublica(linha, abrirSegredos(linha, chave), await listarDestinatarios(admin));
}

/** Valida, criptografa os segredos novos, mantém os que ficaram em branco e salva. */
export async function salvarConfiguracao(entrada: EntradaConfiguracao, usuario: UsuarioAutenticado): Promise<ConfiguracaoPublica> {
  const admin = clienteAdmin();
  const chave = chaveDoAmbiente();
  const linha = await lerLinha(admin);
  const atuais = abrirSegredos(linha, chave);

  // O que já existe, para aceitar campo de segredo em branco (só vale para o mesmo provedor)
  const mesmoProvedor = entrada.email_provedor !== null && entrada.email_provedor === atuais.provedor;
  const senhaSmtpAtual = mesmoProvedor && entrada.email_provedor === "smtp" ? texto(atuais.bruto?.senha) : "";
  const chaveResendAtual = mesmoProvedor && entrada.email_provedor === "resend" ? texto(atuais.bruto?.chave) : "";
  const contexto: ContextoValidacao = {
    tokenJaConfigurado: atuais.token !== "",
    senhaSmtpJaConfigurada: senhaSmtpAtual !== "",
    chaveResendJaConfigurada: chaveResendAtual !== "",
  };
  const problema = validarEntrada(entrada, contexto);
  if (problema) throw new ErroBackup(400, problema);

  // Token do Telegram: o novo (criptografado) ou o que já estava guardado
  const tokenCifrado = entrada.telegram_token !== "" ? cifrarSegredo(entrada.telegram_token, chave) : linha.telegram_token_cifrado;

  // Configuração do e-mail: só a do provedor escolhido é guardada
  let emailCifrado: string | null = null;
  if (entrada.email_provedor === "smtp") {
    emailCifrado = cifrarSegredo(
      JSON.stringify({
        host: entrada.smtp.host,
        porta: Number(entrada.smtp.porta) || 587,
        seguro: entrada.smtp.seguro,
        usuario: entrada.smtp.usuario,
        senha: entrada.smtp.senha !== "" ? entrada.smtp.senha : senhaSmtpAtual,
        remetente: entrada.smtp.remetente,
      }),
      chave
    );
  } else if (entrada.email_provedor === "resend") {
    emailCifrado = cifrarSegredo(
      JSON.stringify({
        chave: entrada.resend.chave !== "" ? entrada.resend.chave : chaveResendAtual,
        remetente: entrada.resend.remetente,
      }),
      chave
    );
  }

  // O que mudou (só nomes de campos, nunca valores secretos), para a Auditoria
  const alterados: string[] = [];
  const marca = (nome: string, mudou: boolean) => {
    if (mudou) alterados.push(nome);
  };
  marca("avisar_sucesso", entrada.notificar_sucesso !== linha.notificar_sucesso);
  marca("avisar_falha", entrada.notificar_falha !== linha.notificar_falha);
  marca("avisar_restauracao", entrada.notificar_restauracao !== linha.notificar_restauracao);
  marca("telegram_ativo", entrada.telegram_ativo !== linha.telegram_ativo);
  marca("telegram_chat", entrada.telegram_chat_id !== texto(linha.telegram_chat_id));
  marca("telegram_token", entrada.telegram_token !== "");
  marca("email_ativo", entrada.email_ativo !== linha.email_ativo);
  marca("email_provedor", entrada.email_provedor !== linha.email_provedor);
  if (entrada.email_provedor === "smtp") {
    const antes = mesmoProvedor ? atuais.bruto : null;
    marca("smtp_host", entrada.smtp.host !== texto(antes?.host).trim());
    marca("smtp_porta", entrada.smtp.porta !== String(antes?.porta ?? ""));
    marca("smtp_usuario", entrada.smtp.usuario !== texto(antes?.usuario).trim());
    marca("smtp_remetente", entrada.smtp.remetente !== texto(antes?.remetente).trim());
    marca("smtp_senha", entrada.smtp.senha !== "");
  } else if (entrada.email_provedor === "resend") {
    const antes = mesmoProvedor ? atuais.bruto : null;
    marca("resend_remetente", entrada.resend.remetente !== texto(antes?.remetente).trim());
    marca("resend_chave", entrada.resend.chave !== "");
  }

  const { error } = await admin.from("backup_configuracao").upsert(
    {
      id: 1,
      notificar_sucesso: entrada.notificar_sucesso,
      notificar_falha: entrada.notificar_falha,
      notificar_restauracao: entrada.notificar_restauracao,
      telegram_ativo: entrada.telegram_ativo,
      telegram_token_cifrado: tokenCifrado,
      telegram_chat_id: entrada.telegram_chat_id === "" ? null : entrada.telegram_chat_id,
      email_ativo: entrada.email_ativo,
      email_provedor: entrada.email_provedor,
      email_config_cifrado: emailCifrado,
      atualizado_em: new Date().toISOString(),
      atualizado_por: usuario.id,
    },
    { onConflict: "id" }
  );
  if (error) throw new ErroBackup(500, "Não foi possível salvar a configuração dos avisos.");

  if (alterados.length > 0) await auditar(admin, usuario.id, "backup_configuracao_alterada", { alterados });
  return lerConfiguracaoPublica();
}

// ---------- Testes e busca de chats ----------

// Monta o envio de e-mail a partir da configuração guardada (nulo se estiver incompleta)
function abrirConfigEmail(segredos: Segredos): ConfigEmail | null {
  if (!segredos.provedor || !segredos.bruto) return null;
  if (segredos.provedor === "smtp") {
    const config = lerConfigSmtp(segredos.bruto);
    return config ? { provedor: "smtp", config } : null;
  }
  const config = lerConfigResend(segredos.bruto);
  return config ? { provedor: "resend", config } : null;
}

/** Envia uma mensagem de teste usando a configuração JÁ SALVA. */
export async function testarAviso(canal: "telegram" | "email", usuario: UsuarioAutenticado): Promise<{ detalhe: string }> {
  const admin = clienteAdmin();
  const chave = chaveDoAmbiente();
  const linha = await lerLinha(admin);
  const segredos = abrirSegredos(linha, chave);
  const mascarar = listaDeSegredos(segredos);
  const quando = dataHoraSalvador(new Date());
  const corpo = `Esta é uma mensagem de teste do módulo de Backup do Sysmusica.\nEnviada por ${usuario.nome || "administrador"} em ${quando}.`;

  try {
    if (canal === "telegram") {
      if (segredos.token === "" || !linha.telegram_chat_id) {
        throw new ErroBackup(400, "Salve o token e o ID do chat do Telegram antes de testar.");
      }
      await enviarTelegram(segredos.token, linha.telegram_chat_id, `Sysmusica: teste de aviso\n\n${corpo}`);
    } else {
      const envio = abrirConfigEmail(segredos);
      if (!envio) throw new ErroBackup(400, "Salve a configuração de e-mail completa antes de testar.");
      const destinos = (await listarDestinatarios(admin)).filter((item) => item.ativo).map((item) => item.email);
      if (destinos.length === 0) throw new ErroBackup(400, "Cadastre pelo menos um destinatário ativo antes de testar.");
      await enviarEmail(envio, destinos, "Sysmusica: teste de aviso", corpo);
    }
  } catch (e) {
    if (e instanceof ErroBackup) throw e;
    throw new ErroBackup(502, `Não foi possível enviar o teste: ${mensagemSegura(e, mascarar)}`);
  }

  await auditar(admin, usuario.id, "backup_aviso_testado", { canal });
  return { detalhe: canal === "telegram" ? "Mensagem de teste enviada ao Telegram. Confira o chat." : "E-mail de teste enviado. Confira a caixa de entrada (e o spam)." };
}

/** Pergunta ao Telegram quais conversas e grupos falaram com o bot nas últimas horas (para descobrir o ID do chat). */
export async function buscarChatsTelegram(): Promise<ChatTelegram[]> {
  const admin = clienteAdmin();
  const chave = chaveDoAmbiente();
  const segredos = abrirSegredos(await lerLinha(admin), chave);
  if (segredos.token === "") throw new ErroBackup(400, "Salve o token do bot antes de buscar os chats.");

  try {
    const resposta = await fetch(`https://api.telegram.org/bot${segredos.token}/getUpdates?limit=100&timeout=0`, {
      signal: AbortSignal.timeout(10_000),
    });
    const corpo = (await resposta.json().catch(() => null)) as { ok?: boolean; description?: string; result?: unknown } | null;
    if (!resposta.ok || !corpo?.ok) {
      throw new ErroBackup(502, `O Telegram recusou a consulta: ${corpo?.description ?? `código ${resposta.status}`}`);
    }
    return extrairChats(corpo.result);
  } catch (e) {
    if (e instanceof ErroBackup) throw e;
    throw new ErroBackup(502, `Não foi possível consultar o Telegram: ${mensagemSegura(e, [segredos.token])}`);
  }
}
