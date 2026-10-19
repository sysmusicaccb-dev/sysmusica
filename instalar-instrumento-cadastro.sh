cd /workspaces/sysmusica/sysmusica || { echo "Pasta do projeto não encontrada"; exit 1; }
(
set -u
BKP="/tmp/bkp-instrumento-cadastro-$(date +%H%M%S)"; mkdir -p "$BKP/a"
ALT=("src/modules/atendimento/components/CartaoConferencia.tsx")
NOV=("supabase/migrations/0029_instrumento_do_cadastro.sql")
for f in "${ALT[@]}"; do mkdir -p "$BKP/a/$(dirname "$f")"; cp "$f" "$BKP/a/$f"; done

reverter() {
  echo ">>> REVERTENDO tudo (nada do que foi tentado fica no projeto)"
  for f in "${ALT[@]}"; do cp "$BKP/a/$f" "$f"; done
  for f in "${NOV[@]}"; do rm -f "$f"; done
  echo ">>> REVERTIDO. Me mande o log: /tmp/instrumento-cadastro-instalar.log"
}

echo "=== 0) Conferência prévia (só leitura) ==="
for f in "${ALT[@]}" supabase/migrations/0028_portaria_toca_avulsa.sql; do
  [ -f "$f" ] || { echo "ERRO: arquivo esperado não existe: $f (a etapa A2 foi instalada?)"; exit 1; }
done
[ -e supabase/migrations/0029_instrumento_do_cadastro.sql ] && { echo "ERRO: esta correção já parece instalada."; exit 1; }

echo; echo "=== 1) Gravando os arquivos ==="
python3 - <<'PYSCRIPT'
import os, sys
NOVOS = {
  'supabase/migrations/0029_instrumento_do_cadastro.sql': r"""-- =====================================================================
-- SysMúsica — Migração 0029: o músico toca SÓ o instrumento do cadastro
--   Na CCB o músico toca o instrumento em que foi certificado e liberado pelo ministério; só muda se o
--   ministério autorizar (e então o cadastro é corrigido). Por isso a Portaria não troca o instrumento:
--   registrar_entrada usa o do cadastro e só aceita o instrumento informado quando o membro NÃO tem um cadastrado.
-- Requer a migração 0028. Idempotente, uma única transação.
-- =====================================================================
begin;

do $$
begin
  if to_regprocedure('public.registrar_entrada(uuid,uuid,text,boolean,uuid)') is null then
    raise exception 'Aplique primeiro a migração 0028.';
  end if;
end $$;

create or replace function public.registrar_entrada(
  p_portaria_id uuid, p_membro_id uuid, p_origem text default 'MANUAL',
  p_toca boolean default null, p_instrumento_id uuid default null
)
returns public.presencas
language plpgsql security definer set search_path = public as $$
declare
  v_evento   uuid;
  v_presenca public.presencas;
  v_m        record;
  v_ef_inst  uuid;
  v_ef_nome  text;
  v_linha    public.linhas_painel;
  v_toca     boolean;
  v_gravar   uuid;
begin
  if p_origem not in ('MANUAL', 'QR') then
    raise exception 'Origem de registro inválida.';
  end if;
  select p.evento_id into v_evento from public.portarias p where p.id = p_portaria_id and p.excluido_em is null;
  if not found then
    raise exception 'Portaria não encontrada.';
  end if;

  select cg.nome as cargo, m.categoria, m.instrumento_id into v_m
    from public.membros m left join public.cargos cg on cg.id = m.cargo_id
   where m.id = p_membro_id and m.excluido_em is null;
  if not found then
    raise exception 'Cadastro do membro não encontrado.';
  end if;

  if p_instrumento_id is not null and not exists (select 1 from public.instrumentos i where i.id = p_instrumento_id) then
    raise exception 'Instrumento inválido.';
  end if;

  -- Instrumento: o músico só toca o instrumento do cadastro (liberado pelo ministério). A escolha feita na
  -- entrada só vale para quem ainda NÃO tem instrumento cadastrado.
  v_ef_inst := coalesce(v_m.instrumento_id, p_instrumento_id);
  select i.nome into v_ef_nome from public.instrumentos i where i.id = v_ef_inst;
  select * into v_linha from public.linhas_painel l
   where l.codigo = public.classificar_linha(v_m.cargo, v_m.categoria, v_ef_nome);

  if v_linha.pergunta_toca then
    if p_toca is null then
      raise exception 'Informe se a pessoa vai tocar.';
    end if;
    v_toca := p_toca;
    if v_toca and v_ef_inst is null then
      raise exception 'Informe o instrumento que a pessoa vai tocar.';
    end if;
    v_gravar := case when v_toca and v_m.instrumento_id is null then p_instrumento_id else null end;
  else
    v_toca := null;               -- sem pergunta: vale a regra da linha (Músico conta sempre; Ancião/Diácono não)
    v_gravar := case when v_m.instrumento_id is null then p_instrumento_id else null end;
  end if;

  perform set_config('sysmusica.origem', p_origem, true);
  insert into public.presencas (membro_id, evento_id, status, portaria_id, toca, instrumento_id, linha_codigo)
  values (p_membro_id, v_evento, 'Presente', p_portaria_id, v_toca, v_gravar, v_linha.codigo)
  returning * into v_presenca;
  return v_presenca;
end;
$$;


revoke all on function public.registrar_entrada(uuid, uuid, text, boolean, uuid) from public, anon;
grant execute on function public.registrar_entrada(uuid, uuid, text, boolean, uuid) to authenticated;

commit;
""",
}

def abrir(c):
    return open(c, encoding="utf-8").read()

def trocar(texto, antigo, novo, onde):
    if texto.count(antigo) != 1:
        print("ERRO: trecho não encontrado exatamente uma vez em", onde, "->", antigo[:80].replace("\n", "\\n")); sys.exit(1)
    return texto.replace(antigo, novo)

for caminho in NOVOS:
    if os.path.exists(caminho):
        print("ERRO: já existe", caminho); sys.exit(1)

# ---------- Conferência: o músico toca só o instrumento do cadastro ----------
# O campo de instrumento só aparece quando o membro AINDA não tem instrumento cadastrado
a = "src/modules/atendimento/components/CartaoConferencia.tsx"
s = abrir(a)
s = trocar(s, "              pedirInstrumento={escolha.toca === true}\n",
  "              pedirInstrumento={escolha.toca === true && !info.instrumento_id} // com instrumento cadastrado, vale o do cadastro\n", a)
open(a, "w", encoding="utf-8").write(s)

for caminho, conteudo in NOVOS.items():
    os.makedirs(os.path.dirname(caminho) or ".", exist_ok=True)
    open(caminho, "w", encoding="utf-8").write(conteudo)
print("Arquivos gravados:", len(NOVOS), "novo, 1 alterado.")
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
npx eslint "${ALT[@]}" || { reverter; exit 1; }
echo; echo "=== 6) Build de produção (pode demorar alguns minutos) ==="
npm run build || { reverter; exit 1; }

echo; echo "=== TUDO CERTO: arquivos gravados e conferidos ==="
git status --short | grep -v "instalar-"
echo
echo "PRÓXIMO PASSO: rodar a migração 0029 no Supabase ANTES de publicar (git push)."
) 2>&1 | tee /tmp/instrumento-cadastro-instalar.log
