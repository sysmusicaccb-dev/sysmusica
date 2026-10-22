/**
 * Sysmusica — Restauração, parte 1 (comparar), lado do servidor. SOMENTE LEITURA: abre o arquivo do backup
 * escolhido e compara, tabela por tabela, com os dados de hoje. Não altera nada no banco nem no armazenamento.
 */
import type { SupabaseClient } from "@supabase/supabase-js";
import { abrirBackup, lerChave } from "../cripto";
import { idValido, lerPacote } from "../regras";
import {
  compararTabela,
  somarTotais,
  type Linha,
  type ResultadoComparacao,
  type ResultadoGrupo,
  type ResultadoTabela,
} from "../restauracao";
import { GRUPOS_DADOS, tabelasDoGrupo, type DefinicaoTabela, type GrupoDados } from "../tabelas";
import { clienteAdmin } from "./clienteAdmin";
import { ErroBackup } from "./erros";

const BUCKET = "backups";
const TAMANHO_PAGINA = 1000;
const LIMITE_LINHAS = 500_000;

// Lê uma tabela inteira de hoje, de mil em mil linhas, em ordem estável
export async function lerTabelaAtual(admin: SupabaseClient, definicao: DefinicaoTabela): Promise<Linha[]> {
  const linhas: Linha[] = [];
  let inicio = 0;
  while (inicio < LIMITE_LINHAS) {
    let consulta = admin.from(definicao.nome).select("*");
    for (const coluna of definicao.pk) consulta = consulta.order(coluna, { ascending: true });
    const { data, error } = await consulta.range(inicio, inicio + TAMANHO_PAGINA - 1);
    if (error) throw new ErroBackup(500, `Não foi possível ler a tabela ${definicao.rotulo}.`);
    const pagina = (data ?? []) as Linha[];
    if (pagina.length === 0) return linhas;
    linhas.push(...pagina);
    inicio += pagina.length;
  }
  throw new ErroBackup(500, `A tabela ${definicao.rotulo} passou do limite de ${LIMITE_LINHAS} linhas.`);
}

/** Compara o backup escolhido com os dados de hoje, nos grupos marcados. Não altera nada. */
export async function compararBackup(id: string, grupos: GrupoDados[]): Promise<ResultadoComparacao> {
  if (!idValido(id)) throw new ErroBackup(400, "Identificador de backup inválido.");
  const admin = clienteAdmin();

  const { data: linha, error } = await admin
    .from("backup_arquivos")
    .select("id, criado_em, tipo, situacao, caminho")
    .eq("id", id)
    .maybeSingle();
  if (error) throw new ErroBackup(500, "Não foi possível consultar o backup.");
  if (!linha) throw new ErroBackup(404, "Backup não encontrado.");
  if (linha.situacao !== "ok" || !linha.caminho) throw new ErroBackup(400, "Este backup não tem arquivo utilizável.");

  let chave: Buffer;
  try {
    chave = lerChave(process.env.BACKUP_CHAVE);
  } catch (e) {
    throw new ErroBackup(500, e instanceof Error ? e.message : "A chave dos backups não está configurada.");
  }

  const baixado = await admin.storage.from(BUCKET).download(String(linha.caminho));
  if (baixado.error || !baixado.data) throw new ErroBackup(500, "Não foi possível ler o arquivo do backup no armazenamento.");
  const arquivo = Buffer.from(await baixado.data.arrayBuffer());

  let tabelasDoArquivo: Record<string, Linha[]>;
  try {
    tabelasDoArquivo = lerPacote(abrirBackup(arquivo, chave).toString("utf8")).tabelas;
  } catch (e) {
    throw new ErroBackup(500, e instanceof Error ? e.message : "Não foi possível abrir o backup.");
  }

  const resultado: ResultadoGrupo[] = [];
  const todas: ResultadoTabela[] = [];
  for (const grupo of GRUPOS_DADOS.filter((g) => grupos.includes(g.id))) {
    const tabelas: ResultadoTabela[] = [];
    for (const definicao of tabelasDoGrupo(grupo.id)) {
      const doBackup: Linha[] | undefined = tabelasDoArquivo[definicao.nome];
      const hoje = await lerTabelaAtual(admin, definicao);
      tabelas.push(compararTabela(definicao, doBackup, hoje));
    }
    todas.push(...tabelas);
    resultado.push({ id: grupo.id, rotulo: grupo.rotulo, tabelas });
  }

  return {
    backup: { id: String(linha.id), criado_em: String(linha.criado_em), tipo: String(linha.tipo) },
    grupos: resultado,
    totais: somarTotais(todas),
  };
}
