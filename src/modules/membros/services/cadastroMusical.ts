/**
 * Sysmusica — Serviço do Cadastro Musical (dados pessoais do membro: estado civil, telefone, endereço, cartão...).
 * Esses dados ficam na tabela protegida membros_cadastro: a tela só fala com as funções do banco, que conferem a
 * permissão (membros.criar / membros.editar) e a abrangência do usuário (casa de oração do membro).
 */
import { supabase } from "@/lib/supabase";
import { mensagemDoErro } from "@/lib/erros";
import { deRetornoDoBanco, paraEnvioAoBanco, type CadastroMusical } from "../cadastroMusical";

/** Dados pessoais do membro, ou null se ele ainda não tem o cadastro preenchido (membros antigos). */
export async function obterCadastroMusical(membroId: string): Promise<CadastroMusical | null> {
  const { data, error } = await supabase.rpc("obter_cadastro_musical", { p_membro: membroId });
  if (error) throw new Error(mensagemDoErro(error, "Não foi possível carregar os dados do cadastro."));
  return data ? deRetornoDoBanco(data) : null;
}

/** Grava (ou atualiza) os dados pessoais do membro. O banco valida de novo todos os campos. */
export async function salvarCadastroMusical(membroId: string, dados: CadastroMusical): Promise<void> {
  const { error } = await supabase.rpc("salvar_cadastro_musical", {
    p_membro: membroId,
    p_dados: paraEnvioAoBanco(dados),
  });
  if (error) throw new Error(mensagemDoErro(error, "Não foi possível salvar os dados do cadastro."));
}
