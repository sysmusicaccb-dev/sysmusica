/**
 * SysMúsica — Destinos do Backup: regras puras (sem acesso a banco nem a rede), compartilhadas entre a tela e o
 * servidor. Hoje existe um destino: o "Servidor local", um receptor que roda no Windows Server da casa do
 * administrador e é alcançado por um túnel da Cloudflare (sem porta aberta no roteador). O OneDrive desse servidor
 * sincroniza a pasta de destino; o sistema NÃO enxerga o OneDrive, só confirma que o servidor recebeu o arquivo.
 */

export type TipoDestino = "servidor_local";

/** Como o destino volta para a tela: segredos só aparecem mascarados ("…abcd"). */
export interface DestinoPublico {
  tipo: TipoDestino;
  configurado: boolean; // endereço, Client ID, Client Secret e chave de assinatura preenchidos
  ativo: boolean; // envio automático depois de cada backup verificado
  endereco: string;
  client_id_final: string;
  client_secret_final: string;
  chave_final: string;
  ultimo_envio_em: string | null;
  ultimo_envio_situacao: "ok" | "falhou" | null;
  ultimo_envio_detalhe: string | null;
  aviso_segredos: string | null; // preenchido quando os segredos salvos não abrem com a BACKUP_CHAVE atual
}

/** O que a tela envia ao salvar. Campo de segredo em branco = manter o valor salvo. */
export interface EntradaDestino {
  ativo: boolean;
  endereco: string;
  client_id: string;
  client_secret: string;
  chave_assinatura: string;
}

/** Quais segredos já existem salvos (para aceitar campo em branco). */
export interface SegredosSalvos {
  clientId: boolean;
  clientSecret: boolean;
  assinatura: boolean;
}

export interface ResultadoCopia {
  estado: "enviado" | "ja_existia" | "erro" | "desligado";
  detalhe?: string;
}

export const MIN_SEGREDO = 16;

export function formularioInicialDestino(destino: DestinoPublico): EntradaDestino {
  return { ativo: destino.ativo, endereco: destino.endereco, client_id: "", client_secret: "", chave_assinatura: "" };
}

/** Tira espaços e barras do final: "https://x.com.br/ " vira "https://x.com.br". */
export function normalizarEndereco(texto: string): string {
  return texto.trim().replace(/\/+$/, "");
}

/** Só aceita https com domínio (sem usuário, senha, caminho, parâmetros ou âncora). */
export function enderecoValido(texto: string): boolean {
  let url: URL;
  try {
    url = new URL(texto);
  } catch {
    return false;
  }
  return (
    url.protocol === "https:" &&
    url.hostname.includes(".") &&
    url.username === "" &&
    url.password === "" &&
    url.search === "" &&
    url.hash === "" &&
    url.pathname === "/"
  );
}

/** Devolve a mensagem de erro (para a tela) ou null se a entrada está boa. */
export function validarEntradaDestino(entrada: EntradaDestino, salvos: SegredosSalvos): string | null {
  const endereco = normalizarEndereco(entrada.endereco);
  const clientId = entrada.client_id.trim();
  const segredo = entrada.client_secret.trim();
  const assinatura = entrada.chave_assinatura.trim();

  if (endereco !== "" && !enderecoValido(endereco)) {
    return "O endereço precisa começar com https:// e ter só o domínio, por exemplo https://bkp.seudominio.com.br";
  }
  if (clientId !== "" && clientId.length < 8) {
    return "O Client ID parece curto demais. Copie-o inteiro do painel da Cloudflare.";
  }
  if (segredo !== "" && segredo.length < MIN_SEGREDO) {
    return "O Client Secret parece curto demais. Copie-o inteiro (ele só aparece uma vez no painel da Cloudflare).";
  }
  if (assinatura !== "" && assinatura.length < MIN_SEGREDO) {
    return `A chave de assinatura precisa ter pelo menos ${MIN_SEGREDO} caracteres. Copie-a inteira do arquivo segredo.txt do servidor.`;
  }

  if (entrada.ativo) {
    if (endereco === "") return "Informe o endereço do servidor para ligar o envio automático.";
    if (clientId === "" && !salvos.clientId) return "Informe o Client ID para ligar o envio automático.";
    if (segredo === "" && !salvos.clientSecret) return "Informe o Client Secret para ligar o envio automático.";
    if (assinatura === "" && !salvos.assinatura) return "Informe a chave de assinatura para ligar o envio automático.";
  }
  return null;
}

/** Lê o corpo recebido pela rota; devolve null se o formato estiver errado. */
export function lerEntradaDestino(valor: unknown): EntradaDestino | null {
  if (valor === null || typeof valor !== "object" || Array.isArray(valor)) return null;
  const o = valor as Record<string, unknown>;
  const texto = (campo: unknown, max: number): string | null =>
    typeof campo === "string" && campo.length <= max ? campo : null;

  const endereco = texto(o.endereco, 300);
  const clientId = texto(o.client_id, 300);
  const clientSecret = texto(o.client_secret, 600);
  const assinatura = texto(o.chave_assinatura, 600);
  if (typeof o.ativo !== "boolean" || endereco === null || clientId === null || clientSecret === null || assinatura === null) {
    return null;
  }
  return { ativo: o.ativo, endereco, client_id: clientId, client_secret: clientSecret, chave_assinatura: assinatura };
}

/** Padrão que o receptor do servidor aceita para o nome do arquivo. */
export const NOME_REMOTO_VALIDO = /^[A-Za-z0-9][A-Za-z0-9._-]{0,119}$/;

/** Nome do arquivo no servidor: só o final do caminho, com caracteres seguros (o sufixo único é preservado). */
export function nomeRemoto(caminho: string): string {
  const base = (caminho.split("/").pop() ?? "").replace(/[^A-Za-z0-9._-]/g, "-");
  const nome = (base.length > 120 ? base.slice(-120) : base).replace(/^[^A-Za-z0-9]+/, "");
  return nome === "" ? "backup.sysbk" : nome;
}

/** Linha que entra no aviso de sucesso do backup (nulo = destino desligado, nada a dizer). */
export function linhaDoAviso(resultado: ResultadoCopia): string | null {
  switch (resultado.estado) {
    case "enviado":
      return "Cópia no servidor local: enviada e conferida (a impressão digital confere). A sincronização com o OneDrive é feita pelo próprio servidor.";
    case "ja_existia":
      return "Cópia no servidor local: o arquivo já estava lá.";
    case "erro":
      return `Cópia no servidor local: FALHOU (${resultado.detalhe ?? "motivo desconhecido"}). O backup continua válido no sistema.`;
    default:
      return null;
  }
}
