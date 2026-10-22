#!/usr/bin/env bash
# =============================================================================
# Sysmusica — DIAGNÓSTICO (somente leitura, não altera nada).
# Procura todas as formas de escrever o nome do sistema e mostra o código da impressão.
# Uso:  cd /workspaces/sysmusica/sysmusica && bash diag-nome-impressao.sh
# Saída: /tmp/diag-nome.txt  (anexe esse arquivo na conversa)
# =============================================================================
OUT=/tmp/diag-nome.txt
[ -f package.json ] && [ -d src ] || { echo "ERRO: rode dentro da pasta sysmusica (onde está o package.json)."; exit 1; }
EXC="--exclude-dir=node_modules --exclude-dir=.next --exclude-dir=.git --exclude-dir=coverage --exclude=package-lock.json"
{
echo "##### 1. Escritas do nome que NÃO são 'Sysmusica' (qualquer maiúscula/acento diferente)"
grep -rnIE "Sys[mM][uúUÚ]sica|SYSM[UÚ]SICA|sysm[uú]sica|Sysm[úu]sica" $EXC . | grep -vE "Sysmusica" | grep -vE "(^|[^A-Za-z])sysmusica([^A-Za-z]|$)" | head -400
echo
echo "##### 2. Quantidade por arquivo (formas com acento ou com S/M maiúsculos erradas)"
grep -rcIE "SysMúsica|Sysmúsica|SYSMÚSICA|SysMusica|SYSMUSICA|sysmúsica" $EXC . | grep -v ":0$" | sort -t: -k2 -nr
echo
echo "##### 3. Usos em minúsculo 'sysmusica' (URLs, pastas, pacote: normalmente NÃO se mexe)"
grep -rnIw "sysmusica" $EXC . | head -60
echo
echo "##### 4. Banco: migrações e textos gravados que citam o nome"
grep -rnIE "Sys[mM][uú]sica|SYSM[UÚ]SICA" supabase 2>/dev/null | head -80
echo
echo "##### 5. src/lib/exportacao.ts (impressão: título, cabeçalho, estilos)"
wc -l src/lib/exportacao.ts
cat src/lib/exportacao.ts
echo
echo "##### 6. Quem monta o título das impressões (chamadas de imprimirTabela e de títulos)"
grep -rnE "imprimirTabela|abrirJanelaImpressao|escreverImpressao|montarImpressao" $EXC src | head -40
} > "$OUT" 2>&1
echo "Pronto: $OUT ($(wc -l < "$OUT") linhas). Anexe esse arquivo na conversa."
