cd /workspaces/sysmusica/sysmusica || { echo "Pasta do projeto não encontrada"; exit 1; }
(
set -u
BKP="/tmp/bkp-restauracao2-$(date +%H%M%S)"; mkdir -p "$BKP/a"
ALT=("src/modules/backup/server/restauracao.ts" "src/app/(painel)/administracao/backup/restauracao/page.tsx")
for f in "${ALT[@]}"; do mkdir -p "$BKP/a/$(dirname "$f")"; cp "$f" "$BKP/a/$f"; done

reverter() {
  echo ">>> REVERTENDO tudo (nada do que foi tentado fica no projeto)"
  for f in "${ALT[@]}"; do cp "$BKP/a/$f" "$f"; done
  rm -rf "src/app/api/backup/restauracao/aplicar"
  rm -f src/modules/backup/aplicacao.ts src/modules/backup/aplicacao.test.ts src/modules/backup/server/aplicacao.ts \
        src/modules/backup/services/restauracaoAplicarApi.ts src/modules/backup/components/PainelRestaurar.tsx
  echo ">>> REVERTIDO. Me mande o log: /tmp/restauracao2-instalar.log"
}

echo "=== 0) Conferência prévia (só leitura) ==="
for f in "${ALT[@]}" src/modules/backup/server/operacoes.ts src/modules/backup/server/notificar.ts; do
  [ -f "$f" ] || { echo "ERRO: arquivo esperado não existe: $f (a etapa 1 foi instalada?)"; exit 1; }
done
[ -e src/modules/backup/aplicacao.ts ] && { echo "ERRO: a etapa 2 já parece instalada."; exit 1; }
echo "Variáveis do Supabase no .env.local (só os NOMES):"
grep -o "^[A-Z_]*SUPABASE[A-Z_]*" .env.local 2>/dev/null | sort -u

echo; echo "=== 1) Gravando os arquivos ==="
python3 - <<'PYSCRIPT'
import os, sys
NOVOS = {
  'src/modules/backup/aplicacao.ts': r"""/**
 * SysMúsica — Restauração, parte 2 (aplicar): regras puras que transformam a comparação em um PLANO de
 * operações para a função backup_aplicar do banco (uma única transação: ou tudo, ou nada).
 *
 * Dois modos:
 *   - RECUPERAR (padrão, seguro): devolve o que foi apagado e desfaz as alterações. NÃO mexe no que foi criado
 *     depois do backup.
 *   - ESPELHAR: além do acima, remove o que foi criado depois do backup (os dados ficam idênticos ao backup).
 *     Nunca remove usuários nem o histórico das portarias.
 */
import { chaveDaLinha, ordenarParaApagar, ordenarParaGravar, type DefinicaoTabela, type GrupoDados, type NomeTabela } from "./tabelas";
import type { Linha } from "./restauracao";

export type ModoRestauracao = "recuperar" | "espelhar";
export const TEXTO_ESPELHAR = "ESPELHAR";

export type AcaoBanco = "inserir" | "atualizar" | "excluir_logico" | "excluir";

export interface OperacaoBanco {
  tabela: NomeTabela;
  acao: AcaoBanco;
  colunas: string[];
  linhas: Linha[];
}

export interface EntradaAplicacao {
  id: string;
  grupos: GrupoDados[];
  modo: ModoRestauracao;
  senha: string;
}

export interface ResultadoOperacao {
  tabela: string;
  acao: string;
  afetados: number;
  ignorados: number;
}

export interface RespostaRestauracao {
  restaurado: boolean;
  mensagem: string;
  operacoes: ResultadoOperacao[];
  segurancaId: string | null;
}

// Tabelas em que o modo Espelhar nunca remove nada
const NUNCA_REMOVER: NomeTabela[] = ["usuarios"];

function canonico(valor: unknown): string {
  if (valor === null || valor === undefined) return "null";
  if (Array.isArray(valor)) return `[${valor.map(canonico).join(",")}]`;
  if (typeof valor === "object") {
    const o = valor as Record<string, unknown>;
    return `{${Object.keys(o).sort().map((k) => `${JSON.stringify(k)}:${canonico(o[k])}`).join(",")}}`;
  }
  return JSON.stringify(valor);
}

function diferente(antes: Linha, hoje: Linha): boolean {
  return Object.keys(antes).some((c) => c in hoje && canonico(antes[c]) !== canonico(hoje[c]));
}

/** Lê o corpo recebido pela rota; nulo se estiver errado. */
export function lerEntradaAplicacao(valor: unknown, gruposValidos: string[]): (EntradaAplicacao & { confirmacao: string }) | null {
  if (valor === null || typeof valor !== "object" || Array.isArray(valor)) return null;
  const o = valor as Record<string, unknown>;
  if (typeof o.id !== "string" || typeof o.senha !== "string" || o.senha === "" || o.senha.length > 200) return null;
  if (o.modo !== "recuperar" && o.modo !== "espelhar") return null;
  if (!Array.isArray(o.grupos) || o.grupos.length === 0 || o.grupos.length > 20) return null;
  const confirmacao = typeof o.confirmacao === "string" ? o.confirmacao : "";
  if (o.modo === "espelhar" && confirmacao !== TEXTO_ESPELHAR) return null;
  const grupos: GrupoDados[] = [];
  for (const g of o.grupos) {
    if (typeof g !== "string" || !gruposValidos.includes(g)) return null;
    if (!grupos.includes(g as GrupoDados)) grupos.push(g as GrupoDados);
  }
  return { id: o.id, grupos, modo: o.modo, senha: o.senha, confirmacao };
}

export interface EntradaTabela {
  def: DefinicaoTabela;
  backup: Linha[] | undefined; // linhas do arquivo (undefined = o backup não tem a tabela: nada a fazer)
  hoje: Linha[];
}

function uniaoDeColunas(linhas: Linha[]): string[] {
  const todas = new Set<string>();
  for (const l of linhas) for (const c of Object.keys(l)) todas.add(c);
  return [...todas];
}

/** Plano de uma tabela: o que devolver, o que desfazer e (no modo Espelhar) o que remover. */
export function planoDaTabela(entrada: EntradaTabela, modo: ModoRestauracao): { inserir: Linha[]; atualizar: Linha[]; remover: Linha[] } {
  const { def, backup, hoje } = entrada;
  const vazio = { inserir: [], atualizar: [], remover: [] };
  if (backup === undefined) return vazio;

  const linhasHoje = new Map(hoje.map((l) => [chaveDaLinha(def, l), l] as const));
  const linhasBackup = new Map(backup.map((l) => [chaveDaLinha(def, l), l] as const));
  const inserir: Linha[] = [];
  const atualizar: Linha[] = [];
  const remover: Linha[] = [];

  for (const [chave, antes] of linhasBackup) {
    const atual = linhasHoje.get(chave);
    if (!atual) {
      inserir.push(antes);
    } else if (!def.somenteInserir && diferente(antes, atual)) {
      atualizar.push(antes); // inclui desfazer exclusão lógica (excluido_em volta ao valor do backup)
    }
  }

  if (modo === "espelhar" && !def.somenteInserir && !NUNCA_REMOVER.includes(def.nome)) {
    for (const [chave, atual] of linhasHoje) {
      if (linhasBackup.has(chave)) continue;
      if (def.exclusaoLogica && (atual.excluido_em ?? null) !== null) continue; // já está excluído
      remover.push(Object.fromEntries(def.pk.map((c) => [c, atual[c]])));
    }
  }
  return { inserir, atualizar, remover };
}

/** Plano completo, na ordem certa: gravar (pais primeiro) e depois remover (filhos primeiro). */
export function montarPlano(entradas: EntradaTabela[], modo: ModoRestauracao): OperacaoBanco[] {
  const porNome = new Map(entradas.map((e) => [e.def.nome, e] as const));
  const planos = new Map(entradas.map((e) => [e.def.nome, planoDaTabela(e, modo)] as const));
  const nomes = entradas.map((e) => e.def.nome);
  const ops: OperacaoBanco[] = [];

  for (const nome of ordenarParaGravar(nomes)) {
    const plano = planos.get(nome);
    const entrada = porNome.get(nome);
    if (!plano || !entrada) continue;
    if (plano.inserir.length > 0) ops.push({ tabela: nome, acao: "inserir", colunas: uniaoDeColunas(plano.inserir), linhas: plano.inserir });
    if (plano.atualizar.length > 0) ops.push({ tabela: nome, acao: "atualizar", colunas: uniaoDeColunas(plano.atualizar), linhas: plano.atualizar });
  }
  for (const nome of ordenarParaApagar(nomes)) {
    const plano = planos.get(nome);
    const entrada = porNome.get(nome);
    if (!plano || !entrada || plano.remover.length === 0) continue;
    ops.push({
      tabela: nome,
      acao: entrada.def.exclusaoLogica ? "excluir_logico" : "excluir",
      colunas: [...entrada.def.pk],
      linhas: plano.remover,
    });
  }
  return ops;
}

export function totalDeLinhasDoPlano(ops: OperacaoBanco[]): number {
  return ops.reduce((soma, op) => soma + op.linhas.length, 0);
}

const ROTULO_ACAO: Record<string, string> = {
  inserir: "devolvidos",
  atualizar: "corrigidos",
  excluir_logico: "removidos",
  excluir: "removidos",
};

/** Texto curto para a tela e para os avisos: "Instrumentos: 1 devolvidos; ...". */
export function resumirOperacoes(ops: ResultadoOperacao[], rotulos: Record<string, string>): string {
  const partes = ops.filter((o) => o.afetados > 0).map((o) => `${rotulos[o.tabela] ?? o.tabela}: ${o.afetados} ${ROTULO_ACAO[o.acao] ?? o.acao}`);
  return partes.length > 0 ? partes.join("; ") : "nenhum registro precisou mudar";
}
""",
  'src/modules/backup/aplicacao.test.ts': r"""import { describe, expect, it } from "vitest";
import { lerEntradaAplicacao, montarPlano, planoDaTabela, resumirOperacoes, type EntradaTabela } from "./aplicacao";
import { TABELAS, type DefinicaoTabela } from "./tabelas";

const def = (nome: string): DefinicaoTabela => {
  const achada = TABELAS.find((t) => t.nome === nome);
  if (!achada) throw new Error(`Tabela ${nome} não existe`);
  return achada;
};

describe("planoDaTabela", () => {
  const membros = def("membros");
  const backup = [
    { id: "1", nome: "Ana", excluido_em: null },
    { id: "2", nome: "Bia", excluido_em: null },
    { id: "3", nome: "Caio", excluido_em: null },
  ];
  const hoje = [
    { id: "1", nome: "Ana Maria", excluido_em: null }, // alterada
    { id: "3", nome: "Caio", excluido_em: "2026-10-19T10:00:00Z" }, // excluída depois
    { id: "4", nome: "Davi", excluido_em: null }, // nova
  ]; // "2" sumiu

  it("recuperar devolve apagados e desfaz alterações, sem tocar no que é novo", () => {
    const p = planoDaTabela({ def: membros, backup, hoje }, "recuperar");
    expect(p.inserir.map((l) => l.id)).toEqual(["2"]);
    expect(p.atualizar.map((l) => l.id)).toEqual(["1", "3"]);
    expect(p.remover).toEqual([]);
  });

  it("espelhar também remove o que é novo (só a chave primária vai no plano)", () => {
    const p = planoDaTabela({ def: membros, backup, hoje }, "espelhar");
    expect(p.remover).toEqual([{ id: "4" }]);
  });

  it("espelhar ignora o que já está excluído logicamente", () => {
    const p = planoDaTabela({ def: membros, backup: [], hoje: [{ id: "9", excluido_em: "2026-10-19T10:00:00Z" }] }, "espelhar");
    expect(p.remover).toEqual([]);
  });

  it("nunca remove usuários, nem altera tabela só de inserção", () => {
    const u = planoDaTabela({ def: def("usuarios"), backup: [], hoje: [{ id: "x" }] }, "espelhar");
    expect(u.remover).toEqual([]);
    const h = planoDaTabela({ def: def("portarias_historico"), backup: [{ id: "1", a: 1 }], hoje: [{ id: "1", a: 2 }, { id: "2", a: 1 }] }, "espelhar");
    expect(h).toEqual({ inserir: [], atualizar: [], remover: [] });
  });

  it("backup sem a tabela não gera nada", () => {
    expect(planoDaTabela({ def: membros, backup: undefined, hoje }, "espelhar")).toEqual({ inserir: [], atualizar: [], remover: [] });
  });
});

describe("montarPlano", () => {
  it("grava pais antes dos filhos e remove filhos antes dos pais", () => {
    const entradas: EntradaTabela[] = [
      { def: def("presencas"), backup: [{ id: "p1", excluido_em: null }], hoje: [{ id: "p9", excluido_em: null }] },
      { def: def("membros"), backup: [{ id: "m1", excluido_em: null }], hoje: [{ id: "m9", excluido_em: null }] },
    ];
    const ops = montarPlano(entradas, "espelhar").map((o) => `${o.acao}:${o.tabela}`);
    expect(ops).toEqual(["inserir:membros", "inserir:presencas", "excluir_logico:presencas", "excluir_logico:membros"]);
  });

  it("tabela sem exclusão lógica usa exclusão de verdade, só com a chave", () => {
    const [op] = montarPlano([{ def: def("estados"), backup: [], hoje: [{ id: "e1", nome: "BA" }] }], "espelhar");
    expect(op).toMatchObject({ acao: "excluir", colunas: ["id"], linhas: [{ id: "e1" }] });
  });

  it("sem diferença não há operações", () => {
    const l = [{ id: "1", nome: "BA" }];
    expect(montarPlano([{ def: def("estados"), backup: l, hoje: [...l] }], "espelhar")).toEqual([]);
  });
});

describe("lerEntradaAplicacao", () => {
  const validos = ["membros", "eventos"];
  const base = { id: "x", grupos: ["membros"], modo: "recuperar", senha: "abc" };
  it("aceita recuperar com senha", () => {
    expect(lerEntradaAplicacao(base, validos)).toMatchObject({ id: "x", modo: "recuperar", grupos: ["membros"] });
  });
  it("espelhar exige digitar ESPELHAR", () => {
    expect(lerEntradaAplicacao({ ...base, modo: "espelhar" }, validos)).toBeNull();
    expect(lerEntradaAplicacao({ ...base, modo: "espelhar", confirmacao: "espelhar" }, validos)).toBeNull();
    expect(lerEntradaAplicacao({ ...base, modo: "espelhar", confirmacao: "ESPELHAR" }, validos)).not.toBeNull();
  });
  it("recusa senha vazia, modo ou grupo desconhecido", () => {
    expect(lerEntradaAplicacao({ ...base, senha: "" }, validos)).toBeNull();
    expect(lerEntradaAplicacao({ ...base, modo: "apagar" }, validos)).toBeNull();
    expect(lerEntradaAplicacao({ ...base, grupos: ["tudo"] }, validos)).toBeNull();
    expect(lerEntradaAplicacao(null, validos)).toBeNull();
  });
});

describe("resumirOperacoes", () => {
  it("resume só o que mudou", () => {
    const txt = resumirOperacoes(
      [
        { tabela: "instrumentos", acao: "inserir", afetados: 1, ignorados: 0 },
        { tabela: "membros", acao: "atualizar", afetados: 0, ignorados: 0 },
      ],
      { instrumentos: "Instrumentos" }
    );
    expect(txt).toBe("Instrumentos: 1 devolvidos");
    expect(resumirOperacoes([], {})).toBe("nenhum registro precisou mudar");
  });
});
""",
  'src/modules/backup/server/aplicacao.ts': r"""/**
 * SysMúsica — Restauração, parte 2 (aplicar), lado do servidor.
 * Fluxo: confere a SENHA do administrador de novo -> compara o backup com os dados de hoje -> monta o plano
 * -> faz um BACKUP DE SEGURANÇA verificado (se não passar, nada é restaurado) -> aplica tudo em UMA transação
 * (backup_aplicar: se algo falhar, nada muda) -> avisa por Telegram/e-mail e registra na Auditoria.
 */
import { createClient } from "@supabase/supabase-js";
import type { SupabaseClient } from "@supabase/supabase-js";
import { abrirBackup, lerChave } from "../cripto";
import { dataHoraSalvador, idValido, lerPacote } from "../regras";
import {
  montarPlano,
  resumirOperacoes,
  totalDeLinhasDoPlano,
  type EntradaAplicacao,
  type EntradaTabela,
  type RespostaRestauracao,
  type ResultadoOperacao,
} from "../aplicacao";
import type { Linha } from "../restauracao";
import { GRUPOS_DADOS, TABELAS, tabelasDoGrupo } from "../tabelas";
import type { UsuarioAutenticado } from "./autorizacao";
import { clienteAdmin } from "./clienteAdmin";
import { ErroBackup } from "./erros";
import { notificar } from "./notificar";
import { fazerBackup } from "./operacoes";
import { lerTabelaAtual } from "./restauracao";

const BUCKET = "backups";

// Confere a senha do administrador de novo (login sem guardar sessão)
async function conferirSenha(admin: SupabaseClient, usuarioId: string, senha: string): Promise<void> {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const anon = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY ?? process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY;
  if (!url || !anon) throw new ErroBackup(500, "A chave pública do Supabase não está configurada no servidor.");

  const { data } = await admin.auth.admin.getUserById(usuarioId);
  const email = data.user?.email;
  if (!email) throw new ErroBackup(403, "Não foi possível conferir a sua conta.");

  const cliente = createClient(url, anon, { auth: { persistSession: false, autoRefreshToken: false } });
  const { data: login, error } = await cliente.auth.signInWithPassword({ email, password: senha });
  if (error || login.user?.id !== usuarioId) throw new ErroBackup(403, "Senha incorreta. Nada foi restaurado.");
}

async function registrar(admin: SupabaseClient, usuarioId: string, acao: string, backupId: string, detalhes: Record<string, unknown>) {
  const { error } = await admin
    .from("auditoria")
    .insert({ usuario_id: usuarioId, acao, entidade: "backup", entidade_id: backupId, detalhes });
  if (error) console.error("Falha ao registrar a auditoria da restauração:", error.message);
}

/** Restaura o backup escolhido nos grupos marcados. Ver o fluxo no topo do arquivo. */
export async function restaurarBackup(entrada: EntradaAplicacao, usuario: UsuarioAutenticado): Promise<RespostaRestauracao> {
  if (!idValido(entrada.id)) throw new ErroBackup(400, "Identificador de backup inválido.");
  const admin = clienteAdmin();

  await conferirSenha(admin, usuario.id, entrada.senha);

  const { data: linha, error } = await admin
    .from("backup_arquivos")
    .select("id, criado_em, tipo, situacao, caminho")
    .eq("id", entrada.id)
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

  let doArquivo: Record<string, Linha[]>;
  try {
    doArquivo = lerPacote(abrirBackup(Buffer.from(await baixado.data.arrayBuffer()), chave).toString("utf8")).tabelas;
  } catch (e) {
    throw new ErroBackup(500, e instanceof Error ? e.message : "Não foi possível abrir o backup.");
  }

  // Plano: o que precisa mudar nos grupos escolhidos
  const entradas: EntradaTabela[] = [];
  for (const grupo of GRUPOS_DADOS.filter((g) => entrada.grupos.includes(g.id))) {
    for (const def of tabelasDoGrupo(grupo.id)) {
      const backup: Linha[] | undefined = doArquivo[def.nome];
      entradas.push({ def, backup, hoje: await lerTabelaAtual(admin, def) });
    }
  }
  const plano = montarPlano(entradas, entrada.modo);
  if (plano.length === 0) {
    return { restaurado: false, mensagem: "Nada a restaurar: os dados de hoje já estão iguais ao backup nos grupos escolhidos.", operacoes: [], segurancaId: null };
  }

  const dataDoBackup = dataHoraSalvador(new Date(String(linha.criado_em)));
  const rotulos = Object.fromEntries(TABELAS.map((t) => [t.nome, t.rotulo]));
  const modoTexto = entrada.modo === "espelhar" ? "Espelhar" : "Recuperar";

  // Backup de segurança ANTES de mexer em qualquer coisa; se não passar na verificação, aborta
  let segurancaId: string;
  try {
    const seguranca = await fazerBackup({ tipo: "seguranca", usuario, observacao: `Antes de restaurar o backup de ${dataDoBackup}` });
    if (!seguranca.verificacao.ok) throw new Error("o backup de segurança não passou na verificação");
    segurancaId = seguranca.backup.id;
  } catch (e) {
    const motivo = e instanceof Error ? e.message : "erro desconhecido";
    throw new ErroBackup(500, `Não foi possível fazer o backup de segurança (${motivo}). Nada foi restaurado.`);
  }

  // Aplica tudo em uma única transação
  const resumo = { backup_id: entrada.id, modo: entrada.modo, grupos: entrada.grupos, seguranca_id: segurancaId };
  const { data: resultado, error: erroAplicar } = await admin.rpc("backup_aplicar", {
    p_usuario: usuario.id,
    p_operacoes: plano,
    p_resumo: resumo,
  });
  if (erroAplicar) {
    console.error("Falha ao aplicar a restauração:", erroAplicar.message);
    await registrar(admin, usuario.id, "backup_restauracao_falhou", entrada.id, { ...resumo, erro: erroAplicar.message.slice(0, 300) });
    await notificar("restauracao", {
      assunto: "SysMúsica: a restauração FALHOU (nada foi alterado)",
      texto: `Backup de ${dataDoBackup}, modo ${modoTexto}, feita por ${usuario.nome}.\nMotivo: ${erroAplicar.message.slice(0, 300)}\nOs dados continuam como estavam.`,
    });
    throw new ErroBackup(500, `A restauração foi desfeita e nada foi alterado. Motivo: ${erroAplicar.message}`);
  }

  const operacoes = (Array.isArray(resultado) ? resultado : []) as ResultadoOperacao[];
  const texto = resumirOperacoes(operacoes, rotulos);
  await notificar("restauracao", {
    assunto: "SysMúsica: backup restaurado",
    texto:
      `Backup de ${dataDoBackup} restaurado por ${usuario.nome} (modo ${modoTexto}).\n${texto}.\n` +
      `Antes disso foi feito um backup de segurança, que pode ser usado para desfazer.`,
  });

  return {
    restaurado: true,
    mensagem: `Restauração concluída (${totalDeLinhasDoPlano(plano)} registros analisados): ${texto}. Um backup de segurança foi feito antes.`,
    operacoes,
    segurancaId,
  };
}
""",
  'src/modules/backup/services/restauracaoAplicarApi.ts': r"""/** SysMúsica — Chamada do navegador à rota que restaura o backup (leva o token do login e a senha digitada). */
import { supabase } from "@/lib/supabase";
import type { ModoRestauracao, RespostaRestauracao } from "../aplicacao";
import type { GrupoDados } from "../tabelas";

export async function restaurarBackup(dados: {
  id: string;
  grupos: GrupoDados[];
  modo: ModoRestauracao;
  confirmacao: string;
  senha: string;
}): Promise<RespostaRestauracao> {
  const { data } = await supabase.auth.getSession();
  const token = data.session?.access_token;
  if (!token) throw new Error("Sua sessão expirou. Entre de novo.");

  const resposta = await fetch("/api/backup/restauracao/aplicar", {
    method: "POST",
    headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json" },
    body: JSON.stringify(dados),
    cache: "no-store",
  });
  const json = (await resposta.json().catch(() => null)) as (RespostaRestauracao & { erro?: string }) | null;
  if (!resposta.ok || !json) throw new Error(json?.erro ?? "Não foi possível restaurar o backup.");
  return json;
}
""",
  'src/modules/backup/components/PainelRestaurar.tsx': r""""use client";

/**
 * SysMúsica — Painel "Restaurar" (aparece abaixo da comparação, só para o Administrador).
 * Modos: Recuperar (padrão, seguro) e Espelhar (exige digitar ESPELHAR). A senha é pedida de novo.
 * O servidor faz um backup de segurança antes e aplica tudo em uma única transação.
 */
import { useState } from "react";
import { TEXTO_ESPELHAR, type ModoRestauracao } from "@/modules/backup/aplicacao";
import { restaurarBackup } from "@/modules/backup/services/restauracaoAplicarApi";
import type { GrupoDados } from "@/modules/backup/tabelas";

const classeBotaoPerigo =
  "inline-flex items-center gap-2 rounded-lg bg-red-600 px-3 py-2 text-sm font-medium text-white transition " +
  "hover:bg-red-700 disabled:cursor-not-allowed disabled:opacity-60";

export default function PainelRestaurar({
  backupId,
  grupos,
  podeRestaurar,
}: {
  backupId: string;
  grupos: GrupoDados[];
  podeRestaurar: boolean;
}) {
  const [modo, setModo] = useState<ModoRestauracao>("recuperar");
  const [confirmacao, setConfirmacao] = useState("");
  const [senha, setSenha] = useState("");
  const [executando, setExecutando] = useState(false);
  const [erro, setErro] = useState<string | null>(null);
  const [sucesso, setSucesso] = useState<string | null>(null);

  if (!podeRestaurar) return null;

  const pronto = senha !== "" && (modo === "recuperar" || confirmacao === TEXTO_ESPELHAR);

  async function aoRestaurar() {
    setExecutando(true);
    setErro(null);
    setSucesso(null);
    try {
      const resposta = await restaurarBackup({ id: backupId, grupos, modo, confirmacao, senha });
      setSucesso(resposta.mensagem);
      setSenha("");
      setConfirmacao("");
    } catch (e) {
      setErro(e instanceof Error ? e.message : "Não foi possível restaurar.");
    } finally {
      setExecutando(false);
    }
  }

  return (
    <div className="space-y-4 rounded-xl border border-red-200 bg-red-50/40 p-4">
      <h3 className="text-sm font-semibold text-red-800">Restaurar este backup</h3>
      <p className="text-sm text-slate-700">
        Antes de qualquer mudança o sistema faz um <strong>backup de segurança</strong>, que serve para desfazer. A
        restauração acontece de uma vez só: se algo falhar, nada é alterado.
      </p>

      <fieldset className="space-y-2" disabled={executando}>
        <legend className="text-xs font-medium text-slate-600">Como restaurar</legend>
        <label className="flex items-start gap-2 rounded-lg border border-slate-200 bg-white px-3 py-2 text-sm">
          <input type="radio" name="modo" checked={modo === "recuperar"} onChange={() => setModo("recuperar")} className="mt-0.5" />
          <span>
            <span className="font-medium text-slate-800">Recuperar (recomendado)</span>
            <span className="block text-xs text-slate-500">
              Devolve o que foi apagado e desfaz as alterações. Não mexe no que foi criado depois do backup.
            </span>
          </span>
        </label>
        <label className="flex items-start gap-2 rounded-lg border border-slate-200 bg-white px-3 py-2 text-sm">
          <input type="radio" name="modo" checked={modo === "espelhar"} onChange={() => setModo("espelhar")} className="mt-0.5" />
          <span>
            <span className="font-medium text-slate-800">Espelhar</span>
            <span className="block text-xs text-slate-500">
              Deixa os dados idênticos ao backup: também remove o que foi criado depois dele (nunca remove usuários nem o
              histórico das portarias).
            </span>
          </span>
        </label>
      </fieldset>

      {modo === "espelhar" && (
        <div className="max-w-xs space-y-1.5">
          <label htmlFor="rest-confirmar" className="text-xs font-medium text-slate-600">
            Para confirmar, digite {TEXTO_ESPELHAR}
          </label>
          <input
            id="rest-confirmar"
            type="text"
            value={confirmacao}
            onChange={(e) => setConfirmacao(e.target.value)}
            disabled={executando}
            autoComplete="off"
            className="w-full rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm"
          />
        </div>
      )}

      <div className="max-w-xs space-y-1.5">
        <label htmlFor="rest-senha" className="text-xs font-medium text-slate-600">
          Digite a sua senha de novo
        </label>
        <input
          id="rest-senha"
          type="password"
          value={senha}
          onChange={(e) => setSenha(e.target.value)}
          disabled={executando}
          autoComplete="current-password"
          className="w-full rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm"
        />
      </div>

      <button type="button" className={classeBotaoPerigo} onClick={() => void aoRestaurar()} disabled={executando || !pronto}>
        {executando ? "Restaurando... (pode levar alguns segundos)" : "Restaurar agora"}
      </button>

      {erro && (
        <p role="alert" className="rounded-lg bg-red-50 px-3 py-2 text-sm text-red-700">
          {erro}
        </p>
      )}
      {sucesso && (
        <p role="status" className="rounded-lg bg-emerald-50 px-3 py-2 text-sm text-emerald-800">
          {sucesso} Clique em &quot;Comparar com os dados de hoje&quot; para conferir.
        </p>
      )}
    </div>
  );
}
""",
  'src/app/api/backup/restauracao/aplicar/route.ts': r"""/**
 * SysMúsica — Rota /api/backup/restauracao/aplicar: POST restaura um backup (grava no banco).
 * Somente o Administrador (backup.restaurar), com a SENHA conferida de novo a cada restauração.
 */
import type { NextRequest } from "next/server";
import { lerEntradaAplicacao } from "@/modules/backup/aplicacao";
import { autenticar } from "@/modules/backup/server/autorizacao";
import { ErroBackup } from "@/modules/backup/server/erros";
import { restaurarBackup } from "@/modules/backup/server/aplicacao";
import { responder } from "@/modules/backup/server/rota";
import { GRUPOS_DADOS } from "@/modules/backup/tabelas";

export const maxDuration = 60;

export async function POST(request: NextRequest) {
  return responder(async () => {
    const usuario = await autenticar(request, "backup.restaurar");
    const corpo: unknown = await request.json().catch(() => null);
    const entrada = lerEntradaAplicacao(
      corpo,
      GRUPOS_DADOS.map((g) => g.id)
    );
    if (!entrada) throw new ErroBackup(400, "Confira o backup, os grupos, a senha e (no modo Espelhar) a palavra ESPELHAR.");
    return await restaurarBackup(entrada, usuario);
  });
}
""",
}

def abrir(c):
    return open(c, encoding="utf-8").read()

def trocar(texto, antigo, novo, onde):
    if texto.count(antigo) != 1:
        print("ERRO: trecho não encontrado exatamente uma vez em", onde, "->", antigo[:60]); sys.exit(1)
    return texto.replace(antigo, novo)

# 1) a leitura das tabelas de hoje passa a ser compartilhada
srv = "src/modules/backup/server/restauracao.ts"
s1 = trocar(abrir(srv), "async function lerTabelaAtual(", "export async function lerTabelaAtual(", srv)

# 2) a página mostra o painel "Restaurar" logo abaixo da comparação
pg = "src/app/(painel)/administracao/backup/restauracao/page.tsx"
s2 = abrir(pg)
s2 = trocar(s2, 'import AbasBackup from "@/modules/backup/components/AbasBackup";',
  'import AbasBackup from "@/modules/backup/components/AbasBackup";\nimport PainelRestaurar from "@/modules/backup/components/PainelRestaurar";', pg)
s2 = trocar(s2, "                ))}\n              </section>\n            )}",
  "                ))}\n"
  "                {resultado.totais.apagados + resultado.totais.alterados + resultado.totais.novos > 0 && (\n"
  "                  <PainelRestaurar\n"
  "                    backupId={resultado.backup.id}\n"
  "                    grupos={resultado.grupos.map((g) => g.id)}\n"
  '                    podeRestaurar={pode("backup.restaurar")}\n'
  "                  />\n"
  "                )}\n"
  "              </section>\n            )}", pg)
s2 = trocar(s2, "Esta etapa só <strong>compara</strong>: nada é restaurado nem alterado. Mostra o que foi apagado, alterado ou\n          criado depois do backup escolhido.",
  "Compare o backup escolhido com os dados de hoje (apagado, alterado ou criado depois do backup). A comparação não\n          altera nada; a restauração só acontece no painel &quot;Restaurar&quot;, que aparece abaixo quando há diferenças.", pg)

for caminho in NOVOS:
    if os.path.exists(caminho):
        print("ERRO: já existe", caminho); sys.exit(1)
for caminho, conteudo in NOVOS.items():
    os.makedirs(os.path.dirname(caminho) or ".", exist_ok=True)
    open(caminho, "w", encoding="utf-8").write(conteudo)
open(srv, "w", encoding="utf-8").write(s1)
open(pg, "w", encoding="utf-8").write(s2)
print("Arquivos gravados:", len(NOVOS), "novos, 2 alterados.")
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
npx eslint "${ALT[@]}" src/modules/backup/aplicacao.ts src/modules/backup/aplicacao.test.ts src/modules/backup/server/aplicacao.ts \
  src/modules/backup/services/restauracaoAplicarApi.ts src/modules/backup/components/PainelRestaurar.tsx src/app/api/backup/restauracao || { reverter; exit 1; }
echo; echo "=== 6) Build de produção (pode demorar alguns minutos) ==="
npm run build || { reverter; exit 1; }

echo; echo "=== TUDO CERTO: arquivos instalados e conferidos ==="
git status --short
) 2>&1 | tee /tmp/restauracao2-instalar.log
