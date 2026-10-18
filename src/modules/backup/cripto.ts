/**
 * SysMúsica — Criptografia do backup (só roda no SERVIDOR: usa os módulos "crypto" e "zlib" do Node).
 *  - O arquivo de backup é comprimido (gzip) e criptografado com AES-256-GCM. O GCM também detecta
 *    qualquer alteração no arquivo: se um byte mudar, ou se a chave estiver errada, a abertura falha.
 *  - Os segredos guardados no banco (token do Telegram, senha do e-mail) usam o mesmo método, em formato texto.
 *  - A chave vem da variável BACKUP_CHAVE (32 bytes em base64). SEM ELA OS BACKUPS NÃO ABREM: guarde uma cópia
 *    fora do sistema.
 * Formato do arquivo: marca (6 bytes) + vetor (12) + etiqueta de autenticação (16) + conteúdo cifrado.
 */
import { createCipheriv, createDecipheriv, createHash, randomBytes } from "node:crypto";
import { gunzipSync, gzipSync } from "node:zlib";

const MARCA_ARQUIVO = Buffer.from("SYSBK1");
const MARCA_SEGREDO = Buffer.from("SYSSG1");
const TAM_VETOR = 12;
const TAM_ETIQUETA = 16;

/** Lê a chave (base64) e confere que tem 32 bytes. */
export function lerChave(base64: string | undefined): Buffer {
  if (!base64 || base64.trim() === "") {
    throw new Error("A chave de criptografia dos backups (BACKUP_CHAVE) não está configurada.");
  }
  const chave = Buffer.from(base64.trim(), "base64");
  if (chave.length !== 32) {
    throw new Error("A BACKUP_CHAVE é inválida: ela precisa ter 32 bytes em base64.");
  }
  return chave;
}

// Criptografa os dados e devolve: marca + vetor + etiqueta + conteúdo cifrado
function selar(marca: Buffer, dados: Buffer, chave: Buffer): Buffer {
  const vetor = randomBytes(TAM_VETOR);
  const cifra = createCipheriv("aes-256-gcm", chave, vetor);
  cifra.setAAD(marca); // a marca também é autenticada
  const cifrado = Buffer.concat([cifra.update(dados), cifra.final()]);
  return Buffer.concat([marca, vetor, cifra.getAuthTag(), cifrado]);
}

// Abre o que foi selado; qualquer falha (marca, chave ou alteração) vira uma mensagem clara
function abrir(marca: Buffer, arquivo: Buffer, chave: Buffer): Buffer {
  const minimo = marca.length + TAM_VETOR + TAM_ETIQUETA;
  if (arquivo.length < minimo || !arquivo.subarray(0, marca.length).equals(marca)) {
    throw new Error("Arquivo inválido ou de outro formato.");
  }
  const vetor = arquivo.subarray(marca.length, marca.length + TAM_VETOR);
  const etiqueta = arquivo.subarray(marca.length + TAM_VETOR, minimo);
  const cifrado = arquivo.subarray(minimo);
  try {
    const decifra = createDecipheriv("aes-256-gcm", chave, vetor);
    decifra.setAAD(marca);
    decifra.setAuthTag(etiqueta);
    return Buffer.concat([decifra.update(cifrado), decifra.final()]);
  } catch {
    throw new Error("Não foi possível abrir o arquivo: a chave está errada ou o arquivo foi alterado.");
  }
}

/** Comprime e criptografa o conteúdo de um backup. */
export function cifrarBackup(dados: Buffer, chave: Buffer): Buffer {
  return selar(MARCA_ARQUIVO, gzipSync(dados), chave);
}

/** Abre um arquivo de backup e devolve o conteúdo original. */
export function abrirBackup(arquivo: Buffer, chave: Buffer): Buffer {
  return gunzipSync(abrir(MARCA_ARQUIVO, arquivo, chave));
}

/** Criptografa um texto secreto (token, senha) para guardar no banco; devolve texto em base64. */
export function cifrarSegredo(texto: string, chave: Buffer): string {
  return selar(MARCA_SEGREDO, Buffer.from(texto, "utf8"), chave).toString("base64");
}

/** Abre um segredo guardado no banco. */
export function abrirSegredo(base64: string, chave: Buffer): string {
  return abrir(MARCA_SEGREDO, Buffer.from(base64, "base64"), chave).toString("utf8");
}

/** Impressão digital (SHA-256) para conferir a integridade de um arquivo. */
export function sha256Hex(dados: Buffer | string): string {
  return createHash("sha256").update(dados).digest("hex");
}

/** Mostra só o final de um segredo ("…abcd"): é o que volta para a tela. */
export function mascararSegredo(texto: string): string {
  const limpo = texto.trim();
  return limpo.length <= 4 ? "…" : `…${limpo.slice(-4)}`;
}
