#!/usr/bin/env bash
# =============================================================================
# SysMúsica — NOVO: relatórios de Presença, Membros e Eventos com filtros RRM e ADM (e colunas RRM e ADM)
#
#  ANTES: rode no Supabase o arquivo 0048_relatorios_rrm_adm.sql (o relatório passa a chamar as funções novas).
#
# Segurança: confere cada trecho (exatamente 1 vez), faz backup em /tmp/bkp-relatorios-rrm-adm-*, aplica,
# roda tsc, vitest, eslint e build; se algo falhar, DESFAZ tudo sozinho (inclusive os arquivos novos).
#
# Uso:  cd /workspaces/sysmusica/sysmusica && rm -rf .next && bash instalar-relatorios-rrm-adm.sh
# Log:  /tmp/instalar-relatorios-rrm-adm.log
# =============================================================================

LOG=/tmp/instalar-relatorios-rrm-adm.log
BKP=/tmp/bkp-relatorios-rrm-adm-$(date +%Y%m%d-%H%M%S)
RAIZ="$(pwd)"

(
[ -f package.json ] && [ -d src ] || { echo "ERRO: rode dentro da pasta sysmusica (onde está o package.json)."; exit 1; }
mkdir -p "$BKP"
export BKP RAIZ

echo "== 1/3  Conferindo e aplicando as alterações =="
# (ajuste simples: sem SQL)
python3 - <<'PYSCRIPT'
import os, shutil, sys, hashlib

RAIZ = os.environ["RAIZ"]
BKP = os.environ["BKP"]

# (arquivo, trecho antigo, trecho novo) — cada "antigo" precisa existir EXATAMENTE 1 vez no arquivo.
# Os trechos usam \n; o instalador converte para o fim de linha do próprio arquivo (CRLF ou LF).
EDITS = [
    ('src/modules/relatorios/tipos.ts',
     r'''  | "regiao"
  | "setor"
''',
     r'''  | "rrm"
  | "regiao"
  | "adm"
  | "setor"
'''),
    ('src/modules/relatorios/tipos.ts',
     r'''  eventoId: string;
  regiaoId: string;
  setorId: string;
''',
     r'''  eventoId: string;
  rrmId?: string; // RRM escolhida (vazio = todas)
  regiaoId: string;
  admId?: string; // ADM escolhida (vazio = todas)
  setorId: string;
'''),
    ('src/modules/relatorios/regras.ts',
     r'''  eventoId: "",
  regiaoId: "",
  setorId: "",
''',
     r'''  eventoId: "",
  rrmId: "",
  regiaoId: "",
  admId: "",
  setorId: "",
'''),
    ('src/modules/relatorios/regras.ts',
     r'''"evento" | "regiao" | "setor" | "casa_oracao" | "cargo" | "instrumento", string>''',
     r'''"evento" | "rrm" | "regiao" | "adm" | "setor" | "casa_oracao" | "cargo" | "instrumento", string>'''),
    ('src/modules/relatorios/regras.ts',
     r'''    regiao: nomeDe("RA", filtros.regiaoId), // o filtro "regiao" dos relatórios é a RA
''',
     r'''    rrm: nomeDe("RRM", filtros.rrmId ?? ""),
    regiao: nomeDe("RA", filtros.regiaoId), // o filtro "regiao" dos relatórios é a RA
    adm: nomeDe("ADM", filtros.admId ?? ""),
'''),
    ('src/modules/relatorios/regras.ts',
     r'''  if (tem("regiao") && filtros.regiaoId && rotulos.regiao) partes.push(`RA: ${rotulos.regiao}`);
''',
     r'''  if (tem("rrm") && filtros.rrmId && rotulos.rrm) partes.push(`RRM: ${rotulos.rrm}`);
  if (tem("regiao") && filtros.regiaoId && rotulos.regiao) partes.push(`RA: ${rotulos.regiao}`);
  if (tem("adm") && filtros.admId && rotulos.adm) partes.push(`ADM: ${rotulos.adm}`);
'''),
    ('src/modules/relatorios/regras.ts',
     r'''export function opcoesRegiao(nos: NoOrganizacao[]): OpcaoSelecao[] {
''',
     r'''/** RRMs para escolher (com o estado na frente se houver mais de um estado). */
export function opcoesRrm(nos: NoOrganizacao[]): OpcaoSelecao[] {
  const estados = nos.filter((no) => no.nivel === "ESTADO");
  const porId = new Map(nos.map((no) => [no.id, no] as const));
  return nos
    .filter((no) => no.nivel === "RRM")
    .map((rrm) => {
      const estado = rrm.parent_id ? porId.get(rrm.parent_id) : undefined;
      return { id: rrm.id, rotulo: estados.length > 1 && estado ? `${estado.nome} › ${rrm.nome}` : rrm.nome };
    })
    .sort(porRotulo);
}

/** RAs para escolher; com a RRM escolhida, só as dela. */
export function opcoesRegiao(nos: NoOrganizacao[], rrmId?: string): OpcaoSelecao[] {
'''),
    ('src/modules/relatorios/regras.ts',
     r'''    .filter((no) => no.nivel === "RA")
''',
     r'''    .filter((no) => no.nivel === "RA" && (!rrmId || no.parent_id === rrmId))
'''),
    ('src/modules/relatorios/regras.ts',
     r'''/** Setores da RA escolhida, com o nome da ADM na frente''',
     r'''/** ADMs da RA escolhida. Vazio sem RA. */
export function opcoesAdm(nos: NoOrganizacao[], regiaoId: string): OpcaoSelecao[] {
  if (!regiaoId) return [];
  return filhosDe(nos, regiaoId, "ADM")
    .map((adm) => ({ id: adm.id, rotulo: adm.nome }))
    .sort(porRotulo);
}

/** Setores da RA escolhida (ou só da ADM escolhida), com o nome da ADM na frente'''),
    ('src/modules/relatorios/regras.ts',
     r'''export function opcoesSetor(nos: NoOrganizacao[], regiaoId: string): OpcaoSelecao[] {
  if (!regiaoId) return [];
  return filhosDe(nos, regiaoId, "ADM")
    .flatMap((adm) => filhosDe(nos, adm.id, "SETOR")''',
     r'''export function opcoesSetor(nos: NoOrganizacao[], regiaoId: string, admId?: string): OpcaoSelecao[] {
  if (!regiaoId) return [];
  return filhosDe(nos, regiaoId, "ADM")
    .filter((adm) => !admId || adm.id === admId)
    .flatMap((adm) => filhosDe(nos, adm.id, "SETOR")'''),
    ('src/modules/relatorios/regras.ts',
     r'''export function opcoesCasaOracao(nos: NoOrganizacao[], regiaoId: string, setorId: string): OpcaoSelecao[] {''',
     r'''export function opcoesCasaOracao(nos: NoOrganizacao[], regiaoId: string, setorId: string, admId?: string): OpcaoSelecao[] {'''),
    ('src/modules/relatorios/regras.ts',
     r'''  return filhosDe(nos, regiaoId, "ADM")
    .flatMap((adm) => [''',
     r'''  return filhosDe(nos, regiaoId, "ADM")
    .filter((adm) => !admId || adm.id === admId)
    .flatMap((adm) => ['''),
    ('src/modules/relatorios/regras.ts',
     r'''const partes = [rotulos.regiao, rotulos.setor, rotulos.casa_oracao].filter(''',
     r'''const partes = [rotulos.rrm, rotulos.regiao, rotulos.adm, rotulos.setor, rotulos.casa_oracao].filter('''),
    ('src/modules/relatorios/catalogo.ts',
     r'''"periodo", "evento", "regiao", "setor", "casa_oracao", "statusPresenca"]''',
     r'''"periodo", "evento", "rrm", "regiao", "adm", "setor", "casa_oracao", "statusPresenca"]'''),
    ('src/modules/relatorios/catalogo.ts',
     r'''filtros: ["regiao", "setor", "casa_oracao", "cargo", "instrumento", "situacaoMembro", "visitante"]''',
     r'''filtros: ["rrm", "regiao", "adm", "setor", "casa_oracao", "cargo", "instrumento", "situacaoMembro", "visitante"]'''),
    ('src/modules/relatorios/catalogo.ts',
     r'''filtros: ["periodo", "regiao", "setor", "casa_oracao"]''',
     r'''filtros: ["periodo", "rrm", "regiao", "adm", "setor", "casa_oracao"]'''),
    ('src/modules/relatorios/catalogo.ts',
     r'''      { id: "regiao", rotulo: "RA", padrao: false },
      { id: "setor", rotulo: "Setor", padrao: false },
      { id: "casa_oracao", rotulo: "Casa de Oração do evento", padrao: false },''',
     r'''      { id: "rrm", rotulo: "RRM", padrao: false },
      { id: "regiao", rotulo: "RA", padrao: false },
      { id: "adm", rotulo: "ADM", padrao: false },
      { id: "setor", rotulo: "Setor", padrao: false },
      { id: "casa_oracao", rotulo: "Casa de Oração do evento", padrao: false },'''),
    ('src/modules/relatorios/catalogo.ts',
     r'''      { id: "regiao", rotulo: "RA", padrao: false },
      { id: "setor", rotulo: "Setor", padrao: false },
      { id: "cidade", rotulo: "Cidade", padrao: false },
      { id: "bairro"''',
     r'''      { id: "rrm", rotulo: "RRM", padrao: false },
      { id: "regiao", rotulo: "RA", padrao: false },
      { id: "adm", rotulo: "ADM", padrao: false },
      { id: "setor", rotulo: "Setor", padrao: false },
      { id: "cidade", rotulo: "Cidade", padrao: false },
      { id: "bairro"'''),
    ('src/modules/relatorios/catalogo.ts',
     r'''      { id: "setor", rotulo: "Setor", padrao: false },
      { id: "regiao", rotulo: "RA", padrao: false },
      { id: "cidade", rotulo: "Cidade", padrao: false },
    ],''',
     r'''      { id: "setor", rotulo: "Setor", padrao: false },
      { id: "rrm", rotulo: "RRM", padrao: false },
      { id: "regiao", rotulo: "RA", padrao: false },
      { id: "adm", rotulo: "ADM", padrao: false },
      { id: "cidade", rotulo: "Cidade", padrao: false },
    ],'''),
    ('src/modules/relatorios/services/relatorios.ts',
     r'''    p_limite: LIMITE_LINHAS,
  });
  if (error) throw new Error(mensagemDoErro(error, "Não foi possível gerar o relatório de presença."));''',
     r'''    p_limite: LIMITE_LINHAS,
    p_rrm: filtros.rrmId || null,
    p_adm: filtros.admId || null,
  });
  if (error) throw new Error(mensagemDoErro(error, "Não foi possível gerar o relatório de presença."));'''),
    ('src/modules/relatorios/services/relatorios.ts',
     r'''    p_limite: LIMITE_LINHAS,
  });
  if (error) throw new Error(mensagemDoErro(error, "Não foi possível gerar o relatório de membros."));''',
     r'''    p_limite: LIMITE_LINHAS,
    p_rrm: filtros.rrmId || null,
    p_adm: filtros.admId || null,
  });
  if (error) throw new Error(mensagemDoErro(error, "Não foi possível gerar o relatório de membros."));'''),
    ('src/modules/relatorios/services/relatorios.ts',
     r'''    p_limite: LIMITE_LINHAS,
  });
  if (error) throw new Error(mensagemDoErro(error, "Não foi possível gerar o relatório de eventos."));''',
     r'''    p_limite: LIMITE_LINHAS,
    p_rrm: filtros.rrmId || null,
    p_adm: filtros.admId || null,
  });
  if (error) throw new Error(mensagemDoErro(error, "Não foi possível gerar o relatório de eventos."));'''),
    ('src/modules/relatorios/services/relatorios.ts',
     r'''  evento_finalidade: string | null;
  regiao: string | null;
''',
     r'''  evento_finalidade: string | null;
  rrm: string | null;
  regiao: string | null;
  adm: string | null;
'''),
    ('src/modules/relatorios/services/relatorios.ts',
     r'''  familia: string | null;
  regiao: string | null;
''',
     r'''  familia: string | null;
  rrm: string | null;
  regiao: string | null;
  adm: string | null;
'''),
    ('src/modules/relatorios/services/relatorios.ts',
     r'''  cidade: string | null;
  regiao: string | null;
''',
     r'''  cidade: string | null;
  rrm: string | null;
  regiao: string | null;
  adm: string | null;
'''),
    ('src/modules/relatorios/services/relatorios.ts',
     r'''      evento_finalidade: texto(linha.evento_finalidade),
      regiao: texto(linha.regiao),
''',
     r'''      evento_finalidade: texto(linha.evento_finalidade),
      rrm: texto(linha.rrm),
      regiao: texto(linha.regiao),
      adm: texto(linha.adm),
'''),
    ('src/modules/relatorios/services/relatorios.ts',
     r'''      familia: texto(linha.familia),
      regiao: texto(linha.regiao),
''',
     r'''      familia: texto(linha.familia),
      rrm: texto(linha.rrm),
      regiao: texto(linha.regiao),
      adm: texto(linha.adm),
'''),
    ('src/modules/relatorios/services/relatorios.ts',
     r'''      cidade: texto(linha.cidade),
      regiao: texto(linha.regiao),
''',
     r'''      cidade: texto(linha.cidade),
      rrm: texto(linha.rrm),
      regiao: texto(linha.regiao),
      adm: texto(linha.adm),
'''),
    ('src/modules/relatorios/components/FiltrosDoRelatorio.tsx',
     r'''import { opcoesCasaOracao, opcoesRegiao, opcoesSetor } from "../regras";''',
     r'''import { opcoesAdm, opcoesCasaOracao, opcoesRegiao, opcoesRrm, opcoesSetor } from "../regras";'''),
    ('src/modules/relatorios/components/FiltrosDoRelatorio.tsx',
     r'''      {tem("regiao") && (
        <Campo id="rel-regiao" rotulo="RA (Regional Administrativa)">
          <select
            id="rel-regiao"
            value={valores.regiaoId}
            onChange={(e) => mudar({ regiaoId: e.target.value, setorId: "", casaOracaoId: "" })}''',
     r'''      {tem("rrm") && (
        <Campo id="rel-rrm" rotulo="RRM (Reunião Regional Ministerial)">
          <select
            id="rel-rrm"
            value={valores.rrmId ?? ""}
            onChange={(e) => mudar({ rrmId: e.target.value, regiaoId: "", admId: "", setorId: "", casaOracaoId: "" })}
            disabled={desabilitado}
            className={classeCampo}
          >
            <option value="">Todas as RRMs</option>
            {opcoesRrm(organizacao).map((opcao) => (
              <option key={opcao.id} value={opcao.id}>
                {opcao.rotulo}
              </option>
            ))}
          </select>
        </Campo>
      )}

      {tem("regiao") && (
        <Campo id="rel-regiao" rotulo="RA (Regional Administrativa)">
          <select
            id="rel-regiao"
            value={valores.regiaoId}
            onChange={(e) => mudar({ regiaoId: e.target.value, admId: "", setorId: "", casaOracaoId: "" })}'''),
    ('src/modules/relatorios/components/FiltrosDoRelatorio.tsx',
     r'''{opcoesRegiao(organizacao).map(''',
     r'''{opcoesRegiao(organizacao, valores.rrmId).map('''),
    ('src/modules/relatorios/components/FiltrosDoRelatorio.tsx',
     r'''      {tem("setor") && (
''',
     r'''      {tem("adm") && (
        <Campo id="rel-adm" rotulo="ADM (Administração)">
          <select
            id="rel-adm"
            value={valores.admId ?? ""}
            onChange={(e) => mudar({ admId: e.target.value, setorId: "", casaOracaoId: "" })}
            disabled={desabilitado || !valores.regiaoId}
            className={classeCampo}
          >
            <option value="">{valores.regiaoId ? "Todas as ADMs" : "Escolha a RA primeiro"}</option>
            {opcoesAdm(organizacao, valores.regiaoId).map((opcao) => (
              <option key={opcao.id} value={opcao.id}>
                {opcao.rotulo}
              </option>
            ))}
          </select>
        </Campo>
      )}

      {tem("setor") && (
'''),
    ('src/modules/relatorios/components/FiltrosDoRelatorio.tsx',
     r'''{opcoesSetor(organizacao, valores.regiaoId).map(''',
     r'''{opcoesSetor(organizacao, valores.regiaoId, valores.admId).map('''),
    ('src/modules/relatorios/components/FiltrosDoRelatorio.tsx',
     r'''{opcoesCasaOracao(organizacao, valores.regiaoId, valores.setorId).map(''',
     r'''{opcoesCasaOracao(organizacao, valores.regiaoId, valores.setorId, valores.admId).map('''),
]


# Arquivos NOVOS (o instalador recusa se algum já existir)
NOVOS = {
    'src/modules/relatorios/regras.rrmadm.test.ts': r'''/** SysMúsica — Testes das listas encadeadas RRM › RA › ADM › Setor › Casa de Oração dos filtros de relatório. */
import { describe, expect, it } from "vitest";
import type { NoOrganizacao } from "@/modules/organizacao/tipos";
import { FILTROS_VAZIOS, opcoesAdm, opcoesCasaOracao, opcoesRegiao, opcoesRrm, opcoesSetor, resumoFiltros, rotulosDosFiltros } from "./regras";
import { DEFINICOES_RELATORIO } from "./catalogo";

const no = (id: string, nome: string, nivel: string, parent_id: string | null) => ({ id, nome, nivel, parent_id, ativo: true });

const NOS = [
  no("e1", "Bahia", "ESTADO", null),
  no("r1", "RRM Conquista", "RRM", "e1"),
  no("r2", "RRM Salvador", "RRM", "e1"),
  no("ra1", "RA Jequié", "RA", "r1"),
  no("ra2", "RA Salvador", "RA", "r2"),
  no("a1", "ADM Ipiaú", "ADM", "ra1"),
  no("a2", "ADM Jequié", "ADM", "ra1"),
  no("s1", "Setor 1", "SETOR", "a1"),
  no("c1", "Casa do Setor", "CASA_ORACAO", "s1"),
  no("c2", "Casa Direta", "CASA_ORACAO", "a1"),
  no("c3", "Casa da Outra ADM", "CASA_ORACAO", "a2"),
] as unknown as NoOrganizacao[];

const ids = (lista: { id: string }[]) => lista.map((item) => item.id).sort();

describe("filtros de organização dos relatórios", () => {
  it("lista as RRMs e filtra as RAs pela RRM escolhida", () => {
    expect(ids(opcoesRrm(NOS))).toEqual(["r1", "r2"]);
    expect(ids(opcoesRegiao(NOS))).toEqual(["ra1", "ra2"]);
    expect(ids(opcoesRegiao(NOS, "r1"))).toEqual(["ra1"]);
  });

  it("lista as ADMs só depois de escolher a RA", () => {
    expect(opcoesAdm(NOS, "")).toEqual([]);
    expect(ids(opcoesAdm(NOS, "ra1"))).toEqual(["a1", "a2"]);
  });

  it("limita setores e casas à ADM escolhida", () => {
    expect(ids(opcoesSetor(NOS, "ra1"))).toEqual(["s1"]);
    expect(opcoesSetor(NOS, "ra1", "a2")).toEqual([]);
    expect(ids(opcoesCasaOracao(NOS, "ra1", ""))).toEqual(["c1", "c2", "c3"]);
    expect(ids(opcoesCasaOracao(NOS, "ra1", "", "a1"))).toEqual(["c1", "c2"]);
    expect(ids(opcoesCasaOracao(NOS, "ra1", "", "a2"))).toEqual(["c3"]);
    expect(ids(opcoesCasaOracao(NOS, "ra1", "s1", "a1"))).toEqual(["c1"]);
  });

  it("mostra RRM e ADM no resumo dos filtros", () => {
    const filtros = { ...FILTROS_VAZIOS, rrmId: "r1", regiaoId: "ra1", admId: "a1" };
    const opcoes = { organizacao: NOS, cargos: [], instrumentos: [], eventos: [] };
    const rotulos = rotulosDosFiltros(filtros, opcoes);
    expect(rotulos.rrm).toBe("RRM Conquista");
    expect(rotulos.adm).toBe("ADM Ipiaú");
    const membros = DEFINICOES_RELATORIO.find((d) => d.id === "membros");
    if (!membros) throw new Error("Relatório de membros não encontrado no catálogo.");
    expect(resumoFiltros(membros, filtros, rotulos)).toBe("RRM: RRM Conquista · RA: RA Jequié · ADM: ADM Ipiaú");
  });

  it("os relatórios de presença, membros e eventos oferecem os filtros RRM e ADM", () => {
    for (const id of ["presenca", "membros", "eventos"]) {
      const filtros = DEFINICOES_RELATORIO.find((d) => d.id === id)?.filtros ?? [];
      expect(filtros).toContain("rrm");
      expect(filtros).toContain("adm");
    }
  });
});
''',
}


# Arquivos a REMOVER: só são apagados se o conteúdo for idêntico ao esperado (cópia fica no backup)
REMOVER = {}


# Arquivos SUBSTITUÍDOS por inteiro: só troca se o original tiver o hash (sha256, fim de linha normalizado) esperado
SUBST = {}


def ler(caminho):
    with open(caminho, "r", encoding="utf-8", newline="") as f:
        return f.read()

def eol_de(txt):
    return "\r\n" if "\r\n" in txt else "\n"

def adaptar(trecho, eol):
    return trecho.replace("\n", eol) if eol != "\n" else trecho

def norm(t):
    return t.replace("\r\n", "\n").rstrip("\n")

conteudo, problemas = {}, []
for arq, antigo, novo in EDITS:
    if arq in conteudo:
        continue
    caminho = os.path.join(RAIZ, arq)
    if not os.path.isfile(caminho):
        problemas.append(f"ARQUIVO NÃO ENCONTRADO: {arq}")
        conteudo[arq] = None
    else:
        conteudo[arq] = ler(caminho)

for arq, antigo, novo in EDITS:
    txt = conteudo.get(arq)
    if txt is None:
        continue
    n = txt.count(adaptar(antigo, eol_de(txt)))
    if n != 1:
        resumo = antigo.strip().split("\n")[0][:80]
        problemas.append(f"{arq}: trecho «{resumo}…» aparece {n} vez(es) (esperado 1)")

for arq in list(NOVOS):
    p = os.path.join(RAIZ, arq)
    if os.path.exists(p):
        if norm(ler(p)) == norm(NOVOS[arq]):
            print(f"já existe, idêntico (mantido): {arq}")
            del NOVOS[arq]
        else:
            problemas.append(f"JÁ EXISTE E É DIFERENTE (não vou sobrescrever): {arq}")

for arq, esperado in REMOVER.items():
    caminho = os.path.join(RAIZ, arq)
    if not os.path.isfile(caminho):
        problemas.append(f"PARA REMOVER, NÃO ENCONTRADO: {arq}")
    elif ler(caminho).replace("\r\n", "\n").strip() != esperado.replace("\r\n", "\n").strip():
        problemas.append(f"PARA REMOVER, CONTEÚDO DIFERENTE DO ESPERADO (não vou apagar): {arq}")

for arq, info in SUBST.items():
    caminho = os.path.join(RAIZ, arq)
    if not os.path.isfile(caminho):
        problemas.append(f"PARA SUBSTITUIR, NÃO ENCONTRADO: {arq}")
    elif hashlib.sha256(norm(ler(caminho)).encode("utf-8")).hexdigest() != info["sha"]:
        problemas.append(f"PARA SUBSTITUIR, O ARQUIVO É DIFERENTE DO ESPERADO (não vou sobrescrever): {arq}")

if problemas:
    print("NADA FOI ALTERADO. Divergências encontradas:")
    for p in problemas:
        print("  -", p)
    print("Se TODOS dizem 0 vez(es) / JÁ EXISTE, esta parte provavelmente já foi aplicada.")
    sys.exit(2)

alterados, criados = [], []
for arq in dict.fromkeys(a for a, _, _ in EDITS):
    origem = os.path.join(RAIZ, arq)
    destino = os.path.join(BKP, arq)
    os.makedirs(os.path.dirname(destino), exist_ok=True)
    shutil.copy2(origem, destino)
    txt = conteudo[arq]
    eol = eol_de(txt)
    for a, antigo, novo in EDITS:
        if a != arq:
            continue
        ant = adaptar(antigo, eol)
        if txt.count(ant) != 1:
            print(f"ERRO: {arq}: trecho mudou durante a aplicação. Nada foi gravado.")
            sys.exit(2)
        txt = txt.replace(ant, adaptar(novo, eol), 1)
    with open(origem, "w", encoding="utf-8", newline="") as f:
        f.write(txt)
    alterados.append(arq)

substituidos = []
for arq, info in SUBST.items():
    origem = os.path.join(RAIZ, arq)
    destino = os.path.join(BKP, arq)
    os.makedirs(os.path.dirname(destino), exist_ok=True)
    shutil.copy2(origem, destino)
    eol = eol_de(ler(origem))
    with open(origem, "w", encoding="utf-8", newline="") as f:
        f.write(adaptar(info["novo"].rstrip("\n") + "\n", eol))
    substituidos.append(arq)

removidos = []
for arq in REMOVER:
    origem = os.path.join(RAIZ, arq)
    destino = os.path.join(BKP, arq)
    os.makedirs(os.path.dirname(destino), exist_ok=True)
    shutil.copy2(origem, destino)
    os.remove(origem)
    removidos.append(arq)

for arq, cont in NOVOS.items():
    destino = os.path.join(RAIZ, arq)
    os.makedirs(os.path.dirname(destino), exist_ok=True)
    with open(destino, "w", encoding="utf-8", newline="") as f:
        f.write(cont)
    criados.append(arq)

with open(os.path.join(BKP, ".arquivos"), "w", encoding="utf-8") as f:
    f.write("\n".join(a for a in alterados + substituidos + criados if a.endswith((".ts", ".tsx"))) + "\n")
with open(os.path.join(BKP, ".novos"), "w", encoding="utf-8") as f:
    f.write("\n".join(criados) + "\n")
print(f"OK: {len(EDITS)} trocas em {len(alterados)} arquivos + {len(substituidos)} substituídos + {len(criados)} arquivos novos + {len(removidos)} removidos. Backup em {BKP}")
PYSCRIPT
rc=$?
[ $rc -eq 0 ] || { echo "Nada foi alterado (veja acima)."; exit 1; }

reverter() {
  echo "↩ Desfazendo as alterações a partir de $BKP ..."
  ( cd "$BKP" && find . -type f ! -name .arquivos ! -name .novos -print0 | while IFS= read -r -d '' f; do cp "$f" "$RAIZ/$f"; done )
  while IFS= read -r n; do [ -n "$n" ] && { rm -f "$RAIZ/$n"; rmdir -p "$(dirname "$RAIZ/$n")" 2>/dev/null; }; done < "$BKP/.novos"
  true
}

passo() {
  nome="$1"; shift
  echo "▶ $nome"
  if "$@" > /tmp/relatoriosrr-passo.out 2>&1; then
    echo "  ok"
  else
    echo "  FALHOU: $nome"; tail -40 /tmp/relatoriosrr-passo.out
    reverter; echo "Alterações desfeitas. Me envie o log: $LOG"
    exit 1
  fi
}

echo; echo "== 2/3  Verificações =="
mapfile -t ARQ < <(grep -v '^$' "$BKP/.arquivos")
passo "tipos (tsc)"      npx tsc --noEmit
passo "testes (vitest)"  npx vitest run
passo "lint (eslint)"    npx eslint "${ARQ[@]}"
passo "build"            npm run build

echo; echo "== 3/3  PRONTO =="
echo "Backup: $BKP"
echo "Pronto. Abra Relatórios e teste os filtros RRM, RA, ADM, Setor e Casa de Oração; depois faça o git push."
echo "Depois confira as telas (passo a passo na conversa) e, se estiver tudo certo, faça o git push."
) 2>&1 | tee "$LOG"
