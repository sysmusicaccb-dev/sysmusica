import { describe, expect, it } from "vitest";
import {
  chatIdValido,
  extrairChats,
  formularioInicial,
  lerEntradaConfiguracao,
  normalizarEntrada,
  remetenteValido,
  tokenTelegramValido,
  validarEntrada,
  type ConfiguracaoPublica,
  type ContextoValidacao,
  type EntradaConfiguracao,
} from "@/modules/backup/configuracao";

const TOKEN = "123456789:AAHdqTcvCH1vGWJxfSeofSAs0K5PALDsaw";

const entradaBase: EntradaConfiguracao = {
  notificar_sucesso: true,
  notificar_falha: true,
  notificar_restauracao: true,
  telegram_ativo: false,
  telegram_token: "",
  telegram_chat_id: "",
  email_ativo: false,
  email_provedor: "smtp",
  smtp: { host: "", porta: "587", seguro: false, usuario: "", senha: "", remetente: "" },
  resend: { chave: "", remetente: "" },
};

const nada: ContextoValidacao = { tokenJaConfigurado: false, senhaSmtpJaConfigurada: false, chaveResendJaConfigurada: false };

describe("formatos", () => {
  it("confere o token do Telegram", () => {
    expect(tokenTelegramValido(TOKEN)).toBe(true);
    expect(tokenTelegramValido(` ${TOKEN} `)).toBe(true);
    expect(tokenTelegramValido("123:abc")).toBe(false);
    expect(tokenTelegramValido("sem-dois-pontos")).toBe(false);
  });

  it("confere o ID do chat", () => {
    expect(chatIdValido("-1001234567890")).toBe(true);
    expect(chatIdValido("987654321")).toBe(true);
    expect(chatIdValido("@canal_publico")).toBe(true);
    expect(chatIdValido("grupo da musica")).toBe(false);
    expect(chatIdValido("@a")).toBe(false);
  });

  it("confere o remetente", () => {
    expect(remetenteValido("backup@exemplo.com")).toBe(true);
    expect(remetenteValido("Sysmusica <backup@exemplo.com>")).toBe(true);
    expect(remetenteValido("Sysmusica <backup>")).toBe(false);
    expect(remetenteValido("sem-arroba")).toBe(false);
  });
});

describe("validarEntrada", () => {
  it("aceita tudo desligado e em branco", () => {
    expect(validarEntrada(entradaBase, nada)).toBeNull();
  });

  it("exige token e chat com o Telegram ligado, aceitando o token já guardado", () => {
    const ligado = { ...entradaBase, telegram_ativo: true };
    expect(validarEntrada(ligado, nada)).toMatch(/ID do chat/);
    expect(validarEntrada({ ...ligado, telegram_chat_id: "-100123" }, nada)).toMatch(/token/);
    expect(validarEntrada({ ...ligado, telegram_chat_id: "-100123" }, { ...nada, tokenJaConfigurado: true })).toBeNull();
    expect(validarEntrada({ ...ligado, telegram_chat_id: "-100123", telegram_token: TOKEN }, nada)).toBeNull();
  });

  it("recusa token ou chat inválidos mesmo com o aviso desligado", () => {
    expect(validarEntrada({ ...entradaBase, telegram_token: "abc" }, nada)).toMatch(/token/);
    expect(validarEntrada({ ...entradaBase, telegram_chat_id: "abc" }, nada)).toMatch(/ID do chat/);
  });

  it("exige o provedor e os dados do SMTP com o e-mail ligado", () => {
    const ligado = { ...entradaBase, email_ativo: true };
    expect(validarEntrada({ ...ligado, email_provedor: null }, nada)).toMatch(/provedor/);
    expect(validarEntrada(ligado, nada)).toMatch(/servidor SMTP/);
    const smtp = { host: "smtp.exemplo.com", porta: "587", seguro: false, usuario: "u", senha: "", remetente: "backup@exemplo.com" };
    expect(validarEntrada({ ...ligado, smtp }, nada)).toMatch(/senha do SMTP/);
    expect(validarEntrada({ ...ligado, smtp }, { ...nada, senhaSmtpJaConfigurada: true })).toBeNull();
    expect(validarEntrada({ ...ligado, smtp: { ...smtp, senha: "s" } }, nada)).toBeNull();
    expect(validarEntrada({ ...ligado, smtp: { ...smtp, usuario: "" } }, nada)).toBeNull();
  });

  it("confere servidor, porta e remetente do SMTP", () => {
    const smtp = { ...entradaBase.smtp, host: "smtp exemplo", porta: "587", remetente: "a@b.com" };
    expect(validarEntrada({ ...entradaBase, smtp }, nada)).toMatch(/servidor SMTP/);
    expect(validarEntrada({ ...entradaBase, smtp: { ...smtp, host: "smtp.exemplo.com", porta: "70000" } }, nada)).toMatch(/porta/);
    expect(validarEntrada({ ...entradaBase, smtp: { ...smtp, host: "smtp.exemplo.com", remetente: "x" } }, nada)).toMatch(/remetente/);
  });

  it("exige a chave e o remetente do Resend com o e-mail ligado", () => {
    const resend = { ...entradaBase, email_ativo: true, email_provedor: "resend" as const };
    expect(validarEntrada(resend, nada)).toMatch(/remetente/);
    const comRemetente = { ...resend, resend: { chave: "", remetente: "backup@exemplo.com" } };
    expect(validarEntrada(comRemetente, nada)).toMatch(/chave/);
    expect(validarEntrada(comRemetente, { ...nada, chaveResendJaConfigurada: true })).toBeNull();
    expect(validarEntrada({ ...comRemetente, resend: { chave: "re_123", remetente: "backup@exemplo.com" } }, nada)).toBeNull();
  });
});

describe("normalizarEntrada", () => {
  it("tira os espaços, menos da senha", () => {
    const limpa = normalizarEntrada({
      ...entradaBase,
      telegram_token: ` ${TOKEN} `,
      telegram_chat_id: " -100 ",
      smtp: { host: " h ", porta: " 25 ", seguro: false, usuario: " u ", senha: " s ", remetente: " a@b.com " },
      resend: { chave: " re_1 ", remetente: " r@b.com " },
    });
    expect(limpa.telegram_token).toBe(TOKEN);
    expect(limpa.telegram_chat_id).toBe("-100");
    expect(limpa.smtp).toEqual({ host: "h", porta: "25", seguro: false, usuario: "u", senha: " s ", remetente: "a@b.com" });
    expect(limpa.resend).toEqual({ chave: "re_1", remetente: "r@b.com" });
  });
});

describe("lerEntradaConfiguracao", () => {
  it("aceita um corpo completo e normaliza", () => {
    const lida = lerEntradaConfiguracao({ ...entradaBase, telegram_chat_id: " -100 " });
    expect(lida?.telegram_chat_id).toBe("-100");
  });

  it("recusa corpo com tipo errado, campo faltando ou provedor desconhecido", () => {
    expect(lerEntradaConfiguracao(null)).toBeNull();
    expect(lerEntradaConfiguracao("texto")).toBeNull();
    expect(lerEntradaConfiguracao({ ...entradaBase, notificar_falha: "sim" })).toBeNull();
    expect(lerEntradaConfiguracao({ ...entradaBase, smtp: undefined })).toBeNull();
    expect(lerEntradaConfiguracao({ ...entradaBase, email_provedor: "outro" })).toBeNull();
    expect(lerEntradaConfiguracao({ ...entradaBase, telegram_token: "x".repeat(400) })).toBeNull();
  });
});

describe("formularioInicial", () => {
  const publica: ConfiguracaoPublica = {
    notificar_sucesso: true,
    notificar_falha: false,
    notificar_restauracao: true,
    telegram_ativo: true,
    telegram_chat_id: "-100",
    telegram_token_final: "…saw",
    email_ativo: true,
    email_provedor: "smtp",
    smtp: { host: "smtp.exemplo.com", porta: 465, seguro: true, usuario: "u", remetente: "a@b.com", senha_configurada: true },
    resend: null,
    destinatarios: [],
    atualizado_em: null,
    aviso_segredos: null,
  };

  it("preenche os campos e deixa os segredos em branco", () => {
    const form = formularioInicial(publica);
    expect(form.telegram_token).toBe("");
    expect(form.smtp).toEqual({ host: "smtp.exemplo.com", porta: "465", seguro: true, usuario: "u", senha: "", remetente: "a@b.com" });
    expect(form.notificar_falha).toBe(false);
  });

  it("sem configuração, começa em SMTP na porta 587", () => {
    const form = formularioInicial({ ...publica, email_provedor: null, smtp: null, resend: null });
    expect(form.email_provedor).toBe("smtp");
    expect(form.smtp.porta).toBe("587");
  });
});

describe("extrairChats", () => {
  const resposta = [
    { update_id: 1, message: { chat: { id: 987, type: "private", first_name: "Levi", last_name: "A" } } },
    { update_id: 2, message: { chat: { id: -100123, type: "supergroup", title: "Música CCB" } } },
    { update_id: 3, my_chat_member: { chat: { id: -100123, type: "supergroup", title: "Música CCB" } } },
    { update_id: 4, channel_post: { chat: { id: -100999, type: "channel", username: "avisos" } } },
    { update_id: 5, message: { chat: { id: "abc" } } },
    "lixo",
  ];

  it("lista conversas e grupos, sem repetir e ignorando o que não serve", () => {
    expect(extrairChats(resposta)).toEqual([
      { id: "987", rotulo: "Levi A (conversa privada)" },
      { id: "-100123", rotulo: "Música CCB (grupo)" },
      { id: "-100999", rotulo: "@avisos (canal)" },
    ]);
  });

  it("devolve lista vazia quando a resposta não é uma lista", () => {
    expect(extrairChats(null)).toEqual([]);
    expect(extrairChats({})).toEqual([]);
  });
});
