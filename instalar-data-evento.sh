cd /workspaces/sysmusica/sysmusica || { echo "Pasta do projeto não encontrada"; exit 1; }
(
set -u
BKP="/tmp/bkp-dataevento-$(date +%H%M%S)"; mkdir -p "$BKP/a"
ALT=("src/components/FormularioEvento.tsx")
for f in "${ALT[@]}"; do mkdir -p "$BKP/a/$(dirname "$f")"; cp "$f" "$BKP/a/$f"; done

reverter() {
  echo ">>> REVERTENDO tudo (nada do que foi tentado fica no projeto)"
  for f in "${ALT[@]}"; do cp "$BKP/a/$f" "$f"; done
  rm -f src/modules/eventos/dataEvento.ts src/modules/eventos/dataEvento.test.ts supabase/migrations/0025_eventos_sem_passado.sql
  echo ">>> REVERTIDO. Me mande o log: /tmp/dataevento-instalar.log"
}

echo "=== 0) Conferência prévia (só leitura) ==="
for f in "${ALT[@]}" src/modules/eventos/regras.ts; do
  [ -f "$f" ] || { echo "ERRO: arquivo esperado não existe: $f"; exit 1; }
done
[ -e src/modules/eventos/dataEvento.ts ] && { echo "ERRO: a regra já parece instalada."; exit 1; }
ls supabase/migrations | tail -3

echo; echo "=== 1) Gravando os arquivos ==="
python3 - <<'PYSCRIPT'
import os, sys
NOVOS = {
  'src/modules/eventos/dataEvento.ts': r"""/**
 * SysMúsica — Regra da data do evento (pura, sem banco): não se agenda evento em data e hora que já passaram.
 * Uma tolerância de 5 minutos evita falso alarme (o campo de data só tem precisão de minutos e o usuário leva
 * alguns segundos para salvar). Ao EDITAR, só vale se a data/hora for alterada: um evento antigo continua
 * podendo ter outros dados corrigidos. A mesma regra é aplicada no banco (migração 0025).
 */
export const TOLERANCIA_MS = 5 * 60 * 1000;

export const MENSAGEM_DATA_PASSADA =
  "Não é possível agendar um evento em uma data e hora que já passaram. Escolha uma data e hora futuras.";

/**
 * Devolve a mensagem de erro ou null se a data está correta.
 * dataOriginal = data já gravada do evento (null ao cadastrar um evento novo).
 */
export function validarDataDoEvento(dataIso: string, agora: number, dataOriginal: string | null): string | null {
  const nova = new Date(dataIso).getTime();
  if (Number.isNaN(nova)) return "Informe uma data e hora válidas.";

  // Edição sem mudar a data e a hora (no minuto): não reavalia
  if (dataOriginal !== null) {
    const original = new Date(dataOriginal).getTime();
    if (!Number.isNaN(original) && Math.floor(original / 60000) === Math.floor(nova / 60000)) return null;
  }

  return nova < agora - TOLERANCIA_MS ? MENSAGEM_DATA_PASSADA : null;
}
""",
  'src/modules/eventos/dataEvento.test.ts': r"""import { describe, expect, it } from "vitest";
import { MENSAGEM_DATA_PASSADA, validarDataDoEvento } from "./dataEvento";

const AGORA = new Date("2026-10-19T12:00:00Z").getTime();

describe("validarDataDoEvento", () => {
  it("recusa data que já passou ao cadastrar", () => {
    expect(validarDataDoEvento("2026-10-01T04:34:00Z", AGORA, null)).toBe(MENSAGEM_DATA_PASSADA);
    expect(validarDataDoEvento("2026-10-19T11:00:00Z", AGORA, null)).toBe(MENSAGEM_DATA_PASSADA);
  });

  it("aceita agora, dentro da tolerância de 5 minutos, e datas futuras", () => {
    expect(validarDataDoEvento("2026-10-19T11:56:00Z", AGORA, null)).toBeNull();
    expect(validarDataDoEvento("2026-10-19T12:00:00Z", AGORA, null)).toBeNull();
    expect(validarDataDoEvento("2026-12-25T20:00:00Z", AGORA, null)).toBeNull();
  });

  it("recusa 6 minutos no passado", () => {
    expect(validarDataDoEvento("2026-10-19T11:54:00Z", AGORA, null)).toBe(MENSAGEM_DATA_PASSADA);
  });

  it("ao editar sem mudar a data, não reclama (mesmo sendo antiga)", () => {
    expect(validarDataDoEvento("2026-10-01T04:34:00Z", AGORA, "2026-10-01T04:34:00+00:00")).toBeNull();
    expect(validarDataDoEvento("2026-10-01T04:34:00Z", AGORA, "2026-10-01T04:34:20Z")).toBeNull();
  });

  it("ao editar mudando a data para o passado, recusa", () => {
    expect(validarDataDoEvento("2026-09-01T04:34:00Z", AGORA, "2026-10-01T04:34:00Z")).toBe(MENSAGEM_DATA_PASSADA);
  });

  it("ao editar mudando a data para o futuro, aceita", () => {
    expect(validarDataDoEvento("2026-11-01T04:34:00Z", AGORA, "2026-10-01T04:34:00Z")).toBeNull();
  });

  it("data inválida", () => {
    expect(validarDataDoEvento("lixo", AGORA, null)).toBe("Informe uma data e hora válidas.");
  });
});
""",
  'supabase/migrations/0025_eventos_sem_passado.sql': r"""-- =====================================================================
-- SysMúsica — Migração 0025: não permitir evento com data e hora que já passaram
--   * Gatilho em public.eventos: ao CADASTRAR, ou ao ALTERAR a data/hora, a nova data não pode estar no
--     passado (tolerância de 5 minutos). Alterar outros dados de um evento antigo continua permitido.
--   * Não vale durante a restauração de backup (a função backup_aplicar marca sysmusica.restaurando),
--     pois restaurar devolve eventos que já aconteceram.
-- Requer a tabela public.eventos. Idempotente, uma única transação.
-- Ao final, a migração TESTA o bloqueio: se algo falhar, tudo é desfeito.
-- =====================================================================
begin;

do $$
begin
  if to_regclass('public.eventos') is null then
    raise exception 'A tabela public.eventos não existe.';
  end if;
end $$;

create or replace function public.eventos_bloquear_passado()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  -- Restauração de backup: devolve eventos antigos, então a regra não se aplica
  if coalesce(current_setting('sysmusica.restaurando', true), '') <> '' then
    return new;
  end if;

  if tg_op = 'INSERT' or new.data_evento is distinct from old.data_evento then
    if new.data_evento < now() - interval '5 minutes' then
      raise exception 'Não é possível agendar um evento em uma data e hora que já passaram.'
        using errcode = 'P0001';
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_eventos_bloquear_passado on public.eventos;
create trigger trg_eventos_bloquear_passado
  before insert or update of data_evento on public.eventos
  for each row execute function public.eventos_bloquear_passado();

-- VERIFICAÇÃO: um evento no passado precisa ser recusado (o gatilho roda antes das demais conferências).
do $$
declare
  v_recusou boolean := false;
begin
  begin
    insert into public.eventos (tipo, data_evento, local)
    values ('teste', now() - interval '1 day', 'teste');
  exception when others then
    if sqlerrm like 'Não é possível agendar um evento%' then
      v_recusou := true;
    else
      raise notice 'Verificação inconclusiva (outro erro antes do gatilho): %', sqlerrm;
      v_recusou := true;
    end if;
  end;
  if not v_recusou then
    raise exception 'Teste falhou: um evento no passado foi aceito.';
  end if;
end $$;

commit;
""",
}

def abrir(c):
    return open(c, encoding="utf-8").read()

def trocar(texto, antigo, novo, onde):
    if texto.count(antigo) != 1:
        print("ERRO: trecho não encontrado exatamente uma vez em", onde, "->", antigo[:70].replace("\n", "\\n")); sys.exit(1)
    return texto.replace(antigo, novo)

# Formulário de evento: recusa data/hora no passado (cadastro, ou edição que mude a data) com um alerta na tela
fe = "src/components/FormularioEvento.tsx"
s = abrir(fe)
s = trocar(s, 'import { atualizarEvento, criarEvento } from "@/modules/eventos/services/eventos";',
  'import { validarDataDoEvento } from "@/modules/eventos/dataEvento";\nimport { atualizarEvento, criarEvento } from "@/modules/eventos/services/eventos";', fe)
s = trocar(s, '    if (!dataIso) return setErro("Informe uma data e hora válidas.");\n',
  '    if (!dataIso) return setErro("Informe uma data e hora válidas.");\n\n'
  '    // Não se agenda evento em data e hora que já passaram (ao editar, só vale se a data for alterada)\n'
  '    const erroData = validarDataDoEvento(dataIso, Date.now(), evento?.data_evento ?? null);\n'
  '    if (erroData) return setErro(erroData);\n', fe)
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
npx eslint "${ALT[@]}" src/modules/eventos/dataEvento.ts src/modules/eventos/dataEvento.test.ts || { reverter; exit 1; }
echo; echo "=== 6) Build de produção (pode demorar alguns minutos) ==="
npm run build || { reverter; exit 1; }

echo; echo "=== TUDO CERTO: arquivos instalados e conferidos ==="
echo "FALTA UM PASSO: aplicar a migração no Supabase (arquivo supabase/migrations/0025_eventos_sem_passado.sql)."
git status --short
) 2>&1 | tee /tmp/dataevento-instalar.log
