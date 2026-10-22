/**
 * Sysmusica — Gera a imagem (PNG em data URL) de um QR Code, no navegador.
 * Correção de erro "M": tolera pequenas falhas de impressão ou de leitura.
 */
import { toDataURL } from "qrcode";

export function gerarImagemQr(conteudo: string): Promise<string> {
  return toDataURL(conteudo, { errorCorrectionLevel: "M", margin: 2, width: 512 });
}
