/**
 * SysMúsica — Serviço do catálogo de finalidades de evento.
 * O formulário de evento usa obterOuCriarFinalidade: se a pessoa digita uma finalidade que ainda
 * não existe, ela é salva e fica disponível para os próximos eventos.
 */
import { supabase } from "@/lib/supabase";
import { mensagemDoErro } from "@/lib/erros";
import { normalizarTexto } from "@/lib/texto";
import type { FinalidadeEvento, FinalidadeEventoInsert } from "@/types/database";
import { formatarNomeFinalidade } from "../regras";

export interface ResultadoFinalidade {
  id: string;
  nome: string;
  criada: boolean; // true = acabou de ser criada
}

/**
 * Devolve a finalidade digitada, criando-a se ainda não existir.
 * A comparação ignora acento, maiúsculas e espaços repetidos.
 */
export async function obterOuCriarFinalidade(
  texto: string,
  existentes: FinalidadeEvento[]
): Promise<ResultadoFinalidade> {
  const chave = normalizarTexto(texto);

  // 1) Já existe na lista carregada? Então só reaproveita o id
  const existente = existentes.find((finalidade) => normalizarTexto(finalidade.nome) === chave);
  if (existente) return { id: existente.id, nome: existente.nome, criada: false };

  // 2) Não existe: salva e resgata o registro
  const nova: FinalidadeEventoInsert = { nome: formatarNomeFinalidade(texto) };
  const { data, error } = await supabase.from("finalidades_evento").insert(nova).select().single();
  if (!error && data) {
    const criada = data as FinalidadeEvento;
    return { id: criada.id, nome: criada.nome, criada: true };
  }

  // 3) 23505 = repetida: outra pessoa criou a mesma finalidade agora há pouco. Busca de novo.
  if (error?.code === "23505") {
    const { data: lista, error: erroBusca } = await supabase.from("finalidades_evento").select("*");
    if (erroBusca) throw new Error(erroBusca.message);
    const achada = ((lista ?? []) as FinalidadeEvento[]).find(
      (finalidade) => normalizarTexto(finalidade.nome) === chave
    );
    if (achada) return { id: achada.id, nome: achada.nome, criada: false };
  }

  throw new Error(
    error
      ? mensagemDoErro(error, "Não foi possível salvar a finalidade do evento.")
      : "Não foi possível salvar a finalidade do evento."
  );
}
