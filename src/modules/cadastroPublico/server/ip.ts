/**
 * SysMúsica — IP de quem chamou e o "hash" dele (SEM server-only: é função pura e testada em ip.test.ts).
 *
 * O IP nunca é guardado puro: o banco recebe só o hash (sha256 com um sal secreto), usado apenas para limitar
 * quantos envios saem de um mesmo lugar por hora. Na Vercel, o primeiro item de x-forwarded-for é o IP real
 * (a Vercel sobrescreve o cabeçalho, então quem chama não consegue forjá-lo).
 */
import { createHash } from "node:crypto";

export function extrairIp(cabecalhos: Headers): string | null {
  const encaminhado = cabecalhos.get("x-forwarded-for");
  const primeiro = encaminhado?.split(",")[0]?.trim();
  const ip = primeiro || cabecalhos.get("x-real-ip")?.trim() || "";
  return ip !== "" && ip.length <= 64 ? ip : null;
}

/** sha256(ip + ":" + sal). O sal é CADASTRO_PUBLICO_SALT ou, na falta dela, a chave de serviço (já secreta). */
export function hashDoIp(ip: string | null, sal: string): string | null {
  if (!ip || !sal) return null;
  return createHash("sha256").update(`${ip}:${sal}`).digest("hex");
}
