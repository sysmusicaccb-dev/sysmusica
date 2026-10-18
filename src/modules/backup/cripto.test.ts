import { describe, expect, it } from "vitest";
import {
  abrirBackup,
  abrirSegredo,
  cifrarBackup,
  cifrarSegredo,
  lerChave,
  mascararSegredo,
  sha256Hex,
} from "@/modules/backup/cripto";

const chave = lerChave(Buffer.alloc(32, 7).toString("base64"));
const outraChave = lerChave(Buffer.alloc(32, 9).toString("base64"));

describe("lerChave", () => {
  it("aceita 32 bytes em base64", () => {
    expect(chave.length).toBe(32);
  });

  it("recusa chave ausente ou do tamanho errado", () => {
    expect(() => lerChave(undefined)).toThrow(/não está configurada/);
    expect(() => lerChave("   ")).toThrow(/não está configurada/);
    expect(() => lerChave(Buffer.alloc(16, 1).toString("base64"))).toThrow(/32 bytes/);
  });
});

describe("cifrarBackup e abrirBackup", () => {
  const original = Buffer.from(JSON.stringify({ membros: [{ nome: "Maria da Silva", cpf: "12345678901" }] }), "utf8");

  it("devolve o mesmo conteúdo ao abrir com a mesma chave", () => {
    expect(abrirBackup(cifrarBackup(original, chave), chave).equals(original)).toBe(true);
  });

  it("não deixa o texto original visível no arquivo cifrado", () => {
    expect(cifrarBackup(original, chave).toString("utf8")).not.toContain("Maria da Silva");
  });

  it("gera um arquivo diferente a cada vez (vetor aleatório)", () => {
    expect(cifrarBackup(original, chave).equals(cifrarBackup(original, chave))).toBe(false);
  });

  it("falha com a chave errada", () => {
    expect(() => abrirBackup(cifrarBackup(original, chave), outraChave)).toThrow(/chave está errada ou o arquivo foi alterado/);
  });

  it("detecta um byte alterado", () => {
    const arquivo = cifrarBackup(original, chave);
    arquivo[arquivo.length - 1] ^= 0xff;
    expect(() => abrirBackup(arquivo, chave)).toThrow(/foi alterado/);
  });

  it("recusa um arquivo que não é backup do sistema", () => {
    expect(() => abrirBackup(Buffer.from("qualquer coisa que não é backup, com tamanho suficiente"), chave)).toThrow(
      /inválido ou de outro formato/
    );
    expect(() => abrirBackup(Buffer.alloc(4), chave)).toThrow(/inválido ou de outro formato/);
  });

  it("não aceita um segredo como se fosse um backup", () => {
    expect(() => abrirBackup(Buffer.from(cifrarSegredo("123:abc", chave), "base64"), chave)).toThrow(
      /inválido ou de outro formato/
    );
  });
});

describe("segredos", () => {
  it("cifra e abre um texto, sem mostrá-lo no valor guardado", () => {
    const guardado = cifrarSegredo("123456:token-secreto", chave);
    expect(guardado).not.toContain("token-secreto");
    expect(abrirSegredo(guardado, chave)).toBe("123456:token-secreto");
  });

  it("falha com a chave errada", () => {
    expect(() => abrirSegredo(cifrarSegredo("x", chave), outraChave)).toThrow(/foi alterado/);
  });

  it("mostra só o final do segredo", () => {
    expect(mascararSegredo(" abcdefgh1234 ")).toBe("…1234");
    expect(mascararSegredo("abc")).toBe("…");
  });
});

describe("sha256Hex", () => {
  it("gera a impressão digital conhecida", () => {
    expect(sha256Hex("abc")).toBe("ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad");
    expect(sha256Hex(Buffer.from("abc"))).toBe(sha256Hex("abc"));
  });
});
