import { beforeEach, describe, expect, it, vi } from "vitest";

const enviarTelegram = vi.fn();
let linha: unknown = null;
let erroBanco = false;

vi.mock("../../backup/server/notificar", () => ({ enviarTelegram: (...args: unknown[]) => enviarTelegram(...args) }));
vi.mock("../../backup/cripto", () => ({
  lerChave: () => Buffer.alloc(32),
  abrirSegredo: () => "TOKEN-SECRETO",
}));
vi.mock("../../backup/server/clienteAdmin", () => ({
  clienteAdmin: () => ({
    from: () => ({
      select: () => ({
        eq: () => ({
          maybeSingle: async () => {
            if (erroBanco) throw new Error("banco fora do ar");
            return { data: linha };
          },
        }),
      }),
    }),
  }),
}));

import { avisarNovoCadastro, mensagemNovoCadastro } from "./avisoTelegram";

const ligado = { telegram_ativo: true, telegram_token_cifrado: "cifrado", telegram_chat_id: "-1001" };

beforeEach(() => {
  enviarTelegram.mockReset();
  enviarTelegram.mockResolvedValue(undefined);
  linha = ligado;
  erroBanco = false;
  vi.spyOn(console, "error").mockImplementation(() => undefined);
});

describe("mensagemNovoCadastro", () => {
  it("avisa do cadastro sem trazer dados da pessoa", () => {
    const texto = mensagemNovoCadastro(new Date("2026-10-22T16:00:00Z"));
    expect(texto).toContain("novo cadastro recebido");
    expect(texto).toContain("cadastros pendentes");
    expect(texto).not.toMatch(/\d{3}\.?\d{3}\.?\d{3}-?\d{2}/); // nada parecido com CPF
  });
});

describe("avisarNovoCadastro", () => {
  it("envia ao chat configurado quando o Telegram está ligado", async () => {
    expect(await avisarNovoCadastro()).toBe("enviado");
    expect(enviarTelegram).toHaveBeenCalledTimes(1);
    const [token, chat, texto] = enviarTelegram.mock.calls[0] as [string, string, string];
    expect(token).toBe("TOKEN-SECRETO");
    expect(chat).toBe("-1001");
    expect(texto).toContain("novo cadastro recebido");
  });

  it("não envia quando o Telegram está desligado", async () => {
    linha = { ...ligado, telegram_ativo: false };
    expect(await avisarNovoCadastro()).toBe("desligado");
    expect(enviarTelegram).not.toHaveBeenCalled();
  });

  it("não envia quando falta o token ou o chat, ou não há configuração", async () => {
    linha = { ...ligado, telegram_chat_id: null };
    expect(await avisarNovoCadastro()).toBe("desligado");
    linha = null;
    expect(await avisarNovoCadastro()).toBe("desligado");
    expect(enviarTelegram).not.toHaveBeenCalled();
  });

  it("se o Telegram recusar, devolve erro sem lançar e sem vazar o token no log", async () => {
    enviarTelegram.mockRejectedValue(new Error("falhou em TOKEN-SECRETO"));
    expect(await avisarNovoCadastro()).toBe("erro");
    const registrado = JSON.stringify((console.error as unknown as { mock: { calls: unknown[] } }).mock.calls);
    expect(registrado).not.toContain("TOKEN-SECRETO");
  });

  it("se o banco falhar, devolve erro sem lançar", async () => {
    erroBanco = true;
    expect(await avisarNovoCadastro()).toBe("erro");
  });
});
