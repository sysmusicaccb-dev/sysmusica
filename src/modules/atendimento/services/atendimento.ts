/**
 * SysMúsica — Serviço de dados do atendimento da portaria.
 * Todas as regras (portaria aprovada, abrangência do usuário, QR Code válido, nome completo,
 * duplicidade) são aplicadas pelo banco; a tela só chama e mostra o resultado. Sem acesso à portaria,
 * o banco responde "Portaria indisponível para você" sem revelar nada de outras portarias.
 */
import { supabase } from "@/lib/supabase";
import { mensagemDoErro } from "@/lib/erros";
import type { NoOrganizacao } from "@/modules/organizacao/tipos";
import type { CartaoMembro, EntradaRecente, OpcoesVisitante, OrigemEntrada } from "../tipos";

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
  origem: OrigemEntrada,
  toca: boolean | null = null, // resposta de "Vai tocar?" (só para quem a Portaria pergunta)
  instrumentoId: string | null = null // instrumento escolhido na entrada (vazio = o do cadastro)
): Promise<void> {
  const { error } = await supabase.rpc("registrar_entrada", {
    p_portaria_id: portariaId,
    p_membro_id: membroId,
    p_origem: origem,
    p_toca: toca,
    p_instrumento_id: instrumentoId,
  });
  if (error) throw new Error(mensagemDoErro(error, "Não foi possível registrar a entrada."));
}

/** Estrutura ativa (estados, regiões, setores e comuns) para escolher a origem do visitante. */
export async function listarOrigensVisitante(): Promise<NoOrganizacao[]> {
  const { data, error } = await supabase.rpc("listar_origens_visitante");
  if (error) throw new Error(mensagemDoErro(error, "Não foi possível carregar as origens."));
  return (data ?? []) as NoOrganizacao[];
}

/** Cargos e instrumentos para o formulário de visitante (exige a permissão de cadastrar visitante). */
export async function listarOpcoesVisitante(): Promise<OpcoesVisitante> {
  const { data, error } = await supabase.rpc("opcoes_visitante");
  if (error) throw new Error(mensagemDoErro(error, "Não foi possível carregar as opções do visitante."));

  const linhas = (data ?? []) as {
    tipo: string;
    id: string;
    nome: string;
    permite_instrumento: boolean;
    exige_instrumento: boolean;
    familia_id: string | null;
  }[];
  return {
    cargos: linhas
      .filter((linha) => linha.tipo === "CARGO")
      .map((linha) => ({
        id: linha.id,
        nome: linha.nome,
        permite_instrumento: linha.permite_instrumento,
        exige_instrumento: linha.exige_instrumento,
      })),
    instrumentos: linhas
      .filter((linha) => linha.tipo === "INSTRUMENTO")
      .map((linha) => ({ id: linha.id, nome: linha.nome, familia_id: linha.familia_id })),
    familias: linhas
      .filter((linha) => linha.tipo === "FAMILIA")
      .map((linha) => ({ id: linha.id, nome: linha.nome })),
  };
}

/**
 * Cadastra o visitante na comum da portaria e devolve o cartão para a conferência.
 * O banco confere permissão, portaria aprovada, abrangência, nome completo e nome repetido na comum.
 */
export async function cadastrarVisitante(
  portariaId: string,
  dados: {
    nome: string;
    cargoId: string;
    instrumentoId: string | null;
    origemComumId: string;
    membroId: string; // gerado na tela: a foto sobe para a pasta deste identificador antes do cadastro
    fotoPath: string;
  }
): Promise<CartaoMembro> {
  const { data, error } = await supabase.rpc("cadastrar_visitante", {
    p_portaria_id: portariaId,
    p_nome: dados.nome,
    p_cargo_id: dados.cargoId,
    p_instrumento_id: dados.instrumentoId,
    p_origem_comum_id: dados.origemComumId,
    p_membro_id: dados.membroId,
    p_foto_path: dados.fotoPath,
  });
  if (error || typeof data !== "string") {
    throw new Error(
      error ? mensagemDoErro(error, "Não foi possível cadastrar o visitante.") : "Não foi possível cadastrar o visitante."
    );
  }

  const resposta = await supabase.rpc("cartao_do_membro", { p_portaria_id: portariaId, p_membro_id: data });
  const cartao = ((resposta.data ?? []) as CartaoMembro[])[0];
  if (resposta.error || !cartao) {
    throw new Error("Visitante cadastrado, mas não foi possível abrir a conferência. Busque-o pelo nome completo.");
  }
  return cartao;
}

/** Recarrega o cartão de conferência de um membro (por exemplo, depois de tirar a foto na hora). */
export async function recarregarCartao(portariaId: string, membroId: string): Promise<CartaoMembro> {
  const { data, error } = await supabase.rpc("cartao_do_membro", { p_portaria_id: portariaId, p_membro_id: membroId });
  const cartao = ((data ?? []) as CartaoMembro[])[0];
  if (error || !cartao) {
    throw new Error(error ? mensagemDoErro(error, "Não foi possível atualizar a conferência.") : "Membro não encontrado.");
  }
  return cartao;
}

/** Últimas entradas da portaria (e o total). */
export async function entradasDaPortaria(portariaId: string): Promise<EntradaRecente[]> {
  const { data, error } = await supabase.rpc("entradas_da_portaria", { p_portaria_id: portariaId });
  if (error) throw new Error(mensagemDoErro(error, "Não foi possível carregar as entradas."));
  return (data ?? []) as EntradaRecente[];
}
