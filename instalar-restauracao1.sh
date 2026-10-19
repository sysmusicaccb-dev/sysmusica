cd /workspaces/sysmusica/sysmusica || { echo "Pasta do projeto não encontrada"; exit 1; }
(
set -u
BKP="/tmp/bkp-restauracao1-$(date +%H%M%S)"; mkdir -p "$BKP/a"
ALT=("src/modules/backup/components/AbasBackup.tsx")
for f in "${ALT[@]}"; do mkdir -p "$BKP/a/$(dirname "$f")"; cp "$f" "$BKP/a/$f"; done

reverter() {
  echo ">>> REVERTENDO tudo (nada do que foi tentado fica no projeto)"
  for f in "${ALT[@]}"; do cp "$BKP/a/$f" "$f"; done
  rm -rf "src/app/api/backup/restauracao" "src/app/(painel)/administracao/backup/restauracao"
  rm -f src/modules/backup/restauracao.ts src/modules/backup/restauracao.test.ts \
        src/modules/backup/server/restauracao.ts src/modules/backup/services/restauracaoApi.ts
  echo ">>> REVERTIDO. Me mande o log: /tmp/restauracao1-instalar.log"
}

echo "=== 0) Conferência prévia (só leitura) ==="
for f in "${ALT[@]}" "src/app/(painel)/administracao/backup/destinos/layout.tsx" src/modules/backup/server/rota.ts src/modules/backup/cripto.ts; do
  [ -f "$f" ] || { echo "ERRO: arquivo esperado não existe: $f"; exit 1; }
done
[ -e src/modules/backup/restauracao.ts ] && { echo "ERRO: a restauração já parece instalada."; exit 1; }
grep -n "backup.restaurar" src/lib/permissoes.ts | head -3

echo; echo "=== 1) Gravando os arquivos ==="
python3 - <<'PYSCRIPT'
import os, sys
NOVOS = {
  'src/modules/backup/restauracao.ts': r"""/**
 * SysMúsica — Restauração do Backup, parte 1 (comparar): regras puras, sem banco nem rede.
 * Compara os dados de UMA tabela no backup com os dados de hoje e separa:
 *   - APAGADOS: estavam no backup e hoje não existem (ou foram excluídos logicamente depois do backup);
 *   - ALTERADOS: existem nos dois, mas com colunas diferentes;
 *   - NOVOS: existem hoje e não estavam no backup (criados depois).
 * "Somente as últimas alterações" é exatamente isto: só as linhas que diferem. Nada é alterado por aqui.
 * Colunas sensíveis (CPF, segredo do QR...) nunca aparecem: viram "(protegido)".
 */
import { chaveDaLinha, type DefinicaoTabela, type GrupoDados, type NomeTabela } from "./tabelas";

export type Linha = Record<string, unknown>;

export const LIMITE_AMOSTRA = 100; // itens de cada categoria que vão para a tela (os totais são sempre exatos)
const MAX_COLUNAS = 12; // colunas mostradas por linha alterada
const MAX_TEXTO = 80;

export interface DiferencaColuna {
  coluna: string;
  antes: string; // valor no backup
  depois: string; // valor de hoje
}

export interface ItemDiferenca {
  chave: string;
  rotulo: string;
  detalhe?: string;
  colunas?: DiferencaColuna[];
}

export interface ResultadoTabela {
  nome: NomeTabela;
  rotulo: string;
  ausente: boolean; // o backup não tem esta tabela (backup antigo): nada a comparar
  noBackup: number;
  hoje: number;
  apagados: number;
  alterados: number;
  novos: number;
  amostraApagados: ItemDiferenca[];
  amostraAlterados: ItemDiferenca[];
  amostraNovos: ItemDiferenca[];
}

export interface ResultadoGrupo {
  id: GrupoDados;
  rotulo: string;
  tabelas: ResultadoTabela[];
}

export interface ResultadoComparacao {
  backup: { id: string; criado_em: string; tipo: string };
  grupos: ResultadoGrupo[];
  totais: { apagados: number; alterados: number; novos: number };
}

/** Texto estável de um valor (chaves de objetos em ordem), para comparar sem falso alarme. */
function canonico(valor: unknown): string {
  if (valor === null || valor === undefined) return "null";
  if (Array.isArray(valor)) return `[${valor.map(canonico).join(",")}]`;
  if (typeof valor === "object") {
    const o = valor as Record<string, unknown>;
    return `{${Object.keys(o).sort().map((k) => `${JSON.stringify(k)}:${canonico(o[k])}`).join(",")}}`;
  }
  return JSON.stringify(valor);
}

function mostrar(def: DefinicaoTabela, coluna: string, valor: unknown): string {
  if (def.sensiveis.includes(coluna)) return "(protegido)";
  if (valor === null || valor === undefined || valor === "") return "(vazio)";
  const texto = typeof valor === "string" ? valor : canonico(valor);
  return texto.length > MAX_TEXTO ? `${texto.slice(0, MAX_TEXTO)}…` : texto;
}

const CAMPOS_ROTULO = ["nome", "titulo", "descricao", "email", "login", "codigo", "permissao_codigo", "sigla"];

/** Um nome legível para a linha (nunca usa colunas sensíveis); na falta, a própria chave. */
export function rotuloDaLinha(def: DefinicaoTabela, linha: Linha): string {
  for (const campo of CAMPOS_ROTULO) {
    const valor = linha[campo];
    if (typeof valor === "string" && valor.trim() !== "" && !def.sensiveis.includes(campo)) return valor.trim().slice(0, 80);
  }
  return chaveDaLinha(def, linha);
}

// Colunas (informadas pelo backup) cujo valor hoje é diferente
function colunasDiferentes(def: DefinicaoTabela, antes: Linha, hoje: Linha): DiferencaColuna[] {
  const lista: DiferencaColuna[] = [];
  for (const coluna of Object.keys(antes)) {
    if (!(coluna in hoje)) continue; // coluna que não existe mais: ignorada
    if (canonico(antes[coluna]) !== canonico(hoje[coluna])) {
      lista.push({ coluna, antes: mostrar(def, coluna, antes[coluna]), depois: mostrar(def, coluna, hoje[coluna]) });
    }
  }
  return lista;
}

/** Compara uma tabela: `backup` = linhas do arquivo (undefined se o backup não tem a tabela), `hoje` = linhas atuais. */
export function compararTabela(def: DefinicaoTabela, backup: Linha[] | undefined, hoje: Linha[]): ResultadoTabela {
  const base = { nome: def.nome, rotulo: def.rotulo };
  if (backup === undefined) {
    return { ...base, ausente: true, noBackup: 0, hoje: hoje.length, apagados: 0, alterados: 0, novos: 0, amostraApagados: [], amostraAlterados: [], amostraNovos: [] };
  }

  const linhasHoje = new Map(hoje.map((linha) => [chaveDaLinha(def, linha), linha] as const));
  const linhasBackup = new Map(backup.map((linha) => [chaveDaLinha(def, linha), linha] as const));

  const apagados: ItemDiferenca[] = [];
  const alterados: ItemDiferenca[] = [];
  const novos: ItemDiferenca[] = [];

  for (const [chave, antes] of linhasBackup) {
    const atual = linhasHoje.get(chave);
    if (!atual) {
      apagados.push({ chave, rotulo: rotuloDaLinha(def, antes), detalhe: "não existe mais" });
      continue;
    }
    const diferencas = colunasDiferentes(def, antes, atual);
    if (diferencas.length === 0) continue;

    // Excluído logicamente depois do backup: conta como "apagado" (restaurar é desfazer a exclusão)
    const excluidoDepois = def.exclusaoLogica && (antes.excluido_em ?? null) === null && (atual.excluido_em ?? null) !== null;
    if (excluidoDepois) {
      apagados.push({ chave, rotulo: rotuloDaLinha(def, antes), detalhe: "excluído depois do backup" });
    } else {
      alterados.push({ chave, rotulo: rotuloDaLinha(def, antes), colunas: diferencas.slice(0, MAX_COLUNAS) });
    }
  }

  for (const [chave, atual] of linhasHoje) {
    if (linhasBackup.has(chave)) continue;
    // criado e já excluído depois do backup: não interessa
    if (def.exclusaoLogica && (atual.excluido_em ?? null) !== null) continue;
    novos.push({ chave, rotulo: rotuloDaLinha(def, atual), detalhe: "criado depois do backup" });
  }

  return {
    ...base,
    ausente: false,
    noBackup: backup.length,
    hoje: hoje.length,
    apagados: apagados.length,
    alterados: alterados.length,
    novos: novos.length,
    amostraApagados: apagados.slice(0, LIMITE_AMOSTRA),
    amostraAlterados: alterados.slice(0, LIMITE_AMOSTRA),
    amostraNovos: novos.slice(0, LIMITE_AMOSTRA),
  };
}

/** Soma dos totais de várias tabelas. */
export function somarTotais(tabelas: ResultadoTabela[]): { apagados: number; alterados: number; novos: number } {
  return tabelas.reduce(
    (soma, t) => ({ apagados: soma.apagados + t.apagados, alterados: soma.alterados + t.alterados, novos: soma.novos + t.novos }),
    { apagados: 0, alterados: 0, novos: 0 }
  );
}

/** Lê o corpo recebido pela rota (id do backup + grupos marcados); nulo se estiver errado. */
export function lerEntradaComparacao(valor: unknown, gruposValidos: string[]): { id: string; grupos: GrupoDados[] } | null {
  if (valor === null || typeof valor !== "object" || Array.isArray(valor)) return null;
  const o = valor as Record<string, unknown>;
  if (typeof o.id !== "string" || !Array.isArray(o.grupos) || o.grupos.length === 0 || o.grupos.length > 20) return null;
  const grupos: GrupoDados[] = [];
  for (const g of o.grupos) {
    if (typeof g !== "string" || !gruposValidos.includes(g)) return null;
    if (!grupos.includes(g as GrupoDados)) grupos.push(g as GrupoDados);
  }
  return { id: o.id, grupos };
}
""",
  'src/modules/backup/restauracao.test.ts': r"""import { describe, expect, it } from "vitest";
import { compararTabela, lerEntradaComparacao, rotuloDaLinha, somarTotais } from "./restauracao";
import { TABELAS, type DefinicaoTabela } from "./tabelas";

const def = (nome: string): DefinicaoTabela => {
  const achada = TABELAS.find((t) => t.nome === nome);
  if (!achada) throw new Error(`Tabela ${nome} não existe`);
  return achada;
};
const membros = def("membros");

describe("compararTabela", () => {
  it("sem diferença não aponta nada", () => {
    const linhas = [{ id: "1", nome: "Ana", excluido_em: null }];
    const r = compararTabela(membros, linhas, [...linhas]);
    expect([r.apagados, r.alterados, r.novos]).toEqual([0, 0, 0]);
  });

  it("separa apagados, alterados e novos", () => {
    const backup = [
      { id: "1", nome: "Ana", excluido_em: null },
      { id: "2", nome: "Bia", excluido_em: null },
      { id: "3", nome: "Caio", excluido_em: null },
    ];
    const hoje = [
      { id: "1", nome: "Ana Maria", excluido_em: null }, // alterado
      { id: "3", nome: "Caio", excluido_em: null }, // igual
      { id: "4", nome: "Davi", excluido_em: null }, // novo
    ]; // "2" sumiu: apagado
    const r = compararTabela(membros, backup, hoje);
    expect([r.apagados, r.alterados, r.novos]).toEqual([1, 1, 1]);
    expect(r.amostraApagados[0]).toMatchObject({ chave: "2", rotulo: "Bia" });
    expect(r.amostraAlterados[0].colunas).toEqual([{ coluna: "nome", antes: "Ana", depois: "Ana Maria" }]);
    expect(r.amostraNovos[0]).toMatchObject({ chave: "4", rotulo: "Davi" });
  });

  it("exclusão lógica depois do backup conta como apagado, não como alterado", () => {
    const backup = [{ id: "1", nome: "Ana", excluido_em: null }];
    const hoje = [{ id: "1", nome: "Ana", excluido_em: "2026-10-19T10:00:00Z" }];
    const r = compararTabela(membros, backup, hoje);
    expect([r.apagados, r.alterados]).toEqual([1, 0]);
    expect(r.amostraApagados[0].detalhe).toMatch(/excluído depois/);
  });

  it("registro criado e já excluído depois do backup é ignorado", () => {
    const r = compararTabela(membros, [], [{ id: "9", nome: "X", excluido_em: "2026-10-19T10:00:00Z" }]);
    expect(r.novos).toBe(0);
  });

  it("nunca mostra colunas sensíveis", () => {
    const backup = [{ id: "1", nome: "Ana", cpf: "11122233344", qr_secret: "abc", excluido_em: null }];
    const hoje = [{ id: "1", nome: "Ana", cpf: "99988877766", qr_secret: "xyz", excluido_em: null }];
    const r = compararTabela(membros, backup, hoje);
    const texto = JSON.stringify(r);
    expect(texto).not.toContain("11122233344");
    expect(texto).not.toContain("99988877766");
    expect(texto).not.toContain("xyz");
    expect(r.amostraAlterados[0].colunas?.every((c) => c.antes === "(protegido)" && c.depois === "(protegido)")).toBe(true);
  });

  it("o rótulo nunca usa uma coluna sensível", () => {
    expect(rotuloDaLinha({ ...membros, sensiveis: ["nome"] }, { id: "7", nome: "Segredo" })).toBe("7");
  });

  it("objetos iguais com chaves em outra ordem não contam como alteração", () => {
    const r = compararTabela(membros, [{ id: "1", extra: { a: 1, b: 2 } }], [{ id: "1", extra: { b: 2, a: 1 } }]);
    expect(r.alterados).toBe(0);
  });

  it("chave composta e tabela ausente no backup", () => {
    const perm = def("grupo_permissoes");
    const r = compararTabela(perm, [{ grupo_id: "g", permissao_codigo: "a" }, { grupo_id: "g", permissao_codigo: "b" }], [{ grupo_id: "g", permissao_codigo: "a" }]);
    expect(r.apagados).toBe(1);
    const ausente = compararTabela(perm, undefined, [{ grupo_id: "g", permissao_codigo: "a" }]);
    expect(ausente).toMatchObject({ ausente: true, apagados: 0, alterados: 0, novos: 0, hoje: 1 });
  });

  it("limita a amostra mas conta tudo", () => {
    const muitos = Array.from({ length: 250 }, (_, i) => ({ id: String(i), nome: `m${i}`, excluido_em: null }));
    const r = compararTabela(membros, muitos, []);
    expect(r.apagados).toBe(250);
    expect(r.amostraApagados).toHaveLength(100);
  });

  it("soma os totais", () => {
    const a = compararTabela(membros, [{ id: "1" }], []);
    const b = compararTabela(membros, [], [{ id: "2", excluido_em: null }]);
    expect(somarTotais([a, b])).toEqual({ apagados: 1, alterados: 0, novos: 1 });
  });
});

describe("lerEntradaComparacao", () => {
  const validos = ["membros", "usuarios"];
  it("aceita só grupos conhecidos, sem repetir", () => {
    expect(lerEntradaComparacao({ id: "x", grupos: ["membros", "membros", "usuarios"] }, validos)).toEqual({ id: "x", grupos: ["membros", "usuarios"] });
    expect(lerEntradaComparacao({ id: "x", grupos: ["tudo"] }, validos)).toBeNull();
    expect(lerEntradaComparacao({ id: "x", grupos: [] }, validos)).toBeNull();
    expect(lerEntradaComparacao({ id: 5, grupos: ["membros"] }, validos)).toBeNull();
    expect(lerEntradaComparacao(null, validos)).toBeNull();
  });
});
""",
  'src/modules/backup/server/restauracao.ts': r"""/**
 * SysMúsica — Restauração, parte 1 (comparar), lado do servidor. SOMENTE LEITURA: abre o arquivo do backup
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
async function lerTabelaAtual(admin: SupabaseClient, definicao: DefinicaoTabela): Promise<Linha[]> {
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
""",
  'src/modules/backup/services/restauracaoApi.ts': r"""/** SysMúsica — Chamada do navegador à rota de comparação da restauração (leva o token do login). */
import { supabase } from "@/lib/supabase";
import type { ResultadoComparacao } from "../restauracao";
import type { GrupoDados } from "../tabelas";

export async function compararBackup(id: string, grupos: GrupoDados[]): Promise<ResultadoComparacao> {
  const { data } = await supabase.auth.getSession();
  const token = data.session?.access_token;
  if (!token) throw new Error("Sua sessão expirou. Entre de novo.");

  const resposta = await fetch("/api/backup/restauracao/comparar", {
    method: "POST",
    headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json" },
    body: JSON.stringify({ id, grupos }),
    cache: "no-store",
  });
  const json = (await resposta.json().catch(() => null)) as (ResultadoComparacao & { erro?: string }) | null;
  if (!resposta.ok || !json) throw new Error(json?.erro ?? "Não foi possível comparar o backup.");
  return json;
}
""",
  'src/app/api/backup/restauracao/comparar/route.ts': r"""/**
 * SysMúsica — Rota /api/backup/restauracao/comparar: POST compara um backup com os dados de hoje (só leitura).
 * Somente o Administrador (permissão backup.restaurar, conferida no banco a cada chamada).
 */
import type { NextRequest } from "next/server";
import { autenticar } from "@/modules/backup/server/autorizacao";
import { ErroBackup } from "@/modules/backup/server/erros";
import { responder } from "@/modules/backup/server/rota";
import { compararBackup } from "@/modules/backup/server/restauracao";
import { lerEntradaComparacao } from "@/modules/backup/restauracao";
import { GRUPOS_DADOS } from "@/modules/backup/tabelas";

export const maxDuration = 60;

export async function POST(request: NextRequest) {
  return responder(async () => {
    await autenticar(request, "backup.restaurar");
    const corpo: unknown = await request.json().catch(() => null);
    const entrada = lerEntradaComparacao(
      corpo,
      GRUPOS_DADOS.map((g) => g.id)
    );
    if (!entrada) throw new ErroBackup(400, "Escolha um backup e pelo menos um grupo de dados.");
    return await compararBackup(entrada.id, entrada.grupos);
  });
}
""",
  'src/app/(painel)/administracao/backup/restauracao/page.tsx': r""""use client";

/**
 * SysMúsica — Página /administracao/backup/restauracao (só o Administrador): escolhe um backup e os grupos
 * de dados e mostra o que mudou desde então (apagado, alterado, novo). Nesta etapa NADA é restaurado:
 * a tela só lê e compara. CPF e segredos aparecem como "(protegido)".
 */
import { useEffect, useState } from "react";
import ErrorState from "@/components/ui/ErrorState";
import PageHeader from "@/components/ui/PageHeader";
import Skeleton from "@/components/ui/Skeleton";
import { useSessao } from "@/modules/autenticacao/SessaoProvider";
import AbasBackup from "@/modules/backup/components/AbasBackup";
import { dataHoraSalvador, ROTULO_TIPO } from "@/modules/backup/regras";
import type { ItemDiferenca, ResultadoComparacao, ResultadoTabela } from "@/modules/backup/restauracao";
import { listarBackups } from "@/modules/backup/services/backupApi";
import { compararBackup } from "@/modules/backup/services/restauracaoApi";
import { GRUPOS_DADOS, type GrupoDados } from "@/modules/backup/tabelas";
import type { RegistroBackup } from "@/modules/backup/tipos";

const classeBotaoPrimario =
  "inline-flex items-center gap-2 rounded-lg bg-brand-600 px-3 py-2 text-sm font-medium text-white transition " +
  "hover:bg-brand-700 disabled:cursor-not-allowed disabled:opacity-60";

function rotuloBackup(b: RegistroBackup): string {
  const tipo = (ROTULO_TIPO as Record<string, string>)[b.tipo] ?? b.tipo;
  return `${dataHoraSalvador(new Date(b.criado_em))} — ${tipo}`;
}

function Etiqueta({ n, texto, classe }: { n: number; texto: string; classe: string }) {
  if (n === 0) return null;
  return <span className={`rounded-full px-2 py-0.5 text-xs font-medium ${classe}`}>{n} {texto}</span>;
}

function Lista({ titulo, itens, total, classe }: { titulo: string; itens: ItemDiferenca[]; total: number; classe: string }) {
  if (total === 0) return null;
  return (
    <div className="mt-3">
      <h4 className={`text-xs font-semibold uppercase tracking-wide ${classe}`}>{titulo} ({total})</h4>
      <ul className="mt-1 divide-y divide-slate-100 rounded-lg border border-slate-200 bg-white text-sm">
        {itens.map((item) => (
          <li key={item.chave} className="px-3 py-2">
            <p className="font-medium text-slate-800">{item.rotulo}</p>
            {item.detalhe && <p className="text-xs text-slate-500">{item.detalhe}</p>}
            {item.colunas && (
              <ul className="mt-1 space-y-0.5 text-xs text-slate-600">
                {item.colunas.map((c) => (
                  <li key={c.coluna}>
                    <span className="font-medium">{c.coluna}:</span> {c.antes} <span className="text-slate-400">→ hoje:</span> {c.depois}
                  </li>
                ))}
              </ul>
            )}
          </li>
        ))}
      </ul>
      {itens.length < total && <p className="mt-1 text-xs text-slate-500">Mostrando {itens.length} de {total}.</p>}
    </div>
  );
}

function CartaoTabela({ t }: { t: ResultadoTabela }) {
  const semMudanca = t.apagados + t.alterados + t.novos === 0;
  return (
    <details className="rounded-lg border border-slate-200 bg-slate-50 px-3 py-2">
      <summary className="flex cursor-pointer flex-wrap items-center gap-2 text-sm font-medium text-slate-800">
        <span>{t.rotulo}</span>
        {t.ausente ? (
          <span className="text-xs font-normal text-slate-500">(este backup não tem esta tabela)</span>
        ) : semMudanca ? (
          <span className="text-xs font-normal text-emerald-700">sem diferenças ({t.noBackup} no backup)</span>
        ) : (
          <>
            <Etiqueta n={t.apagados} texto="apagados" classe="bg-red-100 text-red-700" />
            <Etiqueta n={t.alterados} texto="alterados" classe="bg-amber-100 text-amber-700" />
            <Etiqueta n={t.novos} texto="novos" classe="bg-sky-100 text-sky-700" />
          </>
        )}
      </summary>
      {!t.ausente && !semMudanca && (
        <div className="pb-2">
          <p className="mt-2 text-xs text-slate-500">No backup: {t.noBackup} registros. Hoje: {t.hoje}.</p>
          <Lista titulo="Apagados desde o backup" itens={t.amostraApagados} total={t.apagados} classe="text-red-700" />
          <Lista titulo="Alterados desde o backup" itens={t.amostraAlterados} total={t.alterados} classe="text-amber-700" />
          <Lista titulo="Novos (criados depois do backup)" itens={t.amostraNovos} total={t.novos} classe="text-sky-700" />
        </div>
      )}
    </details>
  );
}

export default function PaginaRestauracao() {
  const { pode } = useSessao();
  const [backups, setBackups] = useState<RegistroBackup[] | null>(null);
  const [erro, setErro] = useState<string | null>(null);
  const [escolhido, setEscolhido] = useState("");
  const [grupos, setGrupos] = useState<GrupoDados[]>(GRUPOS_DADOS.map((g) => g.id));
  const [comparando, setComparando] = useState(false);
  const [erroAcao, setErroAcao] = useState<string | null>(null);
  const [resultado, setResultado] = useState<ResultadoComparacao | null>(null);

  const [tentativa, setTentativa] = useState(0); // muda para recarregar a lista

  // Busca os backups; o estado só é alterado dentro das respostas (nunca direto no corpo do efeito)
  useEffect(() => {
    let ativo = true;
    listarBackups()
      .then((todos) => {
        if (!ativo) return;
        const lista = todos.filter((b) => b.situacao === "ok");
        setBackups(lista);
        setEscolhido((atual) => atual || lista[0]?.id || "");
        setErro(null);
      })
      .catch((e: unknown) => {
        if (ativo) setErro(e instanceof Error ? e.message : "Não foi possível carregar os backups.");
      });
    return () => {
      ativo = false;
    };
  }, [tentativa]);

  function alternar(id: GrupoDados) {
    setGrupos((atual) => (atual.includes(id) ? atual.filter((g) => g !== id) : [...atual, id]));
    setResultado(null);
  }

  async function aoComparar() {
    setComparando(true);
    setErroAcao(null);
    setResultado(null);
    try {
      setResultado(await compararBackup(escolhido, grupos));
    } catch (e) {
      setErroAcao(e instanceof Error ? e.message : "Não foi possível comparar.");
    } finally {
      setComparando(false);
    }
  }

  return (
    <main className="text-slate-900">
      <div className="mx-auto max-w-6xl px-4 py-8 sm:px-6 lg:px-8">
        <PageHeader
          titulo="Backup"
          descricao="Compare um backup com os dados de hoje. Somente o Administrador tem acesso."
        />
        <AbasBackup />

        <p className="mb-4 rounded-lg bg-slate-50 px-3 py-2 text-sm text-slate-600">
          Esta etapa só <strong>compara</strong>: nada é restaurado nem alterado. Mostra o que foi apagado, alterado ou
          criado depois do backup escolhido. CPF e segredos aparecem como &quot;(protegido)&quot;.
        </p>

        {!pode("backup.restaurar") ? (
          <p role="alert" className="rounded-lg bg-red-50 px-3 py-2 text-sm text-red-700">
            Somente o Administrador pode usar a restauração.
          </p>
        ) : erro ? (
          <ErrorState titulo="Não foi possível carregar os backups." mensagem={erro} onTentarNovamente={() => { setErro(null); setTentativa((n) => n + 1); }} />
        ) : !backups ? (
          <div role="status" aria-live="polite" className="space-y-3">
            <span className="sr-only">Carregando os backups...</span>
            <Skeleton className="h-24" />
            <Skeleton className="h-24" />
          </div>
        ) : backups.length === 0 ? (
          <p className="rounded-lg bg-slate-50 px-3 py-2 text-sm text-slate-600">Ainda não há backups para comparar.</p>
        ) : (
          <div className="space-y-6">
            <section className="space-y-4 rounded-xl border border-slate-200 bg-white p-4">
              <div className="max-w-md space-y-1.5">
                <label htmlFor="rest-backup" className="text-xs font-medium text-slate-600">Backup</label>
                <select
                  id="rest-backup"
                  value={escolhido}
                  onChange={(e) => { setEscolhido(e.target.value); setResultado(null); }}
                  disabled={comparando}
                  className="w-full rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm"
                >
                  {backups.map((b) => (
                    <option key={b.id} value={b.id}>{rotuloBackup(b)}</option>
                  ))}
                </select>
              </div>

              <fieldset className="space-y-2">
                <legend className="text-xs font-medium text-slate-600">O que comparar</legend>
                <div className="grid gap-2 sm:grid-cols-2">
                  {GRUPOS_DADOS.map((g) => (
                    <label key={g.id} className="flex items-start gap-2 rounded-lg border border-slate-200 px-3 py-2 text-sm">
                      <input
                        type="checkbox"
                        checked={grupos.includes(g.id)}
                        onChange={() => alternar(g.id)}
                        disabled={comparando}
                        className="mt-0.5"
                      />
                      <span>
                        <span className="font-medium text-slate-800">{g.rotulo}</span>
                        <span className="block text-xs text-slate-500">{g.descricao}</span>
                      </span>
                    </label>
                  ))}
                </div>
              </fieldset>

              <button type="button" className={classeBotaoPrimario} onClick={() => void aoComparar()} disabled={comparando || !escolhido || grupos.length === 0}>
                {comparando ? "Comparando..." : "Comparar com os dados de hoje"}
              </button>
              {erroAcao && (
                <p role="alert" className="rounded-lg bg-red-50 px-3 py-2 text-sm text-red-700">{erroAcao}</p>
              )}
            </section>

            {resultado && (
              <section className="space-y-4" aria-live="polite">
                <p className="rounded-lg bg-slate-50 px-3 py-2 text-sm text-slate-700">
                  Backup de {dataHoraSalvador(new Date(resultado.backup.criado_em))}:{" "}
                  <strong>{resultado.totais.apagados}</strong> apagados, <strong>{resultado.totais.alterados}</strong> alterados e{" "}
                  <strong>{resultado.totais.novos}</strong> novos desde então.
                </p>
                {resultado.grupos.map((g) => (
                  <div key={g.id} className="space-y-2">
                    <h3 className="text-sm font-semibold text-slate-800">{g.rotulo}</h3>
                    {g.tabelas.map((t) => (
                      <CartaoTabela key={t.nome} t={t} />
                    ))}
                  </div>
                ))}
              </section>
            )}
          </div>
        )}
      </div>
    </main>
  );
}
""",
}

def abrir(c):
    return open(c, encoding="utf-8").read()

# aba "Restauração" (só quem tem backup.restaurar), logo depois da aba Agendamento
aba = "src/modules/backup/components/AbasBackup.tsx"
linhas = abrir(aba).split("\n")
alvo = [i for i, l in enumerate(linhas) if 'rotulo: "Agendamento"' in l]
if len(alvo) != 1:
    print("ERRO: não achei uma única linha da aba Agendamento em AbasBackup.tsx:", alvo); sys.exit(1)
if "restauracao" in abrir(aba):
    print("ERRO: a aba Restauração já existe."); sys.exit(1)
i = alvo[0]
recuo = linhas[i][: len(linhas[i]) - len(linhas[i].lstrip())]
linhas.insert(i + 1, recuo + '{ href: "/administracao/backup/restauracao", rotulo: "Restauração", permissao: "backup.restaurar" },')
alterado = "\n".join(linhas)

for caminho in NOVOS:
    if os.path.exists(caminho):
        print("ERRO: já existe", caminho); sys.exit(1)
for caminho, conteudo in NOVOS.items():
    os.makedirs(os.path.dirname(caminho) or ".", exist_ok=True)
    open(caminho, "w", encoding="utf-8").write(conteudo)
open(aba, "w", encoding="utf-8").write(alterado)

# layout da nova página: cópia do layout dos Destinos (só o nome muda)
lay = abrir("src/app/(painel)/administracao/backup/destinos/layout.tsx").replace("Destinos", "Restauração").replace("destinos", "restauracao")
open("src/app/(painel)/administracao/backup/restauracao/layout.tsx", "w", encoding="utf-8").write(lay)
print("Arquivos gravados:", len(NOVOS) + 1, "novos, 1 alterado.")
PYSCRIPT
[ $? -eq 0 ] || { reverter; exit 1; }

echo; echo "=== 2) Parando o servidor de teste e limpando o cache ==="
pkill -f "next dev" 2>/dev/null; pkill -f next-server 2>/dev/null; pkill -f "next/dist" 2>/dev/null; sleep 2
for i in 1 2 3 4 5; do rm -rf .next 2>/dev/null; [ -d .next ] || break; sleep 1; done

echo; echo "=== 3) Conferência de tipos ==="
npx tsc --noEmit || { reverter; exit 1; }
echo; echo "=== 4) Testes automáticos ==="
npx vitest run src/modules/backup || { reverter; exit 1; }
echo; echo "=== 5) Lint ==="
npx eslint "${ALT[@]}" src/modules/backup/restauracao.ts src/modules/backup/restauracao.test.ts src/modules/backup/server/restauracao.ts \
  src/modules/backup/services/restauracaoApi.ts "src/app/(painel)/administracao/backup/restauracao" src/app/api/backup/restauracao || { reverter; exit 1; }
echo; echo "=== 6) Build de produção (pode demorar alguns minutos) ==="
npm run build || { reverter; exit 1; }

echo; echo "=== TUDO CERTO: arquivos instalados e conferidos ==="
git status --short
) 2>&1 | tee /tmp/restauracao1-instalar.log
