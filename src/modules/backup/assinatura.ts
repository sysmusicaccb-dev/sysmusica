/**
 * SysMúsica — Assinatura dos envios ao servidor local (só roda no SERVIDOR do sistema).
 * O receptor do Windows Server confere esta mesma conta: HMAC-SHA256, chave = texto da chave de assinatura (UTF-8),
 * mensagem = "timestamp \n nome-do-arquivo \n sha256". Quem não tem a chave não consegue enviar nem repetir um envio
 * antigo (o receptor aceita no máximo 5 minutos de diferença no relógio e nunca sobrescreve um arquivo).
 */
import { createHmac } from "node:crypto";

export function assinarEnvio(chaveAssinatura: string, timestamp: string, nome: string, sha256: string): string {
  return createHmac("sha256", Buffer.from(chaveAssinatura, "utf8"))
    .update(`${timestamp}\n${nome}\n${sha256}`, "utf8")
    .digest("hex");
}
