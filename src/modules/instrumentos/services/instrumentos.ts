/**
 * SysMúsica — Serviço de dados de instrumentos e famílias.
 *
 * Criar, editar e excluir passam pelas regras do banco (permissões e RLS). Excluir usa uma função
 * do banco que recusa a exclusão enquanto algum membro usar o instrumento.
 */
import { supabase } from "@/lib/supabase";
import { mensagemDoErro } from "@/lib/erros";
import { inferirFamilia } from "@/lib/familias";
import { normalizarTexto } from "@/lib/texto";
import type { Familia, Instrumento, InstrumentoInsert } from "@/types/database";
import { formatarNomeInstrumento } from "../regras";

const MSG_DUPLICADO = "Já existe um instrumento com este nome.";

/** Busca instrumentos e famílias, ambos em ordem alfabética. Lança erro se a consulta falhar. */
export async function buscarInstrumentosEFamilias(): Promise<{
  instrumentos: Instrumento[];
  familias: Familia[];
}> {
  const [resInstrumentos, resFamilias] = await Promise.all([
    supabase.from("instrumentos").select("*").order("nome", { ascending: true }),
    supabase.from("familias").select("*").order("nome", { ascending: true }),
  ]);

  const erroBanco = resInstrumentos.error ?? resFamilias.error;
  if (erroBanco) throw new Error(erroBanco.message);

  return {
    instrumentos: (resInstrumentos.data ?? []) as Instrumento[],
    familias: (resFamilias.data ?? []) as Familia[],
  };
}

/** Cria um instrumento (a família pode ir vazia: o banco classifica pelo nome). */
export async function criarInstrumento(dados: {
  nome: string;
  familiaId: string | null;
}): Promise<Instrumento> {
  const novo: InstrumentoInsert = {
    nome: formatarNomeInstrumento(dados.nome),
    familia_id: dados.familiaId,
  };
  const { data, error } = await supabase.from("instrumentos").insert(novo).select().single();
  if (error || !data) {
    throw new Error(
      error
        ? mensagemDoErro(error, "Não foi possível criar o instrumento.", MSG_DUPLICADO)
        : "Não foi possível criar o instrumento."
    );
  }
  return data as Instrumento;
}

/** Altera nome e família de um instrumento (exige a permissão instrumentos.editar). */
export async function atualizarInstrumento(dados: {
  id: string;
  nome: string;
  familiaId: string | null;
}): Promise<void> {
  // .select("id") devolve as linhas alteradas: se o RLS negar, o update não dá erro, só não altera nada
  const { data, error } = await supabase
    .from("instrumentos")
    .update({ nome: formatarNomeInstrumento(dados.nome), familia_id: dados.familiaId })
    .eq("id", dados.id)
    .select("id");
  if (error) {
    throw new Error(mensagemDoErro(error, "Não foi possível salvar o instrumento.", MSG_DUPLICADO));
  }
  if (!data || data.length === 0) {
    throw new Error("Não foi possível salvar: você não tem permissão ou o instrumento não existe mais.");
  }
}

/** Exclui um instrumento (função do banco: recusa se algum membro ainda usar). */
export async function excluirInstrumento(id: string): Promise<void> {
  const { error } = await supabase.rpc("excluir_instrumento", { p_id: id });
  if (error) throw new Error(mensagemDoErro(error, "Não foi possível excluir o instrumento."));
}

export interface ResultadoInstrumento {
  id: string;
  nome: string;
  criado: boolean; // true = acabou de ser criado
  familiaNome: string | null;
}

/**
 * Usado no cadastro de membros: devolve o instrumento digitado, criando-o se ainda não existir.
 * A comparação ignora acento e maiúsculas. Ao criar, a família é inferida pelo nome.
 */
export async function obterOuCriarInstrumento(
  texto: string,
  instrumentos: Instrumento[],
  familias: Familia[]
): Promise<ResultadoInstrumento> {
  const chave = normalizarTexto(texto);
  const nomeDaFamilia = (familiaId: string | null) =>
    familias.find((familia) => familia.id === familiaId)?.nome ?? null;

  // 1) Já existe na lista carregada? Então só reaproveita o id
  const existente = instrumentos.find((instrumento) => normalizarTexto(instrumento.nome) === chave);
  if (existente) {
    return {
      id: existente.id,
      nome: existente.nome,
      criado: false,
      familiaNome: nomeDaFamilia(existente.familia_id),
    };
  }

  // 2) Não existe: cria já com a família inferida e resgata o registro
  const novo: InstrumentoInsert = {
    nome: formatarNomeInstrumento(texto),
    familia_id: inferirFamilia(texto, familias)?.id ?? null,
  };
  const { data, error } = await supabase.from("instrumentos").insert(novo).select().single();
  if (!error && data) {
    const criado = data as Instrumento;
    return {
      id: criado.id,
      nome: criado.nome,
      criado: true,
      familiaNome: nomeDaFamilia(criado.familia_id),
    };
  }

  // 3) 23505 = nome duplicado: outra pessoa criou o mesmo instrumento agora há pouco.
  //    Busca a lista de novo e reaproveita o registro que já existe.
  if (error?.code === "23505") {
    const { data: lista, error: erroBusca } = await supabase.from("instrumentos").select("*");
    if (erroBusca) throw new Error(erroBusca.message);
    const achado = ((lista ?? []) as Instrumento[]).find(
      (instrumento) => normalizarTexto(instrumento.nome) === chave
    );
    if (achado) {
      return {
        id: achado.id,
        nome: achado.nome,
        criado: false,
        familiaNome: nomeDaFamilia(achado.familia_id),
      };
    }
  }

  throw new Error(
    error
      ? mensagemDoErro(error, "Não foi possível criar o instrumento.", MSG_DUPLICADO)
      : "Não foi possível criar o instrumento."
  );
}
