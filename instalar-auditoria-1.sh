#!/usr/bin/env bash
# =============================================================================
# SysMúsica — AUDITORIA 1: cabeçalhos de segurança + migração 0046 (acessos e índices do banco)
#
#  PRECISA DE SQL (0046): copia o arquivo da migração e adiciona cabeçalhos de segurança em next.config.ts.
#
# Segurança: confere cada trecho (exatamente 1 vez), faz backup em /tmp/bkp-auditoria-1-*, aplica,
# roda tsc, vitest, eslint e build; se algo falhar, DESFAZ tudo sozinho (inclusive os arquivos novos).
#
# Uso:  cd /workspaces/sysmusica/sysmusica && rm -rf .next && bash instalar-auditoria-1.sh
# Log:  /tmp/instalar-auditoria-1.log
# =============================================================================

LOG=/tmp/instalar-auditoria-1.log
BKP=/tmp/bkp-auditoria-1-$(date +%Y%m%d-%H%M%S)
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
    ('next.config.ts',
     r'''  cacheComponents: true,
''',
     r'''  cacheComponents: true,
  // Cabeçalhos de segurança em todas as páginas (auditoria). Não mexa sem testar: o formulário público usa o
  // Cloudflare Turnstile, então ainda NÃO há Content-Security-Policy (fica para uma etapa própria).
  async headers() {
    return [
      {
        source: "/:path*",
        headers: [
          { key: "Strict-Transport-Security", value: "max-age=63072000; includeSubDomains" }, // só HTTPS
          { key: "X-Content-Type-Options", value: "nosniff" }, // o navegador não "adivinha" tipos de arquivo
          { key: "X-Frame-Options", value: "SAMEORIGIN" }, // ninguém embute o sistema em outro site
          { key: "Referrer-Policy", value: "strict-origin-when-cross-origin" }, // não vaza endereços internos
          { key: "Permissions-Policy", value: "camera=(self), microphone=(), geolocation=(), payment=()" },
        ],
      },
    ];
  },
'''),
]


# Arquivos NOVOS (o instalador recusa se algum já existir)
NOVOS = {
    'supabase/migrations/0046_endurecimento_grants_indices.sql': r'''-- =============================================================================
-- SysMúsica — Migração 0046: endurecimento de acessos e índices (resultado da auditoria)
--
--  O que faz (nada aqui muda o que as telas mostram ou gravam):
--   A) Tira dos papéis "anon" e "authenticated" os privilégios TRUNCATE, TRIGGER e REFERENCES nas tabelas.
--      (TRUNCATE ignora as regras de linha do RLS; o sistema nunca precisa dele pelo navegador.)
--   B) Tira do visitante sem login ("anon") a execução de funções internas (gatilhos e auxiliares).
--      Continua liberada para o visitante apenas opcoes_cadastro_publico (formulário público).
--      Usuários logados e o servidor (service_role) mantêm tudo como estava.
--   C) Cria índices que faltavam em 15 chaves estrangeiras (deixa consultas e exclusões mais rápidas).
-- Rode UMA vez no SQL Editor do Supabase, ANTES do git push. Pode rodar de novo sem problema.
-- Se der erro, rode:  rollback;
-- =============================================================================
begin;

do $$
begin
  if to_regclass('public.cadastro_publico_config') is null then
    raise exception 'Aplique primeiro as migrações até a 0045. Nada foi alterado.';
  end if;
end $$;

-- A) Privilégios perigosos em todas as tabelas do schema public
do $$
declare t record;
begin
  for t in select c.relname from pg_class c join pg_namespace n on n.oid = c.relnamespace
            where n.nspname = 'public' and c.relkind in ('r', 'p') loop
    execute format('revoke truncate, trigger, references on table public.%I from anon, authenticated', t.relname);
  end loop;
end $$;

-- B) Funções: sem execução para o visitante sem login (exceto a do formulário público)
do $$
declare f record;
begin
  for f in select p.oid::regprocedure as assinatura, p.proname
             from pg_proc p join pg_namespace n on n.oid = p.pronamespace
            where n.nspname = 'public' and p.prokind = 'f'
              and has_function_privilege('anon', p.oid, 'execute')
              and p.proname <> 'opcoes_cadastro_publico' loop
    execute format('revoke execute on function %s from public, anon', f.assinatura);
    -- quem já usava continua usando: usuário logado e servidor
    execute format('grant execute on function %s to authenticated, service_role', f.assinatura);
  end loop;
end $$;

-- C) Índices das chaves estrangeiras sem índice
create index if not exists idx_cadastros_pendentes_membro on public.cadastros_pendentes (membro_id);
create index if not exists idx_cadastros_pendentes_instrumento on public.cadastros_pendentes (instrumento_id);
create index if not exists idx_cadastros_pendentes_cargo on public.cadastros_pendentes (cargo_id);
create index if not exists idx_dados_ensaio_hino_abertura on public.dados_ensaio (hino_abertura_id);
create index if not exists idx_dados_ensaio_hinos_hino on public.dados_ensaio_hinos (hino_id);
create index if not exists idx_grupo_permissoes_permissao on public.grupo_permissoes (permissao_codigo);
create index if not exists idx_membros_origem_casa on public.membros (origem_casa_oracao_id);
create index if not exists idx_portarias_decidida_por on public.portarias (decidida_por);
create index if not exists idx_presencas_linha on public.presencas (linha_codigo);
create index if not exists idx_presencas_instrumento on public.presencas (instrumento_id);
create index if not exists idx_presencas_avulsas_linha on public.presencas_avulsas (linha_codigo);
create index if not exists idx_presencas_avulsas_instrumento on public.presencas_avulsas (instrumento_id);
create index if not exists idx_presencas_avulsas_origem_casa on public.presencas_avulsas (origem_casa_oracao_id);
create index if not exists idx_qr_historico_membro on public.qr_historico (membro_id);
create index if not exists idx_rrms_estado on public.rrms (estado_id);

-- Conferência: nada pode sobrar para o visitante além da função do formulário público
do $$
declare restantes text;
begin
  select string_agg(p.proname, ', ') into restantes
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.prokind = 'f'
     and has_function_privilege('anon', p.oid, 'execute') and p.proname <> 'opcoes_cadastro_publico';
  if restantes is not null then
    raise exception 'Ainda executáveis por anon: %. Nada foi alterado.', restantes;
  end if;
end $$;

commit;
select set_config('sysmusica.migracao_0046', 'ok', false);
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
  if "$@" > /tmp/audit1-passo.out 2>&1; then
    echo "  ok"
  else
    echo "  FALHOU: $nome"; tail -40 /tmp/audit1-passo.out
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
echo "Pronto. PRÓXIMO PASSO: rode o SQL supabase/migrations/0046_endurecimento_grants_indices.sql no Supabase (SQL Editor) e só então o git push."
echo "Depois confira as telas (passo a passo na conversa) e, se estiver tudo certo, faça o git push."
) 2>&1 | tee "$LOG"
