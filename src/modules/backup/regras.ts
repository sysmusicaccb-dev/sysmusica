/**
 * SysMúsica — Regras puras do Backup (sem banco, rede ou criptografia): formato do arquivo, nomes, textos
 * dos avisos e validações. Roda no servidor e no navegador. Testadas em regras.test.ts.
 */

export const VERSAO_FORMATO = 1;
const NOME_FORMATO = "sysmusica-backup";

export type TipoBackup = "manual" | "seguranca" | "diario" | "semanal" | "quinzenal" | "mensal";

export const ROTULO_TIPO: Record<TipoBackup, string> = {
  manual: "Manual",
  seguranca: "Segurança (antes de restaurar)",
  diario: "Diário",
  semanal: "Semanal",
  quinzenal: "Quinzenal",
  mensal: "Mensal",
};

export type DadosPorTabela = Record<string, Record<string, unknown>[]>;

export interface PacoteBackup {
  formato: string;
  versao: number;
  criado_em: string;
  tabelas: DadosPorTabela;
}

/** Resultado do envio de um aviso por canal (Telegram, e-mail ou erro geral). */
export interface ResultadoCanal {
  canal: "telegram" | "email" | "geral";
  estado: "enviado" | "desligado" | "erro";
  detalhe?: string;
}

/** Resultado da verificação de um arquivo de backup (sem restaurar nada). */
export interface ResultadoVerificacao {
  ok: boolean;
  hashConfere: boolean;
  abre: boolean;
  contagensConferem: boolean;
  totalRegistros: number;
  detalhe?: string;
}

// ---------- Conteúdo do arquivo ----------

/** Monta o texto (JSON) que será comprimido e criptografado. */
export function empacotarBackup(tabelas: DadosPorTabela, criadoEm: Date): string {
  const pacote: PacoteBackup = {
    formato: NOME_FORMATO,
    versao: VERSAO_FORMATO,
    criado_em: criadoEm.toISOString(),
    tabelas,
  };
  return JSON.stringify(pacote);
}

/** Lê e confere o conteúdo de um backup já aberto; qualquer problema vira uma mensagem clara. */
export function lerPacote(texto: string): PacoteBackup {
  let valor: unknown;
  try {
    valor = JSON.parse(texto);
  } catch {
    throw new Error("O conteúdo do backup está corrompido.");
  }
  if (valor === null || typeof valor !== "object" || Array.isArray(valor)) {
    throw new Error("O conteúdo do backup está corrompido.");
  }

  const pacote = valor as Record<string, unknown>;
  if (pacote.formato !== NOME_FORMATO) throw new Error("Este arquivo não é um backup do SysMúsica.");
  if (typeof pacote.versao !== "number" || pacote.versao > VERSAO_FORMATO) {
    throw new Error("Este backup foi feito por uma versão mais nova do sistema.");
  }
  if (typeof pacote.criado_em !== "string") throw new Error("O conteúdo do backup está corrompido.");

  const tabelas = pacote.tabelas;
  if (tabelas === null || typeof tabelas !== "object" || Array.isArray(tabelas)) {
    throw new Error("O conteúdo do backup está corrompido.");
  }
  for (const [nome, linhas] of Object.entries(tabelas as Record<string, unknown>)) {
    if (!Array.isArray(linhas)) throw new Error(`A tabela ${nome} do backup está corrompida.`);
  }

  return {
    formato: pacote.formato,
    versao: pacote.versao,
    criado_em: pacote.criado_em,
    tabelas: tabelas as DadosPorTabela,
  };
}

/** Quantas linhas há em cada tabela. */
export function contarLinhas(tabelas: DadosPorTabela): Record<string, number> {
  return Object.fromEntries(Object.entries(tabelas).map(([nome, linhas]) => [nome, linhas.length]));
}

export function totalDeLinhas(contagens: Record<string, number> | null | undefined): number {
  return Object.values(contagens ?? {}).reduce((soma, quantidade) => soma + quantidade, 0);
}

/** As contagens guardadas e as do arquivo aberto são exatamente iguais? */
export function compararContagens(
  lidas: Record<string, number>,
  guardadas: Record<string, number> | null | undefined
): boolean {
  if (!guardadas) return false;
  const nomes = new Set([...Object.keys(lidas), ...Object.keys(guardadas)]);
  for (const nome of nomes) {
    if (lidas[nome] !== guardadas[nome]) return false;
  }
  return true;
}

// ---------- Nomes e formatos ----------

/** Caminho do arquivo no armazenamento: ano/mês/backup-AAAAMMDD-HHMMSS-tipo-sufixo.sysbk (hora UTC). */
export function nomeDoArquivoBackup(tipo: TipoBackup, agora: Date, sufixo: string): string {
  const dois = (n: number) => String(n).padStart(2, "0");
  const ano = agora.getUTCFullYear();
  const mes = dois(agora.getUTCMonth() + 1);
  const marca = `${ano}${mes}${dois(agora.getUTCDate())}-${dois(agora.getUTCHours())}${dois(agora.getUTCMinutes())}${dois(agora.getUTCSeconds())}`;
  const limpo = sufixo.toLowerCase().replace(/[^a-z0-9]/g, "").slice(0, 8) || "x";
  return `${ano}/${mes}/backup-${marca}-${tipo}-${limpo}.sysbk`;
}

/** "1,5 KB", "2,5 MB". */
export function formatarTamanho(bytes: number | null | undefined): string {
  if (bytes === null || bytes === undefined) return "—";
  if (bytes < 1024) return `${bytes} B`;
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1).replace(".", ",")} KB`;
  return `${(bytes / (1024 * 1024)).toFixed(1).replace(".", ",")} MB`;
}

/** Data e hora no fuso de Salvador: "18/10/2026 12:30". */
export function dataHoraSalvador(data: Date): string {
  return new Intl.DateTimeFormat("pt-BR", {
    timeZone: "America/Sao_Paulo",
    day: "2-digit",
    month: "2-digit",
    year: "numeric",
    hour: "2-digit",
    minute: "2-digit",
  })
    .format(data)
    .replace(", ", " ");
}

// ---------- Textos dos avisos (nunca trazem nome de membro, CPF ou foto) ----------

export interface DadosAviso {
  tipo: TipoBackup;
  quando: Date;
  tamanhoBytes?: number;
  totalRegistros?: number;
  totalTabelas?: number;
  feitoPor?: string | null;
  motivo?: string;
}

export function mensagemSucesso(dados: DadosAviso): { assunto: string; texto: string } {
  const linhas = [
    "Backup concluído com sucesso.",
    `Tipo: ${ROTULO_TIPO[dados.tipo]}`,
    `Data: ${dataHoraSalvador(dados.quando)}`,
    `Tamanho: ${formatarTamanho(dados.tamanhoBytes)}`,
    `Registros: ${(dados.totalRegistros ?? 0).toLocaleString("pt-BR")} em ${dados.totalTabelas ?? 0} tabelas`,
    "Guardado em: sistema (criptografado)",
    `Feito por: ${dados.feitoPor?.trim() || "sistema"}`,
  ];
  return { assunto: "SysMúsica: backup concluído", texto: linhas.join("\n") };
}

export function mensagemFalha(dados: DadosAviso): { assunto: string; texto: string } {
  const linhas = [
    "O backup FALHOU.",
    `Tipo: ${ROTULO_TIPO[dados.tipo]}`,
    `Data: ${dataHoraSalvador(dados.quando)}`,
    `Motivo: ${(dados.motivo ?? "não informado").slice(0, 300)}`,
    `Tentativa de: ${dados.feitoPor?.trim() || "sistema"}`,
  ];
  return { assunto: "SysMúsica: o backup falhou", texto: linhas.join("\n") };
}

const ROTULO_CANAL: Record<ResultadoCanal["canal"], string> = {
  telegram: "Telegram",
  email: "E-mail",
  geral: "Avisos",
};

/** Resumo dos avisos enviados, para mostrar na tela. */
export function descreverAvisos(avisos: ResultadoCanal[]): string {
  if (avisos.length === 0) return "Nenhum aviso foi enviado (avisos desligados ou não configurados).";
  return avisos
    .map((aviso) => {
      const situacao =
        aviso.estado === "erro" ? `erro (${aviso.detalhe ?? "sem detalhe"})` : aviso.estado;
      return `${ROTULO_CANAL[aviso.canal]}: ${situacao}`;
    })
    .join(" · ");
}

/** Resumo da verificação de um backup, para mostrar na tela. */
export function descreverVerificacao(resultado: ResultadoVerificacao): string {
  if (resultado.ok) {
    return `Backup íntegro: a impressão digital confere, o arquivo abre e os ${resultado.totalRegistros.toLocaleString("pt-BR")} registros batem com o que foi gravado.`;
  }
  const problemas: string[] = [];
  if (!resultado.hashConfere) problemas.push("a impressão digital do arquivo é diferente da gravada");
  if (!resultado.abre) problemas.push(`o arquivo não abre${resultado.detalhe ? ` (${resultado.detalhe})` : ""}`);
  else if (!resultado.contagensConferem) problemas.push("a quantidade de registros não bate com a gravada");
  return `Problema na verificação: ${problemas.join("; ")}.`;
}

// ---------- Validações ----------

/** Confere o formato de um endereço de e-mail (não garante que a caixa existe). */
export function emailValido(texto: string): boolean {
  const limpo = texto.trim();
  return limpo.length <= 254 && /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(limpo);
}

export interface ConfigSmtp {
  host: string;
  porta: number;
  seguro: boolean;
  usuario: string;
  senha: string;
  remetente: string;
}

export interface ConfigResend {
  chave: string;
  remetente: string;
}

const texto = (valor: unknown): string => (typeof valor === "string" ? valor.trim() : "");

/** Lê a configuração de SMTP guardada (já aberta); nulo se estiver incompleta. */
export function lerConfigSmtp(valor: unknown): ConfigSmtp | null {
  if (valor === null || typeof valor !== "object") return null;
  const bruto = valor as Record<string, unknown>;
  const porta = Number(bruto.porta);
  const host = texto(bruto.host);
  const remetente = texto(bruto.remetente);
  if (!host || !Number.isInteger(porta) || porta < 1 || porta > 65535 || !remetente.includes("@")) return null;
  return {
    host,
    porta,
    seguro: bruto.seguro === true,
    usuario: texto(bruto.usuario),
    senha: typeof bruto.senha === "string" ? bruto.senha : "",
    remetente,
  };
}

/** Lê a configuração do Resend guardada (já aberta); nulo se estiver incompleta. */
export function lerConfigResend(valor: unknown): ConfigResend | null {
  if (valor === null || typeof valor !== "object") return null;
  const bruto = valor as Record<string, unknown>;
  const chave = texto(bruto.chave);
  const remetente = texto(bruto.remetente);
  if (!chave || !remetente.includes("@")) return null;
  return { chave, remetente };
}

/** Pega o token do cabeçalho "Authorization: Bearer ...". */
export function extrairToken(cabecalho: string | null | undefined): string | null {
  const achado = /^Bearer\s+(\S+)$/i.exec((cabecalho ?? "").trim());
  return achado ? achado[1] : null;
}

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export function idValido(valor: string): boolean {
  return UUID.test(valor);
}

/** Todos os grupos de um usuário: o principal mais os extras, sem repetir e sem vazios. */
export function gruposEfetivos(principal: string | null | undefined, extras: string[]): string[] {
  return [...new Set([principal ?? "", ...extras].filter((grupo) => grupo !== ""))];
}
