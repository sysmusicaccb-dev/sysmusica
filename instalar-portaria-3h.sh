cd /workspaces/sysmusica/sysmusica || { echo "Pasta do projeto não encontrada"; exit 1; }
(
set -u
BKP="/tmp/bkp-portaria-3h-$(date +%H%M%S)"; mkdir -p "$BKP/a"
ALT=("src/modules/portarias/janela.ts" "src/modules/portarias/janela.test.ts")
NOV=("supabase/migrations/0027_portaria_3h.sql")
for f in "${ALT[@]}"; do mkdir -p "$BKP/a/$(dirname "$f")"; cp "$f" "$BKP/a/$f"; done

reverter() {
  echo ">>> REVERTENDO tudo (nada do que foi tentado fica no projeto)"
  for f in "${ALT[@]}"; do cp "$BKP/a/$f" "$f"; done
  for f in "${NOV[@]}"; do rm -f "$f"; done
  echo ">>> REVERTIDO. Me mande o log: /tmp/portaria-3h-instalar.log"
}

echo "=== 0) Conferência prévia (só leitura) ==="
for f in "${ALT[@]}"; do [ -f "$f" ] || { echo "ERRO: arquivo esperado não existe: $f"; exit 1; }; done
[ -e supabase/migrations/0027_portaria_3h.sql ] && { echo "ERRO: esta mudança já parece instalada."; exit 1; }

echo; echo "=== 1) Gravando os arquivos ==="
python3 - <<'PYSCRIPT'
import os, sys
NOVOS = {
  'supabase/migrations/0027_portaria_3h.sql': r"""-- =====================================================================
-- SysMúsica — Migração 0027: portaria encerra 3 HORAS DEPOIS do início do evento
--   Antes: de 2h antes a 2h depois. Agora: de 2 HORAS ANTES até 3 HORAS DEPOIS (horário de Salvador).
--   Ex.: ensaio às 14h -> portaria aberta das 12h às 17h.
--   A regra fica em um só lugar (portaria_janela_aberta); a validação do registro e a mensagem de erro seguem ela.
-- Requer a migração 0024. Idempotente, uma única transação. Ao final testa os limites (se falhar, desfaz tudo).
-- =====================================================================
begin;

do $$
begin
  if to_regprocedure('public.portaria_janela_aberta(timestamptz,timestamptz)') is null then
    raise exception 'Aplique primeiro a migração 0024.';
  end if;
end $$;

-- 1) A regra da janela em um só lugar (limites inclusivos): de 2h antes a 3h depois do início
create or replace function public.portaria_janela_aberta(p_data timestamptz, p_agora timestamptz default now())
returns boolean
language sql
immutable
set search_path = public
as $$
  select p_data is not null
     and p_agora >= p_data - interval '2 hours'
     and p_agora <= p_data + interval '3 hours'
$$;

-- 2) A validação do registro (a de 0012) ganha a conferência da janela, logo após a abrangência
create or replace function public.validar_registro_presenca(
  p_portaria_id uuid, p_evento_id uuid, p_membro_id uuid
)
returns void language plpgsql security definer set search_path = public as $$
declare
  v_p         public.portarias;
  v_m         record;
  v_existente record;
  v_data      timestamptz;
begin
  perform public.exigir_permissao('portaria.registrar');

  select * into v_p from public.portarias p where p.id = p_portaria_id and p.excluido_em is null;
  if not found then
    raise exception 'Portaria não encontrada.';
  end if;
  if v_p.status <> 'APROVADA' then
    raise exception 'Esta portaria não está aprovada (situação: %). Só portarias aprovadas registram presenças.',
      case v_p.status when 'PENDENTE_APROVACAO' then 'pendente de aprovação'
                      when 'REJEITADA' then 'rejeitada' else v_p.status end;
  end if;
  if v_p.evento_id <> p_evento_id then
    raise exception 'A portaria não corresponde ao evento informado.';
  end if;
  if not public.comum_na_abrangencia(v_p.comum_id) then
    raise exception 'Você não tem acesso a esta portaria (fora da sua abrangência).' using errcode = '42501';
  end if;

  -- JANELA: de 2 horas antes a 3 horas depois do início do evento (horário de Salvador)
  select e.data_evento into v_data from public.eventos e where e.id = v_p.evento_id;
  if v_data is null then
    raise exception 'O evento desta portaria não foi encontrado.';
  end if;
  if not public.portaria_janela_aberta(v_data) then
    if public.tem_permissao('portarias.controle_total') then
      -- Administrador: permitido, mas fica registrado na Auditoria
      perform public.registrar_auditoria('presenca_fora_da_janela', 'portaria', p_portaria_id,
        jsonb_build_object(
          'evento_id', p_evento_id,
          'membro_id', p_membro_id,
          'inicio_do_evento', v_data,
          'registrado_em', now(),
          'situacao', case when now() < v_data then 'antes da abertura' else 'depois do encerramento' end));
    else
      raise exception 'Fora do horário da portaria. Ela abre em % e encerra em % (2 horas antes e 3 horas depois do início do evento, horário de Salvador).',
        to_char((v_data - interval '2 hours') at time zone 'America/Sao_Paulo', 'DD/MM "às" HH24"h"MI'),
        to_char((v_data + interval '3 hours') at time zone 'America/Sao_Paulo', 'DD/MM "às" HH24"h"MI');
    end if;
  end if;

  select m.status, m.excluido_em into v_m from public.membros m where m.id = p_membro_id;
  if not found then
    raise exception 'Cadastro do membro não encontrado.';
  end if;
  if v_m.excluido_em is not null then
    raise exception 'Cadastro do membro não encontrado.';
  end if;
  if v_m.status <> 'Ativo' then
    raise exception 'O cadastro do membro está inativo.';
  end if;

  -- Duplicidade por EVENTO (inclui registros antigos, sem portaria)
  select pr.hora_entrada, pr.status, pr.portaria_id into v_existente
  from public.presencas pr
  where pr.membro_id = p_membro_id
    and pr.evento_id = p_evento_id
    and pr.excluido_em is null
    and (pr.hora_saida is null or pr.portaria_id = p_portaria_id)
  order by pr.hora_entrada
  limit 1;
  if found then
    raise exception 'Este músico já possui uma entrada registrada neste evento às % (situação: %)%.',
      to_char(v_existente.hora_entrada at time zone 'America/Sao_Paulo', 'HH24"h"MI'),
      v_existente.status,
      case when v_existente.portaria_id is null then ', registro antigo feito antes das portarias' else '' end;
  end if;
end;
$$;

-- 3) VERIFICAÇÃO: os limites da janela (evento às 14h de Salvador = 17h UTC). Se falhar, tudo é desfeito.
do $$
declare
  v_ev constant timestamptz := '2026-10-19T17:00:00Z';
begin
  if public.portaria_janela_aberta(v_ev, '2026-10-19T14:59:59Z') then
    raise exception 'Teste falhou: abriu antes das 12h.';
  end if;
  if not public.portaria_janela_aberta(v_ev, '2026-10-19T15:00:00Z') then
    raise exception 'Teste falhou: não abriu às 12h.';
  end if;
  if not public.portaria_janela_aberta(v_ev, '2026-10-19T20:00:00Z') then
    raise exception 'Teste falhou: fechou antes das 17h.';
  end if;
  if public.portaria_janela_aberta(v_ev, '2026-10-19T20:00:01Z') then
    raise exception 'Teste falhou: não encerrou depois das 17h.';
  end if;
  if public.portaria_janela_aberta(null, now()) then
    raise exception 'Teste falhou: evento sem data não pode estar aberto.';
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

# ---------- Regra da tela: a portaria encerra 3 horas depois do início ----------
j = "src/modules/portarias/janela.ts"
s = abrir(j)
s = trocar(s, "export const HORAS_DEPOIS = 2;", "export const HORAS_DEPOIS = 3; // encerra 3 horas depois do início (igual ao banco, migração 0027)", j)
s = trocar(s, "encerra 2 horas DEPOIS do início", "encerra 3 horas DEPOIS do início", j)
s = trocar(s, "Ex.: ensaio às 14h -> aberta das 12h às 16h.", "Ex.: ensaio às 14h -> aberta das 12h às 17h.", j)

t = "src/modules/portarias/janela.test.ts"
u = abrir(t)
u = trocar(u, 'it("abre 2h antes e encerra 2h depois do início (limites inclusivos)"', 'it("abre 2h antes e encerra 3h depois do início (limites inclusivos)"', t)
u = trocar(u, 't("2026-10-19T19:00:00Z"))?.situacao).toBe("aberta");', 't("2026-10-19T20:00:00Z"))?.situacao).toBe("aberta");', t)
u = trocar(u, 't("2026-10-19T19:00:01Z"))?.situacao).toBe("encerrada");', 't("2026-10-19T20:00:01Z"))?.situacao).toBe("encerrada");', t)
u = trocar(u, "(12h às 16h para um evento das 14h)", "(12h às 17h para um evento das 14h)", t)
u = trocar(u, 'toBe("Aberta até 16h00");', 'toBe("Aberta até 17h00");', t)
u = trocar(u, 'const depois = t("2026-10-19T20:00:00Z");', 'const depois = t("2026-10-19T21:00:00Z");', t)
u = trocar(u, 'toBe("Encerrada às 16h00");', 'toBe("Encerrada às 17h00");', t)

for caminho in NOVOS:
    if os.path.exists(caminho):
        print("ERRO: já existe", caminho); sys.exit(1)
open(j, "w", encoding="utf-8").write(s)
open(t, "w", encoding="utf-8").write(u)
for caminho, conteudo in NOVOS.items():
    os.makedirs(os.path.dirname(caminho) or ".", exist_ok=True)
    open(caminho, "w", encoding="utf-8").write(conteudo)
print("Arquivos gravados:", len(NOVOS), "novo,", 2, "alterados.")
PYSCRIPT
[ $? -eq 0 ] || { reverter; exit 1; }

echo; echo "=== 2) Procurando outros textos com '2 horas' no código (só leitura) ==="
grep -rniE "2 ?horas|2h (depois|antes)|duas horas" src --include=*.ts --include=*.tsx | grep -v "janela.test.ts" || echo "(nenhum outro texto encontrado)"

echo; echo "=== 3) Conferência de tipos ==="
npx tsc --noEmit || { reverter; exit 1; }
echo; echo "=== 4) Testes automáticos ==="
npx vitest run src/modules/portarias || { reverter; exit 1; }
echo; echo "=== 5) Lint ==="
npx eslint "${ALT[@]}" || { reverter; exit 1; }
echo; echo "=== 6) Build de produção (pode demorar alguns minutos) ==="
pkill -f "next dev" 2>/dev/null; sleep 2; rm -rf .next 2>/dev/null
npm run build || { reverter; exit 1; }

echo; echo "=== TUDO CERTO: arquivos gravados e conferidos ==="
git status --short | grep -v "instalar-"
echo
echo "PRÓXIMO PASSO: rodar a migração 0027 no Supabase ANTES de publicar (git push)."
) 2>&1 | tee /tmp/portaria-3h-instalar.log
