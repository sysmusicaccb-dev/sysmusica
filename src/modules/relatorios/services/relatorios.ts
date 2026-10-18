/**
 * SysMúsica — Serviço de dados dos Relatórios.
 * As consultas que juntam várias tabelas são funções do banco (migração 0018), que conferem a permissão e
 * a REGIÃO do usuário. Os cadastros simples (instrumentos, cargos, organização e portarias) usam as mesmas
 * consultas das telas deles. Nada de CPF completo: só o parcial, e só para quem tem a permissão.
 */
import { formatarDataHora } from "@/lib/datas";
import { mensagemDoErro } from "@/lib/erros";
import { supabase } from "@/lib/supabase";
import { intervaloDoFiltro } from "@/modules/auditoria/regras";
import { listarOrganizacao, listarOrganizacaoParaSelecao } from "@/modules/organizacao/services/organizacao";
import type { NoOrganizacao } from "@/modules/organizacao/tipos";
import { listarPortarias } from "@/modules/portarias/services/portarias";
import type { Familia, Instrumento } from "@/types/database";
import {
  contarPor,
  formatarDataFiltro,
  linhasCargos,
  linhasInstrumentos,
  linhasOrganizacao,
  linhasPortarias,
  type CargoRelatorio,
} from "../regras";
import type {
  EventoFiltro,
  FiltrosRelatorio,
  LinhaRelatorio,
  OpcoesFiltros,
  ResultadoRelatorio,
  TipoRelatorioId,
} from "../tipos";

/** Máximo de linhas por relatório (o banco devolve também o total, para avisar quando passar). */
export const LIMITE_LINHAS = 5000;

const texto = (valor: unknown): string => (valor === null || valor === undefined ? "" : String(valor));
const simNao = (valor: boolean | null | undefined): string => (valor ? "Sim" : "Não");
const dataHora = (valor: string | null): string => (valor ? formatarDataHora(valor) : "");
const dataBr = (valor: string | null): string => (valor ? formatarDataFiltro(valor) : "");

function rotuloOrigem(origem: string): string {
  if (origem === "QR") return "QR Code";
  if (origem === "ANTIGO") return "Registro antigo";
  return "Pelo nome";
}

// ---------- Listas dos filtros ----------

export async function carregarOpcoesRelatorio(): Promise<OpcoesFiltros> {
  const [organizacao, resCargos, resInstrumentos, resEventos] = await Promise.all([
    listarOrganizacaoParaSelecao().catch(() => [] as NoOrganizacao[]),
    supabase.from("cargos").select("id, nome").order("nome", { ascending: true }),
    supabase.from("instrumentos").select("id, nome").order("nome", { ascending: true }),
    supabase
      .from("eventos")
      .select("id, tipo, data_evento, local")
      .order("data_evento", { ascending: false })
      .limit(300),
  ]);

  // Uma lista que o usuário não pode ver simplesmente fica vazia (o tipo de relatório correspondente nem aparece)
  return {
    organizacao,
    cargos: (resCargos.data ?? []) as { id: string; nome: string }[],
    instrumentos: (resInstrumentos.data ?? []) as { id: string; nome: string }[],
    eventos: (resEventos.data ?? []) as EventoFiltro[],
  };
}

// ---------- Relatórios vindos de funções do banco ----------

interface LinhaPresencaBanco {
  evento_tipo: string;
  evento_data: string;
  evento_local: string;
  evento_finalidade: string | null;
  regiao: string | null;
  setor: string | null;
  comum: string | null;
  membro_nome: string;
  membro_comum: string | null;
  cargo: string | null;
  instrumento: string | null;
  familia: string | null;
  cidade: string | null;
  bairro: string | null;
  visitante: boolean;
  status: string;
  hora_entrada: string;
  hora_saida: string | null;
  origem: string;
  registrado_por: string | null;
  total: number | string;
}

async function buscarPresencas(filtros: FiltrosRelatorio): Promise<ResultadoRelatorio> {
  const periodo = intervaloDoFiltro(filtros.inicio, filtros.fim);
  const { data, error } = await supabase.rpc("relatorio_presencas", {
    p_inicio: periodo.inicio,
    p_fim: periodo.fim,
    p_evento: filtros.eventoId || null,
    p_regiao: filtros.regiaoId || null,
    p_setor: filtros.setorId || null,
    p_comum: filtros.comumId || null,
    p_status: filtros.statusPresenca || null,
    p_limite: LIMITE_LINHAS,
  });
  if (error) throw new Error(mensagemDoErro(error, "Não foi possível gerar o relatório de presença."));

  const brutas = (data ?? []) as LinhaPresencaBanco[];
  return {
    linhas: brutas.map((linha) => ({
      evento_data: dataHora(linha.evento_data),
      evento_tipo: linha.evento_tipo,
      evento_local: linha.evento_local,
      evento_finalidade: texto(linha.evento_finalidade),
      regiao: texto(linha.regiao),
      setor: texto(linha.setor),
      comum: texto(linha.comum),
      membro: linha.membro_nome,
      membro_comum: texto(linha.membro_comum),
      cargo: texto(linha.cargo),
      instrumento: texto(linha.instrumento),
      familia: texto(linha.familia),
      cidade: texto(linha.cidade),
      visitante: simNao(linha.visitante),
      status: linha.status,
      entrada: dataHora(linha.hora_entrada),
      saida: dataHora(linha.hora_saida),
      origem: rotuloOrigem(linha.origem),
      registrado_por: texto(linha.registrado_por),
    })),
    total: brutas.length > 0 ? Number(brutas[0].total) : 0,
  };
}

interface LinhaMembroBanco {
  nome: string;
  cargo: string | null;
  instrumento: string | null;
  familia: string | null;
  regiao: string | null;
  setor: string | null;
  comum: string | null;
  cidade: string | null;
  bairro: string | null;
  status: string;
  visitante: boolean;
  data_nascimento: string | null;
  cadastrado_em: string;
  cpf_parcial: string | null;
  total: number | string;
}

async function buscarMembros(filtros: FiltrosRelatorio): Promise<ResultadoRelatorio> {
  const { data, error } = await supabase.rpc("relatorio_membros", {
    p_regiao: filtros.regiaoId || null,
    p_setor: filtros.setorId || null,
    p_comum: filtros.comumId || null,
    p_cargo: filtros.cargoId || null,
    p_instrumento: filtros.instrumentoId || null,
    p_status: filtros.situacao || null,
    p_visitante: filtros.visitante || null,
    p_limite: LIMITE_LINHAS,
  });
  if (error) throw new Error(mensagemDoErro(error, "Não foi possível gerar o relatório de membros."));

  const brutas = (data ?? []) as LinhaMembroBanco[];
  return {
    linhas: brutas.map((linha) => ({
      nome: linha.nome,
      cargo: texto(linha.cargo),
      instrumento: texto(linha.instrumento),
      familia: texto(linha.familia),
      regiao: texto(linha.regiao),
      setor: texto(linha.setor),
      comum: texto(linha.comum),
      cidade: texto(linha.cidade),
      bairro: texto(linha.bairro),
      status: linha.status,
      visitante: simNao(linha.visitante),
      data_nascimento: dataBr(linha.data_nascimento),
      cadastrado_em: dataHora(linha.cadastrado_em),
      cpf_parcial: texto(linha.cpf_parcial),
    })),
    total: brutas.length > 0 ? Number(brutas[0].total) : 0,
  };
}

interface LinhaEventoBanco {
  tipo: string;
  data_evento: string;
  local_evento: string;
  finalidade: string | null;
  cidade: string | null;
  regiao: string | null;
  setor: string | null;
  comum: string | null;
  registros: number | string;
  presentes: number | string;
  portaria: string | null;
  total: number | string;
}

async function buscarEventos(filtros: FiltrosRelatorio): Promise<ResultadoRelatorio> {
  const periodo = intervaloDoFiltro(filtros.inicio, filtros.fim);
  const { data, error } = await supabase.rpc("relatorio_eventos", {
    p_inicio: periodo.inicio,
    p_fim: periodo.fim,
    p_regiao: filtros.regiaoId || null,
    p_setor: filtros.setorId || null,
    p_comum: filtros.comumId || null,
    p_limite: LIMITE_LINHAS,
  });
  if (error) throw new Error(mensagemDoErro(error, "Não foi possível gerar o relatório de eventos."));

  const brutas = (data ?? []) as LinhaEventoBanco[];
  return {
    linhas: brutas.map((linha) => ({
      data: dataHora(linha.data_evento),
      tipo: linha.tipo,
      local: linha.local_evento,
      finalidade: texto(linha.finalidade),
      cidade: texto(linha.cidade),
      regiao: texto(linha.regiao),
      setor: texto(linha.setor),
      comum: texto(linha.comum),
      registros: String(Number(linha.registros)),
      presentes: String(Number(linha.presentes)),
      portaria: linha.portaria ?? "Sem portaria",
    })),
    total: brutas.length > 0 ? Number(brutas[0].total) : 0,
  };
}

// ---------- Relatórios de cadastros simples ----------

/** Contagem de membros por instrumento e por cargo (só a abrangência do usuário). Sem permissão, fica vazia. */
async function contagensDeMembros(): Promise<{ porInstrumento: Map<string, number>; porCargo: Map<string, number> }> {
  const { data, error } = await supabase.rpc("contagem_membros_por");
  const porInstrumento = new Map<string, number>();
  const porCargo = new Map<string, number>();
  if (error) return { porInstrumento, porCargo };

  for (const linha of (data ?? []) as { tipo: string; id: string; qtd: number | string }[]) {
    (linha.tipo === "INSTRUMENTO" ? porInstrumento : porCargo).set(linha.id, Number(linha.qtd));
  }
  return { porInstrumento, porCargo };
}

async function buscarInstrumentos(): Promise<ResultadoRelatorio> {
  const [resInstrumentos, resFamilias, contagens] = await Promise.all([
    supabase.from("instrumentos").select("*"),
    supabase.from("familias").select("*"),
    contagensDeMembros(),
  ]);
  const erro = resInstrumentos.error ?? resFamilias.error;
  if (erro) throw new Error(mensagemDoErro(erro, "Não foi possível carregar os instrumentos."));

  const linhas = linhasInstrumentos(
    (resInstrumentos.data ?? []) as Instrumento[],
    (resFamilias.data ?? []) as Familia[],
    contagens.porInstrumento
  );
  return { linhas, total: linhas.length };
}

async function buscarCargos(): Promise<ResultadoRelatorio> {
  const [resCargos, contagens] = await Promise.all([supabase.from("cargos").select("*"), contagensDeMembros()]);
  if (resCargos.error) throw new Error(mensagemDoErro(resCargos.error, "Não foi possível carregar os cargos."));

  const linhas = linhasCargos((resCargos.data ?? []) as CargoRelatorio[], contagens.porCargo);
  return { linhas, total: linhas.length };
}

async function buscarOrganizacao(filtros: FiltrosRelatorio): Promise<ResultadoRelatorio> {
  const nos = await listarOrganizacao();
  const linhas = linhasOrganizacao(nos, { regiaoId: filtros.regiaoId, setorId: filtros.setorId });
  return { linhas, total: linhas.length };
}

async function buscarPortarias(filtros: FiltrosRelatorio): Promise<ResultadoRelatorio> {
  const linhas = linhasPortarias(await listarPortarias(), filtros);
  return { linhas, total: linhas.length };
}

/** Busca os dados de um tipo de relatório (as linhas já vêm em texto, pelo id de cada coluna). */
export async function buscarRelatorio(
  tipo: TipoRelatorioId,
  filtros: FiltrosRelatorio
): Promise<ResultadoRelatorio> {
  switch (tipo) {
    case "presenca":
      return buscarPresencas(filtros);
    case "membros":
      return buscarMembros(filtros);
    case "eventos":
      return buscarEventos(filtros);
    case "instrumentos":
      return buscarInstrumentos();
    case "cargos":
      return buscarCargos();
    case "organizacao":
      return buscarOrganizacao(filtros);
    case "portarias":
      return buscarPortarias(filtros);
  }
}

// Mantém a assinatura clara para quem importar só os tipos
export type { LinhaRelatorio };

// Evita aviso de importação não usada de contarPor (usada nos testes e disponível aos serviços)
void contarPor;
