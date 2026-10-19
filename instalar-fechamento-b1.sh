cd /workspaces/sysmusica/sysmusica || { echo "Pasta do projeto não encontrada"; exit 1; }
(
set -u
BKP="/tmp/bkp-fechamento-$(date +%H%M%S)"; mkdir -p "$BKP/a"
ALT=("src/modules/backup/tabelas.ts" "supabase/migrations/LEIA-ME.md")
NOV=("supabase/migrations/0032_regras_de_regiao.sql" "supabase/migrations/0033_backup_presencas_avulsas.sql")
for f in "${ALT[@]}"; do mkdir -p "$BKP/a/$(dirname "$f")"; cp "$f" "$BKP/a/$f"; done

reverter() {
  echo ">>> REVERTENDO tudo (nada do que foi tentado fica no projeto)"
  for f in "${ALT[@]}"; do cp "$BKP/a/$f" "$f"; done
  for f in "${NOV[@]}"; do rm -f "$f"; done
  echo ">>> REVERTIDO. Me mande o log: /tmp/fechamento-instalar.log"
}

echo "=== 0) Conferência prévia (só leitura) ==="
for f in "${ALT[@]}" supabase/migrations/0031_casa_de_oracao.sql; do
  [ -f "$f" ] || { echo "ERRO: arquivo esperado não existe: $f"; exit 1; }
done
for f in "${NOV[@]}"; do [ -e "$f" ] && { echo "ERRO: já existe $f (esta etapa já foi instalada?)."; exit 1; }; done

echo; echo "=== 1) Gravando os arquivos ==="
python3 - <<'PYSCRIPT'
import os, sys
NOVOS = {
    "supabase/migrations/0032_regras_de_regiao.sql": r"""-- 0032 — Corrige as regras de acesso por região de eventos e membros
-- A migração 0031 recriou regiao_eventos e regiao_membros como regras comuns (permissivas, para todos os papéis).
-- O correto é o mesmo de regiao_presencas: RESTRITIVAS e só para usuários logados (authenticated).
-- Sem isso, eventos e membros já excluídos reapareciam nas telas e quem tinha abrangência passava por cima
-- das permissões de editar/excluir.
drop policy if exists regiao_eventos on public.eventos;
drop policy if exists regiao_membros on public.membros;

create policy regiao_eventos on public.eventos
  as restrictive for all to authenticated
  using (public.casa_oracao_na_abrangencia(casa_oracao_id))
  with check (public.casa_oracao_na_abrangencia(casa_oracao_id));

create policy regiao_membros on public.membros
  as restrictive for all to authenticated
  using (public.casa_oracao_na_abrangencia(casa_oracao_id))
  with check (public.casa_oracao_na_abrangencia(casa_oracao_id));

do $$
begin
  if (select count(*) from pg_policies
       where schemaname = 'public' and policyname in ('regiao_eventos', 'regiao_membros')
         and permissive = 'RESTRICTIVE' and roles = '{authenticated}') <> 2 then
    raise exception 'As regras de região não ficaram restritivas. Nada foi alterado.';
  end if;
  raise notice 'OK: regras de região de eventos e membros agora são restritivas (só autenticados).';
end $$;
""",
    "supabase/migrations/0033_backup_presencas_avulsas.sql": r"""-- 0033 — Entradas sem cadastro (presencas_avulsas) passam a entrar no backup e na restauração
-- Só acrescenta a tabela na lista permitida da função backup_aplicar (o resto da função não muda).
do $$
declare
  v_def  text;
  v_ant  text := '(''presencas'',           array[''id''],                              true,  false, '''')';
  v_novo text;
begin
  select pg_get_functiondef(p.oid) into v_def
    from pg_proc p
   where p.pronamespace = 'public'::regnamespace and p.proname = 'backup_aplicar';
  if v_def is null then
    raise exception 'A função backup_aplicar não foi encontrada. Nada foi alterado.';
  end if;
  if v_def like '%presencas_avulsas%' then
    raise notice 'backup_aplicar já aceita presencas_avulsas. Nada a fazer.';
    return;
  end if;
  if position(v_ant in v_def) = 0 then
    raise exception 'Não encontrei a linha de presencas na lista da backup_aplicar. Nada foi alterado.';
  end if;
  -- presencas_avulsas usa exclusão lógica (excluido_em), como presencas
  v_novo := v_ant || E',\n      (''presencas_avulsas'',   array[''id''],                              true,  false, '''')';
  execute replace(v_def, v_ant, v_novo);
  if pg_get_functiondef('public.backup_aplicar(uuid, jsonb, jsonb)'::regprocedure) not like '%presencas_avulsas%' then
    raise exception 'A atualização da backup_aplicar não foi aplicada. Nada foi alterado.';
  end if;
  raise notice 'OK: presencas_avulsas agora entra no backup e na restauração.';
end $$;
""",
}

def abrir(c):
    return open(c, encoding="utf-8", newline="").read()

def trocar(texto, antigo, novo, onde):
    if texto.count(antigo) != 1:
        print("ERRO: trecho não encontrado exatamente uma vez em", onde, "->", antigo[:80].replace("\n", "\\n")); sys.exit(1)
    return texto.replace(antigo, novo)

for caminho in NOVOS:
    if os.path.exists(caminho):
        print("ERRO: já existe", caminho); sys.exit(1)

# ---------- Backup: entradas sem cadastro (presencas_avulsas) ----------
a = "src/modules/backup/tabelas.ts"
s = abrir(a)
crlf = "\r\n" in s
s = s.replace("\r\n", "\n")
if "presencas_avulsas" in s:
    print("ERRO: tabelas.ts já cita presencas_avulsas."); sys.exit(1)
# 1) nome da tabela
s = trocar(s, '  | "portarias_historico"\n  | "presencas";', '  | "portarias_historico"\n  | "presencas"\n  | "presencas_avulsas";', a)
# 2) definição (entra depois de "presencas": filhos de eventos, portarias, instrumentos, casas de oração e usuários)
s = trocar(s,
  "  }),\n];\n\n/** Os grupos de dados que o administrador escolhe na hora de restaurar. */",
  "  }),\n"
  "  // Entradas sem cadastro feitas na Portaria (candidato, visitante...): não criam membro; exclusão lógica\n"
  "  tabela(\"presencas_avulsas\", \"Entradas sem cadastro\", \"presencas\", {\n"
  "    exclusaoLogica: true,\n"
  "    referencias: [\n"
  "      { coluna: \"evento_id\", tabela: \"eventos\" },\n"
  "      { coluna: \"portaria_id\", tabela: \"portarias\" },\n"
  "      { coluna: \"instrumento_id\", tabela: \"instrumentos\" },\n"
  "      { coluna: \"origem_casa_oracao_id\", tabela: \"casas_oracao\" },\n"
  "    ],\n"
  "  }),\n"
  "];\n\n/** Os grupos de dados que o administrador escolhe na hora de restaurar. */", a)
# 3) grupo de dados
s = trocar(s, '    descricao: "Presenças registradas nos eventos",\n    tabelas: ["presencas"],',
  '    descricao: "Presenças registradas nos eventos e entradas sem cadastro",\n    tabelas: ["presencas", "presencas_avulsas"],', a)
if crlf: s = s.replace("\n", "\r\n")
open(a, "w", encoding="utf-8", newline="").write(s)

# ---------- LEIA-ME das migrações ----------
l = "supabase/migrations/LEIA-ME.md"
t = abrir(l)
if "0032_regras_de_regiao" not in t:
    quebra = "\r\n" if "\r\n" in t else "\n"
    extra = (
        "\n\n## Migrações 0026 a 0033 (aplicar no Supabase SQL Editor, na ordem, ANTES do git push)\n\n"
        "| Arquivo | O que faz |\n|---|---|\n"
        "| `0026_painel_ao_vivo.sql` | Painel ao vivo do evento (linhas, categorias e contagem) |\n"
        "| `0027_portaria_3h.sql` | A portaria fica aberta de 2h antes até 3h depois do início do evento |\n"
        "| `0028_portaria_toca_avulsa.sql` | Pergunta \"Vai tocar?\" e entrada sem cadastro (tabela presencas_avulsas) |\n"
        "| `0029_instrumento_do_cadastro.sql` | O músico toca só o instrumento do cadastro |\n"
        "| `0030_portaria_encerrada.sql` | Portaria encerrada não aceita nada (só o Administrador corrige registros) |\n"
        "| `0031_casa_de_oracao.sql` | Renomeia Comum para Casa de Oração em todo o banco (tabela casas_oracao, coluna casa_oracao_id, nível CASA_ORACAO) |\n"
        "| `0032_regras_de_regiao.sql` | Corrige regiao_eventos e regiao_membros: restritivas e só para usuários logados |\n"
        "| `0033_backup_presencas_avulsas.sql` | Entradas sem cadastro entram no backup e na restauração |\n"
    )
    t = t.rstrip("\r\n") + extra.replace("\n", quebra)
    open(l, "w", encoding="utf-8", newline="").write(t)

for caminho, conteudo in NOVOS.items():
    os.makedirs(os.path.dirname(caminho) or ".", exist_ok=True)
    open(caminho, "w", encoding="utf-8").write(conteudo)
print("Arquivos gravados:", len(NOVOS), "novos, 2 alterados.")
PYSCRIPT
[ $? -eq 0 ] || { reverter; exit 1; }

echo; echo "=== 2) Parando o servidor de teste e limpando o cache ==="
pkill -f "next dev" 2>/dev/null; pkill -f next-server 2>/dev/null; pkill -f "next/dist" 2>/dev/null; sleep 2
for i in 1 2 3 4 5; do rm -rf .next 2>/dev/null; [ -d .next ] || break; sleep 1; done

echo; echo "=== 3) Conferência de tipos ==="
npx tsc --noEmit || { reverter; exit 1; }
echo; echo "=== 4) Testes automáticos ==="
npx vitest run || { reverter; exit 1; }
echo; echo "=== 5) Lint ==="
npx eslint src/modules/backup || { reverter; exit 1; }
echo; echo "=== 6) Build de produção (pode demorar alguns minutos) ==="
npm run build || { reverter; exit 1; }

echo; echo "=== TUDO CERTO: arquivos gravados e conferidos ==="
git status --short | grep -v "instalar-"
echo
echo "PRÓXIMO PASSO: rodar a migração 0033 no Supabase ANTES de publicar (git push). A 0032 você já aplicou."
) 2>&1 | tee /tmp/fechamento-instalar.log
