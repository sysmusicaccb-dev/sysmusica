/**
 * SysMúsica — Conteúdo do QR Code do membro.
 *
 * O QR Code carrega SÓ um código aleatório (sem nome, CPF ou outro dado pessoal), com um prefixo
 * versionado para o leitor reconhecer o que é do SysMúsica. Quem lê o código sempre consulta
 * o servidor, que valida o cadastro e aplica as permissões.
 */
const PREFIXO = "SYSMUSICA:1:";
const REGEX_UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;

/** Texto gravado dentro do QR Code. */
export function montarConteudoQr(codigo: string): string {
  return `${PREFIXO}${codigo}`;
}

/** Extrai o código de um texto lido (câmera ou digitação). Devolve null se não for um QR do SysMúsica. */
export function lerConteudoQr(texto: string): string | null {
  const limpo = texto.trim();
  if (!limpo.toUpperCase().startsWith(PREFIXO)) return null;

  const codigo = limpo.slice(PREFIXO.length).trim().toLowerCase();
  return REGEX_UUID.test(codigo) ? codigo : null;
}
