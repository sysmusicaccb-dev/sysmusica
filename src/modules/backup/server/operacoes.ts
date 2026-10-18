/**
 * SysMúsica — Operações do Backup no servidor: fazer, listar, baixar, verificar e excluir.
 * Usa a chave secreta do Supabase (ignora as políticas de acesso): quem chama já foi autenticado pela rota.
 * O arquivo é comprimido, criptografado (BACKUP_CHAVE) e guardado no armazenamento privado "backups".
 * Atenção: o backup lê as tabelas uma a uma, então não é um instantâneo exato de um único instante.
 */
import { randomUUID } from "node:crypto";
import type { SupabaseClient } from "@supabase/supabase-js";
import { abrirBackup, cifrarBackup, lerChave, sha256Hex } from "../cripto";
import {
  compararContagens,
  contarLinhas,
  empacotarBackup,
  idValido,
  lerPacote,
  mensagemFalha,
  mensagemSucesso,
  nomeDoArquivoBackup,
  totalDeLinhas,
  type DadosPorTabela,
  type ResultadoCanal,
  type ResultadoVerificacao,
  type TipoBackup,
} from "../regras";
import { TABELAS, type DefinicaoTabela } from "../tabelas";
import type { RegistroBackup, RespostaFazerBackup } from "../tipos";
import type { UsuarioAutenticado } from "./autorizacao";
import { clienteAdmin } from "./clienteAdmin";
import { ErroBackup } from "./erros";
import { notificar } from "./notificar";

const BUCKET = "backups";
const COLUNAS =
  "id, criado_em, tipo, situacao, caminho, tamanho_bytes, sha256, contagens, criado_por, observacao, erro, destinos";
const TAMANHO_PAGINA = 1000;
const LIMITE_LINHAS = 500_000; // trava de segurança por tabela

interface LinhaBanco {
  id: string;
  criado_em: string;
  tipo: TipoBackup;
  situacao: "ok" | "falhou";
  caminho: string | null;
  tamanho_bytes: number | null;
  sha256: string | null;
  contagens: Record<string, number> | null;
  criado_por: string | null;
  observacao: string | null;
  erro: string | null;
  destinos: Record<string, boolean> | null;
}

function chaveDoAmbiente(): Buffer {
  try {
    return lerChave(process.env.BACKUP_CHAVE);
  } catch (e) {
    throw new ErroBackup(500, e instanceof Error ? e.message : "A chave dos backups não está configurada.");
  }
}

function exigirId(id: string): void {
  if (!idValido(id)) throw new ErroBackup(400, "Identificador de backup inválido.");
}

function paraRegistro(linha: LinhaBanco, nomes: Map<string, string>): RegistroBackup {
  return {
    id: linha.id,
    criado_em: linha.criado_em,
    tipo: linha.tipo,
    situacao: linha.situacao,
    tamanho_bytes: linha.tamanho_bytes === null ? null : Number(linha.tamanho_bytes),
    sha256: linha.sha256,
    contagens: linha.contagens,
    criado_por: linha.criado_por,
    criado_por_nome: linha.criado_por ? (nomes.get(linha.criado_por) ?? null) : null,
    observacao: linha.observacao,
    erro: linha.erro,
    destinos: linha.destinos,
  };
}

// Nomes dos usuários que fizeram os backups (um nome por identificador)
async function nomesDosUsuarios(admin: SupabaseClient, ids: (string | null)[]): Promise<Map<string, string>> {
  const unicos = [...new Set(ids.filter((id): id is string => Boolean(id)))];
  const nomes = new Map<string, string>();
  if (unicos.length === 0) return nomes;
  const { data } = await admin.from("usuarios").select("id, nome").in("id", unicos);
  for (const usuario of (data ?? []) as { id: string; nome: string }[]) nomes.set(usuario.id, usuario.nome);
  return nomes;
}

// Registra a ação na Auditoria; uma falha aqui nunca derruba a operação
async function auditar(
  admin: SupabaseClient,
  usuarioId: string | null,
  acao: string,
  entidadeId: string | null,
  detalhes: Record<string, unknown>
): Promise<void> {
  const { error } = await admin
    .from("auditoria")
    .insert({ usuario_id: usuarioId, acao, entidade: "backup", entidade_id: entidadeId, detalhes });
  if (error) console.error("Falha ao registrar a auditoria do backup:", error.message);
}

// Lê uma tabela inteira, de mil em mil linhas, em ordem estável
async function lerTabela(admin: SupabaseClient, definicao: DefinicaoTabela): Promise<Record<string, unknown>[]> {
  const linhas: Record<string, unknown>[] = [];
  let inicio = 0;
  while (inicio < LIMITE_LINHAS) {
    let consulta = admin.from(definicao.nome).select("*");
    for (const coluna of definicao.pk) consulta = consulta.order(coluna, { ascending: true });
    const { data, error } = await consulta.range(inicio, inicio + TAMANHO_PAGINA - 1);
    if (error) throw new Error(`Não foi possível ler a tabela ${definicao.rotulo}: ${error.message}`);

    const pagina = (data ?? []) as Record<string, unknown>[];
    if (pagina.length === 0) return linhas;
    linhas.push(...pagina);
    inicio += pagina.length;
  }
  throw new Error(`A tabela ${definicao.rotulo} passou do limite de ${LIMITE_LINHAS} linhas.`);
}

async function baixarArquivo(admin: SupabaseClient, caminho: string): Promise<Buffer> {
  const { data, error } = await admin.storage.from(BUCKET).download(caminho);
  if (error || !data) throw new ErroBackup(500, "Não foi possível ler o arquivo do backup no armazenamento.");
  return Buffer.from(await data.arrayBuffer());
}

async function buscarLinha(admin: SupabaseClient, id: string): Promise<LinhaBanco> {
  exigirId(id);
  const { data, error } = await admin.from("backup_arquivos").select(COLUNAS).eq("id", id).maybeSingle();
  if (error) throw new ErroBackup(500, "Não foi possível consultar o backup.");
  if (!data) throw new ErroBackup(404, "Backup não encontrado.");
  return data as LinhaBanco;
}

/** Lista os 100 backups mais recentes. */
export async function listarBackups(): Promise<RegistroBackup[]> {
  const admin = clienteAdmin();
  const { data, error } = await admin
    .from("backup_arquivos")
    .select(COLUNAS)
    .order("criado_em", { ascending: false })
    .limit(100);
  if (error) throw new ErroBackup(500, "Não foi possível listar os backups.");

  const linhas = (data ?? []) as LinhaBanco[];
  const nomes = await nomesDosUsuarios(admin, linhas.map((linha) => linha.criado_por));
  return linhas.map((linha) => paraRegistro(linha, nomes));
}

/** Faz um backup completo (lê, empacota, criptografa, guarda, registra e avisa). */
export async function fazerBackup(opcoes: {
  tipo: TipoBackup;
  usuario: UsuarioAutenticado | null;
  observacao?: string | null;
}): Promise<RespostaFazerBackup> {
  const admin = clienteAdmin();
  const quando = new Date();
  const feitoPor = opcoes.usuario?.nome ?? null;
  let caminhoEnviado: string | null = null;

  try {
    const chave = chaveDoAmbiente();

    // 1) Lê todas as tabelas, em ordem de dependência
    const tabelas: DadosPorTabela = {};
    for (const definicao of TABELAS) tabelas[definicao.nome] = await lerTabela(admin, definicao);
    const contagens = contarLinhas(tabelas);

    // 2) Empacota, comprime e criptografa; guarda a impressão digital do arquivo final
    const arquivo = cifrarBackup(Buffer.from(empacotarBackup(tabelas, quando), "utf8"), chave);
    const sha256 = sha256Hex(arquivo);

    // 3) Guarda no armazenamento privado
    const caminho = nomeDoArquivoBackup(opcoes.tipo, quando, randomUUID());
    const envio = await admin.storage
      .from(BUCKET)
      .upload(caminho, arquivo, { contentType: "application/octet-stream", upsert: false });
    if (envio.error) throw new Error(`Não foi possível guardar o arquivo: ${envio.error.message}`);
    caminhoEnviado = caminho;

    // 4) Registra na lista de backups
    const { data, error } = await admin
      .from("backup_arquivos")
      .insert({
        tipo: opcoes.tipo,
        situacao: "ok",
        caminho,
        tamanho_bytes: arquivo.length,
        sha256,
        contagens,
        criado_por: opcoes.usuario?.id ?? null,
        observacao: opcoes.observacao ?? null,
        destinos: { sistema: true },
      })
      .select(COLUNAS)
      .single();
    if (error || !data) throw new Error(`Não foi possível registrar o backup: ${error?.message ?? "sem detalhe"}`);
    const linha = data as LinhaBanco;

    await auditar(admin, opcoes.usuario?.id ?? null, "backup_criado", linha.id, {
      tipo: opcoes.tipo,
      tamanho_bytes: arquivo.length,
      registros: totalDeLinhas(contagens),
    });

    // 5) Avisa (nunca derruba o backup)
    const avisos: ResultadoCanal[] = await notificar(
      "sucesso",
      mensagemSucesso({
        tipo: opcoes.tipo,
        quando,
        tamanhoBytes: arquivo.length,
        totalRegistros: totalDeLinhas(contagens),
        totalTabelas: Object.keys(contagens).length,
        feitoPor,
      })
    );

    const nomes = new Map<string, string>();
    if (opcoes.usuario) nomes.set(opcoes.usuario.id, opcoes.usuario.nome);
    return { backup: paraRegistro(linha, nomes), avisos };
  } catch (e) {
    const motivo = e instanceof Error ? e.message : "erro desconhecido";

    // Se o arquivo chegou a ser enviado mas o registro falhou, apaga o arquivo órfão
    if (caminhoEnviado) await admin.storage.from(BUCKET).remove([caminhoEnviado]);

    await admin.from("backup_arquivos").insert({
      tipo: opcoes.tipo,
      situacao: "falhou",
      erro: motivo.slice(0, 500),
      criado_por: opcoes.usuario?.id ?? null,
      observacao: opcoes.observacao ?? null,
      destinos: {},
    });
    await notificar("falha", mensagemFalha({ tipo: opcoes.tipo, quando, motivo, feitoPor }));

    throw new ErroBackup(500, `O backup falhou: ${motivo}`);
  }
}

/** Gera um link temporário (60 segundos) para baixar o arquivo criptografado. */
export async function urlDeDownload(id: string, usuario: UsuarioAutenticado): Promise<{ url: string }> {
  const admin = clienteAdmin();
  const linha = await buscarLinha(admin, id);
  if (!linha.caminho) throw new ErroBackup(400, "Este registro não tem arquivo para baixar.");

  const nome = linha.caminho.split("/").pop() ?? "backup.sysbk";
  const { data, error } = await admin.storage.from(BUCKET).createSignedUrl(linha.caminho, 60, { download: nome });
  if (error || !data) throw new ErroBackup(500, "Não foi possível gerar o link de download.");

  await auditar(admin, usuario.id, "backup_baixado", linha.id, { tipo: linha.tipo });
  return { url: data.signedUrl };
}

/** Confere um backup sem restaurar nada: impressão digital, abertura com a chave e contagem de registros. */
export async function verificarBackup(id: string): Promise<ResultadoVerificacao> {
  const admin = clienteAdmin();
  const linha = await buscarLinha(admin, id);
  if (!linha.caminho) throw new ErroBackup(400, "Este registro não tem arquivo para verificar.");

  const chave = chaveDoAmbiente();
  const arquivo = await baixarArquivo(admin, linha.caminho);
  const hashConfere = linha.sha256 !== null && sha256Hex(arquivo) === linha.sha256;

  let abre = false;
  let contagensConferem = false;
  let totalRegistros = 0;
  let detalhe: string | undefined;
  try {
    const pacote = lerPacote(abrirBackup(arquivo, chave).toString("utf8"));
    const lidas = contarLinhas(pacote.tabelas);
    abre = true;
    totalRegistros = totalDeLinhas(lidas);
    contagensConferem = compararContagens(lidas, linha.contagens);
  } catch (e) {
    detalhe = e instanceof Error ? e.message : "erro desconhecido";
  }

  return { ok: hashConfere && abre && contagensConferem, hashConfere, abre, contagensConferem, totalRegistros, detalhe };
}

/** Exclui o arquivo e o registro de um backup (a Auditoria guarda que foi excluído). */
export async function excluirBackup(id: string, usuario: UsuarioAutenticado): Promise<{ ok: true }> {
  const admin = clienteAdmin();
  const linha = await buscarLinha(admin, id);

  if (linha.caminho) {
    const { error } = await admin.storage.from(BUCKET).remove([linha.caminho]);
    if (error) throw new ErroBackup(500, "Não foi possível apagar o arquivo do armazenamento.");
  }
  const { error } = await admin.from("backup_arquivos").delete().eq("id", id);
  if (error) throw new ErroBackup(500, "Não foi possível excluir o registro do backup.");

  await auditar(admin, usuario.id, "backup_excluido", linha.id, { tipo: linha.tipo, criado_em: linha.criado_em });
  return { ok: true };
}
