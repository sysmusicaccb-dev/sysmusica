/**
 * Sysmusica — Serviço do prazo dos Cadastros Pendentes. Tudo passa por funções do banco (migração 0045),
 * que conferem a permissão: ler a configuração exige cadastros.visualizar; ver a prévia e salvar exigem
 * cadastros.configurar. O navegador nunca lê nem grava a tabela de configuração diretamente.
 */
import { supabase } from "@/lib/supabase";
import { mensagemDoErro } from "@/lib/erros";

export interface ConfigPrazo {
  prazo_dias: number;
  minimo: number;
  maximo: number;
  padrao: number;
}

export interface ResultadoSalvarPrazo {
  prazo_dias: number;
  atualizados: number; // pedidos pendentes que passaram a seguir o novo prazo
  vencerao_agora: number; // pedidos pendentes que já passaram do novo prazo (vencem na próxima limpeza)
}

export async function obterConfigPrazo(): Promise<ConfigPrazo> {
  const { data, error } = await supabase.rpc("obter_config_cadastros");
  if (error) throw new Error(mensagemDoErro(error, "Não foi possível carregar o prazo."));
  if (!data) throw new Error("Não foi possível carregar o prazo.");
  const c = data as Partial<ConfigPrazo>;
  return {
    prazo_dias: Number(c.prazo_dias ?? 60),
    minimo: Number(c.minimo ?? 7),
    maximo: Number(c.maximo ?? 365),
    padrao: Number(c.padrao ?? 60),
  };
}

/** Quantos pedidos pendentes já passaram do prazo informado (só consulta, não altera nada). */
export async function previaPrazo(dias: number): Promise<number> {
  const { data, error } = await supabase.rpc("previa_prazo_cadastros", { p_dias: dias });
  if (error) throw new Error(mensagemDoErro(error, "Não foi possível conferir o novo prazo."));
  return Number(data ?? 0);
}

export async function salvarPrazo(dias: number): Promise<ResultadoSalvarPrazo> {
  const { data, error } = await supabase.rpc("salvar_config_cadastros", { p_dias: dias });
  if (error) throw new Error(mensagemDoErro(error, "Não foi possível salvar o prazo."));
  if (!data) throw new Error("Não foi possível salvar o prazo.");
  const r = data as Partial<ResultadoSalvarPrazo>;
  return {
    prazo_dias: Number(r.prazo_dias ?? dias),
    atualizados: Number(r.atualizados ?? 0),
    vencerao_agora: Number(r.vencerao_agora ?? 0),
  };
}
