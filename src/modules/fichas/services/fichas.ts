/**
 * Sysmusica — Serviço do módulo Fichas Musicais. Tudo passa por funções do banco (listar_fichas, obter_ficha,
 * salvar_ficha, excluir_ficha, definir_resultado_ficha, buscar_membros_para_ficha), que conferem a permissão e a
 * região de quem usa: o navegador nunca lê a tabela diretamente.
 */
import { supabase } from "@/lib/supabase";
import { mensagemDoErro } from "@/lib/erros";
import type { LinhaFicha, TipoFicha } from "../tipos";

/** Fichas da região de quem consulta (mais novas primeiro). Filtra por tipo se informado. */
export async function listarFichas(tipo: TipoFicha | null = null): Promise<LinhaFicha[]> {
  const { data, error } = await supabase.rpc("listar_fichas", { p_tipo: tipo });
  if (error) throw new Error(mensagemDoErro(error, "Não foi possível carregar as fichas."));
  return (data ?? []) as LinhaFicha[];
}
