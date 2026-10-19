cd /workspaces/sysmusica/sysmusica || { echo "Pasta do projeto não encontrada"; exit 1; }
(
set -u
BKP="/tmp/bkp-portaria-encerrada-$(date +%H%M%S)"; mkdir -p "$BKP/a"
ALT=("src/modules/atendimento/components/AtendimentoPortaria.tsx")
NOV=("supabase/migrations/0030_portaria_encerrada.sql")
for f in "${ALT[@]}"; do mkdir -p "$BKP/a/$(dirname "$f")"; cp "$f" "$BKP/a/$f"; done

reverter() {
  echo ">>> REVERTENDO tudo (nada do que foi tentado fica no projeto)"
  for f in "${ALT[@]}"; do cp "$BKP/a/$f" "$f"; done
  for f in "${NOV[@]}"; do rm -f "$f"; done
  echo ">>> REVERTIDO. Me mande o log: /tmp/portaria-encerrada-instalar.log"
}

echo "=== 0) Conferência prévia (só leitura) ==="
for f in "${ALT[@]}" supabase/migrations/0028_portaria_toca_avulsa.sql supabase/migrations/0027_portaria_3h.sql; do
  [ -f "$f" ] || { echo "ERRO: arquivo esperado não existe: $f (as etapas anteriores foram instaladas?)"; exit 1; }
done
[ -e supabase/migrations/0030_portaria_encerrada.sql ] && { echo "ERRO: esta correção já parece instalada."; exit 1; }

echo; echo "=== 1) Gravando os arquivos ==="
python3 - <<'PYSCRIPT'
import os, sys
NOVOS = {
  'supabase/migrations/0030_portaria_encerrada.sql': r"""-- =====================================================================
-- SysMúsica — Migração 0030: portaria ENCERRADA não aceita mais nada
--   Passadas 3 horas do início do evento, a portaria está encerrada:
--     - sai da tela de Portaria;
--     - o banco recusa leitura de QR Code, busca por nome, conferência e QUALQUER registro de entrada
--       (de membro cadastrado ou sem cadastro), inclusive para o Administrador;
--     - só o Administrador corrige registros que já existem (Registros e correções; desfazer entrada sem cadastro).
--   Antes da abertura (2h antes) continua valendo a regra atual: só o controle total, com auditoria.
-- Requer as migrações 0027 e 0028. Idempotente, uma única transação.
-- =====================================================================
begin;

do $$
begin
  if to_regprocedure('public.registrar_entrada_avulsa(uuid,text,boolean,uuid,uuid,text)') is null
     or to_regprocedure('public.validar_registro_presenca(uuid,uuid,uuid)') is null
     or to_regprocedure('public.exigir_acesso_atendimento(uuid)') is null then
    raise exception 'Aplique primeiro as migrações 0027 e 0028.';
  end if;
end $$;

-- A regra do encerramento em um só lugar (3 horas depois do início do evento)
create or replace function public.portaria_encerrada(p_data timestamptz, p_agora timestamptz default now())
returns boolean language sql immutable set search_path = public as $$
  select p_data is not null and p_agora > p_data + interval '3 hours'
$$;

-- Acesso ao atendimento SEM olhar o prazo (só para o Administrador corrigir depois do encerramento)
create or replace function public.exigir_acesso_portaria_sem_prazo(p_portaria_id uuid)
returns void language plpgsql security definer set search_path = public as $$
declare
  v_p public.portarias;
begin
  perform public.exigir_permissao('portaria.registrar');
  select * into v_p from public.portarias p where p.id = p_portaria_id and p.excluido_em is null;
  if not found or v_p.status <> 'APROVADA' or not public.comum_na_abrangencia(v_p.comum_id) then
    raise exception 'Portaria indisponível para você.' using errcode = '42501';
  end if;
end;
$$;

-- Acesso ao atendimento: agora também barra a portaria ENCERRADA (QR, busca, conferência, registro, listas)
create or replace function public.exigir_acesso_atendimento(p_portaria_id uuid)
returns void language plpgsql security definer set search_path = public as $$
declare
  v_p    public.portarias;
  v_data timestamptz;
begin
  perform public.exigir_permissao('portaria.registrar');
  select * into v_p from public.portarias p where p.id = p_portaria_id and p.excluido_em is null;
  if not found or v_p.status <> 'APROVADA' or not public.comum_na_abrangencia(v_p.comum_id) then
    raise exception 'Portaria indisponível para você.' using errcode = '42501';
  end if;
  select e.data_evento into v_data from public.eventos e where e.id = v_p.evento_id;
  if public.portaria_encerrada(v_data) then
    raise exception 'Esta portaria foi encerrada e não aceita mais nada. Só o Administrador pode corrigir registros.'
      using errcode = '42501';
  end if;
end;
$$;

-- Registro de entrada de membro: encerrada = ninguém registra
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

  -- JANELA: de 2 horas antes a 3 horas depois do início do evento (horário de Salvador); depois disso, encerrada
  select e.data_evento into v_data from public.eventos e where e.id = v_p.evento_id;
  if v_data is null then
    raise exception 'O evento desta portaria não foi encontrado.';
  end if;
  -- Portaria ENCERRADA (passou de 3 horas depois do início): ninguém registra, nem o Administrador.
  -- O Administrador só corrige registros já existentes (editar/excluir), nunca cria entrada nova por aqui.
  if public.portaria_encerrada(v_data) then
    raise exception 'Esta portaria foi encerrada em % e não aceita mais entradas. Só o Administrador pode corrigir registros.',
      to_char((v_data + interval '3 hours') at time zone 'America/Sao_Paulo', 'DD/MM "às" HH24"h"MI');
  end if;
  -- Antes da abertura: só o controle total (Administrador), com registro na Auditoria
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

-- Desfazer entrada sem cadastro: depois do encerramento, só o Administrador (controle total)
create or replace function public.desfazer_entrada_avulsa(p_id uuid)
returns void language plpgsql security definer set search_path = public as $$
declare
  v    record;
  v_ev timestamptz;
begin
  select a.portaria_id, a.registrado_por, a.evento_id, l.rotulo into v
    from public.presencas_avulsas a join public.linhas_painel l on l.codigo = a.linha_codigo
   where a.id = p_id and a.excluido_em is null;
  if not found then
    raise exception 'Registro não encontrado.';
  end if;
  perform public.exigir_acesso_portaria_sem_prazo(v.portaria_id);
  select e.data_evento into v_ev from public.eventos e where e.id = v.evento_id;
  if public.portaria_encerrada(v_ev) then
    if not public.tem_permissao('portarias.controle_total') then
      raise exception 'Esta portaria foi encerrada. Só o Administrador pode corrigir registros.' using errcode = '42501';
    end if;
  elsif v.registrado_por is distinct from (select auth.uid()) and not public.tem_permissao('portaria.excluir') then
    raise exception 'Só quem registrou a entrada (ou quem pode excluir registros) pode desfazê-la.' using errcode = '42501';
  end if;
  update public.presencas_avulsas set excluido_em = now(), excluido_por = (select auth.uid()) where id = p_id;
  perform public.registrar_auditoria('entrada_avulsa_desfeita', 'portaria', v.portaria_id,
    jsonb_build_object('linha', v.rotulo));
end;
$$;

revoke all on function public.portaria_encerrada(timestamptz, timestamptz), public.exigir_acesso_portaria_sem_prazo(uuid)
  from public, anon, authenticated;
revoke all on function public.exigir_acesso_atendimento(uuid), public.validar_registro_presenca(uuid, uuid, uuid),
  public.desfazer_entrada_avulsa(uuid) from public, anon;
grant execute on function public.desfazer_entrada_avulsa(uuid) to authenticated;

-- VERIFICAÇÃO 1: limites do encerramento (evento às 14h de Salvador = 17h UTC; encerra às 17h de Salvador = 20h UTC)
do $$
declare
  v_ev constant timestamptz := '2026-10-19T17:00:00Z';
begin
  if public.portaria_encerrada(v_ev, '2026-10-19T20:00:00Z') then
    raise exception 'Teste falhou: encerrou antes das 17h.';
  end if;
  if not public.portaria_encerrada(v_ev, '2026-10-19T20:00:01Z') then
    raise exception 'Teste falhou: não encerrou depois das 17h.';
  end if;
  if public.portaria_encerrada(null, now()) then
    raise exception 'Teste falhou: evento sem data não pode estar encerrado.';
  end if;
end $$;

-- VERIFICAÇÃO 2 (aviso, não desfaz): as funções de leitura da Portaria precisam passar pelo acesso ao atendimento.
-- Se alguma aparecer na lista abaixo, me envie o aviso: ela não barra a leitura depois do encerramento.
do $$
declare
  v_sem text;
begin
  select string_agg(p.proname, ', ') into v_sem
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public'
     and p.proname in ('buscar_membro_por_qr', 'buscar_membros_por_nome', 'cartao_do_membro', 'entradas_da_portaria', 'info_entrada')
     and p.prosrc not like '%exigir_acesso_atendimento%';
  if v_sem is not null then
    raise notice 'ATENCAO: sem a trava de encerramento (verificar): %', v_sem;
  else
    raise notice 'OK: todas as funções de leitura da Portaria passam pela trava de encerramento.';
  end if;
end $$;

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

# ---------- Portaria ENCERRADA sai da tela (para todos) e nada mais é permitido ----------
a = "src/modules/atendimento/components/AtendimentoPortaria.tsx"
s = abrir(a)
s = trocar(s, 'import { useCallback, useEffect, useState } from "react";', 'import { useCallback, useEffect, useMemo, useState } from "react";', a)
s = trocar(s,
  "// A portaria só pode ser usada de 2h antes a 2h depois do início do evento (quem tem controle total usa sempre)\n"
  "function janelaLiberada(portaria: PortariaDetalhada, agora: number, controleTotal: boolean): boolean {\n"
  "  if (controleTotal) return true;\n"
  "  return janelaDaPortaria(portaria.evento_data, agora)?.situacao === \"aberta\";\n"
  "}\n",
  "// Portaria encerrada (passou de 3h depois do início) não atende ninguém, nem o Administrador: ela sai da tela.\n"
  "// Antes da abertura, só o controle total atende (com registro na Auditoria). Depois do encerramento, o Administrador\n"
  "// só corrige registros em \"Registros e correções\".\n"
  "function janelaLiberada(portaria: PortariaDetalhada, agora: number, controleTotal: boolean): boolean {\n"
  "  const situacao = janelaDaPortaria(portaria.evento_data, agora)?.situacao;\n"
  "  if (situacao === \"encerrada\") return false;\n"
  "  if (controleTotal) return true;\n"
  "  return situacao === \"aberta\";\n"
  "}\n", a)
s = trocar(s, "  const [agora, setAgora] = useState(0); // relógio da tela (atualiza a cada 30 s) para abrir e fechar a janela sozinho\n",
  "  const [agora, setAgora] = useState(0); // relógio da tela (atualiza a cada 30 s) para abrir e fechar a janela sozinho\n"
  "\n"
  "  // Portarias que ainda podem aparecer: as ENCERRADAS saem da lista sozinhas (o relógio recalcula a cada 30 s)\n"
  "  const disponiveis = useMemo(\n"
  "    () => portarias.filter((portaria) => janelaDaPortaria(portaria.evento_data, agora)?.situacao !== \"encerrada\"),\n"
  "    [portarias, agora]\n"
  "  );\n", a)
s = trocar(s,
  "      .catch((e: unknown) => console.error(\"Falha ao carregar as opções da entrada:\", e));\n  }, []);\n  /* eslint-enable react-hooks/set-state-in-effect */",
  "      .catch((e: unknown) => console.error(\"Falha ao carregar as opções da entrada:\", e));\n  }, []);\n\n"
  "  // Se a portaria em atendimento encerrar, sai da tela na hora: fecha a conferência e a entrada sem cadastro\n"
  "  useEffect(() => {\n"
  "    if (portariaId && portarias.length > 0 && !disponiveis.some((portaria) => portaria.id === portariaId)) {\n"
  "      setCartao(null);\n"
  "      setSemCadastro(false);\n"
  "      setPortariaId(null);\n"
  "      guardarPortaria(null);\n"
  "      setAviso(\"Esta portaria foi encerrada e saiu da tela. Só o Administrador pode corrigir registros.\");\n"
  "    }\n"
  "  }, [portariaId, portarias, disponiveis]);\n"
  "  /* eslint-enable react-hooks/set-state-in-effect */", a)
s = trocar(s, "  const portaria = portarias.find((item) => item.id === portariaId) ?? null;\n",
  "  const portaria = disponiveis.find((item) => item.id === portariaId) ?? null;\n", a)
s = trocar(s, "      ) : portarias.length === 0 ? (", "      ) : disponiveis.length === 0 ? (", a)
s = trocar(s, "          portarias={portarias}\n", "          portarias={disponiveis}\n", a)
s = trocar(s, "            {portarias.length > 1 && (", "            {disponiveis.length > 1 && (", a)
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
echo "PRÓXIMO PASSO: rodar a migração 0030 no Supabase ANTES de publicar (git push)."
) 2>&1 | tee /tmp/portaria-encerrada-instalar.log
