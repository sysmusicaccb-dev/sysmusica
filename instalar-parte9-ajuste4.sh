#!/usr/bin/env bash
# =============================================================================
# SysMúsica — PARTE 9 (ajuste 4): Casa de Oração em um campo só, com sugestões; casa não cadastrada vai para aprovação
#
#  ATENÇÃO: rode ANTES o SQL supabase/migrations/0043_casa_nao_cadastrada.sql no Supabase (SQL Editor).
#  Este instalador troca 10 arquivos do cadastro público e da tela Cadastros pendentes (serve para quem já instalou
#  os ajustes 1, 2 e/ou 3 ou nenhum deles) e coloca a migração em supabase/migrations.
#
# Segurança: confere cada trecho (exatamente 1 vez), faz backup em /tmp/bkp-parte9aj4-*, aplica,
# roda tsc, vitest, eslint e build; se algo falhar, DESFAZ tudo sozinho (inclusive os arquivos novos).
#
# Uso:  cd /workspaces/sysmusica/sysmusica && rm -rf .next && bash instalar-parte9-ajuste4.sh
# Log:  /tmp/instalar-parte9aj4.log
# =============================================================================

LOG=/tmp/instalar-parte9aj4.log
BKP=/tmp/bkp-parte9aj4-$(date +%Y%m%d-%H%M%S)
RAIZ="$(pwd)"

(
[ -f package.json ] && [ -d src ] || { echo "ERRO: rode dentro da pasta sysmusica (onde está o package.json)."; exit 1; }
mkdir -p "$BKP"
export BKP RAIZ

echo "== 1/3  Conferindo e aplicando as alterações =="
# (se o SQL 0043 ainda não foi rodado no Supabase, enviar uma casa digitada dará erro até rodar)
python3 - <<'PYSCRIPT'
import os, shutil, sys, hashlib

RAIZ = os.environ["RAIZ"]
BKP = os.environ["BKP"]

# (arquivo, trecho antigo, trecho novo) — cada "antigo" precisa existir EXATAMENTE 1 vez no arquivo.
# Os trechos usam \n; o instalador converte para o fim de linha do próprio arquivo (CRLF ou LF).
EDITS = []


# Arquivos NOVOS (o instalador recusa se algum já existir)
NOVOS = {
    "supabase/migrations/0043_casa_nao_cadastrada.sql": r'''-- =============================================================================
-- SysMúsica — Migração 0043: Cadastro público com Casa de Oração que NÃO está cadastrada
--
-- Antes: o formulário público exigia escolher uma Casa de Oração da lista.
-- Agora: a pessoa pode digitar o nome da casa; o pedido entra em "Cadastros pendentes" marcado como
-- "Casa não cadastrada" e quem aprova escolhe a casa correta (ou cadastra antes em Organização).
--
--   * cadastros_pendentes.casa_oracao_id passa a aceitar nulo; nova coluna casa_nome_informada (o texto digitado).
--   * Pedido SEM casa só é visível para quem tem acesso total à organização (não dá para saber de que região é)
--     — ou, nas atualizações, para quem enxerga a casa atual do membro.
--   * aprovar_cadastro_pendente ganha o parâmetro p_casa (obrigatório quando o pedido não tem casa).
--   * listar_cadastros_pendentes ganha a coluna casa_nao_cadastrada.
--   * A limpeza automática também apaga o nome digitado.
-- Rode UMA vez no SQL Editor do Supabase (depois da 0042).
-- =============================================================================
begin;
set local check_function_bodies = off;

do $$
begin
  if to_regclass('public.cadastros_pendentes') is null then
    raise exception 'Aplique primeiro a migração 0042. Nada foi alterado.';
  end if;
  if exists (select 1 from information_schema.columns
              where table_schema = 'public' and table_name = 'cadastros_pendentes' and column_name = 'casa_nome_informada') then
    raise exception 'A migração 0043 já foi aplicada. Nada foi alterado.';
  end if;
  if to_regprocedure('public.tem_acesso_total_organizacao()') is null then
    raise exception 'Função tem_acesso_total_organizacao não encontrada. Nada foi alterado.';
  end if;
end $$;

-- 1. Tabela
alter table public.cadastros_pendentes alter column casa_oracao_id drop not null;
alter table public.cadastros_pendentes
  add column casa_nome_informada text
  check (casa_nome_informada is null or char_length(casa_nome_informada) between 3 and 120);

-- 2. Visibilidade: sem casa => só acesso total à organização (ou a casa atual do membro, nas atualizações)
create or replace function public.cadastro_pendente_visivel(p_casa uuid, p_membro uuid)
returns boolean
language sql stable security definer set search_path to 'public'
as $$
  select (p_casa is null and public.tem_acesso_total_organizacao())
      or (p_casa is not null and public.casa_oracao_na_abrangencia(p_casa))
      or exists (select 1 from public.membros m
                  where m.id = p_membro and m.casa_oracao_id is not null
                    and public.casa_oracao_na_abrangencia(m.casa_oracao_id))
$$;

-- 3. Envio público
create or replace function public.registrar_cadastro_publico(p_envio uuid, p_dados jsonb, p_ip_hash text)
returns void
language plpgsql security definer set search_path to 'public'
as $$
declare
  d              jsonb;
  v_cad          jsonb;
  v_nome         text;
  v_cpf          text;
  v_nasc         date;
  v_casa         uuid;
  v_casa_txt     text;
  v_casa_nome    text;
  v_cargo        record;
  v_cargo_id     uuid;
  v_instr        uuid;
  v_instr_nome   text;
  v_categoria    text;
  v_cidade       text;
  v_bairro       text;
  v_menor        boolean;
  v_resp_nome    text;
  v_resp_tel     text;
  v_ace_resp     boolean;
  v_aviso        text;
  v_membro       uuid;
  v_membro_nasc  date;
  v_tipo         text := 'NOVO';
  v_conflito     boolean := false;
  v_usa_categ    boolean;
  v_batizado     boolean;
  v_dbat         date;
  v_demi         date;
  v_dval         date;
  v_limpo        jsonb;
  v_ec text; v_sx text; v_ddd text; v_tel text; v_wpp text; v_email text; v_cep text; v_end text; v_num text;
  v_comp text; v_uf text; v_cnum text;
begin
  if p_dados is null or jsonb_typeof(p_dados) <> 'object' then
    raise exception 'Não foi possível enviar o cadastro. Atualize a página e tente de novo.';
  end if;
  d := p_dados;

  -- O envio precisa ter sido iniciado há pouco e ainda não usado
  if not exists (select 1 from public.cadastro_publico_uploads u
                  where u.id = p_envio and not u.usado and u.criado_em > now() - interval '2 hours') then
    raise exception 'O envio expirou. Atualize a página e tente de novo.';
  end if;
  -- As três imagens precisam estar no armazenamento
  if (select count(*) from storage.objects o
       where o.bucket_id = 'cadastro-publico'
         and o.name in (p_envio::text || '/foto.jpg', p_envio::text || '/frente.jpg', p_envio::text || '/verso.jpg')) <> 3 then
    raise exception 'As imagens não foram enviadas. Tente novamente.';
  end if;

  -- Armadilha contra robôs
  if nullif(btrim(d ->> 'site'), '') is not null then
    raise exception 'Não foi possível enviar o cadastro. Atualize a página e tente de novo.';
  end if;
  if d -> 'aceite_privacidade' is distinct from 'true'::jsonb then
    raise exception 'Para enviar, é preciso concordar com o aviso de privacidade.';
  end if;
  v_aviso := nullif(btrim(d ->> 'aviso_versao'), '');
  if v_aviso is null or char_length(v_aviso) > 40 then
    raise exception 'Atualize a página e tente de novo.';
  end if;

  -- Identificação
  v_nome := public.limpar_espacos(d ->> 'nome');
  if v_nome is null or char_length(v_nome) < 5 or char_length(v_nome) > 120 or position(' ' in v_nome) = 0 then
    raise exception 'Informe o nome completo (nome e sobrenome).';
  end if;
  v_cpf := nullif(btrim(d ->> 'cpf'), '');
  if v_cpf is null or not public.cpf_valido(v_cpf) then
    raise exception 'CPF inválido. Confira os números digitados.';
  end if;
  v_nasc := public.data_ou_nula(d ->> 'data_nascimento');
  if v_nasc is null or v_nasc > current_date or v_nasc < date '1900-01-01' then
    raise exception 'Data de nascimento inválida.';
  end if;
  v_cidade := public.limpar_espacos(d ->> 'cidade');
  v_bairro := public.limpar_espacos(d ->> 'bairro');
  if v_cidade is null or v_bairro is null or char_length(v_cidade) > 80 or char_length(v_bairro) > 80 then
    raise exception 'Informe a cidade e o bairro.';
  end if;

  -- Casa de Oração
  -- Dois caminhos: (a) escolheu uma casa da lista (id); (b) a casa não existe na lista e a pessoa digitou o nome.
  -- No caso (b) o pedido fica sem casa; quem aprova escolhe (ou cadastra) a casa correta antes de aprovar.
  v_casa_txt := nullif(btrim(d ->> 'casa_oracao_id'), '');
  v_casa := null;
  v_casa_nome := null;
  if v_casa_txt is not null then
    begin v_casa := v_casa_txt::uuid; exception when others then v_casa := null; end;
    if v_casa is null or not exists (select 1 from public.casas_oracao c where c.id = v_casa and c.ativo) then
      raise exception 'Escolha a sua Casa de Oração na lista ou digite o nome dela.';
    end if;
  else
    v_casa_nome := public.limpar_espacos(d ->> 'casa_nome');
    if v_casa_nome is null or char_length(v_casa_nome) < 3 or char_length(v_casa_nome) > 120 then
      raise exception 'Escolha a sua Casa de Oração na lista ou digite o nome dela.';
    end if;
  end if;

  -- Cargo, categoria e instrumento
  begin v_cargo_id := (d ->> 'cargo_id')::uuid; exception when others then v_cargo_id := null; end;
  select c.* into v_cargo from public.cargos c where c.id = v_cargo_id;
  if not found or not public.cargo_aceita_cadastro_publico(v_cargo.nome) then
    raise exception 'Escolha um cargo da lista.';
  end if;
  v_usa_categ := public.normalizar_texto(v_cargo.nome) ~ '^(musico|organista)';
  v_categoria := nullif(btrim(d ->> 'categoria'), '');
  if v_usa_categ then
    if v_categoria is null or v_categoria not in ('OFICIALIZADO', 'CULTO_OFICIAL', 'RJM') then
      raise exception 'Escolha a categoria.';
    end if;
  else
    v_categoria := null;
  end if;

  if v_cargo.permite_instrumento then
    begin v_instr := (d ->> 'instrumento_id')::uuid; exception when others then v_instr := null; end;
    select i.nome into v_instr_nome from public.instrumentos i where i.id = v_instr;
    if v_instr_nome is null then
      raise exception 'Informe o instrumento.';
    end if;
    if v_cargo.somente_orgao and not public.instrumento_e_orgao(v_instr_nome) then
      raise exception 'O cargo % só pode usar o instrumento Órgão.', v_cargo.nome;
    end if;
  else
    v_instr := null;
  end if;

  -- Dados pessoais (mesmas regras de salvar_cadastro_musical)
  v_cad := d -> 'cadastro';
  if v_cad is null or jsonb_typeof(v_cad) <> 'object' then
    raise exception 'Preencha os dados pessoais.';
  end if;
  v_ec    := nullif(btrim(v_cad ->> 'estado_civil'), '');
  v_sx    := nullif(btrim(v_cad ->> 'sexo'), '');
  v_ddd   := nullif(btrim(v_cad ->> 'ddd'), '');
  v_tel   := nullif(btrim(v_cad ->> 'telefone'), '');
  v_wpp   := nullif(btrim(v_cad ->> 'whatsapp'), '');
  v_email := nullif(btrim(v_cad ->> 'email'), '');
  v_cep   := nullif(btrim(v_cad ->> 'cep'), '');
  v_end   := public.limpar_espacos(v_cad ->> 'endereco');
  v_num   := public.limpar_espacos(v_cad ->> 'numero');
  v_comp  := public.limpar_espacos(v_cad ->> 'complemento');
  v_uf    := nullif(btrim(v_cad ->> 'uf'), '');
  v_cnum  := public.limpar_espacos(v_cad ->> 'cartao_numero');
  v_demi  := public.data_ou_nula(v_cad ->> 'cartao_emissao');
  v_dval  := public.data_ou_nula(v_cad ->> 'cartao_validade');
  v_dbat  := public.data_ou_nula(v_cad ->> 'data_batismo');

  if v_ec is null or v_ec not in ('Casado (a)', 'Solteiro (a)', 'Viúvo (a)') then raise exception 'Informe o estado civil.'; end if;
  if v_sx is null or v_sx not in ('Masculino', 'Feminino') then raise exception 'Informe o sexo.'; end if;
  if jsonb_typeof(v_cad -> 'batizado') <> 'boolean' then raise exception 'Informe se a pessoa é batizada.'; end if;
  v_batizado := (v_cad ->> 'batizado')::boolean;
  if v_batizado then
    if v_dbat is null then raise exception 'Informe a data do batismo.'; end if;
    if v_dbat < v_nasc or v_dbat > current_date then raise exception 'A data do batismo é inválida.'; end if;
  else
    v_dbat := null;
  end if;
  if jsonb_typeof(v_cad -> 'selado') <> 'boolean' then raise exception 'Informe se a pessoa é selada.'; end if;
  if v_ddd is null or v_ddd !~ '^[0-9]{2}$' then raise exception 'O DDD deve ter 2 números.'; end if;
  if v_tel is null or v_tel !~ '^[0-9]{8,9}$' then raise exception 'O telefone deve ter 8 ou 9 números.'; end if;
  if jsonb_typeof(v_cad -> 'tem_whatsapp') <> 'boolean' then raise exception 'Informe se o telefone tem WhatsApp.'; end if;
  if (v_cad ->> 'tem_whatsapp')::boolean then
    if v_wpp is not null and v_wpp !~ '^[0-9]{10,11}$' then raise exception 'O WhatsApp deve ter o DDD e 8 ou 9 números.'; end if;
  else
    v_wpp := null;
  end if;
  if v_email is not null and (char_length(v_email) > 120 or v_email !~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$') then
    raise exception 'O e-mail informado não é válido.';
  end if;
  if v_cep is null or v_cep !~ '^[0-9]{8}$' then raise exception 'O CEP deve ter 8 números.'; end if;
  if v_end is null or char_length(v_end) > 150 then raise exception 'Informe o endereço.'; end if;
  if v_num is null or char_length(v_num) > 20 then raise exception 'Informe o número do endereço.'; end if;
  if v_comp is not null and char_length(v_comp) > 80 then raise exception 'O complemento é longo demais.'; end if;
  if v_uf is null or v_uf !~ '^[A-Z]{2}$' then raise exception 'Informe o estado (UF).'; end if;
  if v_cnum is not null and char_length(v_cnum) > 40 then raise exception 'O número do cartão é longo demais.'; end if;
  if v_demi is not null and v_dval is not null and v_demi > v_dval then
    raise exception 'A validade do cartão não pode ser anterior à emissão.';
  end if;
  if coalesce(v_cargo.exige_cartao, false) and (v_cnum is null or v_dval is null) then
    raise exception 'Este cargo exige o número e a validade do cartão de identificação.';
  end if;

  -- Menor de 18 anos: responsável
  v_menor := v_nasc > (current_date - interval '18 years')::date;
  v_resp_nome := null; v_resp_tel := null; v_ace_resp := false;
  if v_menor then
    v_resp_nome := public.limpar_espacos(d ->> 'responsavel_nome');
    v_resp_tel  := nullif(btrim(d ->> 'responsavel_telefone'), '');
    v_ace_resp  := d -> 'aceite_responsavel' is not distinct from 'true'::jsonb;
    if v_resp_nome is null or char_length(v_resp_nome) < 3 or char_length(v_resp_nome) > 120 then
      raise exception 'Para menores de 18 anos, informe o nome do responsável.';
    end if;
    if v_resp_tel is null or v_resp_tel !~ '^[0-9]{10,11}$' then
      raise exception 'Informe o telefone do responsável com o DDD.';
    end if;
    if not v_ace_resp then raise exception 'O responsável precisa concordar com o cadastro.'; end if;
  end if;

  -- Limite por CPF (3 por dia). Só conta a quantidade: não revela se o CPF existe.
  perform public.cadastro_publico_limite('cpf', encode(sha256(convert_to(v_cpf, 'UTF8')), 'hex'), 3, interval '1 day');

  -- É alguém que já está no sistema? CPF + data de nascimento iguais = pedido de ATUALIZAÇÃO.
  select m.id, m.data_nascimento into v_membro, v_membro_nasc
    from public.membros m where m.cpf = v_cpf and m.excluido_em is null;
  if found then
    if v_membro_nasc is not distinct from v_nasc then
      v_tipo := 'ATUALIZACAO';
    else
      v_conflito := true;   -- mesmo CPF, outra data de nascimento: o aprovador confere
      v_membro := null;
    end if;
  else
    v_membro := null;
  end if;

  v_limpo := jsonb_build_object(
    'estado_civil', v_ec, 'sexo', v_sx, 'batizado', v_batizado, 'data_batismo', v_dbat,
    'selado', (v_cad ->> 'selado')::boolean, 'ddd', v_ddd, 'telefone', v_tel,
    'tem_whatsapp', (v_cad ->> 'tem_whatsapp')::boolean, 'whatsapp', v_wpp, 'email', v_email,
    'cep', v_cep, 'endereco', v_end, 'numero', v_num, 'complemento', v_comp, 'uf', v_uf,
    'cartao_numero', v_cnum, 'cartao_emissao', v_demi, 'cartao_validade', v_dval);

  insert into public.cadastros_pendentes (
    id, tipo, membro_id, casa_oracao_id, casa_nome_informada, nome, cpf, data_nascimento, cidade, bairro, cargo_id, instrumento_id,
    categoria, dados, responsavel_nome, responsavel_telefone, aceite_responsavel, aviso_versao, ip_hash, cpf_conflito)
  values (
    p_envio, v_tipo, v_membro, v_casa, v_casa_nome, v_nome, v_cpf, v_nasc, v_cidade, v_bairro, v_cargo_id, v_instr,
    v_categoria, v_limpo, v_resp_nome, v_resp_tel, v_ace_resp, v_aviso, p_ip_hash, v_conflito);

  update public.cadastro_publico_uploads set usado = true where id = p_envio;
end;
$$;

-- 4. Lista (mudou a lista de colunas devolvidas: precisa apagar e recriar)
drop function public.listar_cadastros_pendentes(text);
create function public.listar_cadastros_pendentes(p_status text default 'PENDENTE')
returns table (
  id uuid, tipo text, status text, nome text, cpf_mascarado text, cargo_nome text, casa_nome text,
  casa_nao_cadastrada boolean,
  menor boolean, cpf_conflito boolean, outros_pendentes bigint, criado_em timestamptz, expira_em timestamptz,
  decidido_em timestamptz, motivo_rejeicao text
)
language plpgsql stable security definer set search_path to 'public'
as $$
begin
  perform public.exigir_permissao('cadastros.visualizar');
  if p_status is not null and p_status not in ('PENDENTE', 'APROVADO', 'REJEITADO', 'EXPIRADO', 'TODOS') then
    raise exception 'Situação inválida.' using errcode = '22023';
  end if;
  return query
    select c.id, c.tipo, c.status, c.nome, public.cpf_escondido(c.cpf), g.nome,
           coalesce(ca.nome, c.casa_nome_informada),
           (c.casa_oracao_id is null and c.casa_nome_informada is not null),
           (c.data_nascimento is not null and c.data_nascimento > (c.criado_em::date - interval '18 years')::date),
           c.cpf_conflito,
           (select count(*) from public.cadastros_pendentes o
             where o.status = 'PENDENTE' and o.id <> c.id and c.cpf is not null and o.cpf = c.cpf),
           c.criado_em, c.expira_em, c.decidido_em, c.motivo_rejeicao
      from public.cadastros_pendentes c
      left join public.cargos g on g.id = c.cargo_id
      left join public.casas_oracao ca on ca.id = c.casa_oracao_id
     where (p_status is null or p_status = 'TODOS' or c.status = p_status)
       and public.cadastro_pendente_visivel(c.casa_oracao_id, c.membro_id)
     order by case when c.status = 'PENDENTE' then 0 else 1 end, c.criado_em desc
     limit 500;
end;
$$;
revoke all on function public.listar_cadastros_pendentes(text) from public, anon, authenticated;
grant execute on function public.listar_cadastros_pendentes(text) to authenticated;

-- 5. Detalhe
create or replace function public.obter_cadastro_pendente(p_id uuid)
returns jsonb
language plpgsql stable security definer set search_path to 'public'
as $$
declare
  c      public.cadastros_pendentes%rowtype;
  v_atual jsonb := null;
  v_ver_cpf boolean;
begin
  perform public.exigir_permissao('cadastros.visualizar');
  select * into c from public.cadastros_pendentes where id = p_id;
  if not found or not public.cadastro_pendente_visivel(c.casa_oracao_id, c.membro_id) then
    raise exception 'Cadastro não encontrado.' using errcode = 'P0002';
  end if;
  v_ver_cpf := public.tem_permissao('membros.cpf');

  if c.membro_id is not null then
    select jsonb_build_object(
             'nome', m.nome, 'casa_oracao_id', m.casa_oracao_id, 'casa_nome', ca.nome,
             'cargo_id', m.cargo_id, 'cargo_nome', g.nome, 'instrumento_id', m.instrumento_id, 'instrumento_nome', i.nome,
             'categoria', m.categoria, 'cidade', m.cidade, 'bairro', m.bairro, 'data_nascimento', m.data_nascimento,
             'cadastro', (select to_jsonb(mc) - 'membro_id' - 'criado_em' - 'atualizado_em' - 'documento_frente_path'
                                 - 'documento_verso_path' - 'apresentado_em' - 'apresentado_por' - 'observacao'
                            from public.membros_cadastro mc where mc.membro_id = m.id))
      into v_atual
      from public.membros m
      left join public.casas_oracao ca on ca.id = m.casa_oracao_id
      left join public.cargos g on g.id = m.cargo_id
      left join public.instrumentos i on i.id = m.instrumento_id
     where m.id = c.membro_id and m.excluido_em is null;
  end if;

  return jsonb_build_object(
    'id', c.id, 'tipo', c.tipo, 'status', c.status, 'membro_id', c.membro_id,
    'nome', c.nome, 'data_nascimento', c.data_nascimento, 'cidade', c.cidade, 'bairro', c.bairro,
    'cpf', case when v_ver_cpf then c.cpf else public.cpf_escondido(c.cpf) end,
    'cpf_completo_visivel', v_ver_cpf,
    'casa_oracao_id', c.casa_oracao_id,
    'casa_nome', coalesce((select ca.nome from public.casas_oracao ca where ca.id = c.casa_oracao_id), c.casa_nome_informada),
    'casa_nome_informada', c.casa_nome_informada,
    'cargo_id', c.cargo_id, 'cargo_nome', (select g.nome from public.cargos g where g.id = c.cargo_id),
    'instrumento_id', c.instrumento_id, 'instrumento_nome', (select i.nome from public.instrumentos i where i.id = c.instrumento_id),
    'categoria', c.categoria, 'dados', c.dados,
    'menor', c.data_nascimento is not null and c.data_nascimento > (c.criado_em::date - interval '18 years')::date,
    'responsavel_nome', c.responsavel_nome, 'responsavel_telefone', c.responsavel_telefone,
    'aviso_versao', c.aviso_versao, 'aceite_em', c.aceite_em, 'cpf_conflito', c.cpf_conflito,
    'criado_em', c.criado_em, 'expira_em', c.expira_em, 'decidido_em', c.decidido_em,
    'motivo_rejeicao', c.motivo_rejeicao,
    'arquivos_disponiveis', (c.arquivos_apagados_em is null and c.status in ('PENDENTE', 'REJEITADO')),
    'outros_pendentes', (select count(*) from public.cadastros_pendentes o
                          where o.status = 'PENDENTE' and o.id <> c.id and c.cpf is not null and o.cpf = c.cpf),
    'atual', v_atual);
end;
$$;

-- 6. Aprovação (nova assinatura com p_casa; a antiga é removida)
drop function public.aprovar_cadastro_pendente(uuid, uuid, text, text, text);
create function public.aprovar_cadastro_pendente(
  p_id uuid, p_membro uuid, p_foto text, p_doc_frente text, p_doc_verso text, p_casa uuid default null)
returns jsonb
language plpgsql security definer set search_path to 'public'
as $$
declare
  c         public.cadastros_pendentes%rowtype;
  v_cad     jsonb;
  v_membro  uuid;
  v_casa    uuid;
  v_atual   public.membros%rowtype;
  v_antigos jsonb := '{}'::jsonb;
  v_obs     text;
  v_antigo_cad public.membros_cadastro%rowtype;
begin
  perform public.exigir_permissao('cadastros.aprovar');
  select * into c from public.cadastros_pendentes where id = p_id for update;
  if not found or not public.cadastro_pendente_visivel(c.casa_oracao_id, c.membro_id) then
    raise exception 'Cadastro não encontrado.' using errcode = 'P0002';
  end if;
  if c.status <> 'PENDENTE' then
    raise exception 'Este cadastro já foi analisado.' using errcode = '22023';
  end if;
  -- Pedido com Casa de Oração DIGITADA (não estava na lista): quem aprova escolhe a casa cadastrada correta.
  v_casa := c.casa_oracao_id;
  if v_casa is null then
    v_casa := p_casa;
    if v_casa is null then
      raise exception 'Este pedido trouxe uma Casa de Oração que não está cadastrada. Escolha a casa correta (ou cadastre-a em Organização) antes de aprovar.' using errcode = '22023';
    end if;
    if not exists (select 1 from public.casas_oracao x where x.id = v_casa and x.ativo) then
      raise exception 'Casa de Oração inválida ou inativa.' using errcode = '22023';
    end if;
  end if;
  if not public.casa_oracao_na_abrangencia(v_casa) then
    raise exception 'A Casa de Oração do pedido está fora da sua abrangência. Peça a quem tem acesso total.' using errcode = '42501';
  end if;

  v_membro := coalesce(c.membro_id, p_membro);
  if v_membro is null then raise exception 'Identificação do membro ausente.' using errcode = '22023'; end if;
  if left(p_foto, 37) <> v_membro::text || '/' then
    raise exception 'Caminho da fotografia inválido.' using errcode = '22023';
  end if;
  if left(p_doc_frente, 37) <> v_membro::text || '/' or left(p_doc_verso, 37) <> v_membro::text || '/' then
    raise exception 'Caminho do documento inválido.' using errcode = '22023';
  end if;
  if position('..' in p_foto || p_doc_frente || p_doc_verso) > 0 then
    raise exception 'Caminho inválido.' using errcode = '22023';
  end if;
  if not exists (select 1 from storage.objects o where o.bucket_id = 'documentos-membros' and o.name = p_doc_frente)
     or not exists (select 1 from storage.objects o where o.bucket_id = 'documentos-membros' and o.name = p_doc_verso) then
    raise exception 'Os arquivos do documento não foram encontrados. Tente aprovar de novo.' using errcode = '22023';
  end if;
  perform public.validar_foto_membro(v_membro, p_foto);

  -- A partir daqui o gatilho dos membros aceita o CPF (a permissão cadastros.aprovar já foi conferida)
  perform set_config('sysmusica.aprovando_cadastro', 'sim', true);

  v_cad := c.dados;
  v_obs := null;
  if c.responsavel_nome is not null then
    v_obs := 'Menor de idade no cadastro público (' || to_char(c.criado_em at time zone 'America/Sao_Paulo', 'DD/MM/YYYY')
             || '). Responsável: ' || c.responsavel_nome || ', telefone ' || c.responsavel_telefone || '.';
  end if;

  if c.tipo = 'NOVO' then
    if c.cpf is null or exists (select 1 from public.membros m where m.cpf = c.cpf and m.excluido_em is null) then
      raise exception 'Já existe um membro com este CPF. Recuse este pedido e atualize o cadastro existente.' using errcode = '23505';
    end if;
    insert into public.membros (id, nome, congregacao, casa_oracao_id, cargo_id, data_nascimento, status,
                                instrumento_id, cpf, cidade, bairro, foto_path, categoria)
    values (v_membro, c.nome, '', v_casa, c.cargo_id, c.data_nascimento, 'Ativo',
            c.instrumento_id, c.cpf, c.cidade, c.bairro, p_foto, c.categoria);

    insert into public.membros_cadastro (
      membro_id, estado_civil, sexo, batizado, data_batismo, selado, ddd, telefone, tem_whatsapp, whatsapp, email,
      cep, endereco, numero, complemento, uf, cartao_numero, cartao_emissao, cartao_validade, observacao,
      documento_frente_path, documento_verso_path)
    values (
      v_membro, v_cad ->> 'estado_civil', v_cad ->> 'sexo', (v_cad ->> 'batizado')::boolean,
      public.data_ou_nula(v_cad ->> 'data_batismo'), (v_cad ->> 'selado')::boolean, v_cad ->> 'ddd', v_cad ->> 'telefone',
      (v_cad ->> 'tem_whatsapp')::boolean, v_cad ->> 'whatsapp', v_cad ->> 'email',
      v_cad ->> 'cep', v_cad ->> 'endereco', v_cad ->> 'numero', v_cad ->> 'complemento', v_cad ->> 'uf',
      v_cad ->> 'cartao_numero', public.data_ou_nula(v_cad ->> 'cartao_emissao'),
      public.data_ou_nula(v_cad ->> 'cartao_validade'), v_obs, p_doc_frente, p_doc_verso);
  else
    select * into v_atual from public.membros m where m.id = v_membro and m.excluido_em is null for update;
    if not found then
      raise exception 'O membro deste pedido foi excluído. Recuse o pedido.' using errcode = '22023';
    end if;
    if v_atual.casa_oracao_id is not null and not public.casa_oracao_na_abrangencia(v_atual.casa_oracao_id) then
      raise exception 'O membro está em uma Casa de Oração fora da sua abrangência. Peça a quem tem acesso total.' using errcode = '42501';
    end if;
    select * into v_antigo_cad from public.membros_cadastro where membro_id = v_membro;
    v_antigos := jsonb_build_object('foto', v_atual.foto_path,
                                    'doc_frente', v_antigo_cad.documento_frente_path,
                                    'doc_verso', v_antigo_cad.documento_verso_path);

    update public.membros
       set nome = c.nome, casa_oracao_id = v_casa, cargo_id = c.cargo_id, instrumento_id = c.instrumento_id,
           categoria = c.categoria, cidade = c.cidade, bairro = c.bairro, foto_path = p_foto
     where id = v_membro;

    insert into public.membros_cadastro as mc (
      membro_id, estado_civil, sexo, batizado, data_batismo, selado, ddd, telefone, tem_whatsapp, whatsapp, email,
      cep, endereco, numero, complemento, uf, cartao_numero, cartao_emissao, cartao_validade, observacao,
      documento_frente_path, documento_verso_path)
    values (
      v_membro, v_cad ->> 'estado_civil', v_cad ->> 'sexo', (v_cad ->> 'batizado')::boolean,
      public.data_ou_nula(v_cad ->> 'data_batismo'), (v_cad ->> 'selado')::boolean, v_cad ->> 'ddd', v_cad ->> 'telefone',
      (v_cad ->> 'tem_whatsapp')::boolean, v_cad ->> 'whatsapp', v_cad ->> 'email',
      v_cad ->> 'cep', v_cad ->> 'endereco', v_cad ->> 'numero', v_cad ->> 'complemento', v_cad ->> 'uf',
      v_cad ->> 'cartao_numero', public.data_ou_nula(v_cad ->> 'cartao_emissao'),
      public.data_ou_nula(v_cad ->> 'cartao_validade'), v_obs, p_doc_frente, p_doc_verso)
    on conflict (membro_id) do update set
      estado_civil = excluded.estado_civil, sexo = excluded.sexo, batizado = excluded.batizado,
      data_batismo = excluded.data_batismo, selado = excluded.selado, ddd = excluded.ddd, telefone = excluded.telefone,
      tem_whatsapp = excluded.tem_whatsapp, whatsapp = excluded.whatsapp, email = excluded.email, cep = excluded.cep,
      endereco = excluded.endereco, numero = excluded.numero, complemento = excluded.complemento, uf = excluded.uf,
      cartao_numero = excluded.cartao_numero, cartao_emissao = excluded.cartao_emissao,
      cartao_validade = excluded.cartao_validade,
      -- menor de idade: acrescenta a anotação do responsável sem apagar a observação que já existia
      observacao = case when excluded.observacao is null then mc.observacao
                        when mc.observacao is null then excluded.observacao
                        else mc.observacao || E'\n' || excluded.observacao end,
      documento_frente_path = excluded.documento_frente_path, documento_verso_path = excluded.documento_verso_path,
      atualizado_em = now();
  end if;

  -- O pedido vira histórico: os dados já estão no membro, então saem daqui (guardamos só quem decidiu e quando)
  update public.cadastros_pendentes
     set status = 'APROVADO', membro_id = v_membro, casa_oracao_id = v_casa, casa_nome_informada = null, decidido_em = now(), decidido_por = (select auth.uid()),
         dados = '{}'::jsonb, responsavel_nome = null, responsavel_telefone = null, ip_hash = null,
         arquivos_apagados_em = now()
   where id = p_id;

  perform public.registrar_auditoria('cadastro_aprovado', 'cadastro_pendente', p_id,
            jsonb_build_object('tipo', c.tipo, 'membro_id', v_membro, 'rotulo', c.nome));
  perform set_config('sysmusica.aprovando_cadastro', '', true);
  return jsonb_build_object('membro_id', v_membro, 'tipo', c.tipo, 'antigos', v_antigos);
end;
$$;
revoke all on function public.aprovar_cadastro_pendente(uuid, uuid, text, text, text, uuid) from public, anon, authenticated;
grant execute on function public.aprovar_cadastro_pendente(uuid, uuid, text, text, text, uuid) to authenticated;

-- 7. Limpeza
create or replace function public.marcar_cadastros_limpos(p_ids uuid[], p_abandonados uuid[] default '{}')
returns integer
language plpgsql security definer set search_path to 'public'
as $$
declare v_n integer;
begin
  delete from public.cadastro_publico_uploads where id = any (p_abandonados) and not usado;
  update public.cadastros_pendentes
     set arquivos_apagados_em = now(), casa_nome_informada = null, nome = null, cpf = null, data_nascimento = null, cidade = null, bairro = null,
         dados = '{}'::jsonb, responsavel_nome = null, responsavel_telefone = null, ip_hash = null
   where id = any (p_ids) and status in ('REJEITADO', 'EXPIRADO', 'SUBSTITUIDO') and arquivos_apagados_em is null;
  get diagnostics v_n = row_count;
  return v_n;
end;
$$;

-- 8. Conferência final
do $$
begin
  if to_regprocedure('public.aprovar_cadastro_pendente(uuid, uuid, text, text, text, uuid)') is null
     or to_regprocedure('public.aprovar_cadastro_pendente(uuid, uuid, text, text, text)') is not null then
    raise exception 'Falha ao instalar a nova função de aprovação. Nada foi alterado.';
  end if;
  if has_function_privilege('anon', 'public.aprovar_cadastro_pendente(uuid, uuid, text, text, text, uuid)', 'execute')
     or has_function_privilege('anon', 'public.listar_cadastros_pendentes(text)', 'execute')
     or has_function_privilege('anon', 'public.registrar_cadastro_publico(uuid, jsonb, text)', 'execute') then
    raise exception 'Permissões inesperadas para o papel anon. Nada foi alterado.';
  end if;
end $$;

commit;
select set_config('sysmusica.migracao_0043', 'ok', false);
''',
}


# Arquivos a REMOVER: só são apagados se o conteúdo for idêntico ao esperado (cópia fica no backup)
REMOVER = {}


# Arquivos SUBSTITUÍDOS por inteiro: só troca se o original tiver o hash (sha256, fim de linha normalizado) esperado
SUBST = {
    "src/modules/cadastroPublico/regras.ts": {"sha": ["0ec4ea663e4f538a775b9310ffde35192a38e55efa06b17e546fdb90bae75ce2"], "novo": r'''/**
 * SysMúsica — Regras puras do Cadastro Musical PÚBLICO (sem banco, sem tela). Testadas em regras.test.ts.
 *
 * O formulário público usa as mesmas regras do cadastro interno (modules/membros/cadastroMusical.ts) e soma:
 *  - aceite do aviso de privacidade (LGPD) e campo-armadilha contra robôs;
 *  - menores de 18 anos: nome e telefone do responsável e o aceite dele;
 *  - fotografia e documento (frente e verso) sempre obrigatórios.
 * O banco refaz todas as conferências (função registrar_cadastro_publico, migração 0042): a tela é só a resposta rápida.
 */
import {
  cargoEntraNoCadastro,
  cargoExigeCartao,
  cargoSomenteOrgao,
  instrumentosDoCargo,
  paraEnvioAoBanco,
  somenteDigitos,
  validarCadastro,
  type CadastroMusical,
  type CargoCadastro,
} from "@/modules/membros/cadastroMusical";
import { validarInstrumentoDoCargo } from "@/modules/instrumentos/selecao";
import { cargoUsaCategoria, validarCategoria } from "@/modules/painel/regras";
import { VERSAO_AVISO } from "./aviso";
import { cpfValido, soDigitos } from "./cpf";

export const IDADE_MAIORIDADE = 18;
export const NOME_MINIMO = 5;
export const NOME_MAXIMO = 120;
export const RESPONSAVEL_NOME_MINIMO = 3;

/** Cargo como a função opcoes_cadastro_publico devolve. */
export interface CargoPublico extends CargoCadastro {
  permite_instrumento: boolean;
  exige_instrumento: boolean;
}

export interface InstrumentoPublico {
  id: string;
  nome: string;
  familia_id: string | null;
}

export interface FamiliaPublica {
  id: string;
  nome: string;
}

/** Casa de Oração com o caminho na organização (para a pessoa achar a dela). */
export interface CasaPublica {
  id: string;
  nome: string;
  adm: string | null;
  ra: string | null;
  rrm: string | null;
  setor: string | null;
}

export interface OpcoesCadastroPublico {
  cargos: CargoPublico[];
  instrumentos: InstrumentoPublico[];
  familias: FamiliaPublica[];
  casas: CasaPublica[];
}

/** Tudo o que a pessoa preenche (textos, para ligar direto nos campos). */
export interface DadosFormularioPublico {
  nome: string;
  casaOracaoId: string; // id da casa escolhida na lista ("" se a pessoa digitou uma casa que não está na lista)
  casaNome: string; // nome digitado (usado só quando casaOracaoId está vazio)
  cargoId: string;
  instrumentoId: string;
  categoria: string;
  cpf: string;
  dataNascimento: string; // AAAA-MM-DD
  cidade: string;
  bairro: string;
  cadastro: CadastroMusical;
  responsavelNome: string;
  responsavelTelefone: string; // DDD + número
  aceiteResponsavel: boolean;
  aceitePrivacidade: boolean;
  /** Campo-armadilha: invisível para pessoas; robôs costumam preencher. Deve ficar vazio. */
  site: string;
}

/** Tamanho do nome de uma Casa de Oração digitada (mesmos limites do banco). */
export const CASA_NOME_MINIMO = 3;
export const CASA_NOME_MAXIMO = 120;

export interface ContextoValidacao {
  cargo: CargoPublico | undefined;
  temFoto: boolean;
  temDocumentoFrente: boolean;
  temDocumentoVerso: boolean;
  /** Data de hoje (AAAA-MM-DD), recebida de fora para a regra ser testável. */
  hoje: string;
}

/** Tira espaços das pontas e os repetidos do nome. */
export function limparNome(texto: string): string {
  return texto.trim().replace(/\s+/g, " ");
}

/** "AAAA-MM-DD" válida (existe no calendário)? */
export function dataIsoValida(texto: string): boolean {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(texto)) return false;
  const [a, m, d] = texto.split("-").map(Number);
  const data = new Date(Date.UTC(a, m - 1, d));
  return data.getUTCFullYear() === a && data.getUTCMonth() === m - 1 && data.getUTCDate() === d;
}

/** Idade em anos completos em `hoje` (AAAA-MM-DD); null se alguma data for inválida. */
export function idadeEm(dataNascimento: string, hoje: string): number | null {
  if (!dataIsoValida(dataNascimento) || !dataIsoValida(hoje)) return null;
  const [an, mn, dn] = dataNascimento.split("-").map(Number);
  const [ah, mh, dh] = hoje.split("-").map(Number);
  let idade = ah - an;
  if (mh < mn || (mh === mn && dh < dn)) idade -= 1;
  return idade;
}

export function ehMenorDeIdade(dataNascimento: string, hoje: string): boolean {
  const idade = idadeEm(dataNascimento, hoje);
  return idade !== null && idade < IDADE_MAIORIDADE;
}

export function formularioVazio(cadastroVazio: CadastroMusical): DadosFormularioPublico {
  return {
    nome: "",
    casaOracaoId: "",
    casaNome: "",
    cargoId: "",
    instrumentoId: "",
    categoria: "",
    cpf: "",
    dataNascimento: "",
    cidade: "",
    bairro: "",
    cadastro: cadastroVazio,
    responsavelNome: "",
    responsavelTelefone: "",
    aceiteResponsavel: false,
    aceitePrivacidade: false,
    site: "",
  };
}

/** Cargos oferecidos no formulário público: só os que têm Cadastro Musical. */
export function cargosDoFormularioPublico(cargos: CargoPublico[]): CargoPublico[] {
  return cargos.filter((cargo) => cargoEntraNoCadastro(cargo.nome));
}

/** Instrumentos que o cargo aceita (só Órgão nos cargos travados). */
export function instrumentosDoFormularioPublico(
  instrumentos: InstrumentoPublico[],
  cargo: CargoPublico | undefined
): InstrumentoPublico[] {
  return instrumentosDoCargo(instrumentos, cargoSomenteOrgao(cargo));
}

/**
 * Confere o formulário. Devolve a mensagem do primeiro problema ou null se estiver tudo certo.
 * Fica na ordem em que os campos aparecem na tela.
 */
export function validarEnvioPublico(dados: DadosFormularioPublico, ctx: ContextoValidacao): string | null {
  // Robô: mensagem genérica, sem explicar o motivo
  if (dados.site.trim() !== "") return "Não foi possível enviar o cadastro. Atualize a página e tente de novo.";

  if (!ctx.temFoto) return "A fotografia é obrigatória. Tire a foto ou escolha uma imagem.";

  const nome = limparNome(dados.nome);
  if (nome.length < NOME_MINIMO || !nome.includes(" ")) return "Informe o nome completo (nome e sobrenome).";
  if (nome.length > NOME_MAXIMO) return `O nome pode ter no máximo ${NOME_MAXIMO} caracteres.`;

  const cpf = soDigitos(dados.cpf);
  if (cpf === "") return "Informe o CPF.";
  if (!cpfValido(cpf)) return "CPF inválido. Confira os números digitados.";

  if (dados.dataNascimento.trim() === "") return "Informe a data de nascimento.";
  if (!dataIsoValida(dados.dataNascimento)) return "Data de nascimento inválida.";
  if (dados.dataNascimento > ctx.hoje) return "A data de nascimento não pode estar no futuro.";
  if (dados.dataNascimento < "1900-01-01") return "Data de nascimento inválida.";

  // Casa de Oração: escolhida na lista OU digitada (quando não existe na lista; a secretaria confere depois)
  if (!dados.casaOracaoId) {
    const casa = limparNome(dados.casaNome);
    if (casa.length < CASA_NOME_MINIMO) return "Escolha a sua Casa de Oração na lista ou digite o nome dela.";
    if (casa.length > CASA_NOME_MAXIMO) return `O nome da Casa de Oração pode ter no máximo ${CASA_NOME_MAXIMO} caracteres.`;
  }

  const cargo = ctx.cargo;
  if (!dados.cargoId || !cargo) return "Escolha o cargo.";
  if (!cargoEntraNoCadastro(cargo.nome)) return "Este cargo não faz o cadastro por aqui. Procure a secretaria.";

  const erroCategoria = validarCategoria(cargo.nome, dados.categoria);
  if (erroCategoria) return erroCategoria;

  // No cadastro completo, todo cargo que aceita instrumento exige a escolha dele (mesma regra da tela interna).
  const permiteInstrumento = cargo.permite_instrumento;
  const erroInstrumento = validarInstrumentoDoCargo(permiteInstrumento, dados.instrumentoId, cargo.nome);
  if (erroInstrumento) return erroInstrumento;

  const erroCadastro = validarCadastro(dados.cadastro, {
    completo: true,
    exigeCartao: cargoExigeCartao(cargo),
    cidade: dados.cidade,
    bairro: dados.bairro,
    cpf,
    cpfObrigatorio: true,
    dataNascimento: dados.dataNascimento,
    instrumentoId: permiteInstrumento ? dados.instrumentoId : "",
    instrumentoObrigatorio: permiteInstrumento,
    temDocumentoFrente: ctx.temDocumentoFrente,
    temDocumentoVerso: ctx.temDocumentoVerso,
  });
  if (erroCadastro) return erroCadastro;

  if (ehMenorDeIdade(dados.dataNascimento, ctx.hoje)) {
    if (limparNome(dados.responsavelNome).length < RESPONSAVEL_NOME_MINIMO) {
      return "Para menores de 18 anos, informe o nome do responsável.";
    }
    if (!/^\d{10,11}$/.test(somenteDigitos(dados.responsavelTelefone))) {
      return "Informe o telefone do responsável com o DDD.";
    }
    if (!dados.aceiteResponsavel) return "O responsável precisa concordar com o cadastro.";
  }

  if (!dados.aceitePrivacidade) return "Para enviar, leia o aviso de privacidade e marque que concorda.";
  return null;
}

/** JSON que vai para a rota de envio (e dali para registrar_cadastro_publico). Chaves iguais às do banco. */
export interface CargaCadastroPublico {
  nome: string;
  casa_oracao_id: string; // "" quando a casa foi digitada
  casa_nome: string | null; // nome digitado (só quando não escolheu da lista)
  cargo_id: string;
  instrumento_id: string | null;
  categoria: string | null;
  cpf: string;
  data_nascimento: string;
  cidade: string;
  bairro: string;
  cadastro: Record<string, string | boolean | null>;
  responsavel_nome: string | null;
  responsavel_telefone: string | null;
  aceite_responsavel: boolean;
  aceite_privacidade: boolean;
  aviso_versao: string;
  site: string;
}

export function montarCargaPublica(dados: DadosFormularioPublico, ctx: Pick<ContextoValidacao, "cargo" | "hoje">): CargaCadastroPublico {
  const menor = ehMenorDeIdade(dados.dataNascimento, ctx.hoje);
  const permiteInstrumento = ctx.cargo?.permite_instrumento ?? false;
  // Os caminhos dos arquivos NÃO vão aqui: o servidor os conhece (pasta do envio).
  // Campos de uso interno (apresentação, observação) não existem no formulário público: sempre vazios.
  const cadastro = paraEnvioAoBanco({
    ...dados.cadastro,
    apresentado_em: "",
    apresentado_por: "",
    observacao: "",
    documento_frente_path: "",
    documento_verso_path: "",
  });
  delete cadastro.documento_frente_path;
  delete cadastro.documento_verso_path;
  return {
    nome: limparNome(dados.nome),
    casa_oracao_id: dados.casaOracaoId,
    casa_nome: dados.casaOracaoId ? null : limparNome(dados.casaNome),
    cargo_id: dados.cargoId,
    instrumento_id: permiteInstrumento && dados.instrumentoId ? dados.instrumentoId : null,
    categoria: cargoUsaCategoria(ctx.cargo?.nome) && dados.categoria ? dados.categoria : null,
    cpf: soDigitos(dados.cpf),
    data_nascimento: dados.dataNascimento,
    cidade: dados.cidade.trim(),
    bairro: dados.bairro.trim(),
    cadastro,
    responsavel_nome: menor ? limparNome(dados.responsavelNome) : null,
    responsavel_telefone: menor ? somenteDigitos(dados.responsavelTelefone) : null,
    aceite_responsavel: menor ? dados.aceiteResponsavel : false,
    aceite_privacidade: dados.aceitePrivacidade,
    aviso_versao: VERSAO_AVISO,
    site: dados.site,
  };
}

/** Mensagem exibida depois do envio (a mesma em qualquer situação: não revela se o CPF já existia). */
export const MENSAGEM_ENVIO_RECEBIDO =
  "Cadastro recebido! Ele será analisado pela secretaria. Se for aprovado, você passa a constar no sistema.";
'''},
    "src/modules/cadastroPublico/regras.test.ts": {"sha": ["9a4235a4aa0fd351d257c79de2c86140f595d3c524829e7ebd55f39b76631ab0"], "novo": r'''import { describe, expect, it } from "vitest";
import { CADASTRO_VAZIO, type CadastroMusical } from "@/modules/membros/cadastroMusical";
import { cpfValido, formatarCpfParcial } from "./cpf";
import { VERSAO_AVISO, itensDoAviso } from "./aviso";
import {
  cargosDoFormularioPublico,
  dataIsoValida,
  ehMenorDeIdade,
  formularioVazio,
  idadeEm,
  montarCargaPublica,
  validarEnvioPublico,
  type CargoPublico,
  type DadosFormularioPublico,
} from "./regras";

const HOJE = "2026-10-21";
const musico: CargoPublico = { id: "c1", nome: "Músico", permite_instrumento: true, exige_instrumento: true, exige_cartao: false };
const encarregado: CargoPublico = { id: "c2", nome: "Encarregado Local", permite_instrumento: true, exige_instrumento: false, exige_cartao: true };
const ctx = (cargo: CargoPublico | undefined = musico) => ({ cargo, temFoto: true, temDocumentoFrente: true, temDocumentoVerso: true, hoje: HOJE });

const cadastroOk: CadastroMusical = {
  ...CADASTRO_VAZIO,
  estado_civil: "Solteiro (a)", sexo: "Masculino", batizado: "nao", selado: "nao",
  ddd: "11", telefone: "987654321", tem_whatsapp: "sim",
  cep: "01001000", endereco: "Praça da Sé", numero: "1", uf: "SP",
};
function base(extra: Partial<DadosFormularioPublico> = {}): DadosFormularioPublico {
  return {
    ...formularioVazio(CADASTRO_VAZIO),
    nome: "João da Silva", casaOracaoId: "casa1", casaNome: "", cargoId: "c1", instrumentoId: "i1", categoria: "OFICIALIZADO",
    cpf: "529.982.247-25", dataNascimento: "1990-05-10", cidade: "São Paulo", bairro: "Sé",
    cadastro: cadastroOk, aceitePrivacidade: true, ...extra,
  };
}

describe("cpf", () => {
  it("aceita válido, recusa inválido e repetido", () => {
    expect(cpfValido("529.982.247-25")).toBe(true);
    expect(cpfValido("52998224725")).toBe(true);
    expect(cpfValido("529.982.247-24")).toBe(false);
    expect(cpfValido("111.111.111-11")).toBe(false);
    expect(cpfValido("123")).toBe(false);
  });
  it("formata parcial", () => {
    expect(formatarCpfParcial("5299822")).toBe("529.982.2");
    expect(formatarCpfParcial("52998224725999")).toBe("529.982.247-25");
  });
});

describe("datas e idade", () => {
  it("valida datas existentes", () => {
    expect(dataIsoValida("2024-02-29")).toBe(true);
    expect(dataIsoValida("2026-02-29")).toBe(false);
    expect(dataIsoValida("10/05/1990")).toBe(false);
  });
  it("calcula a idade no aniversário", () => {
    expect(idadeEm("2008-10-21", HOJE)).toBe(18);
    expect(idadeEm("2008-10-22", HOJE)).toBe(17);
    expect(ehMenorDeIdade("2008-10-22", HOJE)).toBe(true);
    expect(ehMenorDeIdade("2008-10-21", HOJE)).toBe(false);
    expect(ehMenorDeIdade("lixo", HOJE)).toBe(false);
  });
});

describe("validarEnvioPublico", () => {
  it("aceita um cadastro completo", () => expect(validarEnvioPublico(base(), ctx())).toBeNull());
  it("barra o robô (campo-armadilha) sem explicar", () =>
    expect(validarEnvioPublico(base({ site: "x" }), ctx())).toMatch(/Não foi possível/));
  it("exige foto, documento, aceite", () => {
    expect(validarEnvioPublico(base(), { ...ctx(), temFoto: false })).toMatch(/fotografia/);
    expect(validarEnvioPublico(base(), { ...ctx(), temDocumentoVerso: false })).toMatch(/verso/);
    expect(validarEnvioPublico(base({ aceitePrivacidade: false }), ctx())).toMatch(/privacidade/);
  });
  it("confere nome, CPF, nascimento, casa, cargo", () => {
    expect(validarEnvioPublico(base({ nome: "João" }), ctx())).toMatch(/completo/);
    expect(validarEnvioPublico(base({ cpf: "" }), ctx())).toMatch(/Informe o CPF/);
    expect(validarEnvioPublico(base({ cpf: "111.111.111-11" }), ctx())).toMatch(/inválido/);
    expect(validarEnvioPublico(base({ dataNascimento: "2030-01-01" }), ctx())).toMatch(/futuro/);
    expect(validarEnvioPublico(base({ casaOracaoId: "" }), ctx())).toMatch(/Casa de Oração/);
    // Casa digitada: aceita quando tem nome razoável; recusa vazio/curto/longo
    expect(validarEnvioPublico(base({ casaOracaoId: "", casaNome: "Casa Nova" }), ctx())).toBeNull();
    expect(validarEnvioPublico(base({ casaOracaoId: "", casaNome: "  " }), ctx())).toMatch(/na lista ou digite/);
    expect(validarEnvioPublico(base({ casaOracaoId: "", casaNome: "ab" }), ctx())).toMatch(/na lista ou digite/);
    expect(validarEnvioPublico(base({ casaOracaoId: "", casaNome: "x".repeat(121) }), ctx())).toMatch(/no máximo 120/);
    expect(validarEnvioPublico(base({ cargoId: "" }), ctx(undefined))).toMatch(/cargo/);
  });
  it("recusa cargo sem cadastro musical", () =>
    expect(validarEnvioPublico(base(), ctx({ ...musico, nome: "Ancião" }))).toMatch(/secretaria/));
  it("exige categoria e instrumento do músico", () => {
    expect(validarEnvioPublico(base({ categoria: "" }), ctx())).toMatch(/categoria/);
    expect(validarEnvioPublico(base({ instrumentoId: "" }), ctx())).toMatch(/instrumento/i);
  });
  it("exige cartão no cargo que pede", () => {
    const d = base({ cargoId: "c2", categoria: "" });
    expect(validarEnvioPublico(d, ctx(encarregado))).toMatch(/cartão/);
  });
  it("menor: pede responsável, telefone e aceite", () => {
    const m = { dataNascimento: "2012-01-01" };
    expect(validarEnvioPublico(base(m), ctx())).toMatch(/nome do responsável/);
    expect(validarEnvioPublico(base({ ...m, responsavelNome: "Maria Silva" }), ctx())).toMatch(/telefone do responsável/);
    expect(validarEnvioPublico(base({ ...m, responsavelNome: "Maria Silva", responsavelTelefone: "11987654321" }), ctx())).toMatch(/concordar/);
    expect(validarEnvioPublico(base({ ...m, responsavelNome: "Maria Silva", responsavelTelefone: "(11) 98765-4321", aceiteResponsavel: true }), ctx())).toBeNull();
  });
  it("maior ignora responsável", () => expect(validarEnvioPublico(base(), ctx())).toBeNull());
});

describe("montarCargaPublica", () => {
  it("casa da lista envia o id; casa digitada envia só o nome (sem espaços repetidos)", () => {
    const da_lista = montarCargaPublica(base({ casaOracaoId: "casa1", casaNome: "ignorado" }), ctx());
    expect(da_lista.casa_oracao_id).toBe("casa1");
    expect(da_lista.casa_nome).toBeNull();
    const digitada = montarCargaPublica(base({ casaOracaoId: "", casaNome: "  Casa   Nova " }), ctx());
    expect(digitada.casa_oracao_id).toBe("");
    expect(digitada.casa_nome).toBe("Casa Nova");
  });

  it("normaliza e não leva campos internos", () => {
    const c = montarCargaPublica(base({ nome: "  João   da Silva ", cadastro: { ...cadastroOk, observacao: "x", apresentado_por: "y" } }), ctx());
    expect(c.nome).toBe("João da Silva");
    expect(c.cpf).toBe("52998224725");
    expect(c.cadastro.observacao).toBeNull();
    expect(c.cadastro.apresentado_por).toBeNull();
    expect("documento_frente_path" in c.cadastro).toBe(false);
    expect(c.responsavel_nome).toBeNull();
    expect(c.aviso_versao).toBe(VERSAO_AVISO);
  });
  it("menor leva o responsável só com números no telefone", () => {
    const c = montarCargaPublica(base({ dataNascimento: "2012-01-01", responsavelNome: "Maria  Silva", responsavelTelefone: "(11) 98765-4321", aceiteResponsavel: true }), ctx());
    expect(c.responsavel_nome).toBe("Maria Silva");
    expect(c.responsavel_telefone).toBe("11987654321");
    expect(c.aceite_responsavel).toBe(true);
  });
});

describe("cargos e aviso", () => {
  it("lista só cargos com cadastro", () => {
    const r = cargosDoFormularioPublico([musico, encarregado, { ...musico, id: "x", nome: "Ancião" }]);
    expect(r.map((c) => c.nome)).toEqual(["Músico", "Encarregado Local"]);
  });
  it("aviso usa o contato ou o texto alternativo", () => {
    expect(JSON.stringify(itensDoAviso("lgpd@x.org"))).toContain("lgpd@x.org");
    expect(JSON.stringify(itensDoAviso(""))).toContain("secretaria da sua Casa de Oração");
  });
});
'''},
    "src/modules/cadastroPublico/components/SeletorCasaPublico.tsx": {"sha": ["0e69412136ba0ca2cfdf4e53fd96c703272ee15309c6ba6bd03042fca3ba1046", "4f0acb265060fabdd9ac05149b6063e7b5ae1e99756f93dc9df8026f5c86ea6e", "8e78805ce6a8285e2902c64585848e77331d8da05a9bc473bcb1cfac4c499ba8"], "novo": r'''"use client";

/**
 * SysMúsica — Casa de Oração no formulário público: UM campo com sugestões.
 * A pessoa começa a digitar e aparece, na hora, a lista das Casas de Oração cadastradas que combinam (por nome ou pelo
 * caminho RRM › RA › ADM › Setor). Clicar numa sugestão (ou setas + Enter) escolhe a casa.
 * Se a casa NÃO existe na lista, a pessoa simplesmente termina de digitar o nome: o formulário avisa que ela não está
 * cadastrada, mas deixa enviar. O pedido vai para "Cadastros pendentes" e a secretaria escolhe (ou cadastra) a casa correta.
 * A lista vem inteira de uma vez da função pública opcoes_cadastro_publico (só nome e caminho na organização), então a busca
 * é instantânea e não consulta o banco a cada letra.
 */
import { useId, useMemo, useState, type KeyboardEvent } from "react";
import type { CasaPublica } from "../regras";
import { classeInput } from "./Campos";

/** Quantas sugestões aparecem de uma vez (o resto some até a pessoa digitar mais). */
const MAXIMO_SUGESTOES = 30;
/** Só avisa "casa não cadastrada" depois de algumas letras (evita avisar enquanto a pessoa ainda começa a digitar). */
const LETRAS_PARA_AVISAR = 3;

function semAcento(texto: string): string {
  return texto.normalize("NFD").replace(/[\u0300-\u036f]/g, "").toLowerCase().replace(/\s+/g, " ").trim();
}

function caminho(casa: CasaPublica): string {
  return [casa.rrm, casa.ra, casa.adm, casa.setor].filter((parte): parte is string => !!parte).join(" › ");
}

interface Props {
  id: string;
  /** Id da casa escolhida na lista ("" = nenhuma). */
  valor: string;
  /** Chamado a cada mudança: `casaId` preenchido quando escolheu da lista; vazio quando é um nome digitado. */
  onChange: (casaId: string, nomeDigitado: string) => void;
  casas: CasaPublica[];
  disabled?: boolean;
}

export default function SeletorCasaPublico({ id, valor, onChange, casas, disabled }: Props) {
  const idLista = useId();
  const [texto, setTexto] = useState("");
  const [aberto, setAberto] = useState(false);
  const [destaque, setDestaque] = useState(0);

  const termo = semAcento(texto);
  // Com uma casa escolhida, ao abrir a lista mostra todas; sem escolha, filtra pelo que foi digitado
  const encontradas = useMemo(() => {
    const filtro = valor ? "" : termo;
    if (filtro === "") return casas;
    return casas.filter((c) => semAcento(`${c.nome} ${caminho(c)}`).includes(filtro));
  }, [termo, valor, casas]);
  const sugestoes = encontradas.slice(0, MAXIMO_SUGESTOES);
  const naoCadastrada = !valor && termo.length >= LETRAS_PARA_AVISAR && encontradas.length === 0;

  function escolher(casa: CasaPublica) {
    setTexto(casa.nome);
    onChange(casa.id, "");
    setAberto(false);
  }

  function aoDigitar(novo: string) {
    setTexto(novo);
    onChange("", novo); // mudou o texto: vale o que está escrito (a escolha anterior deixa de valer)
    setAberto(true);
    setDestaque(0);
  }

  // Ao sair do campo: se o que foi digitado é exatamente o nome de UMA casa da lista, escolhe essa casa
  function aoSair() {
    setAberto(false);
    if (valor || termo === "") return;
    const iguais = casas.filter((c) => semAcento(c.nome) === termo);
    if (iguais.length === 1) escolher(iguais[0]);
  }

  function aoTeclar(e: KeyboardEvent<HTMLInputElement>) {
    if (e.key === "ArrowDown") {
      e.preventDefault();
      setAberto(true);
      setDestaque((d) => Math.min(d + 1, sugestoes.length - 1));
    } else if (e.key === "ArrowUp") {
      e.preventDefault();
      setDestaque((d) => Math.max(d - 1, 0));
    } else if (e.key === "Enter" && aberto && sugestoes[destaque]) {
      e.preventDefault(); // não envia o formulário: só escolhe a casa
      escolher(sugestoes[destaque]);
    } else if (e.key === "Escape") {
      setAberto(false);
    }
  }

  return (
    <div className="relative space-y-1">
      <input
        id={id}
        type="text"
        role="combobox"
        aria-expanded={aberto}
        aria-controls={idLista}
        aria-autocomplete="list"
        autoComplete="off"
        maxLength={120}
        value={texto}
        disabled={disabled}
        placeholder="Comece a digitar o nome da Casa de Oração"
        onChange={(e) => aoDigitar(e.target.value)}
        onFocus={() => setAberto(true)}
        onBlur={aoSair}
        onKeyDown={aoTeclar}
        className={classeInput}
      />

      {aberto && sugestoes.length > 0 && (
        <ul
          id={idLista}
          role="listbox"
          className="absolute z-20 mt-1 max-h-64 w-full overflow-y-auto rounded-lg border border-slate-300 bg-white py-1 text-sm shadow-lg"
        >
          {sugestoes.map((casa, i) => (
            <li
              key={casa.id}
              role="option"
              aria-selected={casa.id === valor}
              // mouseDown (e não click): acontece ANTES de o campo perder o foco e fechar a lista
              onMouseDown={(e) => {
                e.preventDefault();
                escolher(casa);
              }}
              onMouseEnter={() => setDestaque(i)}
              className={`cursor-pointer px-3 py-2 ${i === destaque ? "bg-brand-50" : ""} ${casa.id === valor ? "font-semibold" : ""}`}
            >
              <span className="block text-slate-900">{casa.nome}</span>
              {caminho(casa) && <span className="block text-xs text-slate-500">{caminho(casa)}</span>}
            </li>
          ))}
          {encontradas.length > MAXIMO_SUGESTOES && (
            <li className="px-3 py-2 text-xs text-slate-500">
              Mostrando {MAXIMO_SUGESTOES} de {encontradas.length}. Digite mais letras para refinar.
            </li>
          )}
        </ul>
      )}

      {valor && <p className="text-xs font-medium text-emerald-700">Casa de Oração escolhida na lista.</p>}
      {naoCadastrada && (
        <p role="status" className="rounded-lg bg-amber-50 px-3 py-2 text-xs text-amber-900">
          Não encontramos esta Casa de Oração na lista. Você pode continuar: o nome digitado será enviado e a secretaria vai
          conferir e cadastrar a casa. Se foi erro de digitação, corrija o nome acima.
        </p>
      )}
    </div>
  );
}
'''},
    "src/modules/cadastroPublico/components/FormularioPublico.tsx": {"sha": ["22f481ec355e1eabcbf5590256bc6a9b66f8599d6813264534fe5f66ad0f1f4c", "4d88f8b3849322fd98a9b56b9d9266911df9cc5bd5f4916033c5778f42e46e36"], "novo": r'''"use client";

/**
 * SysMúsica — Formulário PÚBLICO do Cadastro Musical (sem login). Página: /cadastro.
 * Mesmos campos do cadastro interno, mais: aviso de privacidade (LGPD), responsável (menores de 18 anos) e
 * verificação anti-robô. O envio NÃO cria o membro: gera um pedido que a secretaria aprova em "Cadastros pendentes".
 * Depois de enviar, a tela é sempre a mesma, exista ou não um cadastro anterior com o mesmo CPF.
 */
import { useCallback, useMemo, useState, type FormEvent } from "react";
import { CheckCircle2, Send } from "lucide-react";
import CampoFoto from "@/modules/membros/components/CampoFoto";
import CampoDocumento from "@/modules/membros/components/CampoDocumento";
import SeletorInstrumento, { FamiliaAutomatica } from "@/modules/instrumentos/components/SeletorInstrumento";
import { buscarEnderecoPorCep } from "@/modules/membros/services/cep";
import {
  ESTADOS_CIVIS,
  SEXOS,
  UFS,
  CADASTRO_VAZIO,
  cargoExigeCartao,
  formatarCep,
  formatarTelefone,
  formatarWhatsapp,
  somenteDigitos,
  type CadastroMusical,
  type SimNao,
} from "@/modules/membros/cadastroMusical";
import { CATEGORIAS, cargoUsaCategoria } from "@/modules/painel/regras";
import { cpfValido, formatarCpfParcial, soDigitos } from "../cpf";
import { itensDoAviso } from "../aviso";
import { enviarCadastroPublico } from "../services/envio";
import {
  MENSAGEM_ENVIO_RECEBIDO,
  cargosDoFormularioPublico,
  ehMenorDeIdade,
  formularioVazio,
  instrumentosDoFormularioPublico,
  montarCargaPublica,
  validarEnvioPublico,
  type DadosFormularioPublico,
  type OpcoesCadastroPublico,
} from "../regras";
import { Campo, Secao, classeInput } from "./Campos";
import SeletorCasaPublico from "./SeletorCasaPublico";
import Turnstile from "./Turnstile";

/** Data de hoje (AAAA-MM-DD) no fuso do navegador. */
function hojeIso(): string {
  const d = new Date();
  const p = (n: number) => String(n).padStart(2, "0");
  return `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())}`;
}

/** Mensagem vermelha junto do campo (para a pessoa ver exatamente o que falta). */
function ErroCampo({ id, mensagem }: { id: string; mensagem?: string }) {
  if (!mensagem) return null;
  return (
    <p id={id} role="alert" className="text-xs font-medium text-red-700">
      {mensagem}
    </p>
  );
}

/** Confirmação verde de que a imagem já foi anexada. */
function Anexada({ ok, texto }: { ok: boolean; texto: string }) {
  if (!ok) return null;
  return (
    <p className="flex items-center gap-1 text-xs font-medium text-emerald-700">
      <CheckCircle2 className="h-3.5 w-3.5" aria-hidden="true" /> {texto}
    </p>
  );
}

/** Mensagem do CPF digitado: só fala quando os 11 números já foram digitados (ou ao sair do campo). */
function problemaDoCpf(texto: string, terminou: boolean): string | undefined {
  const n = soDigitos(texto);
  if (n.length === 11) return cpfValido(n) ? undefined : "CPF inválido. Confira os números digitados.";
  if (terminou) return n.length === 0 ? "Informe o CPF." : "CPF incompleto: são 11 números.";
  return undefined;
}

/** Rola a tela até o campo (pelo id do bloco) para a pessoa ver o que corrigir. */
function irParaCampo(id: string) {
  if (typeof document === "undefined") return;
  document.getElementById(id)?.scrollIntoView({ behavior: "smooth", block: "center" });
}

export default function FormularioPublico({ opcoes }: { opcoes: OpcoesCadastroPublico }) {
  const [dados, setDados] = useState<DadosFormularioPublico>(() => formularioVazio(CADASTRO_VAZIO));
  const [foto, setFoto] = useState<Blob | null>(null);
  const [frente, setFrente] = useState<Blob | null>(null);
  const [verso, setVerso] = useState<Blob | null>(null);
  const [token, setToken] = useState("");
  const [reiniciarTurnstile, setReiniciarTurnstile] = useState(0);
  const [enviando, setEnviando] = useState(false);
  const [erro, setErro] = useState<string | null>(null);
  const [enviado, setEnviado] = useState(false);
  const [avisoCep, setAvisoCep] = useState<string | null>(null);
  const [buscandoCep, setBuscandoCep] = useState(false);
  const [cpfTocado, setCpfTocado] = useState(false); // saiu do campo CPF pelo menos uma vez
  const [errosCampo, setErrosCampo] = useState<{ foto?: string; frente?: string; verso?: string }>({});

  const cargos = useMemo(() => cargosDoFormularioPublico(opcoes.cargos), [opcoes.cargos]);
  const cargo = cargos.find((c) => c.id === dados.cargoId);
  const tipoCategoria = cargoUsaCategoria(cargo?.nome);
  const instrumentos = instrumentosDoFormularioPublico(opcoes.instrumentos, cargo);
  const menor = ehMenorDeIdade(dados.dataNascimento, hojeIso());
  const itens = useMemo(() => itensDoAviso(process.env.NEXT_PUBLIC_CONTATO_PRIVACIDADE), []);

  const mudar = <K extends keyof DadosFormularioPublico>(campo: K, valor: DadosFormularioPublico[K]) =>
    setDados((d) => ({ ...d, [campo]: valor }));
  const mudarCad = <K extends keyof CadastroMusical>(campo: K, valor: CadastroMusical[K]) =>
    setDados((d) => ({ ...d, cadastro: { ...d.cadastro, [campo]: valor } }));

  const aoToken = useCallback((t: string) => setToken(t), []);

  // Ao anexar/remover uma imagem, guarda o arquivo e apaga o aviso vermelho daquele campo
  const aoFoto = useCallback((b: Blob | null) => {
    setFoto(b);
    if (b) setErrosCampo((e) => ({ ...e, foto: undefined }));
  }, []);
  const aoFrente = useCallback((b: Blob | null) => {
    setFrente(b);
    if (b) setErrosCampo((e) => ({ ...e, frente: undefined }));
  }, []);
  const aoVerso = useCallback((b: Blob | null) => {
    setVerso(b);
    if (b) setErrosCampo((e) => ({ ...e, verso: undefined }));
  }, []);
  const erroCpf = problemaDoCpf(dados.cpf, cpfTocado);

  // Preenche o endereço pelo CEP (ViaCEP); se falhar, a pessoa digita
  async function aoSairDoCep() {
    const cep = dados.cadastro.cep;
    setAvisoCep(null);
    if (!/^\d{8}$/.test(cep)) return;
    setBuscandoCep(true);
    const r = await buscarEnderecoPorCep(cep);
    setBuscandoCep(false);
    if (r.tipo === "ok") {
      setDados((d) => ({
        ...d,
        cidade: r.endereco.cidade || d.cidade,
        bairro: r.endereco.bairro || d.bairro,
        cadastro: {
          ...d.cadastro,
          endereco: r.endereco.endereco || d.cadastro.endereco,
          complemento: d.cadastro.complemento || r.endereco.complemento,
          uf: r.endereco.uf || d.cadastro.uf,
        },
      }));
    } else {
      setAvisoCep(r.tipo === "nao_encontrado" ? "CEP não encontrado. Digite o endereço." : "Não consegui consultar o CEP agora. Digite o endereço.");
    }
  }

  async function aoEnviar(e: FormEvent) {
    e.preventDefault();
    if (enviando) return;
    const hoje = hojeIso();

    // Confere primeiro o que costuma ser esquecido (imagens e CPF) e mostra o aviso junto de cada campo
    const faltas: { foto?: string; frente?: string; verso?: string } = {};
    if (!foto) faltas.foto = "Falta a sua fotografia. Tire uma foto ou escolha da galeria.";
    if (!frente) faltas.frente = "Falta a foto da frente do documento.";
    if (!verso) faltas.verso = "Falta a foto do verso do documento.";
    setErrosCampo(faltas);
    setCpfTocado(true);
    const cpfProblema = problemaDoCpf(dados.cpf, true);
    const primeiro = faltas.foto ? "campo-foto" : cpfProblema ? "cpf" : faltas.frente ? "campo-frente" : faltas.verso ? "campo-verso" : null;
    if (primeiro) {
      setErro("Corrija os campos marcados em vermelho.");
      irParaCampo(primeiro);
      return;
    }

    const problema = validarEnvioPublico(dados, {
      cargo,
      temFoto: foto !== null,
      temDocumentoFrente: frente !== null,
      temDocumentoVerso: verso !== null,
      hoje,
    });
    if (problema) return setErro(problema);
    if (token === "") return setErro("Aguarde a verificação de segurança e tente de novo.");
    if (!foto || !frente || !verso) return;

    setErro(null);
    setEnviando(true);
    try {
      await enviarCadastroPublico(montarCargaPublica(dados, { cargo, hoje }), { foto, frente, verso }, token);
      setEnviado(true);
    } catch (ex) {
      setErro(ex instanceof Error ? ex.message : "Não foi possível enviar o cadastro.");
      setToken(""); // o token vale uma só vez: pede uma nova verificação
      setReiniciarTurnstile((n) => n + 1);
    } finally {
      setEnviando(false);
    }
  }

  if (enviado) {
    return (
      <div role="status" className="rounded-2xl border border-emerald-200 bg-emerald-50 p-6 text-center">
        <CheckCircle2 className="mx-auto h-10 w-10 text-emerald-600" aria-hidden="true" />
        <p className="mt-3 text-base font-medium text-emerald-900">{MENSAGEM_ENVIO_RECEBIDO}</p>
      </div>
    );
  }

  const cad = dados.cadastro;
  const exigeCartao = cargoExigeCartao(cargo);
  const bloqueado = enviando;

  return (
    <form onSubmit={(ev) => void aoEnviar(ev)} className="space-y-8" noValidate>
      {/* Campo-armadilha: invisível para pessoas; robôs costumam preencher. Não remova. */}
      <div aria-hidden="true" className="absolute -left-[9999px] h-0 w-0 overflow-hidden">
        <label htmlFor="site">Site</label>
        <input id="site" type="text" tabIndex={-1} autoComplete="off" value={dados.site} onChange={(e) => mudar("site", e.target.value)} />
      </div>

      <Secao titulo="Fotografia">
        <div id="campo-foto" className="space-y-2">
          <CampoFoto nome={dados.nome || "você"} obrigatoria onChange={aoFoto} disabled={bloqueado} />
          <Anexada ok={foto !== null} texto="Fotografia anexada" />
          <ErroCampo id="erro-foto" mensagem={errosCampo.foto} />
        </div>
      </Secao>

      <Secao titulo="Identificação">
        <Campo id="nome" rotulo="Nome completo" obrigatorio>
          <input id="nome" type="text" autoComplete="name" maxLength={120} value={dados.nome} onChange={(e) => mudar("nome", e.target.value)} disabled={bloqueado} className={classeInput} placeholder="Ex: João da Silva" />
        </Campo>
        <div className="grid gap-3 sm:grid-cols-2">
          <Campo id="cpf" rotulo="CPF" obrigatorio>
            <input id="cpf" type="text" inputMode="numeric" autoComplete="off" value={dados.cpf} onChange={(e) => mudar("cpf", formatarCpfParcial(e.target.value))} onBlur={() => setCpfTocado(true)} aria-invalid={erroCpf ? true : undefined} aria-describedby={erroCpf ? "erro-cpf" : undefined} disabled={bloqueado} className={`${classeInput}${erroCpf ? " border-red-500" : ""}`} placeholder="000.000.000-00" maxLength={14} />
            <ErroCampo id="erro-cpf" mensagem={erroCpf} />
          </Campo>
          <Campo id="nascimento" rotulo="Data de nascimento" obrigatorio>
            <input id="nascimento" type="date" autoComplete="bday" max={hojeIso()} value={dados.dataNascimento} onChange={(e) => mudar("dataNascimento", e.target.value)} disabled={bloqueado} className={classeInput} />
          </Campo>
        </div>
        <div className="grid gap-3 sm:grid-cols-2">
          <Campo id="estado_civil" rotulo="Estado civil" obrigatorio>
            <select id="estado_civil" value={cad.estado_civil} onChange={(e) => mudarCad("estado_civil", e.target.value)} disabled={bloqueado} className={classeInput}>
              <option value="">Selecione</option>
              {ESTADOS_CIVIS.map((v) => <option key={v} value={v}>{v}</option>)}
            </select>
          </Campo>
          <Campo id="sexo" rotulo="Sexo" obrigatorio>
            <select id="sexo" value={cad.sexo} onChange={(e) => mudarCad("sexo", e.target.value)} disabled={bloqueado} className={classeInput}>
              <option value="">Selecione</option>
              {SEXOS.map((v) => <option key={v} value={v}>{v}</option>)}
            </select>
          </Campo>
        </div>
      </Secao>

      {menor && (
        <Secao titulo="Responsável (menor de 18 anos)">
          <Campo id="resp-nome" rotulo="Nome do responsável" obrigatorio>
            <input id="resp-nome" type="text" maxLength={120} value={dados.responsavelNome} onChange={(e) => mudar("responsavelNome", e.target.value)} disabled={bloqueado} className={classeInput} />
          </Campo>
          <Campo id="resp-tel" rotulo="Telefone do responsável (com DDD)" obrigatorio>
            <input id="resp-tel" type="tel" inputMode="numeric" value={dados.responsavelTelefone} onChange={(e) => mudar("responsavelTelefone", formatarWhatsapp(e.target.value))} disabled={bloqueado} className={classeInput} />
          </Campo>
          <label className="flex items-start gap-2 text-sm text-slate-700">
            <input type="checkbox" checked={dados.aceiteResponsavel} onChange={(e) => mudar("aceiteResponsavel", e.target.checked)} disabled={bloqueado} className="mt-0.5" />
            <span>Eu sou o responsável e concordo com este cadastro e com o aviso de privacidade.</span>
          </label>
        </Secao>
      )}

      <Secao titulo="Casa de Oração e cargo">
        <Campo id="casa" rotulo="Casa de Oração" obrigatorio dica="Digite e escolha na lista. Se a sua casa não existir na lista, digite o nome dela mesmo assim.">
          <SeletorCasaPublico id="casa" valor={dados.casaOracaoId} onChange={(casaId, nome) => setDados((d) => ({ ...d, casaOracaoId: casaId, casaNome: nome }))} casas={opcoes.casas} disabled={bloqueado} />
        </Campo>
        <Campo id="cargo" rotulo="Cargo" obrigatorio>
          <select
            id="cargo"
            value={dados.cargoId}
            onChange={(e) => setDados((d) => ({ ...d, cargoId: e.target.value, categoria: "", instrumentoId: "" }))}
            disabled={bloqueado}
            className={classeInput}
          >
            <option value="">Selecione o cargo</option>
            {cargos.map((c) => <option key={c.id} value={c.id}>{c.nome}</option>)}
          </select>
        </Campo>
        {tipoCategoria && (
          <Campo id="categoria" rotulo="Categoria" obrigatorio>
            <select id="categoria" value={dados.categoria} onChange={(e) => mudar("categoria", e.target.value)} disabled={bloqueado} className={classeInput}>
              <option value="">Selecione a categoria</option>
              {CATEGORIAS.map((c) => <option key={c.valor} value={c.valor}>{c[tipoCategoria === "organista" ? "organista" : "musico"]}</option>)}
            </select>
          </Campo>
        )}
        {cargo?.permite_instrumento && (
          <>
            <Campo id="instrumento" rotulo="Instrumento" obrigatorio>
              <SeletorInstrumento id="instrumento" valor={dados.instrumentoId} onChange={(v) => mudar("instrumentoId", v)} instrumentos={instrumentos} familias={opcoes.familias} obrigatorio disabled={bloqueado} className={classeInput} />
            </Campo>
            <FamiliaAutomatica instrumentoId={dados.instrumentoId} instrumentos={instrumentos} familias={opcoes.familias} />
          </>
        )}
      </Secao>

      <Secao titulo="Dados religiosos (consentimento específico)">
        <div className="grid gap-3 sm:grid-cols-2">
          <Campo id="batizado" rotulo="É batizado(a)?" obrigatorio>
            <select id="batizado" value={cad.batizado} onChange={(e) => mudarCad("batizado", e.target.value as SimNao)} disabled={bloqueado} className={classeInput}>
              <option value="">Selecione</option>
              <option value="sim">Sim</option>
              <option value="nao">Não</option>
            </select>
          </Campo>
          {cad.batizado === "sim" && (
            <Campo id="data_batismo" rotulo="Data do batismo" obrigatorio>
              <input id="data_batismo" type="date" value={cad.data_batismo} onChange={(e) => mudarCad("data_batismo", e.target.value)} disabled={bloqueado} className={classeInput} />
            </Campo>
          )}
        </div>
        <Campo id="selado" rotulo="É selado(a)?" obrigatorio>
          <select id="selado" value={cad.selado} onChange={(e) => mudarCad("selado", e.target.value as SimNao)} disabled={bloqueado} className={classeInput}>
            <option value="">Selecione</option>
            <option value="sim">Sim</option>
            <option value="nao">Não</option>
          </select>
        </Campo>
      </Secao>

      <Secao titulo="Contato">
        <div className="grid grid-cols-3 gap-3">
          <Campo id="ddd" rotulo="DDD" obrigatorio>
            <input id="ddd" type="tel" inputMode="numeric" maxLength={2} value={cad.ddd} onChange={(e) => mudarCad("ddd", somenteDigitos(e.target.value, 2))} disabled={bloqueado} className={classeInput} />
          </Campo>
          <div className="col-span-2">
            <Campo id="telefone" rotulo="Telefone" obrigatorio>
              <input id="telefone" type="tel" inputMode="numeric" value={cad.telefone} onChange={(e) => mudarCad("telefone", formatarTelefone(e.target.value))} disabled={bloqueado} className={classeInput} />
            </Campo>
          </div>
        </div>
        <Campo id="tem_whatsapp" rotulo="O telefone tem WhatsApp?" obrigatorio>
          <select id="tem_whatsapp" value={cad.tem_whatsapp} onChange={(e) => mudarCad("tem_whatsapp", e.target.value as SimNao)} disabled={bloqueado} className={classeInput}>
            <option value="">Selecione</option>
            <option value="sim">Sim</option>
            <option value="nao">Não</option>
          </select>
        </Campo>
        {cad.tem_whatsapp === "sim" && (
          <Campo id="whatsapp" rotulo="WhatsApp (com DDD)" dica="Deixe vazio se for o mesmo número do telefone.">
            <input id="whatsapp" type="tel" inputMode="numeric" value={cad.whatsapp} onChange={(e) => mudarCad("whatsapp", formatarWhatsapp(e.target.value))} disabled={bloqueado} className={classeInput} />
          </Campo>
        )}
        <Campo id="email" rotulo="E-mail">
          <input id="email" type="email" autoComplete="email" maxLength={120} value={cad.email} onChange={(e) => mudarCad("email", e.target.value)} disabled={bloqueado} className={classeInput} />
        </Campo>
      </Secao>

      <Secao titulo="Endereço">
        <Campo id="cep" rotulo="CEP" obrigatorio dica={buscandoCep ? "Consultando o CEP..." : (avisoCep ?? undefined)}>
          <input id="cep" type="text" inputMode="numeric" autoComplete="postal-code" value={formatarCep(cad.cep)} onChange={(e) => mudarCad("cep", somenteDigitos(e.target.value, 8))} onBlur={() => void aoSairDoCep()} disabled={bloqueado} className={classeInput} />
        </Campo>
        <Campo id="endereco" rotulo="Endereço" obrigatorio>
          <input id="endereco" type="text" autoComplete="street-address" maxLength={150} value={cad.endereco} onChange={(e) => mudarCad("endereco", e.target.value)} disabled={bloqueado} className={classeInput} />
        </Campo>
        <div className="grid grid-cols-2 gap-3">
          <Campo id="numero" rotulo="Número" obrigatorio>
            <input id="numero" type="text" maxLength={20} value={cad.numero} onChange={(e) => mudarCad("numero", e.target.value)} disabled={bloqueado} className={classeInput} />
          </Campo>
          <Campo id="complemento" rotulo="Complemento">
            <input id="complemento" type="text" maxLength={80} value={cad.complemento} onChange={(e) => mudarCad("complemento", e.target.value)} disabled={bloqueado} className={classeInput} />
          </Campo>
        </div>
        <div className="grid gap-3 sm:grid-cols-3">
          <Campo id="bairro" rotulo="Bairro" obrigatorio>
            <input id="bairro" type="text" maxLength={80} value={dados.bairro} onChange={(e) => mudar("bairro", e.target.value)} disabled={bloqueado} className={classeInput} />
          </Campo>
          <Campo id="cidade" rotulo="Cidade" obrigatorio>
            <input id="cidade" type="text" maxLength={80} value={dados.cidade} onChange={(e) => mudar("cidade", e.target.value)} disabled={bloqueado} className={classeInput} />
          </Campo>
          <Campo id="uf" rotulo="UF" obrigatorio>
            <select id="uf" value={cad.uf} onChange={(e) => mudarCad("uf", e.target.value)} disabled={bloqueado} className={classeInput}>
              <option value="">UF</option>
              {UFS.map((u) => <option key={u} value={u}>{u}</option>)}
            </select>
          </Campo>
        </div>
      </Secao>

      {exigeCartao && (
        <Secao titulo="Cartão de identificação">
          <Campo id="cartao_numero" rotulo="Número do cartão" obrigatorio>
            <input id="cartao_numero" type="text" autoComplete="off" maxLength={40} value={cad.cartao_numero} onChange={(e) => mudarCad("cartao_numero", e.target.value)} disabled={bloqueado} className={classeInput} />
          </Campo>
          <div className="grid grid-cols-2 gap-3">
            <Campo id="cartao_emissao" rotulo="Emissão">
              <input id="cartao_emissao" type="date" value={cad.cartao_emissao} onChange={(e) => mudarCad("cartao_emissao", e.target.value)} disabled={bloqueado} className={classeInput} />
            </Campo>
            <Campo id="cartao_validade" rotulo="Validade" obrigatorio>
              <input id="cartao_validade" type="date" value={cad.cartao_validade} onChange={(e) => mudarCad("cartao_validade", e.target.value)} disabled={bloqueado} className={classeInput} />
            </Campo>
          </div>
        </Secao>
      )}

      <Secao titulo="Documento de identificação">
        <p className="text-xs text-slate-500">Anexe uma foto da frente e uma do verso (RG ou CNH). Os arquivos ficam em armazenamento privado.</p>
        <div id="campo-frente" className="space-y-2">
          <CampoDocumento id="pub-doc-frente" rotulo="Frente do documento" obrigatorio onChange={aoFrente} disabled={bloqueado} />
          <Anexada ok={frente !== null} texto="Frente anexada" />
          <ErroCampo id="erro-frente" mensagem={errosCampo.frente} />
        </div>
        <div id="campo-verso" className="space-y-2">
          <CampoDocumento id="pub-doc-verso" rotulo="Verso do documento" obrigatorio onChange={aoVerso} disabled={bloqueado} />
          <Anexada ok={verso !== null} texto="Verso anexado" />
          <ErroCampo id="erro-verso" mensagem={errosCampo.verso} />
        </div>
      </Secao>

      <Secao titulo="Aviso de privacidade (LGPD)">
        <div className="max-h-64 space-y-3 overflow-y-auto rounded-lg border border-slate-200 bg-slate-50 p-3 text-sm text-slate-700">
          {itens.map((item) => (
            <div key={item.titulo}>
              <p className="font-semibold">{item.titulo}</p>
              <p>{item.texto}</p>
            </div>
          ))}
        </div>
        <label className="flex items-start gap-2 text-sm text-slate-800">
          <input type="checkbox" checked={dados.aceitePrivacidade} onChange={(e) => mudar("aceitePrivacidade", e.target.checked)} disabled={bloqueado} className="mt-0.5" />
          <span>Li e concordo com o aviso de privacidade, inclusive com o uso dos dados sobre batismo e selamento.</span>
        </label>
      </Secao>

      <Turnstile onToken={aoToken} reiniciar={reiniciarTurnstile} />

      {erro && (
        <p role="alert" className="rounded-lg bg-red-50 px-3 py-2 text-sm text-red-700">
          {erro}
        </p>
      )}

      <button
        type="submit"
        disabled={enviando}
        className="inline-flex w-full items-center justify-center gap-2 rounded-lg bg-brand-600 px-4 py-3 text-sm font-semibold text-white shadow-sm transition hover:bg-brand-700 disabled:cursor-not-allowed disabled:opacity-60"
      >
        <Send className="h-4 w-4" aria-hidden="true" />
        {enviando ? "Enviando..." : "Enviar cadastro"}
      </button>
    </form>
  );
}
'''},
    "src/modules/cadastrosPendentes/tipos.ts": {"sha": ["04ffc87cd82eeb3d91a63e35638005c6b3fccd848961cffa5aac9dc713af821f"], "novo": r'''/** SysMúsica — Tipos da tela "Cadastros pendentes" (formato das funções do banco da migração 0042). */

export type StatusCadastro = "PENDENTE" | "APROVADO" | "REJEITADO" | "EXPIRADO" | "SUBSTITUIDO";
export type TipoCadastro = "NOVO" | "ATUALIZACAO";
/** Filtro da lista: um status ou todos. */
export type FiltroStatus = "PENDENTE" | "APROVADO" | "REJEITADO" | "EXPIRADO" | "TODOS";

export interface ResumoCadastro {
  id: string;
  tipo: TipoCadastro;
  status: StatusCadastro;
  nome: string | null;
  cpf_mascarado: string | null;
  cargo_nome: string | null;
  casa_nome: string | null;
  /** A pessoa digitou uma Casa de Oração que não estava na lista (migração 0043). */
  casa_nao_cadastrada?: boolean;
  menor: boolean;
  cpf_conflito: boolean;
  outros_pendentes: number;
  criado_em: string;
  expira_em: string;
  decidido_em: string | null;
  motivo_rejeicao: string | null;
}

/** Campos do cadastro musical como o banco guarda no pedido (valores já limpos). */
export interface DadosCadastro {
  estado_civil?: string | null;
  sexo?: string | null;
  batizado?: boolean | null;
  data_batismo?: string | null;
  selado?: boolean | null;
  ddd?: string | null;
  telefone?: string | null;
  tem_whatsapp?: boolean | null;
  whatsapp?: string | null;
  email?: string | null;
  cep?: string | null;
  endereco?: string | null;
  numero?: string | null;
  complemento?: string | null;
  uf?: string | null;
  cartao_numero?: string | null;
  cartao_emissao?: string | null;
  cartao_validade?: string | null;
}

/** Como o membro está HOJE (só nas atualizações), para comparar com o pedido. */
export interface MembroAtual {
  nome: string | null;
  casa_oracao_id: string | null;
  casa_nome: string | null;
  cargo_id: string | null;
  cargo_nome: string | null;
  instrumento_id: string | null;
  instrumento_nome: string | null;
  categoria: string | null;
  cidade: string | null;
  bairro: string | null;
  data_nascimento: string | null;
  cadastro: DadosCadastro | null;
}

export interface DetalheCadastro {
  id: string;
  tipo: TipoCadastro;
  status: StatusCadastro;
  membro_id: string | null;
  nome: string | null;
  data_nascimento: string | null;
  cidade: string | null;
  bairro: string | null;
  cpf: string | null;
  cpf_completo_visivel: boolean;
  casa_oracao_id: string | null; // nulo quando a casa foi digitada (veja casa_nome_informada)
  casa_nome: string | null;
  casa_nome_informada?: string | null;
  cargo_id: string | null;
  cargo_nome: string | null;
  instrumento_id: string | null;
  instrumento_nome: string | null;
  categoria: string | null;
  dados: DadosCadastro;
  menor: boolean;
  responsavel_nome: string | null;
  responsavel_telefone: string | null;
  aviso_versao: string;
  aceite_em: string;
  cpf_conflito: boolean;
  criado_em: string;
  expira_em: string;
  decidido_em: string | null;
  motivo_rejeicao: string | null;
  arquivos_disponiveis: boolean;
  outros_pendentes: number;
  atual: MembroAtual | null;
}

/** Endereços temporários das imagens (documento só para quem tem a permissão CPF). */
export interface ArquivosDoCadastro {
  disponivel: boolean;
  foto?: string | null;
  frente?: string | null;
  verso?: string | null;
  documentos_liberados?: boolean;
}
'''},
    "src/modules/cadastrosPendentes/components/TabelaCadastros.tsx": {"sha": ["f6b27122c27fdd22356420d8c4c64a2b8f782c4897d570bea31234c5fc36e137"], "novo": r'''"use client";

/**
 * SysMúsica — Lista de cadastros enviados pelo link público. Clicar em "Abrir" mostra o detalhe.
 * O CPF aparece escondido (***.123.***-45); o completo só no detalhe, para quem tem a permissão CPF.
 */
import { Eye } from "lucide-react";
import Badge from "@/components/ui/Badge";
import BotaoIcone from "@/components/ui/BotaoIcone";
import { ROTULO_STATUS, ROTULO_TIPO, VARIANTE_STATUS, diasParaVencer, formatarDataHora } from "../regras";
import type { ResumoCadastro } from "../tipos";

const classeCabecalho = "px-4 py-3 text-left text-xs font-semibold uppercase tracking-wide text-slate-500";

export default function TabelaCadastros({ itens, onAbrir }: { itens: ResumoCadastro[]; onAbrir: (item: ResumoCadastro) => void }) {
  return (
    <div className="overflow-hidden rounded-2xl border border-slate-200 bg-white shadow-sm">
      <div className="overflow-x-auto">
        <table className="min-w-full divide-y divide-slate-200 text-sm">
          <thead className="bg-slate-50">
            <tr>
              <th scope="col" className={classeCabecalho}>Nome</th>
              <th scope="col" className={classeCabecalho}>Cargo</th>
              <th scope="col" className={classeCabecalho}>Casa de Oração</th>
              <th scope="col" className={classeCabecalho}>Tipo</th>
              <th scope="col" className={classeCabecalho}>Enviado em</th>
              <th scope="col" className={classeCabecalho}>Situação</th>
              <th scope="col" className={classeCabecalho + " text-right"}>Ações</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-slate-100">
            {itens.map((item) => (
              <tr key={item.id} className="transition hover:bg-slate-50">
                <td className="px-4 py-3">
                  <div className="font-medium text-slate-900">{item.nome ?? "(dados removidos)"}</div>
                  <div className="text-xs tabular-nums text-slate-500">{item.cpf_mascarado ?? ""}</div>
                  <div className="mt-1 flex flex-wrap gap-1">
                    {item.menor && <Badge variante="marca">Menor de idade</Badge>}
                    {item.cpf_conflito && <Badge variante="perigo">CPF com outra data de nascimento</Badge>}
                    {item.outros_pendentes > 0 && <Badge variante="alerta">{item.outros_pendentes} outro(s) pedido(s) com este CPF</Badge>}
                  </div>
                </td>
                <td className="px-4 py-3 text-slate-800">{item.cargo_nome ?? "—"}</td>
                <td className="px-4 py-3 text-slate-800">
                  {item.casa_nome ?? "—"}
                  {item.casa_nao_cadastrada && (
                    <div className="mt-1">
                      <Badge variante="alerta">Casa não cadastrada</Badge>
                    </div>
                  )}
                </td>
                <td className="px-4 py-3 text-slate-800">{ROTULO_TIPO[item.tipo]}</td>
                <td className="whitespace-nowrap px-4 py-3 tabular-nums text-slate-700">
                  {formatarDataHora(item.criado_em)}
                  {item.status === "PENDENTE" && (
                    <div className="text-xs text-slate-500">vence em {diasParaVencer(item.expira_em)} dia(s)</div>
                  )}
                </td>
                <td className="px-4 py-3">
                  <Badge variante={VARIANTE_STATUS[item.status]}>{ROTULO_STATUS[item.status]}</Badge>
                </td>
                <td className="px-4 py-3">
                  <div className="flex justify-end">
                    <BotaoIcone icone={Eye} rotulo={`Abrir o cadastro de ${item.nome ?? "pessoa sem nome"}`} onClick={() => onAbrir(item)} />
                  </div>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}
'''},
    "src/modules/cadastrosPendentes/components/DetalheCadastro.tsx": {"sha": ["ae33e5f27020da6e854e9c1564850bd2736f5c27ab9039c35d8de541479e881b"], "novo": r'''"use client";

/**
 * SysMúsica — Detalhe de um cadastro enviado pelo link público (dentro do painel lateral).
 * Mostra a foto e o documento (endereços temporários), os dados e, nas ATUALIZAÇÕES, a comparação campo a campo
 * com o cadastro atual do membro. Aprovar e Recusar só aparecem para quem tem cadastros.aprovar.
 */
import { useEffect, useState } from "react";
import { AlertTriangle, Check, ExternalLink, X } from "lucide-react";
import Badge from "@/components/ui/Badge";
import Button from "@/components/ui/Button";
import Skeleton from "@/components/ui/Skeleton";
import { listarOrganizacaoParaSelecao } from "@/modules/organizacao/services/organizacao";
import { arquivosDoCadastro } from "../services/cadastrosPendentes";
import {
  ROTULO_STATUS,
  ROTULO_TIPO,
  VARIANTE_STATUS,
  compararComAtual,
  formatarData,
  formatarDataHora,
  quantosMudaram,
} from "../regras";
import type { ArquivosDoCadastro, DetalheCadastro } from "../tipos";

/** Imagem sem usar <img> (mesmo padrão dos campos de foto) e com link para abrir em tamanho real. */
function Imagem({ url, rotulo, alto }: { url: string | null | undefined; rotulo: string; alto: string }) {
  if (!url) {
    return (
      <div className={`flex ${alto} w-full items-center justify-center rounded-lg bg-slate-100 px-2 text-center text-xs text-slate-500`}>
        {rotulo}: indisponível
      </div>
    );
  }
  return (
    <a href={url} target="_blank" rel="noopener noreferrer" className="block" title={`Abrir ${rotulo} em tamanho real`}>
      <div role="img" aria-label={rotulo} style={{ backgroundImage: `url(${url})` }} className={`${alto} w-full rounded-lg bg-slate-100 bg-contain bg-center bg-no-repeat`} />
      <span className="mt-1 inline-flex items-center gap-1 text-xs text-brand-700">
        {rotulo} <ExternalLink className="h-3 w-3" aria-hidden="true" />
      </span>
    </a>
  );
}

interface Props {
  detalhe: DetalheCadastro;
  podeAprovar: boolean;
  ocupado: boolean;
  /** `casaId`: preenchido quando o pedido veio com uma Casa de Oração digitada e quem aprova escolheu a correta. */
  onAprovar: (casaId?: string) => void;
  onRecusar: () => void;
}

export default function DetalheDoCadastro({ detalhe, podeAprovar, ocupado, onAprovar, onRecusar }: Props) {
  const [arquivos, setArquivos] = useState<ArquivosDoCadastro | null>(null);
  const [erroArquivos, setErroArquivos] = useState<string | null>(null);

  // Pedido com Casa de Oração DIGITADA (não estava na lista): quem aprova escolhe a casa cadastrada correta
  const semCasa = detalhe.casa_oracao_id === null;
  const [casas, setCasas] = useState<{ id: string; nome: string }[] | null>(null);
  const [erroCasas, setErroCasas] = useState<string | null>(null);
  const [casaId, setCasaId] = useState("");
  useEffect(() => {
    let ativo = true;
    if (!semCasa || detalhe.status !== "PENDENTE") return;
    // Só as casas que quem aprova enxerga (o banco aplica a abrangência)
    listarOrganizacaoParaSelecao()
      .then((nos) => {
        if (!ativo) return;
        const lista = nos
          .filter((no) => String(no.nivel) === "CASA_ORACAO")
          .map((no) => ({ id: no.id, nome: no.nome }))
          .sort((a, b) => a.nome.localeCompare(b.nome, "pt-BR"));
        setCasas(lista);
      })
      .catch(() => ativo && setErroCasas("Não foi possível carregar a lista de Casas de Oração."));
    return () => {
      ativo = false;
    };
  }, [semCasa, detalhe.status]);

  // Busca os endereços temporários das imagens quando o detalhe abre
  useEffect(() => {
    let ativo = true;
    if (!detalhe.arquivos_disponiveis) return;
    arquivosDoCadastro(detalhe.id)
      .then((r) => ativo && setArquivos(r))
      .catch((e: unknown) => ativo && setErroArquivos(e instanceof Error ? e.message : "Não foi possível carregar as imagens."));
    return () => {
      ativo = false;
    };
  }, [detalhe.id, detalhe.arquivos_disponiveis]);

  const linhas = compararComAtual(detalhe);
  const atualizacao = detalhe.tipo === "ATUALIZACAO";
  const mudancas = quantosMudaram(linhas);
  const pendente = detalhe.status === "PENDENTE";

  return (
    <div className="space-y-6">
      <div className="flex flex-wrap items-center gap-2">
        <Badge variante={VARIANTE_STATUS[detalhe.status]}>{ROTULO_STATUS[detalhe.status]}</Badge>
        <Badge variante="neutro">{ROTULO_TIPO[detalhe.tipo]}</Badge>
        {detalhe.menor && <Badge variante="marca">Menor de idade</Badge>}
      </div>

      {detalhe.cpf_conflito && (
        <p role="alert" className="flex gap-2 rounded-lg bg-red-50 px-3 py-2 text-sm text-red-800">
          <AlertTriangle className="mt-0.5 h-4 w-4 shrink-0" aria-hidden="true" />
          Já existe um membro com este CPF, mas com outra data de nascimento. Confira com a pessoa antes de decidir: este
          pedido não pode ser aprovado como novo cadastro enquanto o CPF existir.
        </p>
      )}
      {semCasa && detalhe.status === "PENDENTE" && (
        <section className="space-y-2 rounded-lg border border-amber-300 bg-amber-50 px-3 py-3 text-sm text-amber-950">
          <p role="alert">
            <strong>Casa de Oração não cadastrada.</strong> A pessoa digitou: “{detalhe.casa_nome_informada ?? detalhe.casa_nome ?? "—"}”.
            Escolha abaixo a casa correta. Se ela ainda não existe, cadastre-a antes em <strong>Organização</strong> e volte aqui.
          </p>
          {erroCasas ? (
            <p className="text-red-700">{erroCasas}</p>
          ) : !casas ? (
            <Skeleton className="h-9" />
          ) : (
            <select
              aria-label="Casa de Oração correta"
              value={casaId}
              onChange={(e) => setCasaId(e.target.value)}
              disabled={ocupado}
              className="w-full rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 [color-scheme:light]"
            >
              <option value="">Selecione a Casa de Oração</option>
              {casas.map((c) => (
                <option key={c.id} value={c.id}>{c.nome}</option>
              ))}
            </select>
          )}
        </section>
      )}
      {detalhe.outros_pendentes > 0 && (
        <p className="rounded-lg bg-amber-50 px-3 py-2 text-sm text-amber-900">
          Há {detalhe.outros_pendentes} outro(s) pedido(s) pendente(s) com este CPF. Aprove só um e recuse os demais.
        </p>
      )}
      {detalhe.status === "REJEITADO" && detalhe.motivo_rejeicao && (
        <p className="rounded-lg bg-slate-100 px-3 py-2 text-sm text-slate-800">
          <strong>Motivo da recusa:</strong> {detalhe.motivo_rejeicao}
        </p>
      )}
      {atualizacao && (
        <p className="rounded-lg bg-brand-50 px-3 py-2 text-sm text-slate-800">
          Esta pessoa já tem cadastro. Ao aprovar, os dados abaixo <strong>substituem</strong> os atuais
          {mudancas > 0 ? ` (${mudancas} campo(s) diferente(s), em destaque)` : " (nenhum campo mudou)"}.
        </p>
      )}

      {/* Fotografia e documento */}
      {detalhe.arquivos_disponiveis ? (
        erroArquivos ? (
          <p role="alert" className="rounded-lg bg-red-50 px-3 py-2 text-sm text-red-700">{erroArquivos}</p>
        ) : !arquivos ? (
          <Skeleton className="h-40" />
        ) : !arquivos.disponivel ? (
          <p className="text-sm text-slate-500">As imagens deste cadastro não estão mais disponíveis.</p>
        ) : (
          <div className="grid grid-cols-3 gap-3">
            <Imagem url={arquivos.foto} rotulo="Fotografia" alto="h-40" />
            <Imagem url={arquivos.frente} rotulo="Documento (frente)" alto="h-40" />
            <Imagem url={arquivos.verso} rotulo="Documento (verso)" alto="h-40" />
            {!arquivos.documentos_liberados && (
              <p className="col-span-3 text-xs text-slate-500">O documento só aparece para quem tem a permissão CPF.</p>
            )}
          </div>
        )
      ) : (
        <p className="text-sm text-slate-500">As imagens não estão mais guardadas (aprovadas ou apagadas pela limpeza automática).</p>
      )}

      {/* Dados pessoais */}
      <section>
        <h3 className="mb-2 border-b border-slate-200 pb-1 text-xs font-semibold uppercase tracking-wide text-slate-500">Identificação</h3>
        <dl className="grid grid-cols-[8rem_1fr] gap-x-3 gap-y-1 text-sm">
          <dt className="text-slate-500">Nome</dt>
          <dd className="font-medium text-slate-900">{detalhe.nome ?? "(removido)"}</dd>
          <dt className="text-slate-500">CPF</dt>
          <dd className="tabular-nums text-slate-900">{detalhe.cpf ?? "—"}</dd>
          <dt className="text-slate-500">Nascimento</dt>
          <dd className="text-slate-900">{formatarData(detalhe.data_nascimento)}</dd>
          <dt className="text-slate-500">Enviado em</dt>
          <dd className="text-slate-900">{formatarDataHora(detalhe.criado_em)}</dd>
          <dt className="text-slate-500">Aceite LGPD</dt>
          <dd className="text-slate-900">versão {detalhe.aviso_versao}, em {formatarDataHora(detalhe.aceite_em)}</dd>
        </dl>
      </section>

      {detalhe.menor && (
        <section>
          <h3 className="mb-2 border-b border-slate-200 pb-1 text-xs font-semibold uppercase tracking-wide text-slate-500">Responsável</h3>
          <dl className="grid grid-cols-[8rem_1fr] gap-x-3 gap-y-1 text-sm">
            <dt className="text-slate-500">Nome</dt>
            <dd className="text-slate-900">{detalhe.responsavel_nome ?? "—"}</dd>
            <dt className="text-slate-500">Telefone</dt>
            <dd className="tabular-nums text-slate-900">{detalhe.responsavel_telefone ?? "—"}</dd>
          </dl>
        </section>
      )}

      <section>
        <h3 className="mb-2 border-b border-slate-200 pb-1 text-xs font-semibold uppercase tracking-wide text-slate-500">
          {atualizacao ? "Hoje × pedido" : "Dados do cadastro"}
        </h3>
        <div className="overflow-x-auto">
          <table className="min-w-full text-sm">
            <thead>
              <tr className="text-left text-xs uppercase tracking-wide text-slate-500">
                <th scope="col" className="py-1 pr-3 font-semibold">Campo</th>
                {atualizacao && <th scope="col" className="py-1 pr-3 font-semibold">Hoje</th>}
                <th scope="col" className="py-1 font-semibold">{atualizacao ? "Pedido" : "Informado"}</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100">
              {linhas.map((l) => (
                <tr key={l.chave} className={l.mudou ? "bg-amber-50" : undefined}>
                  <th scope="row" className="py-1.5 pr-3 text-left font-normal text-slate-500">{l.rotulo}</th>
                  {atualizacao && <td className="py-1.5 pr-3 text-slate-700">{l.atual}</td>}
                  <td className={"py-1.5 " + (l.mudou ? "font-semibold text-slate-900" : "text-slate-800")}>{l.novo}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>

      {pendente && podeAprovar && (
        <div className="flex flex-wrap gap-2 border-t border-slate-200 pt-4">
          <Button icone={Check} onClick={() => onAprovar(semCasa ? casaId : undefined)} disabled={ocupado || (detalhe.cpf_conflito && !atualizacao) || (semCasa && casaId === "")}>
            Aprovar
          </Button>
          <Button variante="perigo" icone={X} onClick={onRecusar} disabled={ocupado}>
            Recusar
          </Button>
        </div>
      )}
    </div>
  );
}
'''},
    "src/modules/cadastrosPendentes/services/cadastrosPendentes.ts": {"sha": ["e96898d27f1e4666e79166e9c1754b4f4565c08fd1d0b3fa58d03866196a8384"], "novo": r'''/**
 * SysMúsica — Serviço da tela "Cadastros pendentes". Listar, abrir, contar e recusar passam por funções do banco
 * (que conferem permissão e abrangência). Aprovar e ver as imagens passam por rotas do servidor, porque mexem
 * no armazenamento privado com a chave de serviço.
 */
import { supabase } from "@/lib/supabase";
import { mensagemDoErro } from "@/lib/erros";
import type { ArquivosDoCadastro, DetalheCadastro, FiltroStatus, ResumoCadastro } from "../tipos";

/** Avisa o contador do menu que a fila mudou (aprovar, recusar). */
export const EVENTO_FILA_MUDOU = "sysmusica:cadastros-mudaram";
export function avisarQueFilaMudou(): void {
  if (typeof window !== "undefined") window.dispatchEvent(new Event(EVENTO_FILA_MUDOU));
}

export async function listarCadastros(status: FiltroStatus): Promise<ResumoCadastro[]> {
  const { data, error } = await supabase.rpc("listar_cadastros_pendentes", { p_status: status });
  if (error) throw new Error(mensagemDoErro(error, "Não foi possível carregar os cadastros."));
  return ((data ?? []) as ResumoCadastro[]).map((linha) => ({ ...linha, outros_pendentes: Number(linha.outros_pendentes ?? 0) }));
}

export async function obterCadastro(id: string): Promise<DetalheCadastro> {
  const { data, error } = await supabase.rpc("obter_cadastro_pendente", { p_id: id });
  if (error) throw new Error(mensagemDoErro(error, "Não foi possível abrir o cadastro."));
  if (!data) throw new Error("Não foi possível abrir o cadastro."); // sem erro, mas sem dados (ex.: fora da sua abrangência)
  const d = data as DetalheCadastro;
  return { ...d, outros_pendentes: Number(d.outros_pendentes ?? 0) };
}

/** Quantos pedidos esperam análise (0 para quem não tem permissão; nunca lança erro). */
export async function contarPendentes(): Promise<number> {
  const { data, error } = await supabase.rpc("contar_cadastros_pendentes");
  if (error) return 0;
  return Number(data ?? 0);
}

export async function recusarCadastro(id: string, motivo: string): Promise<void> {
  const { error } = await supabase.rpc("rejeitar_cadastro_pendente", { p_id: id, p_motivo: motivo });
  if (error) throw new Error(mensagemDoErro(error, "Não foi possível recusar o cadastro."));
  avisarQueFilaMudou();
}

/** Chama uma rota do servidor levando o token do login. */
async function chamar<T>(caminho: string, metodo: "GET" | "POST", corpo?: unknown): Promise<T> {
  const { data } = await supabase.auth.getSession();
  const token = data.session?.access_token;
  if (!token) throw new Error("Sua sessão expirou. Entre de novo.");
  const resposta = await fetch(caminho, {
    method: metodo,
    headers: { Authorization: `Bearer ${token}`, ...(corpo === undefined ? {} : { "Content-Type": "application/json" }) },
    body: corpo === undefined ? undefined : JSON.stringify(corpo),
    cache: "no-store",
  });
  const json = (await resposta.json().catch(() => null)) as { erro?: string } | null;
  if (!resposta.ok) throw new Error(json?.erro ?? "Não foi possível concluir a operação.");
  return json as T;
}

export function arquivosDoCadastro(id: string): Promise<ArquivosDoCadastro> {
  return chamar<ArquivosDoCadastro>(`/api/cadastros/${id}/arquivos`, "GET");
}

/** `casaId`: obrigatório quando o pedido veio com uma Casa de Oração digitada (que não estava cadastrada). */
export async function aprovarCadastro(id: string, casaId?: string): Promise<{ membro_id: string }> {
  const r = await chamar<{ membro_id: string }>(`/api/cadastros/${id}/aprovar`, "POST", casaId ? { casa_id: casaId } : {});
  avisarQueFilaMudou();
  return r;
}
'''},
    "src/app/api/cadastros/[id]/aprovar/route.ts": {"sha": ["69e84e31b4b526d78bcd177ce578d0fbff3200270ad0f827683cf8268fed6909"], "novo": r'''/**
 * SysMúsica — POST /api/cadastros/[id]/aprovar: aprova um cadastro pendente.
 *
 * Fluxo (precisa da permissão cadastros.aprovar e da abrangência, conferidas no banco):
 *  1) lê o pedido como o usuário (confirma que ele existe, está PENDENTE e é visível para quem aprova);
 *  2) MOVE as 3 imagens da fila para as pastas finais do membro (fotos-membros / documentos-membros);
 *  3) chama aprovar_cadastro_pendente COMO O USUÁRIO (cria/atualiza o membro e registra quem aprovou);
 *  4) se o banco recusar, DEVOLVE as imagens à fila; se aprovar, apaga as imagens antigas (atualização).
 */
import { NextResponse } from "next/server";
import { exigirPermissao } from "@/modules/administracao/server/autorizacao";
import { clienteAdmin } from "@/modules/administracao/server/clienteAdmin";
import { ErroHttp } from "@/modules/administracao/server/erros";
import { respostaDeErro } from "@/modules/administracao/server/resposta";
import { apagar, desfazer, moverTodos, movimentosDaAprovacao } from "@/modules/cadastroPublico/server/arquivos";
import { erroDoBanco, exigirUuid } from "@/modules/cadastroPublico/server/erros";
import { clienteDoUsuario } from "@/modules/cadastroPublico/server/usuario";

interface Detalhe {
  casa_oracao_id: string | null;
  tipo: "NOVO" | "ATUALIZACAO";
  status: string;
  membro_id: string | null;
  arquivos_disponiveis: boolean;
  atual: unknown;
}

interface ResultadoAprovacao {
  membro_id: string;
  antigos: { foto?: string | null; doc_frente?: string | null; doc_verso?: string | null };
}

export async function POST(request: Request, contexto: { params: Promise<{ id: string }> }) {
  try {
    const id = exigirUuid((await contexto.params).id);
    await exigirPermissao(request, "cadastros.aprovar");
    const usuario = clienteDoUsuario(request);

    // Corpo opcional: { casa_id } — a Casa de Oração escolhida por quem aprova (pedido com casa digitada)
    let casaId: string | null = null;
    try {
      const corpo = (await request.json()) as { casa_id?: unknown } | null;
      if (corpo && corpo.casa_id !== undefined && corpo.casa_id !== null && corpo.casa_id !== "") casaId = exigirUuid(corpo.casa_id);
    } catch (e) {
      if (e instanceof ErroHttp) throw e; // id inválido: devolve o erro
      casaId = null; // sem corpo / corpo vazio: segue sem casa escolhida
    }

    const { data, error } = await usuario.rpc("obter_cadastro_pendente", { p_id: id });
    if (error) throw erroDoBanco(error);
    const pedido = data as Detalhe;
    if (pedido.status !== "PENDENTE") throw new ErroHttp(409, "Este cadastro já foi analisado.");
    if (!pedido.arquivos_disponiveis) throw new ErroHttp(409, "As imagens deste cadastro não estão mais disponíveis. Recuse o pedido.");
    if (!pedido.casa_oracao_id && !casaId) {
      throw new ErroHttp(400, "Este pedido trouxe uma Casa de Oração que não está cadastrada. Escolha a casa correta antes de aprovar.");
    }
    if (pedido.tipo === "ATUALIZACAO" && !pedido.atual) {
      throw new ErroHttp(409, "O membro deste pedido foi excluído. Recuse o pedido.");
    }

    // Atualização usa a pasta do membro existente; cadastro novo ganha um id novo (que o banco usa no INSERT)
    const membroId = pedido.tipo === "ATUALIZACAO" && pedido.membro_id ? pedido.membro_id : crypto.randomUUID();
    const mov = movimentosDaAprovacao(id, membroId, () => crypto.randomUUID());

    const admin = clienteAdmin();
    let feitos;
    try {
      feitos = await moverTodos(admin, [mov.foto, mov.frente, mov.verso]);
    } catch (e) {
      console.error("Falha ao mover as imagens do cadastro", id, e);
      throw new ErroHttp(409, "Não foi possível preparar as imagens. Atualize a lista e tente de novo.");
    }

    const { data: resultado, error: erroAprovar } = await usuario.rpc("aprovar_cadastro_pendente", {
      p_id: id,
      p_membro: pedido.tipo === "NOVO" ? membroId : null,
      p_foto: mov.foto.para.caminho,
      p_doc_frente: mov.frente.para.caminho,
      p_doc_verso: mov.verso.para.caminho,
      p_casa: pedido.casa_oracao_id ? null : casaId, // só vale quando o pedido não tem casa
    });
    if (erroAprovar) {
      await desfazer(admin, feitos); // o banco recusou: as imagens voltam para a fila
      throw erroDoBanco(erroAprovar);
    }

    // Atualização: apaga a foto e o documento que foram substituídos
    const antigos = (resultado as ResultadoAprovacao).antigos ?? {};
    await apagar(admin, "fotos-membros", [antigos.foto]);
    await apagar(admin, "documentos-membros", [antigos.doc_frente, antigos.doc_verso]);

    return NextResponse.json({ membro_id: (resultado as ResultadoAprovacao).membro_id }, { headers: { "Cache-Control": "no-store" } });
  } catch (erro) {
    return respostaDeErro(erro);
  }
}
'''},
    "src/app/(painel)/cadastros-pendentes/page.tsx": {"sha": ["0cafc35abaddb83f1403ca457f0335e79a7d38d4bf3b661dac521ce6dfd8c13c"], "novo": r'''"use client";

/**
 * SysMúsica — Página /cadastros-pendentes: cadastros enviados pelo link público (/cadastro), aguardando análise.
 * Aprovar cria o membro (ou atualiza o que já existe); Recusar exige um motivo. Nada entra no sistema sem aprovação.
 * Cada pessoa só enxerga os pedidos das Casas de Oração da sua abrangência.
 */
import { useCallback, useEffect, useState } from "react";
import {
  aprovarCadastro,
  avisarQueFilaMudou,
  listarCadastros,
  obterCadastro,
  recusarCadastro,
} from "@/modules/cadastrosPendentes/services/cadastrosPendentes";
import DetalheDoCadastro from "@/modules/cadastrosPendentes/components/DetalheCadastro";
import TabelaCadastros from "@/modules/cadastrosPendentes/components/TabelaCadastros";
import { validarMotivo } from "@/modules/cadastrosPendentes/regras";
import type { DetalheCadastro, FiltroStatus, ResumoCadastro } from "@/modules/cadastrosPendentes/tipos";
import { useSessao } from "@/modules/autenticacao/SessaoProvider";
import ConfirmDialog from "@/components/ui/ConfirmDialog";
import Drawer from "@/components/ui/Drawer";
import EmptyState from "@/components/ui/EmptyState";
import ErrorState from "@/components/ui/ErrorState";
import Notificacao from "@/components/ui/Notificacao";
import PageHeader from "@/components/ui/PageHeader";
import Skeleton from "@/components/ui/Skeleton";

const FILTROS: { valor: FiltroStatus; rotulo: string }[] = [
  { valor: "PENDENTE", rotulo: "Pendentes" },
  { valor: "APROVADO", rotulo: "Aprovados" },
  { valor: "REJEITADO", rotulo: "Recusados" },
  { valor: "EXPIRADO", rotulo: "Vencidos" },
  { valor: "TODOS", rotulo: "Todos" },
];

export default function CadastrosPendentesPage() {
  const { pode } = useSessao();
  const [filtro, setFiltro] = useState<FiltroStatus>("PENDENTE");
  const [itens, setItens] = useState<ResumoCadastro[]>([]);
  const [carregando, setCarregando] = useState(true);
  const [erro, setErro] = useState<string | null>(null);
  const [aberto, setAberto] = useState<DetalheCadastro | null>(null);
  const [abrindoId, setAbrindoId] = useState<string | null>(null);
  const [confirmando, setConfirmando] = useState<"aprovar" | "recusar" | null>(null);
  const [motivo, setMotivo] = useState("");
  const [erroDecisao, setErroDecisao] = useState<string | null>(null);
  const [processando, setProcessando] = useState(false);
  const [aviso, setAviso] = useState<string | null>(null);
  const [casaEscolhida, setCasaEscolhida] = useState(""); // casa escolhida ao aprovar um pedido com casa digitada

  const carregar = useCallback(async (status: FiltroStatus) => {
    try {
      setItens(await listarCadastros(status));
      setErro(null);
    } catch (e) {
      console.error("Falha ao carregar cadastros pendentes:", e);
      setErro("Não foi possível carregar os cadastros. Verifique a conexão e tente novamente.");
    } finally {
      setCarregando(false);
    }
  }, []);

  useEffect(() => {
    // O setState só roda DEPOIS do await, então o aviso da regra set-state-in-effect não se aplica aqui.
    // eslint-disable-next-line react-hooks/set-state-in-effect
    void carregar(filtro);
  }, [carregar, filtro]);

  function trocarFiltro(novo: FiltroStatus) {
    setCarregando(true);
    setFiltro(novo);
  }

  async function abrir(item: ResumoCadastro) {
    if (abrindoId) return;
    setAbrindoId(item.id);
    setAviso(null);
    try {
      setAberto(await obterCadastro(item.id));
    } catch (e) {
      setAviso(e instanceof Error ? e.message : "Não foi possível abrir o cadastro.");
    } finally {
      setAbrindoId(null);
    }
  }

  function fecharDecisao() {
    setConfirmando(null);
    setCasaEscolhida("");
    setMotivo("");
    setErroDecisao(null);
  }

  async function decidir() {
    if (!aberto || !confirmando) return;
    if (confirmando === "recusar") {
      const problema = validarMotivo(motivo);
      if (problema) return setErroDecisao(problema);
    }
    setProcessando(true);
    setErroDecisao(null);
    try {
      if (confirmando === "aprovar") {
        await aprovarCadastro(aberto.id, casaEscolhida || undefined);
        setAviso(
          aberto.tipo === "NOVO"
            ? `Cadastro de "${aberto.nome}" aprovado: o membro foi criado.`
            : `Cadastro de "${aberto.nome}" aprovado: os dados do membro foram atualizados.`
        );
      } else {
        await recusarCadastro(aberto.id, motivo.trim());
        setAviso(`Cadastro de "${aberto.nome}" recusado.`);
      }
      fecharDecisao();
      setAberto(null);
      await carregar(filtro);
    } catch (e) {
      setErroDecisao(e instanceof Error ? e.message : "Não foi possível concluir.");
      avisarQueFilaMudou(); // se outro aprovador já decidiu, o contador do menu se acerta
    } finally {
      setProcessando(false);
    }
  }

  return (
    <main className="text-slate-900">
      <div className="mx-auto max-w-7xl px-4 py-8 sm:px-6 lg:px-8">
        <PageHeader
          titulo="Cadastros pendentes"
          descricao="Cadastros enviados pelo link público. Nada entra no sistema sem a sua aprovação."
        />

        <div role="group" aria-label="Filtrar por situação" className="mb-4 flex flex-wrap gap-1">
          {FILTROS.map((f) => (
            <button
              key={f.valor}
              type="button"
              aria-pressed={filtro === f.valor}
              onClick={() => trocarFiltro(f.valor)}
              className={
                "rounded-lg px-3 py-1.5 text-sm font-medium transition " +
                (filtro === f.valor ? "bg-brand-600 text-white" : "bg-slate-100 text-slate-700 hover:bg-slate-200")
              }
            >
              {f.rotulo}
            </button>
          ))}
        </div>

        {carregando ? (
          <div role="status" aria-live="polite" className="space-y-3">
            <span className="sr-only">Carregando cadastros...</span>
            {[0, 1, 2, 3].map((i) => (
              <Skeleton key={i} className="h-12" />
            ))}
          </div>
        ) : erro ? (
          <ErrorState
            titulo="Não foi possível carregar os cadastros."
            mensagem={erro}
            onTentarNovamente={() => {
              setCarregando(true);
              void carregar(filtro);
            }}
          />
        ) : itens.length === 0 ? (
          <EmptyState
            titulo={filtro === "PENDENTE" ? "Nenhum cadastro aguardando análise." : "Nenhum cadastro nesta situação."}
            descricao="O link para divulgar é o endereço do sistema seguido de /cadastro (há um botão para copiá-lo em Músicos / Organistas)."
          />
        ) : (
          <TabelaCadastros itens={itens} onAbrir={(item) => void abrir(item)} />
        )}
      </div>

      <Drawer
        aberto={aberto !== null}
        onFechar={() => setAberto(null)}
        titulo={aberto?.nome ?? "Cadastro"}
        descricao="Confira os dados e as imagens antes de decidir."
      >
        {aberto && (
          <DetalheDoCadastro
            key={aberto.id}
            detalhe={aberto}
            podeAprovar={pode("cadastros.aprovar")}
            ocupado={processando}
            onAprovar={(casaId) => {
              setErroDecisao(null);
              setCasaEscolhida(casaId ?? "");
              setConfirmando("aprovar");
            }}
            onRecusar={() => {
              setErroDecisao(null);
              setConfirmando("recusar");
            }}
          />
        )}
      </Drawer>

      <ConfirmDialog
        aberto={confirmando !== null}
        titulo={confirmando === "aprovar" ? "Aprovar este cadastro?" : "Recusar este cadastro?"}
        mensagem={
          <>
            {confirmando === "aprovar" ? (
              <p>
                {aberto?.tipo === "NOVO" ? (
                  <>
                    O membro <strong>{aberto?.nome}</strong> será criado com estes dados.
                  </>
                ) : (
                  <>
                    Os dados de <strong>{aberto?.nome}</strong> serão substituídos pelos do pedido.
                  </>
                )}
              </p>
            ) : (
              <div className="space-y-2">
                <p>Explique o motivo. Ele fica registrado para a secretaria; a pessoa não é avisada pelo sistema.</p>
                <label htmlFor="motivo-recusa" className="sr-only">
                  Motivo da recusa
                </label>
                <textarea
                  id="motivo-recusa"
                  rows={3}
                  maxLength={300}
                  value={motivo}
                  onChange={(e) => setMotivo(e.target.value)}
                  className="w-full rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 shadow-sm focus:border-brand-500 focus:outline-none focus:ring-2 focus:ring-brand-200 [color-scheme:light]"
                  placeholder="Ex.: documento ilegível, envie novamente"
                />
              </div>
            )}
            {erroDecisao && (
              <p role="alert" className="mt-3 rounded-lg bg-red-50 px-3 py-2 text-red-700">
                {erroDecisao}
              </p>
            )}
          </>
        }
        textoConfirmar={confirmando === "aprovar" ? "Aprovar" : "Recusar"}
        processando={processando}
        onConfirmar={() => void decidir()}
        onCancelar={fecharDecisao}
      />

      <Notificacao mensagem={aviso} onFechar={() => setAviso(null)} />
    </main>
  );
}
'''},
}


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
    elif hashlib.sha256(norm(ler(caminho)).encode("utf-8")).hexdigest() not in ([info["sha"]] if isinstance(info["sha"], str) else info["sha"]):
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
  if "$@" > /tmp/p9aj4-passo.out 2>&1; then
    echo "  ok"
  else
    echo "  FALHOU: $nome"; tail -40 /tmp/p9aj4-passo.out
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
echo "Lembrete: o SQL 0043 precisa ter sido rodado no Supabase ANTES de testar as telas."
echo "Depois confira as telas (passo a passo na conversa) e, se estiver tudo certo, faça o git push."
) 2>&1 | tee "$LOG"
