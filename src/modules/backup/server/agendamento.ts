/**
 * SysMúsica — Agendamento dos backups no servidor: configuração, rotina diária (backup + retenção) e conferência
 * da tarde (aviso de atraso + verificação semanal). As duas rotinas são chamadas pelo Vercel (vercel.json) com o
 * segredo CRON_SECRET; quem aperta o botão "Executar a rotina agora" passa pela permissão de Administrador.
 *
 * SEGURANÇA DA RETENÇÃO: só são apagados backups AGENDADOS (diário, semanal, quinzenal, mensal) que já foram
 * VERIFICADOS, e sempre fica pelo menos um. Backup manual, de segurança, com falha ou ainda não verificado
 * nunca é apagado automaticamente. Cópias já enviadas ao servidor local NÃO são apagadas daqui.
 */
import { timingSafeEqual } from "node:crypto";
import type { SupabaseClient } from "@supabase/supabase-js";
import {
  PADRAO_AGENDAMENTO,
  DIA_VERIFICACAO_SEMANAL,
  TIPOS_AGENDADOS,
  descreverTipoDoDia,
  escolherTipo,
  excedentes,
  inicioDoDiaSalvador,
  proximoBackup,
  validarAgendamento,
  type AgendamentoPublico,
  type ConfigAgendamento,
  type TipoAgendado,
} from "../agendamento";
import { ROTULO_TIPO, dataHoraSalvador, descreverVerificacao } from "../regras";
import type { UsuarioAutenticado } from "./autorizacao";
import { clienteAdmin } from "./clienteAdmin";
import { ErroBackup } from "./erros";
import { notificar } from "./notificar";
import { fazerBackup, verificarPeloSistema } from "./operacoes";

const BUCKET = "backups";
const COLUNAS =
  "ativo, diario_ativo, diario_retencao, semanal_ativo, semanal_retencao, semanal_dia, quinzenal_ativo, quinzenal_retencao, " +
  "mensal_ativo, mensal_retencao, mensal_dia, ultimo_em, ultimo_resultado, ultimo_detalhe, ultima_verificacao_em";

interface LinhaAgendamento extends ConfigAgendamento {
  ultimo_em: string | null;
  ultimo_resultado: "ok" | "falhou" | "pulado" | null;
  ultimo_detalhe: string | null;
  ultima_verificacao_em: string | null;
}

export interface ResultadoRotina {
  resultado: "ok" | "falhou" | "pulado";
  tipo: TipoAgendado | null;
  detalhe: string;
  apagados: number;
}

/** Confere o segredo que o Vercel manda nas tarefas automáticas (cabeçalho Authorization: Bearer ...). */
export function exigirCron(request: Request): void {
  const segredo = process.env.CRON_SECRET;
  if (!segredo || segredo.length < 16) {
    throw new ErroBackup(500, "A variável CRON_SECRET não está configurada (mínimo de 16 caracteres).");
  }
  const recebido = Buffer.from(request.headers.get("authorization") ?? "");
  const esperado = Buffer.from(`Bearer ${segredo}`);
  if (recebido.length !== esperado.length || !timingSafeEqual(recebido, esperado)) {
    throw new ErroBackup(401, "Não autorizado.");
  }
}

// Registra na Auditoria; uma falha aqui nunca derruba a operação
async function auditar(
  admin: SupabaseClient,
  usuarioId: string | null,
  acao: string,
  detalhes: Record<string, unknown>
): Promise<void> {
  const { error } = await admin
    .from("auditoria")
    .insert({ usuario_id: usuarioId, acao, entidade: "backup", entidade_id: null, detalhes });
  if (error) console.error("Falha ao registrar a auditoria do agendamento:", error.message);
}

async function lerLinha(admin: SupabaseClient): Promise<LinhaAgendamento> {
  const { data, error } = await admin.from("backup_agendamento").select(COLUNAS).eq("id", 1).maybeSingle();
  if (error) throw new ErroBackup(500, "Não foi possível ler o agendamento. A migração 0023 foi aplicada?");
  const vazio = { ultimo_em: null, ultimo_resultado: null, ultimo_detalhe: null, ultima_verificacao_em: null };
  return data ? (data as unknown as LinhaAgendamento) : { ...PADRAO_AGENDAMENTO, ...vazio };
}

function soConfig(linha: LinhaAgendamento): ConfigAgendamento {
  return {
    ativo: linha.ativo,
    diario_ativo: linha.diario_ativo,
    diario_retencao: linha.diario_retencao,
    semanal_ativo: linha.semanal_ativo,
    semanal_retencao: linha.semanal_retencao,
    semanal_dia: linha.semanal_dia,
    quinzenal_ativo: linha.quinzenal_ativo,
    quinzenal_retencao: linha.quinzenal_retencao,
    mensal_ativo: linha.mensal_ativo,
    mensal_retencao: linha.mensal_retencao,
    mensal_dia: linha.mensal_dia,
  };
}

// ---------- Ler e salvar ----------

export async function lerAgendamentoPublico(): Promise<AgendamentoPublico> {
  const linha = await lerLinha(clienteAdmin());
  const config = soConfig(linha);
  const proximo = proximoBackup(config, new Date());
  return {
    config,
    ultimo_em: linha.ultimo_em,
    ultimo_resultado: linha.ultimo_resultado,
    ultimo_detalhe: linha.ultimo_detalhe,
    ultima_verificacao_em: linha.ultima_verificacao_em,
    proximo: proximo ? { quando: proximo.quando.toISOString(), tipo: proximo.tipo } : null,
  };
}

export async function salvarAgendamento(entrada: ConfigAgendamento, usuario: UsuarioAutenticado): Promise<AgendamentoPublico> {
  const erro = validarAgendamento(entrada);
  if (erro) throw new ErroBackup(400, erro);

  const admin = clienteAdmin();
  const atual = soConfig(await lerLinha(admin));
  const alterados = (Object.keys(entrada) as (keyof ConfigAgendamento)[]).filter((campo) => entrada[campo] !== atual[campo]);

  const { error } = await admin
    .from("backup_agendamento")
    .upsert({ id: 1, ...entrada, atualizado_em: new Date().toISOString(), atualizado_por: usuario.id }, { onConflict: "id" });
  if (error) throw new ErroBackup(500, "Não foi possível salvar o agendamento.");

  if (alterados.length > 0) await auditar(admin, usuario.id, "backup_agendamento_alterado", { alterados });
  return lerAgendamentoPublico();
}

// ---------- Retenção ----------

// Apaga os backups verificados de UM tipo que passam do limite. Devolve quantos foram apagados.
async function aplicarRetencao(admin: SupabaseClient, tipo: TipoAgendado, manter: number): Promise<number> {
  const { data, error } = await admin
    .from("backup_arquivos")
    .select("id, caminho, criado_em")
    .eq("tipo", tipo)
    .eq("situacao", "ok")
    .eq("verificacao", "ok") // só conta e só apaga backup verificado
    .order("criado_em", { ascending: false })
    .limit(500);
  if (error) {
    console.error("Falha ao consultar a retenção do backup:", error.message);
    return 0;
  }

  const apagar = excedentes((data ?? []) as { id: string; caminho: string | null; criado_em: string }[], manter).slice(0, 50);
  let apagados = 0;
  for (const linha of apagar) {
    if (linha.caminho) {
      const remocao = await admin.storage.from(BUCKET).remove([linha.caminho]);
      if (remocao.error) {
        console.error("Falha ao apagar o arquivo na retenção:", remocao.error.message);
        continue; // sem apagar o arquivo, não apaga o registro
      }
    }
    const { error: erroLinha } = await admin.from("backup_arquivos").delete().eq("id", linha.id);
    if (erroLinha) console.error("Falha ao apagar o registro na retenção:", erroLinha.message);
    else apagados += 1;
  }
  if (apagados > 0) await auditar(admin, null, "backup_retencao_aplicada", { tipo, apagados, mantidos: manter });
  return apagados;
}

function retencaoDe(config: ConfigAgendamento, tipo: TipoAgendado): number {
  return config[`${tipo}_retencao` as const];
}

async function registrarExecucao(
  admin: SupabaseClient,
  resultado: "ok" | "falhou" | "pulado",
  detalhe: string
): Promise<void> {
  const { error } = await admin
    .from("backup_agendamento")
    .update({ ultimo_em: new Date().toISOString(), ultimo_resultado: resultado, ultimo_detalhe: detalhe.slice(0, 500) })
    .eq("id", 1);
  if (error) console.error("Falha ao gravar a última execução do agendamento:", error.message);
}

// Já existe backup agendado criado hoje (dia de Salvador)?
async function existeAgendadoHoje(admin: SupabaseClient, agora: Date, apenasOk: boolean): Promise<boolean> {
  let consulta = admin
    .from("backup_arquivos")
    .select("id")
    .in("tipo", TIPOS_AGENDADOS)
    .gte("criado_em", inicioDoDiaSalvador(agora).toISOString());
  if (apenasOk) consulta = consulta.eq("situacao", "ok");
  const { data } = await consulta.limit(1);
  return (data ?? []).length > 0;
}

// ---------- Rotina diária ----------

/**
 * Decide o tipo do dia, faz o backup (que verifica, copia para o servidor local e avisa) e aplica a retenção.
 * "forcar" é o botão manual: ignora a chave geral e a trava de "já fez hoje", mas respeita o tipo do dia.
 */
export async function executarRotina(opcoes: { forcar: boolean; usuario: UsuarioAutenticado | null }): Promise<ResultadoRotina> {
  const admin = clienteAdmin();
  const agora = new Date();
  const linha = await lerLinha(admin);
  const config = soConfig(linha);

  const tipo = escolherTipo({ ...config, ativo: opcoes.forcar ? true : config.ativo }, agora);
  if (!tipo) {
    const detalhe = config.ativo || opcoes.forcar ? "nenhum tipo de backup vale para hoje" : "o agendamento está desligado";
    await registrarExecucao(admin, "pulado", detalhe);
    return { resultado: "pulado", tipo: null, detalhe, apagados: 0 };
  }
  if (!opcoes.forcar && (await existeAgendadoHoje(admin, agora, false))) {
    const detalhe = "já existe um backup agendado hoje";
    await registrarExecucao(admin, "pulado", detalhe);
    return { resultado: "pulado", tipo, detalhe, apagados: 0 };
  }

  try {
    const resposta = await fazerBackup({
      tipo,
      usuario: opcoes.usuario,
      observacao: `Backup agendado (${descreverTipoDoDia(tipo)})`,
    });
    const verificado = resposta.verificacao.ok;
    const apagados = verificado ? await aplicarRetencao(admin, tipo, retencaoDe(config, tipo)) : 0;
    const detalhe =
      `backup ${descreverTipoDoDia(tipo)} ${verificado ? "feito e verificado" : "feito, mas FALHOU na verificação"}` +
      (apagados > 0 ? `; ${apagados} antigo(s) apagado(s) pela retenção` : "");
    await registrarExecucao(admin, verificado ? "ok" : "falhou", detalhe);
    await auditar(admin, opcoes.usuario?.id ?? null, "backup_agendado_executado", { tipo, forcado: opcoes.forcar, verificado, apagados });
    return { resultado: verificado ? "ok" : "falhou", tipo, detalhe, apagados };
  } catch (e) {
    // fazerBackup já avisou a falha por Telegram e e-mail
    const detalhe = e instanceof Error ? e.message : "erro desconhecido";
    await registrarExecucao(admin, "falhou", detalhe);
    await auditar(admin, opcoes.usuario?.id ?? null, "backup_agendado_executado", { tipo, forcado: opcoes.forcar, verificado: false, erro: detalhe.slice(0, 200) });
    return { resultado: "falhou", tipo, detalhe, apagados: 0 };
  }
}

// ---------- Conferência da tarde ----------

export interface ResultadoConferencia {
  atrasado: boolean;
  verificados: number;
  problemas: number;
}

/**
 * Roda à tarde: (1) se o backup de hoje deveria ter sido feito e não existe, avisa o atraso;
 * (2) às segundas-feiras, reverifica os 3 backups mais recentes e manda um aviso único com o resultado.
 */
export async function conferirDia(): Promise<ResultadoConferencia> {
  const admin = clienteAdmin();
  const agora = new Date();
  const config = soConfig(await lerLinha(admin));
  const resultado: ResultadoConferencia = { atrasado: false, verificados: 0, problemas: 0 };
  if (!config.ativo) return resultado;

  // 1) Aviso de atraso
  const tipo = escolherTipo(config, agora);
  if (tipo && !(await existeAgendadoHoje(admin, agora, true))) {
    resultado.atrasado = true;
    await auditar(admin, null, "backup_agendado_atrasado", { tipo });
    await notificar("falha", {
      assunto: "SysMúsica: o backup agendado de hoje não foi feito",
      texto:
        `Quando: ${dataHoraSalvador(agora)}\n` +
        `Era esperado um backup ${descreverTipoDoDia(tipo)} às 03:00, mas não há nenhum backup concluído hoje.\n` +
        `Entre em Administração > Backup, veja a lista e use "Fazer backup agora" ou "Executar a rotina agora" na aba Agendamento.`,
    });
  }

  // 2) Verificação semanal (segunda-feira)
  const hoje = new Date(agora.getTime() - 3 * 3_600_000).getUTCDay();
  if (hoje === DIA_VERIFICACAO_SEMANAL) {
    const { data } = await admin
      .from("backup_arquivos")
      .select("id, tipo, criado_em")
      .eq("situacao", "ok")
      .order("criado_em", { ascending: false })
      .limit(3);
    const lista = (data ?? []) as { id: string; tipo: keyof typeof ROTULO_TIPO; criado_em: string }[];

    const linhas: string[] = [];
    for (const backup of lista) {
      const verificacao = await verificarPeloSistema(backup.id);
      resultado.verificados += 1;
      if (!verificacao.ok) resultado.problemas += 1;
      linhas.push(
        `- ${ROTULO_TIPO[backup.tipo] ?? backup.tipo} de ${dataHoraSalvador(new Date(backup.criado_em))}: ` +
          (verificacao.ok ? "íntegro" : `PROBLEMA (${descreverVerificacao(verificacao)})`)
      );
    }
    if (lista.length > 0) {
      await admin.from("backup_agendamento").update({ ultima_verificacao_em: agora.toISOString() }).eq("id", 1);
      await notificar(resultado.problemas === 0 ? "sucesso" : "falha", {
        assunto:
          resultado.problemas === 0
            ? "SysMúsica: verificação semanal dos backups concluída"
            : "SysMúsica: ALERTA na verificação semanal dos backups",
        texto:
          `Quando: ${dataHoraSalvador(agora)}\n` +
          `Backups reverificados: ${resultado.verificados}. Com problema: ${resultado.problemas}.\n\n${linhas.join("\n")}`,
      });
    }
  }
  return resultado;
}
