import { describe, expect, it } from "vitest";
import {
  enderecoValido,
  lerEntradaDestino,
  linhaDoAviso,
  NOME_REMOTO_VALIDO,
  nomeRemoto,
  normalizarEndereco,
  validarEntradaDestino,
  type EntradaDestino,
} from "./destinos";

const nada = { clientId: false, clientSecret: false, assinatura: false };
const tudo = { clientId: true, clientSecret: true, assinatura: true };
const entrada = (parcial: Partial<EntradaDestino> = {}): EntradaDestino => ({
  ativo: false,
  endereco: "",
  client_id: "",
  client_secret: "",
  chave_assinatura: "",
  ...parcial,
});

describe("endereço", () => {
  it("normaliza espaços e barras finais", () => {
    expect(normalizarEndereco("  https://bkp.exemplo.com.br/// ")).toBe("https://bkp.exemplo.com.br");
  });
  it("aceita só https com domínio e sem caminho", () => {
    expect(enderecoValido("https://bkp-sysmusicaccb.2atelecom.net.br")).toBe(true);
    expect(enderecoValido("http://bkp.exemplo.com.br")).toBe(false);
    expect(enderecoValido("https://localhost")).toBe(false);
    expect(enderecoValido("https://usuario:senha@bkp.exemplo.com.br")).toBe(false);
    expect(enderecoValido("https://bkp.exemplo.com.br/caminho")).toBe(false);
    expect(enderecoValido("https://bkp.exemplo.com.br?x=1")).toBe(false);
    expect(enderecoValido("isto não é um endereço")).toBe(false);
  });
});

describe("validarEntradaDestino", () => {
  it("aceita formulário vazio desligado", () => {
    expect(validarEntradaDestino(entrada(), nada)).toBeNull();
  });
  it("recusa endereço ruim, mesmo desligado", () => {
    expect(validarEntradaDestino(entrada({ endereco: "http://x.com.br" }), nada)).toMatch(/https/);
  });
  it("recusa segredos curtos demais", () => {
    expect(validarEntradaDestino(entrada({ client_id: "abc" }), nada)).toMatch(/Client ID/);
    expect(validarEntradaDestino(entrada({ client_secret: "curto" }), nada)).toMatch(/Client Secret/);
    expect(validarEntradaDestino(entrada({ chave_assinatura: "curta" }), nada)).toMatch(/chave de assinatura/);
  });
  it("para ligar exige tudo, contando o que já está salvo", () => {
    const ligado = entrada({ ativo: true, endereco: "https://bkp.exemplo.com.br" });
    expect(validarEntradaDestino(ligado, nada)).toMatch(/Client ID/);
    expect(validarEntradaDestino({ ...ligado, client_id: "12345678.access" }, nada)).toMatch(/Client Secret/);
    expect(
      validarEntradaDestino({ ...ligado, client_id: "12345678.access", client_secret: "x".repeat(20) }, nada)
    ).toMatch(/chave de assinatura/);
    expect(validarEntradaDestino(ligado, tudo)).toBeNull(); // campos em branco mantêm o que está salvo
  });
  it("para ligar exige o endereço", () => {
    expect(validarEntradaDestino(entrada({ ativo: true }), tudo)).toMatch(/endereço/);
  });
});

describe("lerEntradaDestino", () => {
  it("lê um corpo válido e recusa formatos errados", () => {
    const ok = { ativo: true, endereco: "https://a.b.com", client_id: "", client_secret: "", chave_assinatura: "" };
    expect(lerEntradaDestino(ok)).toEqual(ok);
    expect(lerEntradaDestino(null)).toBeNull();
    expect(lerEntradaDestino([])).toBeNull();
    expect(lerEntradaDestino({ ...ok, ativo: "sim" })).toBeNull();
    expect(lerEntradaDestino({ ...ok, endereco: 5 })).toBeNull();
    expect(lerEntradaDestino({ ...ok, client_secret: "x".repeat(601) })).toBeNull();
  });
});

describe("nomeRemoto", () => {
  it("usa só o final do caminho e caracteres seguros", () => {
    expect(nomeRemoto("2026/10/manual-20261018-abc.sysbk")).toBe("manual-20261018-abc.sysbk");
    expect(nomeRemoto("pasta/arquivo com espaço.sysbk")).toBe("arquivo-com-espa-o.sysbk");
  });
  it("sempre gera um nome que o receptor aceita", () => {
    for (const caminho of ["../../etc/passwd", "...", "-x", "a/b/" + "z".repeat(300), "", "ç/ç"]) {
      expect(nomeRemoto(caminho)).toMatch(NOME_REMOTO_VALIDO);
    }
    expect(nomeRemoto("a/" + "z".repeat(300) + "-fim")).toMatch(/-fim$/); // o final (sufixo único) é preservado
  });
});

describe("linhaDoAviso", () => {
  it("descreve cada resultado", () => {
    expect(linhaDoAviso({ estado: "enviado" })).toMatch(/enviada e conferida/);
    expect(linhaDoAviso({ estado: "ja_existia" })).toMatch(/já estava/);
    expect(linhaDoAviso({ estado: "erro", detalhe: "túnel fora" })).toMatch(/FALHOU \(túnel fora\)/);
    expect(linhaDoAviso({ estado: "desligado" })).toBeNull();
  });
});
