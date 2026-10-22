/**
 * Sysmusica — Operações do Backup no servidor: fazer, listar, baixar, verificar e excluir.
 * Usa a chave secreta do Supabase (ignora as políticas de acesso): quem chama já foi autenticado pela rota.
 * O arquivo é comprimido, criptografado (BACKUP_CHAVE) e guardado no armazenamento privado "backups".
 *
 * VERIFICAÇÃO AUTOMÁTICA: logo depois de gravar, o sistema RELÊ o arquivo do armazenamento e confere
 * impressão digital, abertura com a chave e contagem de registros. O resultado fica gravado no backup e vai
 * no aviso. Se falhar, o backup é refeito UMA vez e verificado de novo; se falhar de novo, vira alerta.
 * Atenção: o backup lê as tabelas uma a uma, então não é um instantâneo exato de um único instante.
 */
import { randomUUID } from "node:crypto";
import type { SupabaseClient } from "@supabase/supabase-js";
import { abrirBackup, cifrarBackup, lerChave, sha256Hex } from "../cripto";
import {
  compararContagens,
  contarLinhas,
  descreverVerificacao,
  empacotarBackup,
  idValido,
  lerPacote,
  mensagemFalha,
  mensagemSucesso,
  mensagemVerificacaoFalhou,
  mensagemVerificacaoManual,
  nomeDoArquivoBackup,
  totalDeLinhas,
  type DadosPorTabela,
  type ResultadoVerificacao,
  type SituacaoVerificacao,
  type TipoBackup,
} from "../regras";
import { TABELAS, type DefinicaoTabela } from "../tabelas";
import type { RegistroBackup, RespostaFazerBackup } from "../tipos";
import type { UsuarioAutenticado } from "./autorizacao";
import { clienteAdmin } from "./clienteAdmin";
import { acrescentarCopia, enviarAutomatico } from "./destinos";
import { ErroBackup } from "./erros";
import { notificar } from "./notificar";

const BUCKET = "backups";
const COLUNAS =
  "id, criado_em, tipo, situacao, caminho, tamanho_bytes, sha256, contagens, criado_por, observacao, erro, destinos, " +
  "verificacao, verificado_em, verificado_por, verificacao_detalhe";
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
  verificacao: SituacaoVerificacao;
  verificado_em: string | null;
  verificado_por: string | null;
  verificacao_detalhe: string | null;
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
    verificacao: linha.verificacao,
    verificado_em: linha.verificado_em,
    verificado_por_nome: linha.verificado_por ? (nomes.get(linha.verificado_por) ?? null) : null,
    verificacao_detalhe: linha.verificacao_detalhe,
  };
}

// Nomes dos usuários que fizeram ou verificaram os backups (um nome por identificador)
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
  return data as unknown as LinhaBanco;
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

  const linhas = (data ?? []) as unknown as LinhaBanco[];
  const nomes = await nomesDosUsuarios(
    admin,
    linhas.flatMap((linha) => [linha.criado_por, linha.verificado_por])
  );
  return linhas.map((linha) => paraRegistro(linha, nomes));
}

// ---------- Verificação ----------

// Resultado de uma verificação que nem chegou a ser feita (arquivo ausente, chave indisponível...)
function semVerificacao(impedimento: string): ResultadoVerificacao {
  return {
    ok: false,
    hashConfere: false,
    abre: false,
    contagensConferem: false,
    totalRegistros: 0,
    impedimento,
  };
}

/**
 * Confere um arquivo de backup sem restaurar nada: impressão digital, abertura com a chave e contagem de
 * registros. NUNCA lança erro: qualquer problema vira um resultado "não ok" com o motivo.
 */
async function verificarArquivo(
  admin: SupabaseClient,
  linha: Pick<LinhaBanco, "caminho" | "sha256" | "contagens">
): Promise<ResultadoVerificacao> {
  if (!linha.caminho) return semVerificacao("este registro não tem arquivo");

  let chave: Buffer;
  try {
    chave = chaveDoAmbiente();
  } catch (e) {
    return semVerificacao(e instanceof Error ? e.message : "a chave não está disponível");
  }

  let arquivo: Buffer;
  try {
    arquivo = await baixarArquivo(admin, linha.caminho);
  } catch (e) {
    return semVerificacao(e instanceof Error ? e.message : "não foi possível reler o arquivo");
  }

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

// Grava no backup o resultado da verificação (usuarioId nulo = verificado pelo sistema, automaticamente)
async function gravarVerificacao(
  admin: SupabaseClient,
  id: string,
  resultado: ResultadoVerificacao,
  usuarioId: string | null
): Promise<void> {
  const { error } = await admin
    .from("backup_arquivos")
    .update({
      verificacao: resultado.ok ? "ok" : "falhou",
      verificado_em: new Date().toISOString(),
      verificado_por: usuarioId,
      verificacao_detalhe: resultado.ok ? null : descreverVerificacao(resultado).slice(0, 500),
    })
    .eq("id", id);
  if (error) console.error("Falha ao gravar a verificação do backup:", error.message);
}

// ---------- Fazer backup ----------

interface OpcoesBackup {
  tipo: TipoBackup;
  usuario: UsuarioAutenticado | null;
  observacao?: string | null;
}

// Lê, empacota, criptografa, guarda e registra. Lança erro comum se algo falhar (a cópia órfã é apagada).
async function gerarBackup(
  admin: SupabaseClient,
  opcoes: OpcoesBackup,
  quando: Date
): Promise<{ id: string; tamanhoBytes: number; contagens: Record<string, number> }> {
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

  // 4) Registra na lista de backups (se falhar, apaga o arquivo para não deixar cópia órfã)
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
    .select("id")
    .single();
  if (error || !data) {
    await admin.storage.from(BUCKET).remove([caminho]);
    throw new Error(`Não foi possível registrar o backup: ${error?.message ?? "sem detalhe"}`);
  }
  const id = (data as { id: string }).id;

  await auditar(admin, opcoes.usuario?.id ?? null, "backup_criado", id, {
    tipo: opcoes.tipo,
    tamanho_bytes: arquivo.length,
    registros: totalDeLinhas(contagens),
  });
  return { id, tamanhoBytes: arquivo.length, contagens };
}

type Tentativa =
  | {
      estado: "gerado";
      id: string;
      tamanhoBytes: number;
      contagens: Record<string, number>;
      quando: Date;
      verificacao: ResultadoVerificacao;
    }
  | { estado: "erro"; motivo: string; quando: Date };

// Uma tentativa completa: gera, verifica automaticamente e grava o resultado. Não lança erro.
async function tentarBackup(admin: SupabaseClient, opcoes: OpcoesBackup): Promise<Tentativa> {
  const quando = new Date();
  try {
    const gerado = await gerarBackup(admin, opcoes, quando);

    // Verificação automática: relê o arquivo guardado e confere tudo
    const verificacao = await verificarArquivo(admin, await buscarLinha(admin, gerado.id));
    await gravarVerificacao(admin, gerado.id, verificacao, null);
    await auditar(admin, opcoes.usuario?.id ?? null, "backup_verificado", gerado.id, {
      resultado: verificacao.ok ? "integro" : "falhou",
      automatica: true,
    });

    return { estado: "gerado", ...gerado, quando, verificacao };
  } catch (e) {
    const motivo = e instanceof Error ? e.message : "erro desconhecido";
    await admin.from("backup_arquivos").insert({
      tipo: opcoes.tipo,
      situacao: "falhou",
      erro: motivo.slice(0, 500),
      criado_por: opcoes.usuario?.id ?? null,
      observacao: opcoes.observacao ?? null,
      destinos: {},
    });
    return { estado: "erro", motivo, quando };
  }
}

/**
 * Faz um backup completo, verifica automaticamente e avisa. Se a verificação falhar, refaz UMA vez.
 * Falha na geração: avisa e devolve erro. Falha na verificação após a nova tentativa: avisa com alerta.
 */
export async function fazerBackup(opcoes: OpcoesBackup): Promise<RespostaFazerBackup> {
  const admin = clienteAdmin();
  const feitoPor = opcoes.usuario?.nome ?? null;

  const primeira = await tentarBackup(admin, opcoes);
  if (primeira.estado === "erro") {
    await notificar("falha", mensagemFalha({ tipo: opcoes.tipo, quando: primeira.quando, motivo: primeira.motivo, feitoPor }));
    throw new ErroBackup(500, `O backup falhou: ${primeira.motivo}`);
  }

  let final = primeira;
  let refeito = false;
  if (!primeira.verificacao.ok) {
    // A primeira cópia não passou na verificação: refaz uma vez
    refeito = true;
    const segunda = await tentarBackup(admin, opcoes);
    if (segunda.estado === "erro") {
      await notificar(
        "falha",
        mensagemFalha({
          tipo: opcoes.tipo,
          quando: segunda.quando,
          motivo: `a primeira cópia falhou na verificação (${descreverVerificacao(primeira.verificacao)}) e a nova tentativa não pôde ser feita: ${segunda.motivo}`,
          feitoPor,
        })
      );
      throw new ErroBackup(500, `O backup falhou na verificação e não pôde ser refeito: ${segunda.motivo}`);
    }
    final = segunda;
  }

  // Cópia automática para o servidor local: só depois de o backup passar na verificação. Nunca derruba o backup.
  const copia = final.verificacao.ok ? await enviarAutomatico(admin, final.id) : null;

  const avisos = final.verificacao.ok
    ? await notificar(
        "sucesso",
        acrescentarCopia(copia, mensagemSucesso({
          tipo: opcoes.tipo,
          quando: final.quando,
          tamanhoBytes: final.tamanhoBytes,
          totalRegistros: totalDeLinhas(final.contagens),
          totalTabelas: Object.keys(final.contagens).length,
          feitoPor,
          verificacao: final.verificacao,
          refeito,
        }))
      )
    : await notificar(
        "falha",
        mensagemVerificacaoFalhou({ tipo: opcoes.tipo, quando: final.quando, verificacao: final.verificacao, feitoPor })
      );

  const linha = await buscarLinha(admin, final.id);
  const nomes = new Map<string, string>();
  if (opcoes.usuario) nomes.set(opcoes.usuario.id, opcoes.usuario.nome);
  return { backup: paraRegistro(linha, nomes), avisos, verificacao: final.verificacao, refeito };
}

// ---------- Baixar, verificar manualmente e excluir ----------

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

/** Verificação feita por um administrador (botão): grava o resultado, registra na Auditoria e avisa. */
export async function verificarBackup(id: string, usuario: UsuarioAutenticado): Promise<ResultadoVerificacao> {
  const admin = clienteAdmin();
  const linha = await buscarLinha(admin, id);

  const resultado = await verificarArquivo(admin, linha);
  await gravarVerificacao(admin, linha.id, resultado, usuario.id);
  await auditar(admin, usuario.id, "backup_verificado", linha.id, {
    resultado: resultado.ok ? "integro" : "falhou",
    automatica: false,
  });
  await notificar(
    resultado.ok ? "sucesso" : "falha",
    mensagemVerificacaoManual({
      tipo: linha.tipo,
      criadoEm: new Date(linha.criado_em),
      quando: new Date(),
      verificacao: resultado,
      feitoPor: usuario.nome,
    })
  );
  return resultado;
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

// ---------- Verificação feita pelo sistema (agendamento) ----------

/** Verifica um backup sem usuário (conferência semanal do agendamento): grava o resultado e registra na Auditoria. */
export async function verificarPeloSistema(id: string): Promise<ResultadoVerificacao> {
  const admin = clienteAdmin();
  const linha = await buscarLinha(admin, id);
  const resultado = await verificarArquivo(admin, linha);
  await gravarVerificacao(admin, linha.id, resultado, null);
  await auditar(admin, null, "backup_verificado", linha.id, {
    resultado: resultado.ok ? "integro" : "falhou",
    automatica: true,
    semanal: true,
  });
  return resultado;
}
