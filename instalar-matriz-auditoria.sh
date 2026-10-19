cd /workspaces/sysmusica/sysmusica || { echo "Pasta do projeto não encontrada"; exit 1; }
(
set -u
BKP="/tmp/bkp-matriz-auditoria-$(date +%H%M%S)"; mkdir -p "$BKP/a"
ALT=("src/modules/administracao/components/FormularioGrupo.tsx" "src/modules/auditoria/regras.ts")
for f in "${ALT[@]}"; do mkdir -p "$BKP/a/$(dirname "$f")"; cp "$f" "$BKP/a/$f"; done

reverter() {
  echo ">>> REVERTENDO tudo (nada do que foi tentado fica no projeto)"
  for f in "${ALT[@]}"; do cp "$BKP/a/$f" "$f"; done
  echo ">>> REVERTIDO. Me mande o log: /tmp/matriz-auditoria-instalar.log"
}

echo "=== 0) Conferência prévia (só leitura) ==="
for f in "${ALT[@]}"; do [ -f "$f" ] || { echo "ERRO: arquivo esperado não existe: $f"; exit 1; }; done

echo; echo "=== 1) Alterando os arquivos ==="
python3 - <<'PYSCRIPT'
import sys

def abrir(c):
    return open(c, encoding="utf-8").read()

def trocar(texto, antigo, novo, onde):
    if texto.count(antigo) != 1:
        print("ERRO: trecho não encontrado exatamente uma vez em", onde, "->", antigo[:70].replace("\n", "\\n")); sys.exit(1)
    return texto.replace(antigo, novo)

# ---------- Formulário de grupo: o módulo Backup é exclusivo do Administrador e não aparece nos demais grupos ----------
fg = "src/modules/administracao/components/FormularioGrupo.tsx"
s = abrir(fg)
s = trocar(s, "  const protegido = grupo?.sistema ?? false;\n",
  "  const protegido = grupo?.sistema ?? false;\n\n"
  "  // O módulo Backup só pertence ao grupo protegido (Administrador; o banco também trava). Nos outros grupos\n"
  "  // essas permissões nem aparecem na grade.\n"
  "  const ehBackup = (codigo: string) => codigo.startsWith(\"backup.\");\n"
  "  const catalogoVisivel = protegido ? catalogo : catalogo.filter((permissao) => !ehBackup(permissao.codigo));\n", fg)
s = trocar(s, "      const permissoes = [...selecionadas];\n",
  "      const permissoes = [...selecionadas].filter((codigo) => protegido || !ehBackup(codigo));\n", fg)
s = trocar(s, "            {protegido ? catalogo.length : selecionadas.size} de {catalogo.length} selecionadas\n",
  "            {protegido ? catalogoVisivel.length : [...selecionadas].filter((codigo) => !ehBackup(codigo)).length} de{\" \"}\n"
  "            {catalogoVisivel.length} selecionadas\n", fg)
s = trocar(s, "          catalogo={catalogo}\n          selecionadas={\n            protegido ? new Set(catalogo.map((permissao) => permissao.codigo)) : selecionadas\n          }\n",
  "          catalogo={catalogoVisivel}\n          selecionadas={\n            protegido ? new Set(catalogoVisivel.map((permissao) => permissao.codigo)) : selecionadas\n          }\n", fg)
s = trocar(s, "          desabilitado={salvando || protegido}\n        />\n",
  "          desabilitado={salvando || protegido}\n        />\n"
  "        {!protegido && (\n"
  "          <p className=\"text-xs text-slate-500\">O módulo Backup é exclusivo do Administrador e não aparece aqui.</p>\n"
  "        )}\n", fg)
open(fg, "w", encoding="utf-8").write(s)

# ---------- Auditoria: nomes legíveis para as ações e campos novos ----------
au = "src/modules/auditoria/regras.ts"
t = abrir(au)
t = trocar(t, '  backup_configuracao_alterada: "Alterou a configuração do backup",\n};',
  '  backup_configuracao_alterada: "Alterou a configuração do backup",\n'
  '  backup_restauracao_falhou: "A restauração de backup falhou (nada foi alterado)",\n'
  '  presenca_fora_da_janela: "Registrou entrada fora do horário da portaria (controle total)",\n};', au)
t = trocar(t, '  qr_secret: "QR Code",\n};',
  '  qr_secret: "QR Code",\n'
  '  inicio_do_evento: "Início do evento",\n'
  '  registrado_em: "Registrado em",\n'
  '  situacao: "Situação",\n'
  '  backup_id: "Backup",\n'
  '  seguranca_id: "Backup de segurança",\n'
  '  modo: "Modo",\n'
  '  grupos: "Grupos de dados",\n'
  '  operacoes: "Operações",\n};', au)
open(au, "w", encoding="utf-8").write(t)
print("Arquivos alterados: 2.")
PYSCRIPT
[ $? -eq 0 ] || { reverter; exit 1; }

echo; echo "=== 2) Parando o servidor de teste e limpando o cache ==="
pkill -f "next dev" 2>/dev/null; pkill -f next-server 2>/dev/null; pkill -f "next/dist" 2>/dev/null; sleep 2
for i in 1 2 3 4 5; do rm -rf .next 2>/dev/null; [ -d .next ] || break; sleep 1; done

echo; echo "=== 3) Conferência de tipos ==="
npx tsc --noEmit || { reverter; exit 1; }
echo; echo "=== 4) Testes automáticos ==="
npx vitest run src/modules/auditoria src/modules/administracao || { reverter; exit 1; }
echo; echo "=== 5) Lint ==="
npx eslint "${ALT[@]}" || { reverter; exit 1; }
echo; echo "=== 6) Build de produção (pode demorar alguns minutos) ==="
npm run build || { reverter; exit 1; }

echo; echo "=== TUDO CERTO: arquivos alterados e conferidos ==="
git status --short
) 2>&1 | tee /tmp/matriz-auditoria-instalar.log
