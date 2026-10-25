/**
 * Sysmusica — Busca os dados do cadastro de uma pessoa para preencher as fichas sozinhas.
 * Passa pela função do banco dados_do_membro_para_ficha (confere permissão e região; não traz CPF nem documentos).
 */
import { supabase } from "@/lib/supabase";
import { mensagemDoErro } from "@/lib/erros";
import type { CadastroParaFicha } from "../dados";

export async function obterDadosDoMembro(membroId: string): Promise<CadastroParaFicha> {
  const { data, error } = await supabase.rpc("dados_do_membro_para_ficha", { p_membro: membroId });
  if (error) throw new Error(mensagemDoErro(error, "Não foi possível ler o cadastro da pessoa."));
  return (data ?? {}) as CadastroParaFicha;
}
