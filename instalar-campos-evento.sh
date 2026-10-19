cd /workspaces/sysmusica/sysmusica || { echo "Pasta do projeto não encontrada"; exit 1; }
(
set -u
BKP="/tmp/bkp-camposevento-$(date +%H%M%S)"; mkdir -p "$BKP/a"
ALT=("src/components/FormularioEvento.tsx")
for f in "${ALT[@]}"; do mkdir -p "$BKP/a/$(dirname "$f")"; cp "$f" "$BKP/a/$f"; done

reverter() {
  echo ">>> REVERTENDO tudo (nada do que foi tentado fica no projeto)"
  for f in "${ALT[@]}"; do cp "$BKP/a/$f" "$f"; done
  rm -f src/modules/eventos/camposEvento.ts src/modules/eventos/camposEvento.test.ts
  echo ">>> REVERTIDO. Me mande o log: /tmp/camposevento-instalar.log"
}

echo "=== 0) Conferência prévia (só leitura) ==="
for f in "${ALT[@]}" src/modules/eventos/dataEvento.ts; do
  [ -f "$f" ] || { echo "ERRO: arquivo esperado não existe: $f (a regra da data foi instalada?)"; exit 1; }
done
[ -e src/modules/eventos/camposEvento.ts ] && { echo "ERRO: esta regra já parece instalada."; exit 1; }

echo; echo "=== 1) Gravando os arquivos ==="
python3 - <<'PYSCRIPT'
import os, sys
NOVOS = {
  'src/modules/eventos/camposEvento.ts': r"""/**
 * SysMúsica — Campos obrigatórios do evento (regra pura, sem banco).
 * Todos os campos do formulário de evento são obrigatórios. Devolve os NOMES (como aparecem na tela) dos
 * campos que estão vazios, na ordem do formulário, para a tela marcar cada um e mostrar o alerta.
 */
export interface CamposEvento {
  tipo: string;
  finalidade: string;
  dataEvento: string; // valor do campo data e hora (vazio = não preenchido)
  local: string;
  cidade: string;
  comumId: string;
}

export const ROTULO_TIPO = "Tipo";
export const ROTULO_FINALIDADE = "Finalidade do evento";
export const ROTULO_DATA = "Data e hora";
export const ROTULO_LOCAL = "Local";
export const ROTULO_CIDADE = "Cidade";
export const ROTULO_COMUM = "Comum";

export function camposFaltando(campos: CamposEvento): string[] {
  const faltando: string[] = [];
  if (!campos.tipo.trim()) faltando.push(ROTULO_TIPO);
  if (!campos.finalidade.trim()) faltando.push(ROTULO_FINALIDADE);
  if (!campos.dataEvento.trim()) faltando.push(ROTULO_DATA);
  if (!campos.local.trim()) faltando.push(ROTULO_LOCAL);
  if (!campos.cidade.trim()) faltando.push(ROTULO_CIDADE);
  if (!campos.comumId.trim()) faltando.push(ROTULO_COMUM);
  return faltando;
}

/** Mensagem do alerta: "Preencha todos os campos obrigatórios: Local, Cidade." */
export function mensagemCamposFaltando(faltando: string[]): string {
  return `Preencha todos os campos obrigatórios: ${faltando.join(", ")}.`;
}
""",
  'src/modules/eventos/camposEvento.test.ts': r"""import { describe, expect, it } from "vitest";
import { camposFaltando, mensagemCamposFaltando, type CamposEvento } from "./camposEvento";

const completo: CamposEvento = {
  tipo: "Ensaio",
  finalidade: "Ensaio Regional",
  dataEvento: "2026-10-25T10:00",
  local: "Casa de Oração de Cidade Nova",
  cidade: "Jequié",
  comumId: "abc",
};

describe("camposFaltando", () => {
  it("nada falta quando tudo está preenchido", () => {
    expect(camposFaltando(completo)).toEqual([]);
  });

  it("aponta o Local vazio (caso do print) e a ordem do formulário", () => {
    expect(camposFaltando({ ...completo, local: "" })).toEqual(["Local"]);
    expect(camposFaltando({ tipo: "", finalidade: "", dataEvento: "", local: "", cidade: "", comumId: "" })).toEqual([
      "Tipo",
      "Finalidade do evento",
      "Data e hora",
      "Local",
      "Cidade",
      "Comum",
    ]);
  });

  it("espaços em branco contam como vazio", () => {
    expect(camposFaltando({ ...completo, cidade: "   ", local: " " })).toEqual(["Local", "Cidade"]);
  });

  it("a comum escolhida é obrigatória ('Nenhuma' = vazio)", () => {
    expect(camposFaltando({ ...completo, comumId: "" })).toEqual(["Comum"]);
  });
});

describe("mensagemCamposFaltando", () => {
  it("monta o texto do alerta", () => {
    expect(mensagemCamposFaltando(["Local", "Cidade"])).toBe("Preencha todos os campos obrigatórios: Local, Cidade.");
  });
});
""",
}

def abrir(c):
    return open(c, encoding="utf-8").read()

def trocar(texto, antigo, novo, onde):
    if texto.count(antigo) != 1:
        print("ERRO: trecho não encontrado exatamente uma vez em", onde, "->", antigo[:70].replace("\n", "\\n")); sys.exit(1)
    return texto.replace(antigo, novo)

fe = "src/components/FormularioEvento.tsx"
s = abrir(fe)

# importa as regras dos campos obrigatórios
s = trocar(s, 'import { validarDataDoEvento } from "@/modules/eventos/dataEvento";',
  'import { validarDataDoEvento } from "@/modules/eventos/dataEvento";\n'
  'import {\n  camposFaltando,\n  mensagemCamposFaltando,\n  ROTULO_CIDADE,\n  ROTULO_COMUM,\n  ROTULO_DATA,\n  ROTULO_FINALIDADE,\n  ROTULO_LOCAL,\n  ROTULO_TIPO,\n} from "@/modules/eventos/camposEvento";', fe)

# estado dos campos que ficaram vazios (ficam com borda vermelha)
s = trocar(s, "  const [erro, setErro] = useState<string | null>(null);\n",
  "  const [erro, setErro] = useState<string | null>(null);\n"
  "  const [faltando, setFaltando] = useState<string[]>([]); // campos obrigatórios vazios (borda vermelha)\n\n"
  "  // Borda vermelha no campo obrigatório que ficou vazio\n"
  "  const classeCampo = (rotulo: string) =>\n"
  "    classeInput + (faltando.includes(rotulo) ? \" !border-red-500 !ring-2 !ring-red-200\" : \"\");\n", fe)

# validação: TODOS os campos são obrigatórios, com alerta que lista os que faltam
s = trocar(s, '    if (!tipo.trim() || !local.trim()) return setErro("Preencha o tipo e o local do evento.");\n',
  "    // Todos os campos são obrigatórios: o alerta lista os que faltam e eles ficam com borda vermelha\n"
  "    const vazios = camposFaltando({ tipo, finalidade: finalidadeTexto, dataEvento, local, cidade, comumId });\n"
  "    setFaltando(vazios);\n"
  "    if (vazios.length > 0) return setErro(mensagemCamposFaltando(vazios));\n", fe)

# formulário sem a validação do navegador (para mostrar o nosso alerta) + aviso no topo
s = trocar(s, '    <form onSubmit={salvar} className="space-y-5">\n',
  '    <form onSubmit={salvar} noValidate className="space-y-5">\n'
  '      <p className="text-xs text-slate-500">Todos os campos são obrigatórios (marcados com *).</p>\n\n', fe)

# asteriscos vermelhos nos rótulos
ast = '<span className="text-red-600"> *</span>'
s = trocar(s, "          Tipo\n        </label>", "          Tipo " + ast + "\n        </label>", fe)
s = trocar(s, "          Finalidade do evento\n        </label>", "          Finalidade do evento " + ast + "\n        </label>", fe)
s = trocar(s, "          Data e hora\n        </label>", "          Data e hora " + ast + "\n        </label>", fe)
s = trocar(s, "          Local\n        </label>", "          Local " + ast + "\n        </label>", fe)
s = trocar(s, 'Cidade <span className="font-normal text-slate-400">(informativo)</span>', 'Cidade ' + ast, fe)
s = trocar(s, 'Comum <span className="font-normal text-slate-400">(define o setor da portaria)</span>',
  'Comum ' + ast + ' <span className="font-normal text-slate-400">(define o setor da portaria)</span>', fe)

# borda vermelha em cada campo
s = trocar(s, 'placeholder="Ex: Ensaio, Culto"\n          className={classeInput}', 'placeholder="Ex: Ensaio, Culto"\n          className={classeCampo(ROTULO_TIPO)}', fe)
s = trocar(s, 'placeholder="Digite ou escolha uma finalidade"\n          className={classeInput}', 'placeholder="Digite ou escolha uma finalidade"\n          className={classeCampo(ROTULO_FINALIDADE)}', fe)
s = trocar(s, 'onChange={(e) => setDataEvento(e.target.value)}\n          disabled={salvando}\n          className={classeInput}', 'onChange={(e) => setDataEvento(e.target.value)}\n          disabled={salvando}\n          className={classeCampo(ROTULO_DATA)}', fe)
s = trocar(s, 'placeholder="Ex: Congregação Central"\n          className={classeInput}', 'placeholder="Ex: Congregação Central"\n          className={classeCampo(ROTULO_LOCAL)}', fe)
s = trocar(s, 'placeholder="Ex: Lauro de Freitas"\n          className={classeInput}', 'placeholder="Ex: Lauro de Freitas"\n          className={classeCampo(ROTULO_CIDADE)}', fe)
s = trocar(s, 'onChange={setComumId}\n          disabled={salvando}\n          className={classeInput}', 'onChange={setComumId}\n          disabled={salvando}\n          className={classeCampo(ROTULO_COMUM)}', fe)
open(fe, "w", encoding="utf-8").write(s)

for caminho in NOVOS:
    if os.path.exists(caminho):
        print("ERRO: já existe", caminho); sys.exit(1)
for caminho, conteudo in NOVOS.items():
    os.makedirs(os.path.dirname(caminho) or ".", exist_ok=True)
    open(caminho, "w", encoding="utf-8").write(conteudo)
print("Arquivos gravados:", len(NOVOS), "novos, 1 alterado.")
PYSCRIPT
[ $? -eq 0 ] || { reverter; exit 1; }

echo; echo "=== 2) Parando o servidor de teste e limpando o cache ==="
pkill -f "next dev" 2>/dev/null; pkill -f next-server 2>/dev/null; pkill -f "next/dist" 2>/dev/null; sleep 2
for i in 1 2 3 4 5; do rm -rf .next 2>/dev/null; [ -d .next ] || break; sleep 1; done

echo; echo "=== 3) Conferência de tipos ==="
npx tsc --noEmit || { reverter; exit 1; }
echo; echo "=== 4) Testes automáticos ==="
npx vitest run src/modules/eventos || { reverter; exit 1; }
echo; echo "=== 5) Lint ==="
npx eslint "${ALT[@]}" src/modules/eventos/camposEvento.ts src/modules/eventos/camposEvento.test.ts || { reverter; exit 1; }
echo; echo "=== 6) Build de produção (pode demorar alguns minutos) ==="
npm run build || { reverter; exit 1; }

echo; echo "=== TUDO CERTO: arquivos instalados e conferidos ==="
git status --short
) 2>&1 | tee /tmp/camposevento-instalar.log
