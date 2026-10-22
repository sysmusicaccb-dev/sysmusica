/**
 * Sysmusica — Restauração, parte 2 (aplicar), lado do servidor.
 * Fluxo: confere a SENHA do administrador de novo -> compara o backup com os dados de hoje -> monta o plano
 * -> faz um BACKUP DE SEGURANÇA verificado (se não passar, nada é restaurado) -> aplica tudo em UMA transação
 * (backup_aplicar: se algo falhar, nada muda) -> avisa por Telegram/e-mail e registra na Auditoria.
 */
import { createClient } from "@supabase/supabase-js";
import type { SupabaseClient } from "@supabase/supabase-js";
import { abrirBackup, lerChave } from "../cripto";
import { dataHoraSalvador, idValido, lerPacote } from "../regras";
import {
  montarPlano,
  resumirOperacoes,
  totalDeLinhasDoPlano,
  type EntradaAplicacao,
  type EntradaTabela,
  type RespostaRestauracao,
  type ResultadoOperacao,
} from "../aplicacao";
import type { Linha } from "../restauracao";
import { GRUPOS_DADOS, TABELAS, tabelasDoGrupo } from "../tabelas";
import type { UsuarioAutenticado } from "./autorizacao";
import { clienteAdmin } from "./clienteAdmin";
import { ErroBackup } from "./erros";
import { notificar } from "./notificar";
import { fazerBackup } from "./operacoes";
import { lerTabelaAtual } from "./restauracao";

const BUCKET = "backups";

// Confere a senha do administrador de novo (login sem guardar sessão)
async function conferirSenha(admin: SupabaseClient, usuarioId: string, senha: string): Promise<void> {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const anon = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY ?? process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY;
  if (!url || !anon) throw new ErroBackup(500, "A chave pública do Supabase não está configurada no servidor.");

  const { data } = await admin.auth.admin.getUserById(usuarioId);
  const email = data.user?.email;
  if (!email) throw new ErroBackup(403, "Não foi possível conferir a sua conta.");

  const cliente = createClient(url, anon, { auth: { persistSession: false, autoRefreshToken: false } });
  const { data: login, error } = await cliente.auth.signInWithPassword({ email, password: senha });
  if (error || login.user?.id !== usuarioId) throw new ErroBackup(403, "Senha incorreta. Nada foi restaurado.");
}

async function registrar(admin: SupabaseClient, usuarioId: string, acao: string, backupId: string, detalhes: Record<string, unknown>) {
  const { error } = await admin
    .from("auditoria")
    .insert({ usuario_id: usuarioId, acao, entidade: "backup", entidade_id: backupId, detalhes });
  if (error) console.error("Falha ao registrar a auditoria da restauração:", error.message);
}

/** Restaura o backup escolhido nos grupos marcados. Ver o fluxo no topo do arquivo. */
export async function restaurarBackup(entrada: EntradaAplicacao, usuario: UsuarioAutenticado): Promise<RespostaRestauracao> {
  if (!idValido(entrada.id)) throw new ErroBackup(400, "Identificador de backup inválido.");
  const admin = clienteAdmin();

  await conferirSenha(admin, usuario.id, entrada.senha);

  const { data: linha, error } = await admin
    .from("backup_arquivos")
    .select("id, criado_em, tipo, situacao, caminho")
    .eq("id", entrada.id)
    .maybeSingle();
  if (error) throw new ErroBackup(500, "Não foi possível consultar o backup.");
  if (!linha) throw new ErroBackup(404, "Backup não encontrado.");
  if (linha.situacao !== "ok" || !linha.caminho) throw new ErroBackup(400, "Este backup não tem arquivo utilizável.");

  let chave: Buffer;
  try {
    chave = lerChave(process.env.BACKUP_CHAVE);
  } catch (e) {
    throw new ErroBackup(500, e instanceof Error ? e.message : "A chave dos backups não está configurada.");
  }
  const baixado = await admin.storage.from(BUCKET).download(String(linha.caminho));
  if (baixado.error || !baixado.data) throw new ErroBackup(500, "Não foi possível ler o arquivo do backup no armazenamento.");

  let doArquivo: Record<string, Linha[]>;
  try {
    doArquivo = lerPacote(abrirBackup(Buffer.from(await baixado.data.arrayBuffer()), chave).toString("utf8")).tabelas;
  } catch (e) {
    throw new ErroBackup(500, e instanceof Error ? e.message : "Não foi possível abrir o backup.");
  }

  // Plano: o que precisa mudar nos grupos escolhidos
  const entradas: EntradaTabela[] = [];
  for (const grupo of GRUPOS_DADOS.filter((g) => entrada.grupos.includes(g.id))) {
    for (const def of tabelasDoGrupo(grupo.id)) {
      const backup: Linha[] | undefined = doArquivo[def.nome];
      entradas.push({ def, backup, hoje: await lerTabelaAtual(admin, def) });
    }
  }
  const plano = montarPlano(entradas, entrada.modo);
  if (plano.length === 0) {
    return { restaurado: false, mensagem: "Nada a restaurar: os dados de hoje já estão iguais ao backup nos grupos escolhidos.", operacoes: [], segurancaId: null };
  }

  const dataDoBackup = dataHoraSalvador(new Date(String(linha.criado_em)));
  const rotulos = Object.fromEntries(TABELAS.map((t) => [t.nome, t.rotulo]));
  const modoTexto = entrada.modo === "espelhar" ? "Espelhar" : "Recuperar";

  // Backup de segurança ANTES de mexer em qualquer coisa; se não passar na verificação, aborta
  let segurancaId: string;
  try {
    const seguranca = await fazerBackup({ tipo: "seguranca", usuario, observacao: `Antes de restaurar o backup de ${dataDoBackup}` });
    if (!seguranca.verificacao.ok) throw new Error("o backup de segurança não passou na verificação");
    segurancaId = seguranca.backup.id;
  } catch (e) {
    const motivo = e instanceof Error ? e.message : "erro desconhecido";
    throw new ErroBackup(500, `Não foi possível fazer o backup de segurança (${motivo}). Nada foi restaurado.`);
  }

  // Aplica tudo em uma única transação
  const resumo = { backup_id: entrada.id, modo: entrada.modo, grupos: entrada.grupos, seguranca_id: segurancaId };
  const { data: resultado, error: erroAplicar } = await admin.rpc("backup_aplicar", {
    p_usuario: usuario.id,
    p_operacoes: plano,
    p_resumo: resumo,
  });
  if (erroAplicar) {
    console.error("Falha ao aplicar a restauração:", erroAplicar.message);
    await registrar(admin, usuario.id, "backup_restauracao_falhou", entrada.id, { ...resumo, erro: erroAplicar.message.slice(0, 300) });
    await notificar("restauracao", {
      assunto: "Sysmusica: a restauração FALHOU (nada foi alterado)",
      texto: `Backup de ${dataDoBackup}, modo ${modoTexto}, feita por ${usuario.nome}.\nMotivo: ${erroAplicar.message.slice(0, 300)}\nOs dados continuam como estavam.`,
    });
    throw new ErroBackup(500, `A restauração foi desfeita e nada foi alterado. Motivo: ${erroAplicar.message}`);
  }

  const operacoes = (Array.isArray(resultado) ? resultado : []) as ResultadoOperacao[];
  const texto = resumirOperacoes(operacoes, rotulos);
  await notificar("restauracao", {
    assunto: "Sysmusica: backup restaurado",
    texto:
      `Backup de ${dataDoBackup} restaurado por ${usuario.nome} (modo ${modoTexto}).\n${texto}.\n` +
      `Antes disso foi feito um backup de segurança, que pode ser usado para desfazer.`,
  });

  return {
    restaurado: true,
    mensagem: `Restauração concluída (${totalDeLinhasDoPlano(plano)} registros analisados): ${texto}. Um backup de segurança foi feito antes.`,
    operacoes,
    segurancaId,
  };
}
