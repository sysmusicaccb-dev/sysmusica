/**
 * Sysmusica — Destino "Servidor local" do Backup, no servidor do sistema: salvar a configuração, testar a conexão e
 * enviar o arquivo (já criptografado) pelo túnel da Cloudflare até o receptor do Windows Server.
 *
 * SEGURANÇA, em três camadas:
 *  1) Cloudflare Access: só quem tem o token de serviço (Client ID + Client Secret) chega ao receptor.
 *  2) Assinatura HMAC com horário (assinatura.ts): sem a chave de assinatura, o receptor recusa e não aceita repetição.
 *  3) O arquivo já viaja criptografado com a BACKUP_CHAVE e o receptor devolve o SHA-256, que o sistema confere.
 * Client ID, Client Secret e chave de assinatura ficam criptografados no banco (BACKUP_CHAVE) e nunca voltam inteiros
 * para a tela. Nada aqui derruba o backup: uma falha na cópia vira aviso, e o backup continua válido no sistema.
 */
import type { SupabaseClient } from "@supabase/supabase-js";
import { assinarEnvio } from "../assinatura";
import { abrirSegredo, cifrarSegredo, lerChave, mascararSegredo, sha256Hex } from "../cripto";
import {
  linhaDoAviso,
  nomeRemoto,
  normalizarEndereco,
  validarEntradaDestino,
  type DestinoPublico,
  type EntradaDestino,
  type ResultadoCopia,
  type TipoDestino,
} from "../destinos";
import { dataHoraSalvador } from "../regras";
import type { UsuarioAutenticado } from "./autorizacao";
import { clienteAdmin } from "./clienteAdmin";
import { ErroBackup } from "./erros";
import { notificar } from "./notificar";

const BUCKET = "backups";
const TIPO: TipoDestino = "servidor_local";
const COLUNAS = "ativo, endereco, config_cifrado, ultimo_envio_em, ultimo_envio_situacao, ultimo_envio_detalhe";

interface LinhaDestino {
  ativo: boolean;
  endereco: string | null;
  config_cifrado: string | null;
  ultimo_envio_em: string | null;
  ultimo_envio_situacao: "ok" | "falhou" | null;
  ultimo_envio_detalhe: string | null;
}

// Segredos já abertos. "assinatura" é a chave de assinatura (não confundir com a BACKUP_CHAVE).
interface Segredos {
  client_id: string;
  client_secret: string;
  assinatura: string;
  ilegivel: boolean; // os dados salvos não abriram com a BACKUP_CHAVE atual
}

interface ConfigDestino {
  endereco: string;
  clientId: string;
  clientSecret: string;
  assinatura: string;
}

function chaveDoAmbiente(): Buffer {
  try {
    return lerChave(process.env.BACKUP_CHAVE);
  } catch (e) {
    throw new ErroBackup(500, e instanceof Error ? e.message : "A chave dos backups não está configurada.");
  }
}

const texto = (valor: unknown): string => (typeof valor === "string" ? valor : "");

// Mensagem de erro sem nenhum segredo dentro
function mensagemSegura(erro: unknown, segredos: string[]): string {
  let mensagem = erro instanceof Error ? erro.message : "erro desconhecido";
  for (const segredo of segredos) {
    if (segredo.length >= 4) mensagem = mensagem.split(segredo).join("***");
  }
  return mensagem.slice(0, 300);
}

async function lerLinha(admin: SupabaseClient): Promise<LinhaDestino | null> {
  const { data, error } = await admin.from("backup_destinos").select(COLUNAS).eq("tipo", TIPO).maybeSingle();
  if (error) throw new ErroBackup(500, "Não foi possível ler a configuração do destino. A migração 0022 foi aplicada?");
  return (data as unknown as LinhaDestino | null) ?? null;
}

function lerSegredos(linha: LinhaDestino | null, chave: Buffer): Segredos {
  const vazio: Segredos = { client_id: "", client_secret: "", assinatura: "", ilegivel: false };
  if (!linha?.config_cifrado) return vazio;
  try {
    const bruto: unknown = JSON.parse(abrirSegredo(linha.config_cifrado, chave));
    if (bruto === null || typeof bruto !== "object" || Array.isArray(bruto)) return { ...vazio, ilegivel: true };
    const o = bruto as Record<string, unknown>;
    return { client_id: texto(o.client_id), client_secret: texto(o.client_secret), assinatura: texto(o.assinatura), ilegivel: false };
  } catch {
    return { ...vazio, ilegivel: true };
  }
}

// Configuração completa e pronta para usar (nulo = incompleta ou ilegível)
function configCompleta(linha: LinhaDestino | null, segredos: Segredos): ConfigDestino | null {
  if (!linha?.endereco || !segredos.client_id || !segredos.client_secret || !segredos.assinatura) return null;
  return { endereco: linha.endereco, clientId: segredos.client_id, clientSecret: segredos.client_secret, assinatura: segredos.assinatura };
}

// Registra na Auditoria; uma falha aqui nunca derruba a operação
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
  if (error) console.error("Falha ao registrar a auditoria do destino do backup:", error.message);
}

// ---------- Ler e salvar ----------

export async function lerDestinoPublico(): Promise<DestinoPublico> {
  const admin = clienteAdmin();
  const linha = await lerLinha(admin);
  const segredos = lerSegredos(linha, chaveDoAmbiente());
  return {
    tipo: TIPO,
    configurado: configCompleta(linha, segredos) !== null,
    ativo: linha?.ativo ?? false,
    endereco: linha?.endereco ?? "",
    client_id_final: segredos.client_id ? mascararSegredo(segredos.client_id) : "",
    client_secret_final: segredos.client_secret ? mascararSegredo(segredos.client_secret) : "",
    chave_final: segredos.assinatura ? mascararSegredo(segredos.assinatura) : "",
    ultimo_envio_em: linha?.ultimo_envio_em ?? null,
    ultimo_envio_situacao: linha?.ultimo_envio_situacao ?? null,
    ultimo_envio_detalhe: linha?.ultimo_envio_detalhe ?? null,
    aviso_segredos: segredos.ilegivel
      ? "Os dados salvos deste destino não abrem com a BACKUP_CHAVE atual. Preencha os três campos secretos de novo e salve."
      : null,
  };
}

export async function salvarDestino(entrada: EntradaDestino, usuario: UsuarioAutenticado): Promise<DestinoPublico> {
  const admin = clienteAdmin();
  const chave = chaveDoAmbiente();
  const linha = await lerLinha(admin);
  const atuais = lerSegredos(linha, chave);

  const erro = validarEntradaDestino(entrada, {
    clientId: atuais.client_id !== "",
    clientSecret: atuais.client_secret !== "",
    assinatura: atuais.assinatura !== "",
  });
  if (erro) throw new ErroBackup(400, erro);

  const endereco = normalizarEndereco(entrada.endereco);
  const novos = {
    client_id: entrada.client_id.trim() || atuais.client_id,
    client_secret: entrada.client_secret.trim() || atuais.client_secret,
    assinatura: entrada.chave_assinatura.trim() || atuais.assinatura,
  };

  // Só os NOMES dos campos que mudaram vão para a Auditoria (nunca os valores)
  const alterados: string[] = [];
  if (entrada.ativo !== (linha?.ativo ?? false)) alterados.push("envio_automatico");
  if (endereco !== (linha?.endereco ?? "")) alterados.push("endereco");
  if (entrada.client_id.trim() !== "") alterados.push("client_id");
  if (entrada.client_secret.trim() !== "") alterados.push("client_secret");
  if (entrada.chave_assinatura.trim() !== "") alterados.push("chave_assinatura");

  const { error } = await admin.from("backup_destinos").upsert(
    {
      tipo: TIPO,
      ativo: entrada.ativo,
      endereco: endereco === "" ? null : endereco,
      config_cifrado: cifrarSegredo(JSON.stringify(novos), chave),
      atualizado_em: new Date().toISOString(),
      atualizado_por: usuario.id,
    },
    { onConflict: "tipo" }
  );
  if (error) throw new ErroBackup(500, "Não foi possível salvar o destino do backup.");

  if (alterados.length > 0) await auditar(admin, usuario.id, "backup_destino_alterado", null, { destino: TIPO, alterados });
  return lerDestinoPublico();
}

// ---------- Conversa com o receptor ----------

interface RespostaServidor {
  status: number;
  ok: boolean;
  json: Record<string, unknown> | null;
}

async function chamar(
  config: ConfigDestino,
  metodo: "GET" | "PUT",
  caminho: string,
  opcoes: { headers?: Record<string, string>; corpo?: BodyInit; limiteMs: number }
): Promise<RespostaServidor> {
  let resposta: Response;
  try {
    resposta = await fetch(`${config.endereco}${caminho}`, {
      method: metodo,
      headers: {
        "CF-Access-Client-Id": config.clientId,
        "CF-Access-Client-Secret": config.clientSecret,
        ...opcoes.headers,
      },
      body: opcoes.corpo,
      redirect: "manual", // um redirecionamento é a Cloudflare pedindo login: tratamos como acesso recusado
      cache: "no-store",
      signal: AbortSignal.timeout(opcoes.limiteMs),
    });
  } catch (e) {
    throw new Error(
      `não foi possível falar com o servidor (${mensagemSegura(e, [config.clientId, config.clientSecret, config.assinatura])})`
    );
  }
  const tipo = resposta.headers.get("content-type") ?? "";
  const json = tipo.includes("json") ? ((await resposta.json().catch(() => null)) as Record<string, unknown> | null) : null;
  return { status: resposta.status, ok: resposta.ok, json };
}

// Traduz a resposta de erro em uma frase que o administrador entende
function explicar(resposta: RespostaServidor): string {
  const erro = typeof resposta.json?.erro === "string" ? resposta.json.erro : null;
  if (erro === "assinatura") {
    return "o servidor recusou a assinatura: a chave de assinatura salva aqui é diferente da que está no arquivo segredo.txt do servidor";
  }
  if (erro === "timestamp") return "o relógio do servidor está diferente do relógio do sistema (mais de 5 minutos de diferença)";
  if (erro === "sha256 diferente") return "o arquivo chegou diferente do enviado (conexão instável); tente de novo";
  if (erro) return `o servidor respondeu: ${erro}`;
  if (resposta.status === 302 || resposta.status === 401 || resposta.status === 403) {
    return "a Cloudflare recusou o acesso: confira o Client ID, o Client Secret e se a política do aplicativo aceita o token de serviço";
  }
  if ([502, 503, 504, 530].includes(resposta.status)) {
    return "o túnel ou o receptor não está respondendo (servidor desligado, túnel desconectado ou receptor parado)";
  }
  if (resposta.status === 413) return "o arquivo é grande demais para passar pelo túnel";
  return `resposta inesperada do servidor (código ${resposta.status})`;
}

// Envia um arquivo assinado e confere a impressão digital devolvida
async function enviarArquivo(config: ConfigDestino, nome: string, dados: Buffer, sha256: string): Promise<"enviado" | "ja_existia"> {
  const horario = String(Math.floor(Date.now() / 1000));
  const resposta = await chamar(config, "PUT", `/backup/${encodeURIComponent(nome)}`, {
    headers: {
      "Content-Type": "application/octet-stream",
      "X-Sys-Timestamp": horario,
      "X-Sys-Sha256": sha256,
      "X-Sys-Assinatura": assinarEnvio(config.assinatura, horario, nome, sha256),
    },
    corpo: new Uint8Array(dados),
    limiteMs: 40_000,
  });

  if (resposta.status === 409) return "ja_existia"; // o receptor nunca sobrescreve
  if (!resposta.ok || resposta.json?.ok !== true) throw new Error(explicar(resposta));
  if (resposta.json.sha256 !== sha256 || Number(resposta.json.bytes) !== dados.length) {
    throw new Error("o servidor confirmou um arquivo diferente do enviado (a impressão digital não confere)");
  }
  return "enviado";
}

// ---------- Testar ----------

/** Testa a configuração JÁ SALVA: alcança o receptor e envia um arquivo pequeno de teste, assinado. */
export async function testarDestino(usuario: UsuarioAutenticado): Promise<{ detalhe: string }> {
  const admin = clienteAdmin();
  const linha = await lerLinha(admin);
  const config = configCompleta(linha, lerSegredos(linha, chaveDoAmbiente()));
  if (!config) throw new ErroBackup(400, "Salve o endereço, o Client ID, o Client Secret e a chave de assinatura antes de testar.");
  const segredos = [config.clientId, config.clientSecret, config.assinatura];

  try {
    const saude = await chamar(config, "GET", "/saude", { limiteMs: 15_000 });
    if (!saude.ok || saude.json?.ok !== true) throw new Error(explicar(saude));

    const nome = `teste-conexao-${Math.floor(Date.now() / 1000)}.txt`;
    const conteudo = Buffer.from(`Teste de conexão do Sysmusica em ${dataHoraSalvador(new Date())}\n`, "utf8");
    await enviarArquivo(config, nome, conteudo, sha256Hex(conteudo));
    await auditar(admin, usuario.id, "backup_destino_testado", null, { destino: TIPO, resultado: "ok" });
    return {
      detalhe: `Conexão confirmada: o servidor aceitou e gravou o arquivo de teste ${nome}. Você pode apagá-lo da pasta BACKUPS.`,
    };
  } catch (e) {
    await auditar(admin, usuario.id, "backup_destino_testado", null, { destino: TIPO, resultado: "falhou" });
    throw new ErroBackup(502, `O teste falhou: ${mensagemSegura(e, segredos)}`);
  }
}

// ---------- Copiar um backup ----------

// Copia um backup para o servidor, grava o resultado (backup, destino e Auditoria) e avisa se falhar. Nunca lança erro.
async function executarCopia(
  admin: SupabaseClient,
  id: string,
  usuarioId: string | null,
  origem: "automatico" | "manual",
  config: ConfigDestino
): Promise<ResultadoCopia> {
  let resultado: ResultadoCopia;
  let destinosAtuais: Record<string, boolean> | null = null;
  try {
    const { data } = await admin.from("backup_arquivos").select("situacao, caminho, sha256, destinos").eq("id", id).maybeSingle();
    const linha = data as { situacao: string; caminho: string | null; sha256: string | null; destinos: Record<string, boolean> | null } | null;
    if (!linha || linha.situacao !== "ok" || !linha.caminho || !linha.sha256) {
      throw new Error("este backup não tem um arquivo válido para copiar");
    }
    destinosAtuais = linha.destinos ?? {};

    const baixado = await admin.storage.from(BUCKET).download(linha.caminho);
    if (baixado.error || !baixado.data) throw new Error("não foi possível ler o arquivo do backup no armazenamento");
    const arquivo = Buffer.from(await baixado.data.arrayBuffer());
    if (sha256Hex(arquivo) !== linha.sha256) {
      throw new Error("o arquivo guardado no sistema não confere com a impressão digital registrada");
    }

    resultado = { estado: await enviarArquivo(config, nomeRemoto(linha.caminho), arquivo, linha.sha256) };
  } catch (e) {
    resultado = { estado: "erro", detalhe: mensagemSegura(e, [config.clientId, config.clientSecret, config.assinatura]) };
  }

  const deu = resultado.estado === "enviado" || resultado.estado === "ja_existia";
  if (destinosAtuais !== null) {
    const { error } = await admin.from("backup_arquivos").update({ destinos: { ...destinosAtuais, [TIPO]: deu } }).eq("id", id);
    if (error) console.error("Falha ao gravar o destino do backup:", error.message);
  }
  const { error } = await admin
    .from("backup_destinos")
    .update({
      ultimo_envio_em: new Date().toISOString(),
      ultimo_envio_situacao: deu ? "ok" : "falhou",
      ultimo_envio_detalhe: deu ? null : (resultado.detalhe ?? null),
    })
    .eq("tipo", TIPO);
  if (error) console.error("Falha ao gravar o último envio do destino:", error.message);

  await auditar(admin, usuarioId, "backup_copiado_destino", id, {
    destino: TIPO,
    origem,
    resultado: resultado.estado,
    ...(deu ? {} : { motivo: resultado.detalhe ?? null }),
  });

  if (!deu) {
    await notificar("falha", {
      assunto: "Sysmusica: a cópia do backup para o servidor local falhou",
      texto:
        `Quando: ${dataHoraSalvador(new Date())}\n` +
        `O backup foi feito, mas não foi copiado para o servidor local.\nMotivo: ${resultado.detalhe ?? "desconhecido"}\n` +
        `O arquivo continua guardado e válido no sistema. Resolva o problema e use "Enviar o backup mais recente agora" na aba Destinos.`,
    });
  }
  return resultado;
}

/**
 * Cópia automática, chamada logo depois de um backup verificado. Se o envio automático está desligado devolve
 * "desligado". NUNCA lança erro (nem se a migração 0022 ainda não foi aplicada): o backup não pode falhar por isso.
 */
export async function enviarAutomatico(admin: SupabaseClient, id: string): Promise<ResultadoCopia> {
  try {
    const linha = await lerLinha(admin);
    if (!linha?.ativo) return { estado: "desligado" };
    const config = configCompleta(linha, lerSegredos(linha, chaveDoAmbiente()));
    if (!config) {
      const resultado: ResultadoCopia = {
        estado: "erro",
        detalhe: "o envio automático está ligado, mas a configuração está incompleta ou não abre com a chave atual",
      };
      await notificar("falha", {
        assunto: "Sysmusica: a cópia do backup para o servidor local falhou",
        texto: `Motivo: ${resultado.detalhe}.\nO backup continua válido no sistema. Confira a aba Destinos.`,
      });
      return resultado;
    }
    return await executarCopia(admin, id, null, "automatico", config);
  } catch (e) {
    console.error("Falha na cópia automática do backup:", e);
    return { estado: "desligado" };
  }
}

/** Botão "Enviar o backup mais recente agora" (funciona mesmo com o envio automático desligado). */
export async function enviarMaisRecente(usuario: UsuarioAutenticado): Promise<{ detalhe: string }> {
  const admin = clienteAdmin();
  const linha = await lerLinha(admin);
  const config = configCompleta(linha, lerSegredos(linha, chaveDoAmbiente()));
  if (!config) throw new ErroBackup(400, "Salve o endereço, o Client ID, o Client Secret e a chave de assinatura antes de enviar.");

  const { data } = await admin
    .from("backup_arquivos")
    .select("id")
    .eq("situacao", "ok")
    .order("criado_em", { ascending: false })
    .limit(1)
    .maybeSingle();
  const id = (data as { id: string } | null)?.id;
  if (!id) throw new ErroBackup(400, "Ainda não existe nenhum backup para enviar. Faça um backup primeiro.");

  const resultado = await executarCopia(admin, id, usuario.id, "manual", config);
  if (resultado.estado === "erro") throw new ErroBackup(502, `Não foi possível enviar: ${resultado.detalhe ?? "motivo desconhecido"}`);
  return {
    detalhe:
      resultado.estado === "ja_existia"
        ? "O backup mais recente já estava no servidor local."
        : "Backup mais recente copiado para o servidor local e conferido. O OneDrive do servidor sincroniza em seguida.",
  };
}

/** Acrescenta ao aviso de sucesso do backup uma linha dizendo como ficou a cópia no servidor local. */
export function acrescentarCopia(
  copia: ResultadoCopia | null,
  mensagem: { assunto: string; texto: string }
): { assunto: string; texto: string } {
  const linha = copia ? linhaDoAviso(copia) : null;
  return linha ? { ...mensagem, texto: `${mensagem.texto}\n\n${linha}` } : mensagem;
}
