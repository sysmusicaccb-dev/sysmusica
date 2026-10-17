/**
 * SysMúsica — Serviço de dados do atendimento da portaria.
 * Todas as regras (portaria aprovada, abrangência do usuário, QR Code válido, nome completo,
 * duplicidade) são aplicadas pelo banco; a tela só chama e mostra o resultado. Sem acesso à portaria,
 * o banco responde "Portaria indisponível para você" sem revelar nada de outras portarias.
 */
import { supabase } from "@/lib/supabase";
import { mensagemDoErro } from "@/lib/erros";
import type { CartaoMembro, EntradaRecente, OrigemEntrada } from "../tipos";

/** Localiza o membro pelo conteúdo lido do QR Code. */
export async function buscarMembroPorQr(portariaId: string, codigo: string): Promise<CartaoMembro> {
  const { data, error } = await supabase.rpc("buscar_membro_por_qr", {
    p_portaria_id: portariaId,
    p_codigo: codigo,
  });
  const membro = ((data ?? []) as CartaoMembro[])[0];
  if (error || !membro) {
    throw new Error(error ? mensagemDoErro(error, "Não foi possível consultar o QR Code.") : "Membro não encontrado.");
  }
  return membro;
}

/** Localiza membros pelo nome completo (até 6 resultados). */
export async function buscarMembrosPorNome(portariaId: string, nome: string): Promise<CartaoMembro[]> {
  const { data, error } = await supabase.rpc("buscar_membros_por_nome", {
    p_portaria_id: portariaId,
    p_nome: nome,
  });
  if (error) throw new Error(mensagemDoErro(error, "Não foi possível buscar o membro."));
  return (data ?? []) as CartaoMembro[];
}

/** Registra a entrada (o banco confere tudo de novo e define a hora, quem registrou e a origem). */
export async function registrarEntrada(
  portariaId: string,
  membroId: string,
  origem: OrigemEntrada
): Promise<void> {
  const { error } = await supabase.rpc("registrar_entrada", {
    p_portaria_id: portariaId,
    p_membro_id: membroId,
    p_origem: origem,
  });
  if (error) throw new Error(mensagemDoErro(error, "Não foi possível registrar a entrada."));
}

/** Últimas entradas da portaria (e o total). */
export async function entradasDaPortaria(portariaId: string): Promise<EntradaRecente[]> {
  const { data, error } = await supabase.rpc("entradas_da_portaria", { p_portaria_id: portariaId });
  if (error) throw new Error(mensagemDoErro(error, "Não foi possível carregar as entradas."));
  return (data ?? []) as EntradaRecente[];
}
