/**
 * Sysmusica — Aviso no Telegram quando chega um novo Cadastro Musical pelo formulário público.
 * Usa o mesmo bot e o mesmo chat configurados em Backup > Notificações (só envia se o Telegram estiver ligado lá).
 * A mensagem NÃO traz nome, CPF, foto nem nenhum dado da pessoa. O aviso é "melhor esforço": qualquer falha
 * (Telegram fora do ar, chave errada, demora) fica só no log do servidor e NUNCA atrapalha o cadastro.
 */
import { abrirSegredo, lerChave } from "../../backup/cripto";
import { dataHoraSalvador } from "../../backup/regras";
import { clienteAdmin } from "../../backup/server/clienteAdmin";
import { enviarTelegram } from "../../backup/server/notificar";

export type ResultadoAviso = "enviado" | "desligado" | "erro";

const LIMITE_MS = 5_000; // quem está se cadastrando não espera mais que isso pelo aviso

export function mensagemNovoCadastro(quando: Date): string {
  return [
    "Sysmusica: novo cadastro recebido",
    "",
    "Uma pessoa enviou o Cadastro Musical pelo formulário público e aguarda análise.",
    `Recebido em ${dataHoraSalvador(quando)}.`,
    "",
    "Abra o Sysmusica e veja os cadastros pendentes para aprovar ou recusar.",
  ].join("\n");
}

async function enviar(quando: Date): Promise<ResultadoAviso> {
  const { data } = await clienteAdmin()
    .from("backup_configuracao")
    .select("telegram_ativo, telegram_token_cifrado, telegram_chat_id")
    .eq("id", 1)
    .maybeSingle();
  const config = data as { telegram_ativo: boolean; telegram_token_cifrado: string | null; telegram_chat_id: string | null } | null;
  if (!config || !config.telegram_ativo) return "desligado";
  if (!config.telegram_token_cifrado || !config.telegram_chat_id) return "desligado";

  let token = "";
  try {
    token = abrirSegredo(config.telegram_token_cifrado, lerChave(process.env.BACKUP_CHAVE));
    await enviarTelegram(token, config.telegram_chat_id, mensagemNovoCadastro(quando));
    return "enviado";
  } catch (e) {
    let detalhe = e instanceof Error ? e.message : "erro desconhecido";
    if (token) detalhe = detalhe.split(token).join("***");
    console.error("Falha ao avisar o novo cadastro no Telegram:", detalhe.slice(0, 200));
    return "erro";
  }
}

/** Avisa pelo Telegram (se estiver ligado). Nunca lança erro e nunca demora mais que o limite. */
export async function avisarNovoCadastro(quando: Date = new Date()): Promise<ResultadoAviso> {
  let relogio: ReturnType<typeof setTimeout> | undefined;
  try {
    const limite = new Promise<ResultadoAviso>((resolver) => {
      relogio = setTimeout(() => resolver("erro"), LIMITE_MS);
    });
    return await Promise.race([enviar(quando), limite]);
  } catch (e) {
    console.error("Falha ao avisar o novo cadastro no Telegram:", e instanceof Error ? e.name : "erro");
    return "erro";
  } finally {
    if (relogio) clearTimeout(relogio);
  }
}
