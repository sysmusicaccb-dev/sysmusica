#!/usr/bin/env bash
# =============================================================================
# SysMúsica — AUDITORIA 2: backup passa a incluir mais 5 tabelas (migração 0047)
#
#  PRECISA DE SQL (0047): amplia a lista de tabelas do backup (código + função backup_aplicar do banco).
#
# Segurança: confere cada trecho (exatamente 1 vez), faz backup em /tmp/bkp-auditoria-2-*, aplica,
# roda tsc, vitest, eslint e build; se algo falhar, DESFAZ tudo sozinho (inclusive os arquivos novos).
#
# Uso:  cd /workspaces/sysmusica/sysmusica && rm -rf .next && bash instalar-auditoria-2.sh
# Log:  /tmp/instalar-auditoria-2.log
# =============================================================================

LOG=/tmp/instalar-auditoria-2.log
BKP=/tmp/bkp-auditoria-2-$(date +%Y%m%d-%H%M%S)
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
    ('src/modules/backup/tabelas.test.ts',
     r'''      "usuarios",
      "usuario_grupos",
      "usuario_vinculos",
    ]);''',
     r'''      "usuarios",
      "usuario_grupos",
      "usuario_vinculos",
      "usuario_cidades",
      "usuario_preferencias",
    ]);'''),
    ('src/modules/backup/tabelas.ts',
     r'''  | "presencas_avulsas";''',
     r'''  | "presencas_avulsas"
  | "usuario_cidades"
  | "usuario_preferencias"
  | "casas_oracao_historico"
  | "qr_historico"
  | "cadastro_publico_config";'''),
    ('src/modules/backup/tabelas.ts',
     r'''  tabela("membros", "Membros", "membros", {
''',
     r'''  tabela("usuario_cidades", "Cidades dos usuários", "usuarios", {
    pk: ["usuario_id", "cidade"],
    referencias: [{ coluna: "usuario_id", tabela: "usuarios" }],
  }),
  tabela("usuario_preferencias", "Preferências dos usuários (tema, cor, fonte)", "usuarios", {
    pk: ["usuario_id"],
    referencias: [{ coluna: "usuario_id", tabela: "usuarios" }],
  }),
  // Histórico de mudança de setor/ADM das casas: só se devolve o que foi apagado (fica depois dos usuários na ordem)
  tabela("casas_oracao_historico", "Histórico das casas de oração", "organizacao", {
    somenteInserir: true,
    referencias: [{ coluna: "casa_oracao_id", tabela: "casas_oracao" }],
  }),
  // Prazo (em dias) dos pedidos do link público: uma linha só
  tabela("cadastro_publico_config", "Prazo dos cadastros pendentes", "membros", {
    referencias: [{ coluna: "atualizado_por", tabela: "usuarios" }],
  }),
  tabela("membros", "Membros", "membros", {
'''),
    ('src/modules/backup/tabelas.ts',
     r'''  tabela("eventos", "Eventos", "eventos", {
''',
     r'''  // QR de membros já revogados: o código (token_hash) nunca vai para o navegador
  tabela("qr_historico", "Histórico de QR revogados", "membros", {
    somenteInserir: true,
    referencias: [{ coluna: "membro_id", tabela: "membros" }],
    sensiveis: ["token_hash"],
  }),
  tabela("eventos", "Eventos", "eventos", {
'''),
    ('src/modules/backup/tabelas.ts',
     r'''    descricao: "Estados, RRMs, RAs, ADMs, setores e casas de oração",
    tabelas: ["estados", "rrms", "ras", "adms", "setores", "casas_oracao"],''',
     r'''    descricao: "Estados, RRMs, RAs, ADMs, setores, casas de oração e o histórico delas",
    tabelas: ["estados", "rrms", "ras", "adms", "setores", "casas_oracao", "casas_oracao_historico"],'''),
    ('src/modules/backup/tabelas.ts',
     r'''    descricao: "Perfil, grupos e vínculos (a senha não é guardada no backup)",
    tabelas: ["usuarios", "usuario_grupos", "usuario_vinculos"],''',
     r'''    descricao: "Perfil, grupos, vínculos, cidades e preferências (a senha não é guardada no backup)",
    tabelas: ["usuarios", "usuario_grupos", "usuario_vinculos", "usuario_cidades", "usuario_preferencias"],'''),
    ('src/modules/backup/tabelas.ts',
     r'''    tabelas: ["membros", "membros_cadastro", "cadastros_pendentes"],''',
     r'''    tabelas: ["membros", "membros_cadastro", "cadastros_pendentes", "cadastro_publico_config", "qr_historico"],'''),
]


# Arquivos NOVOS (o instalador recusa se algum já existir)
NOVOS = {
    'supabase/migrations/0047_backup_mais_tabelas.sql': r'''-- =============================================================================
-- SysMúsica — Migração 0047: o backup passa a guardar mais 5 tabelas (resultado da auditoria)
--
--  Entram no backup e na restauração (grupo entre parênteses):
--   * cadastro_publico_config  — prazo dos pedidos do link público (Membros)
--   * qr_historico             — histórico de QR revogados; o código (token_hash) fica protegido (Membros)
--   * usuario_cidades          — cidades de abrangência dos usuários (Usuários)
--   * usuario_preferencias     — tema, cor e fonte de cada usuário (Usuários)
--   * casas_oracao_historico   — histórico de mudanças de setor/ADM das casas (Organização)
--  Fora do backup de propósito: auditoria (histórico longo, não se restaura), linhas_painel (catálogo fixo
--  do sistema) e tabelas temporárias do cadastro público.
--  Esta migração só amplia a lista permitida da função backup_aplicar; os dados atuais não mudam.
--  O código (src/modules/backup/tabelas.ts) é atualizado pelo instalador instalar-auditoria-2.sh.
-- Rode UMA vez no SQL Editor do Supabase, ANTES do git push. Pode rodar de novo sem problema.
-- Se der erro, rode:  rollback;
-- =============================================================================
begin;
set local check_function_bodies = off;

do $$
begin
  if to_regprocedure('public.backup_aplicar(uuid, jsonb, jsonb)') is null
     or to_regclass('public.cadastro_publico_config') is null
     or to_regclass('public.qr_historico') is null
     or to_regclass('public.usuario_cidades') is null
     or to_regclass('public.usuario_preferencias') is null
     or to_regclass('public.casas_oracao_historico') is null then
    raise exception 'Aplique primeiro as migrações até a 0046. Nada foi alterado.';
  end if;
end $$;

create or replace function public.backup_aplicar(p_usuario uuid, p_operacoes jsonb, p_resumo jsonb)
returns jsonb
language plpgsql security definer set search_path to 'public'
as $$
declare
  v_op        jsonb;
  v_tabela    text;
  v_acao      text;
  v_linhas    jsonb;
  v_colunas   text[];
  v_def       record;
  v_cols      text;
  v_bcols     text;
  v_set       text;
  v_pk_cond   text;
  v_extra     text;
  v_n         bigint;
  v_ignorados bigint;
  v_resultado jsonb := '[]'::jsonb;
begin
  if p_operacoes is null or jsonb_typeof(p_operacoes) <> 'array' then
    raise exception 'Operações inválidas.';
  end if;

  perform set_config('sysmusica.restaurando', 'sim', true);

  for v_op in select * from jsonb_array_elements(p_operacoes) loop
    v_tabela := v_op ->> 'tabela';
    v_acao   := v_op ->> 'acao';
    v_linhas := coalesce(v_op -> 'linhas', '[]'::jsonb);

    select t.* into v_def
    from (values
      ('estados',             array['id'],                              false, false, ''),
      ('rrms',                array['id'],                              false, false, ''),
      ('ras',                 array['id'],                              false, false, ''),
      ('adms',                array['id'],                              false, false, ''),
      ('setores',             array['id'],                              false, false, ''),
      ('casas_oracao',        array['id'],                              false, false, ''),
      ('familias',            array['id'],                              false, false, ''),
      ('cargos',              array['id'],                              false, false, ''),
      ('finalidades_evento',  array['id'],                              false, false, ''),
      ('instrumentos',        array['id'],                              false, false, ''),
      ('tipos_evento',        array['id'],                              false, false, ''),
      ('hinos',               array['id'],                              false, false, ''),
      ('cadastros_pendentes', array['id'],                              false, false, ''),
      ('membros_cadastro',    array['membro_id'],                       false, false, ''),
      ('dados_ensaio',        array['id'],                              false, false, ''),
      ('dados_ensaio_encarregados', array['id'],                        false, false, ''),
      ('dados_ensaio_hinos',  array['id'],                              false, false, ''),
      ('grupos',              array['id'],                              false, false, ''),
      ('grupo_permissoes',    array['grupo_id', 'permissao_codigo'],    false, false, ''),
      ('usuarios',            array['id'],                              false, false, 'login'),
      ('usuario_grupos',      array['usuario_id', 'grupo_id'],          false, false, ''),
      ('usuario_vinculos',    array['usuario_id', 'nivel', 'alvo_id'],  false, false, ''),
      ('usuario_cidades',     array['usuario_id', 'cidade'],            false, false, ''),
      ('usuario_preferencias', array['usuario_id'],                      false, false, ''),
      ('casas_oracao_historico', array['id'],                           false, true,  ''),
      ('qr_historico',        array['id'],                              false, true,  ''),
      ('cadastro_publico_config', array['id'],                          false, false, ''),
      ('membros',             array['id'],                              true,  false, ''),
      ('eventos',             array['id'],                              true,  false, ''),
      ('portarias',           array['id'],                              true,  false, ''),
      ('portarias_historico', array['id'],                              false, true,  ''),
      ('presencas',           array['id'],                              true,  false, ''),
      ('presencas_avulsas',   array['id'],                              true,  false, '')
    ) as t(tabela, pk, soft, so_inserir, extra)
    where t.tabela = v_tabela;
    if not found then
      raise exception 'Tabela não permitida na restauração: %', coalesce(v_tabela, '(vazia)');
    end if;

    if v_acao is null or v_acao not in ('inserir', 'atualizar', 'excluir_logico', 'excluir') then
      raise exception 'Ação inválida na restauração: %', coalesce(v_acao, '(vazia)');
    end if;
    if v_def.so_inserir and v_acao <> 'inserir' then
      raise exception 'A tabela % só aceita devolver registros apagados.', v_tabela;
    end if;
    if v_acao = 'excluir_logico' and not v_def.soft then
      raise exception 'A tabela % não usa exclusão lógica.', v_tabela;
    end if;
    if v_acao = 'excluir' and v_def.soft then
      raise exception 'Os itens da tabela % são excluídos logicamente.', v_tabela;
    end if;
    if jsonb_typeof(v_linhas) <> 'array' then
      raise exception 'Linhas inválidas em %.', v_tabela;
    end if;
    if jsonb_array_length(v_linhas) = 0 then
      continue;
    end if;

    select coalesce(array_agg(x), '{}'::text[]) into v_colunas
    from jsonb_array_elements_text(coalesce(v_op -> 'colunas', '[]'::jsonb)) as x;

    if not (v_def.pk <@ v_colunas) then
      raise exception 'Faltam as colunas de identificação em %.', v_tabela;
    end if;

    -- Só colunas que existem e podem ser gravadas (as geradas ficam de fora)
    select string_agg(quote_ident(c.column_name), ', ' order by c.ordinal_position),
           string_agg(format('b.%I', c.column_name), ', ' order by c.ordinal_position),
           string_agg(format('%1$I = b.%1$I', c.column_name), ', ' order by c.ordinal_position)
             filter (where c.column_name <> all (v_def.pk))
      into v_cols, v_bcols, v_set
    from information_schema.columns c
    where c.table_schema = 'public' and c.table_name = v_tabela
      and c.is_generated = 'NEVER' and c.column_name = any (v_colunas);

    select string_agg(format('c.%1$I = b.%1$I', k), ' and ') into v_pk_cond from unnest(v_def.pk) as k;

    v_ignorados := 0;

    if v_acao = 'inserir' then
      -- Usuários só voltam se a conta de login ainda existir (a senha não é guardada no backup)
      v_extra := case when v_def.extra = 'login' then 'where exists (select 1 from auth.users a where a.id = b.id)' else '' end;
      execute format(
        'insert into public.%1$I (%2$s) select %3$s from jsonb_populate_recordset(null::public.%1$I, $1) b %4$s',
        v_tabela, v_cols, v_bcols, v_extra) using v_linhas;
      get diagnostics v_n = row_count;
      v_ignorados := jsonb_array_length(v_linhas) - v_n;

    elsif v_acao = 'atualizar' then
      if v_set is null then
        v_n := 0;
      else
        execute format(
          'update public.%1$I c set %2$s from jsonb_populate_recordset(null::public.%1$I, $1) b where %3$s',
          v_tabela, v_set, v_pk_cond) using v_linhas;
        get diagnostics v_n = row_count;
      end if;

    elsif v_acao = 'excluir_logico' then
      execute format(
        'update public.%1$I c set excluido_em = now() from jsonb_populate_recordset(null::public.%1$I, $1) b where %2$s and c.excluido_em is null',
        v_tabela, v_pk_cond) using v_linhas;
      get diagnostics v_n = row_count;

    else
      execute format(
        'delete from public.%1$I c using jsonb_populate_recordset(null::public.%1$I, $1) b where %2$s',
        v_tabela, v_pk_cond) using v_linhas;
      get diagnostics v_n = row_count;
    end if;

    v_resultado := v_resultado || jsonb_build_object(
      'tabela', v_tabela, 'acao', v_acao, 'afetados', v_n, 'ignorados', v_ignorados);
  end loop;

  perform set_config('sysmusica.restaurando', '', true);

  -- Uma única entrada resumida na auditoria (a auditoria linha a linha ficou pausada)
  insert into public.auditoria (usuario_id, acao, entidade, entidade_id, detalhes)
  values (p_usuario, 'backup_restaurado', 'backup', null,
          coalesce(p_resumo, '{}'::jsonb) || jsonb_build_object('operacoes', v_resultado));

  return v_resultado;
end;
$$;
commit;
select set_config('sysmusica.migracao_0047', 'ok', false);
''',
    'src/modules/backup/tabelas.auditoria.test.ts': r'''import { describe, expect, it } from "vitest";
import { GRUPOS_DADOS, TABELAS, ordenarParaGravar } from "./tabelas";

// Auditoria: tabelas acrescentadas ao backup (migração 0047)
describe("backup — tabelas da auditoria", () => {
  const novas = ["cadastro_publico_config", "qr_historico", "usuario_cidades", "usuario_preferencias", "casas_oracao_historico"] as const;

  it("estão na lista e em exatamente um grupo de dados", () => {
    for (const nome of novas) {
      expect(TABELAS.some((t) => t.nome === nome)).toBe(true);
      expect(GRUPOS_DADOS.filter((g) => g.tabelas.includes(nome))).toHaveLength(1);
    }
  });

  it("o código do QR revogado é protegido e os históricos só aceitam devolver apagados", () => {
    const qr = TABELAS.find((t) => t.nome === "qr_historico");
    expect(qr?.sensiveis).toContain("token_hash");
    expect(qr?.somenteInserir).toBe(true);
    expect(TABELAS.find((t) => t.nome === "casas_oracao_historico")?.somenteInserir).toBe(true);
  });

  it("os pais vêm antes dos filhos na gravação", () => {
    const ordem = ordenarParaGravar(["qr_historico", "membros", "usuario_cidades", "usuarios"]);
    expect(ordem.indexOf("membros")).toBeLessThan(ordem.indexOf("qr_historico"));
    expect(ordem.indexOf("usuarios")).toBeLessThan(ordem.indexOf("usuario_cidades"));
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
  if "$@" > /tmp/audit2-passo.out 2>&1; then
    echo "  ok"
  else
    echo "  FALHOU: $nome"; tail -40 /tmp/audit2-passo.out
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
echo "Pronto. PRÓXIMO PASSO: rode o SQL supabase/migrations/0047_backup_mais_tabelas.sql no Supabase (SQL Editor) e só então o git push."
echo "Depois confira as telas (passo a passo na conversa) e, se estiver tudo certo, faça o git push."
) 2>&1 | tee "$LOG"
